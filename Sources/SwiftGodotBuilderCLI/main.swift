import Foundation

@main
enum SwiftGodotBuilderCLI {
  static func main() {
    do {
      let command = try CLIConfig.parseCommand(arguments: CommandLine.arguments)
      switch command {
      case let .clean(cacheRoot, quiet):
        let logger = Logger(verbose: false, quiet: quiet)
        try CacheCleaner.clean(cacheRoot: cacheRoot, logger: logger)
      case let .build(config):
        let logger = Logger(verbose: config.verbose, quiet: config.quiet)
        let scaffold = PlaygroundScaffold(config: config, logger: logger)

        try scaffold.prepare()
        try scaffold.build()

        if config.runGodot {
          try scaffold.launchGodot()
        } else {
          logger.info("Godot project ready at \(scaffold.godotProjectPath.path)")
        }
      }
    } catch let error as CLIError {
      fputs("error: \(error.message)\n", stderr)
      exit(1)
    } catch {
      fputs("error: \(error.localizedDescription)\n", stderr)
      exit(1)
    }
  }
}

struct CLIError: Error {
  let message: String
  init(_ message: String) { self.message = message }
}

enum BuildConfiguration: String {
  case debug, release
}

private enum CLICommand {
  case build(CLIConfig)
  case clean(cacheRoot: URL, quiet: Bool)
}

private struct CLIConfig {
  let viewFile: URL
  let viewSource: String
  let viewType: String
  let assetDirectories: [URL]
  let includeDirectories: [URL]
  let godotCommand: String
  let runGodot: Bool
  let cacheRoot: URL
  let builderDependency: BuilderDependency
  let buildConfiguration: BuildConfiguration
  let verbose: Bool
  let quiet: Bool
  let workspaceDirectory: URL
  let codesign: Bool
  let customProjectGodot: URL?

  static func parseCommand(arguments: [String]) throws -> CLICommand {
    let args = Array(arguments.dropFirst())
    if args.isEmpty || args.contains(where: { $0 == "--help" || $0 == "-h" }) {
      printUsage()
      exit(0)
    }

    var viewPath: String?
    var explicitViewType: String?
    var assetDirectories: [URL] = []
    var includeDirectories: [URL] = []
    var godotCommand: String?
    var runGodot = true
    var cacheRoot = Self.defaultCacheRoot()
    var builderPathOverride: URL?
    var buildConfiguration: BuildConfiguration = .debug
    var verbose = false
    var quiet = false
    var cleanCache = false
    var codesign = false
    var customProjectGodot: URL?
    let baseDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)

    var index = 0
    while index < args.count {
      let token = args[index]
      switch token {
      case "--view":
        index += 1
        guard index < args.count else { throw CLIError("--view requires a type name") }
        explicitViewType = args[index]
      case "--assets", "--assets-dir":
        index += 1
        guard index < args.count else { throw CLIError("\(token) requires a directory path") }
        let dirURL = Self.absoluteURL(for: args[index], baseDirectory: baseDirectory)
        guard Self.directoryExists(at: dirURL) else {
          throw CLIError("Assets directory not found at \(dirURL.path)")
        }
        assetDirectories.append(dirURL)
      case "--include":
        index += 1
        guard index < args.count else { throw CLIError("--include requires a directory path") }
        let dirURL = Self.absoluteURL(for: args[index], baseDirectory: baseDirectory)
        guard Self.directoryExists(at: dirURL) else {
          throw CLIError("Include directory not found at \(dirURL.path)")
        }
        includeDirectories.append(dirURL)
      case "--godot":
        index += 1
        guard index < args.count else { throw CLIError("--godot requires a command path") }
        godotCommand = args[index]
      case "--cache":
        index += 1
        guard index < args.count else { throw CLIError("--cache requires a directory") }
        cacheRoot = Self.absoluteURL(for: args[index], baseDirectory: baseDirectory)
      case "--no-run":
        runGodot = false
      case "--builder-path":
        index += 1
        guard index < args.count else { throw CLIError("--builder-path requires a directory") }
        builderPathOverride = Self.absoluteURL(for: args[index], baseDirectory: baseDirectory)
      case "--verbose":
        verbose = true
      case "--quiet":
        quiet = true
      case "--clean":
        cleanCache = true
      case "--release":
        buildConfiguration = .release
      case "--debug":
        buildConfiguration = .debug
      case "--codesign":
        codesign = true
      case "--project":
        index += 1
        guard index < args.count else { throw CLIError("--project requires a file path") }
        let projectURL = Self.absoluteURL(for: args[index], baseDirectory: baseDirectory)
        guard FileManager.default.fileExists(atPath: projectURL.path) else {
          throw CLIError("Project file not found at \(projectURL.path)")
        }
        customProjectGodot = projectURL
      default:
        if token.hasPrefix("--") {
          throw CLIError("Unknown option: \(token)")
        }
        if viewPath == nil {
          viewPath = token
        } else {
          throw CLIError("Unexpected argument: \(token)")
        }
      }
      index += 1
    }

    if quiet && verbose {
      throw CLIError("Cannot enable both --quiet and --verbose")
    }

    if cleanCache {
      return .clean(cacheRoot: cacheRoot, quiet: quiet)
    }

    guard let path = viewPath else {
      throw CLIError("Missing Swift view file path")
    }

    let viewFile = Self.absoluteURL(for: path, baseDirectory: baseDirectory)
    guard FileManager.default.fileExists(atPath: viewFile.path) else {
      throw CLIError("View file not found at \(viewFile.path)")
    }

    let viewSource = try String(contentsOf: viewFile)
    let viewType = try explicitViewType ?? detectViewType(in: viewSource)
    let workspaceName = makeWorkspaceName(viewFile: viewFile, viewType: viewType)
    let workspaceDirectory = cacheRoot.appendingPathComponent(workspaceName, isDirectory: true)
    let builderDependency = BuilderDependency.resolve(
      overridePath: builderPathOverride,
      baseDirectory: baseDirectory
    )
    let resolvedGodotCommand = godotCommand ?? resolveGodotCommand()

    return .build(
      CLIConfig(
        viewFile: viewFile,
        viewSource: viewSource,
        viewType: viewType,
        assetDirectories: assetDirectories,
        includeDirectories: includeDirectories,
        godotCommand: resolvedGodotCommand,
        runGodot: runGodot,
        cacheRoot: cacheRoot,
        builderDependency: builderDependency,
        buildConfiguration: buildConfiguration,
        verbose: verbose,
        quiet: quiet,
        workspaceDirectory: workspaceDirectory,
        codesign: codesign,
        customProjectGodot: customProjectGodot
      )
    )
  }

  private static func printUsage() {
    let message = """
    Usage: swiftgodotbuilder <GView.swift> [options]

    Options:
      --include <dir>         Copy .swift files from directory into sources (repeatable)
      --assets <dir>          Symlink an assets directory into the Godot project
      --project <file>        Use a custom project.godot file (Use "res://main.tscn" for main_scene)
      --godot <command>       Path to Godot (default: PATH, then mdfind on macOS)
      --cache <dir>           Workspace cache directory (default: ~/.swiftgodotbuilder/playgrounds)
      --builder-path <path>   Override the SwiftGodotBuilder dependency path
      --view <Type>           Override the GView type to instantiate
      --verbose               Print extra logs and commands
      --quiet                 Suppress informational logs
      --clean                 Delete cached playgrounds and exit
      --release               Build in release mode
      --debug                 Build in debug mode (default)
      --no-run                Do not launch Godot after building
      --codesign              Codesign dylibs
      -h, --help              Show this help text
    """
    print(message)
  }

  private static func detectViewType(in source: String) throws -> String {
    // Take the first struct/class that declares conformance to GView; good enough for quick previews.
    let pattern = #"(?:(?:public|internal|fileprivate|open|final)\s+)*(?:struct|class)\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*[^\{]*\bG?View\b"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
      throw CLIError("Failed to build parser for view type")
    }
    let range = NSRange(source.startIndex ..< source.endIndex, in: source)
    if let match = regex.firstMatch(in: source, options: [], range: range),
       let nameRange = Range(match.range(at: 1), in: source)
    {
      return String(source[nameRange])
    }
    throw CLIError("Unable to detect a type conforming to GView. Pass --view <TypeName> explicitly.")
  }

  private static func makeWorkspaceName(viewFile: URL, viewType: String) -> String {
    // Deterministic folder = cached builds per view file/type combo; avoids rebuilding if nothing changed.
    let base = sanitize(viewFile.deletingPathExtension().lastPathComponent)
    let hash = stableHash(viewFile.path + ":" + viewType)
    return "\(base)-\(hash)"
  }

  private static func sanitize(_ component: String) -> String {
    let allowed = component
      .replacingOccurrences(of: " ", with: "_")
      .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
    return allowed.isEmpty ? "Playground" : allowed
  }

  static func stableHash(_ value: String) -> String {
    var hash: UInt64 = 5381
    for byte in value.utf8 {
      hash = ((hash << 5) &+ hash) &+ UInt64(byte)
    }
    return String(format: "%016llx", hash)
  }

  private static func defaultCacheRoot() -> URL {
    let home = FileManager.default.homeDirectoryForCurrentUser
    return home.appendingPathComponent(".swiftgodotbuilder/playgrounds", isDirectory: true)
  }

  private static func absoluteURL(for path: String, baseDirectory: URL) -> URL {
    URL(fileURLWithPath: path, relativeTo: baseDirectory).standardizedFileURL
  }

  private static func directoryExists(at url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
  }

  private static func resolveGodotCommand() -> String {
    // Check if godot is available in PATH
    let which = Process()
    which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    which.arguments = ["godot"]
    which.standardOutput = Pipe()
    which.standardError = Pipe()
    do {
      try which.run()
      which.waitUntilExit()
      if which.terminationStatus == 0 {
        return "godot"
      }
    } catch {}

    #if os(macOS)
      // Try mdfind to locate Godot by bundle identifier
      let mdfindProcess = Process()
      mdfindProcess.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
      mdfindProcess.arguments = ["kMDItemCFBundleIdentifier = \"org.godotengine.godot\""]
      let mdfindPipe = Pipe()
      mdfindProcess.standardOutput = mdfindPipe
      mdfindProcess.standardError = Pipe()
      do {
        try mdfindProcess.run()
        mdfindProcess.waitUntilExit()
        if mdfindProcess.terminationStatus == 0 {
          let data = mdfindPipe.fileHandleForReading.readDataToEndOfFile()
          if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
             !output.isEmpty, let appPath = output.components(separatedBy: "\n").first
          {
            let execPath = "\(appPath)/Contents/MacOS/Godot"
            if FileManager.default.fileExists(atPath: execPath) {
              return execPath
            }
          }
        }
      } catch {}
    #endif

    // Default to godot and let it fail with a clear error if not found
    return "godot"
  }
}

private enum BuilderDependency {
  case local(URL)
  case remote

  static func resolve(overridePath: URL?, baseDirectory: URL) -> BuilderDependency {
    if let override = overridePath {
      return .local(override)
    }
    if let env = ProcessInfo.processInfo.environment["SWIFTGODOTBUILDER_PATH"] {
      let url = URL(fileURLWithPath: env, relativeTo: baseDirectory).standardizedFileURL
      if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
        return .local(url)
      }
    }
    if let inferred = inferredPackageRoot() {
      return .local(inferred)
    }
    return .remote
  }

  var manifestEntry: String {
    switch self {
    case let .local(url):
      return #".package(name: "SwiftGodotBuilder", path: "\#(url.path)")"#
    case .remote:
      return #".package(url: "https://github.com/Maxim-Lanskoy/SwiftGodotBuilder", branch: "tweaks")"#
    }
  }

  private static func inferredPackageRoot() -> URL? {
    // If the CLI ships inside the repo, prefer the checked-out sources so changes are reflected instantly.
    let fileURL = URL(fileURLWithPath: #filePath)
    let root = fileURL
      .deletingLastPathComponent() // main.swift
      .deletingLastPathComponent() // SwiftGodotBuilderCLI
      .deletingLastPathComponent() // Sources
    let packageFile = root.appendingPathComponent("Package.swift")
    return FileManager.default.fileExists(atPath: packageFile.path) ? root : nil
  }
}

private struct PlaygroundScaffold {
  let config: CLIConfig
  let logger: Logger
  private let targetName = "SwiftGodotBuilderPlayground"
  private let fileManager = FileManager.default

  private var rootClassName: String {
    let cleaned = config.viewType.filter { $0.isLetter || $0.isNumber }
    return "\(cleaned.isEmpty ? "View" : cleaned)RootNode"
  }

  private var packageDirectory: URL {
    config.workspaceDirectory.appendingPathComponent("SwiftPackage", isDirectory: true)
  }

  private var sourcesDirectory: URL {
    packageDirectory
      .appendingPathComponent("Sources", isDirectory: true)
      .appendingPathComponent(targetName, isDirectory: true)
  }

  private var godotDirectory: URL {
    config.workspaceDirectory.appendingPathComponent("GodotProject", isDirectory: true)
  }

  private var godotBinDirectory: URL {
    godotDirectory.appendingPathComponent("bin", isDirectory: true)
  }

  private var godotHiddenDirectory: URL {
    godotDirectory.appendingPathComponent(".godot", isDirectory: true)
  }

  var godotProjectPath: URL { godotDirectory }

  func prepare() throws {
    try ensureDirectories()
    try writeSwiftSources()
    try writePackageManifest()
    try writeGodotFiles()
    try linkAssetDirectories()
  }

  func build() throws {
    logger.info("Building Swift package in \(packageDirectory.path)...")
    try runProcess(["swift", "build", "-c", config.buildConfiguration.rawValue], in: packageDirectory, suppressOutput: config.quiet)
    guard let binPathString = try runProcess(
      [
        "swift",
        "build",
        "-c",
        config.buildConfiguration.rawValue,
        "--show-bin-path",
      ],
      in: packageDirectory,
      captureOutput: true,
      suppressOutput: config.quiet
    )?.trimmingCharacters(in: .whitespacesAndNewlines), !binPathString.isEmpty else {
      // Some SwiftPM setups don't use .build/debug; rely on --show-bin-path so we copy the right dylibs.
      throw CLIError("Unable to determine Swift build output path")
    }

    let binDirectory = URL(fileURLWithPath: binPathString, isDirectory: true)
    try syncLibraries(binDirectory: binDirectory)
    if !config.assetDirectories.isEmpty {
      try runHeadlessImport()
    }
  }

  func launchGodot() throws {
    logger.info("Launching Godot from \(godotDirectory.path)...")

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [config.godotCommand, "--path", godotDirectory.path, "--disable-crash-handler"]
    process.currentDirectoryURL = config.workspaceDirectory
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError

    // Set up signal handler to forward SIGINT to Godot
    let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    signal(SIGINT, SIG_IGN) // Ignore default handler
    signalSource.setEventHandler {
      process.terminate()
    }
    signalSource.resume()

    try process.run()
    process.waitUntilExit()

    signalSource.cancel()
  }

  private func ensureDirectories() throws {
    try fileManager.createDirectory(at: config.cacheRoot, withIntermediateDirectories: true, attributes: nil)
    try fileManager.createDirectory(at: config.workspaceDirectory, withIntermediateDirectories: true, attributes: nil)
    try fileManager.createDirectory(at: packageDirectory, withIntermediateDirectories: true, attributes: nil)
    // Clean stale .swift files but preserve directory to avoid triggering SPM rebuilds
    if fileManager.fileExists(atPath: sourcesDirectory.path) {
      let contents = try fileManager.contentsOfDirectory(at: sourcesDirectory, includingPropertiesForKeys: nil)
      for file in contents where file.pathExtension == "swift" {
        try fileManager.removeItem(at: file)
      }
    }
    try fileManager.createDirectory(at: sourcesDirectory, withIntermediateDirectories: true, attributes: nil)
    try fileManager.createDirectory(at: godotDirectory, withIntermediateDirectories: true, attributes: nil)
    try fileManager.createDirectory(at: godotBinDirectory, withIntermediateDirectories: true, attributes: nil)
    try fileManager.createDirectory(at: godotHiddenDirectory, withIntermediateDirectories: true, attributes: nil)
  }

  private func writeSwiftSources() throws {
    // Copy the main view file
    let destination = sourcesDirectory.appendingPathComponent(config.viewFile.lastPathComponent)
    try writeIfChanged(config.viewSource, to: destination)

    // Copy .swift files from included directories
    for includeDir in config.includeDirectories {
      try copySwiftFiles(from: includeDir)
    }

    let entryPoint = """
    import SwiftGodot
    import SwiftGodotBuilder

    #initSwiftExtension(
      cdecl: "swift_entry_point",
      types: [\(rootClassName).self] + BuilderRegistry.types
    )

    @Godot
    final class \(rootClassName): Node2D {
      override func _ready() {
        let node = \(config.viewType)().toNode()
        addChild(node: node)
      }
    }
    """

    let entryURL = sourcesDirectory.appendingPathComponent("PlaygroundRoot.swift")
    try writeIfChanged(entryPoint, to: entryURL)
  }

  private func writeIfChanged(_ contents: String, to file: URL) throws {
    let data = Data(contents.utf8)
    // Important: avoid touching the file if contents are unchanged to prevent unnecessary rebuilds.
    if let existing = try? Data(contentsOf: file), existing == data {
      return
    }
    try data.write(to: file, options: [.atomic])
  }

  private func copySwiftFiles(from directory: URL) throws {
    let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    for file in contents where file.pathExtension == "swift" {
      let destination = sourcesDirectory.appendingPathComponent(file.lastPathComponent)
      // Skip if already exists (main view file takes precedence)
      guard !fileManager.fileExists(atPath: destination.path) else {
        logger.debug("Skipping \(file.lastPathComponent) (already exists)")
        continue
      }
      let source = try String(contentsOf: file)
      try writeIfChanged(source, to: destination)
      logger.debug("Copied: \(file.lastPathComponent)")
    }
  }

  private func writePackageManifest() throws {
    let manifest = """
    // swift-tools-version: 6.2
    import PackageDescription

    let package = Package(
      name: "\(targetName)",
      platforms: [.macOS(.v14)],
      products: [
        .library(name: "\(targetName)", type: .dynamic, targets: ["\(targetName)"])
      ],
      dependencies: [
        \(config.builderDependency.manifestEntry),
        .package(url: "https://github.com/migueldeicaza/SwiftGodot", branch: "main")
      ],
      targets: [
        .target(
          name: "\(targetName)",
          dependencies: [
            "SwiftGodotBuilder",
            .product(name: "SwiftGodot", package: "SwiftGodot")
          ],
          path: "Sources"
        )
      ]
    )
    """

    let packageURL = packageDirectory.appendingPathComponent("Package.swift")
    try writeIfChanged(manifest, to: packageURL)
  }

  private func writeGodotFiles() throws {
    let projectGodotPath = godotDirectory.appendingPathComponent("project.godot")

    if let customProject = config.customProjectGodot {
      if fileManager.fileExists(atPath: projectGodotPath.path) {
        try fileManager.removeItem(at: projectGodotPath)
      }
      try fileManager.copyItem(at: customProject, to: projectGodotPath)
      logger.debug("Using custom project.godot from \(customProject.path)")
    } else {
      let projectGodot = """
      config_version=5

      [application]
      config/name="SwiftGodotBuilderPlayground"
      run/main_scene="res://main.tscn"
      config/features=PackedStringArray("4.4")

      [display]
      window/size/viewport_width=320
      window/size/viewport_height=180
      window/size/window_width_override=640
      window/size/window_height_override=360
      window/stretch/mode="viewport"
      window/stretch/scale_mode="integer"
      """

      try projectGodot.write(to: projectGodotPath, atomically: true, encoding: .utf8)
    }

    let scene = """
    [gd_scene format=3]

    [node name="Root" type="\(rootClassName)"]
    """

    try scene.write(
      to: godotDirectory.appendingPathComponent("main.tscn"),
      atomically: true,
      encoding: .utf8
    )

    let extensionFile = """
    [configuration]
    entry_symbol = "swift_entry_point"
    compatibility_minimum = 4.2

    [libraries]
    macos.debug = "res://bin/lib\(targetName).dylib"
    macos.release = "res://bin/lib\(targetName).dylib"
    windows.debug.x86_64 = "res://bin/\(targetName).dll"
    windows.release.x86_64 = "res://bin/\(targetName).dll"
    linux.debug.x86_64 = "res://bin/lib\(targetName).so"
    linux.release.x86_64 = "res://bin/lib\(targetName).so"

    [dependencies]
    macos.debug = { "res://bin/libSwiftGodot.dylib": "Contents/Frameworks" }
    macos.release = { "res://bin/libSwiftGodot.dylib": "Contents/Frameworks" }
    windows.debug.x86_64 = { "res://bin/SwiftGodot.dll": "" }
    windows.release.x86_64 = { "res://bin/SwiftGodot.dll": "" }
    linux.debug.x86_64 = { "res://bin/libSwiftGodot.so": "" }
    linux.release.x86_64 = { "res://bin/libSwiftGodot.so": "" }
    """

    try extensionFile.write(
      to: godotDirectory.appendingPathComponent("\(targetName).gdextension"),
      atomically: true,
      encoding: .utf8
    )

    let extensionList = "res://\(targetName).gdextension\n"
    try extensionList.write(
      to: godotHiddenDirectory.appendingPathComponent("extension_list.cfg"),
      atomically: true,
      encoding: .utf8
    )
  }

  private func linkAssetDirectories() throws {
    guard !config.assetDirectories.isEmpty else { return }
    for dir in config.assetDirectories {
      let destination = godotDirectory.appendingPathComponent(dir.lastPathComponent)
      if fileManager.fileExists(atPath: destination.path) {
        try fileManager.removeItem(at: destination)
      }
      try fileManager.createSymbolicLink(atPath: destination.path, withDestinationPath: dir.path)
      logger.debug("Symlinked assets directory '\(dir.lastPathComponent)' -> \(dir.path)")
    }
  }

  private func syncLibraries(binDirectory: URL) throws {
    guard fileManager.fileExists(atPath: binDirectory.path) else {
      throw CLIError("Build artifacts not found at \(binDirectory.path)")
    }

    let contents = try fileManager.contentsOfDirectory(at: binDirectory, includingPropertiesForKeys: nil)
    let dylibs = contents.filter { $0.pathExtension == "dylib" }

    guard !dylibs.isEmpty else {
      throw CLIError("No dynamic libraries produced by swift build")
    }

    let existing = try fileManager.contentsOfDirectory(at: godotBinDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
    for url in existing where url.pathExtension == "dylib" {
      try fileManager.removeItem(at: url)
    }

    var copied: [URL] = []

    for lib in dylibs {
      // Playground target + SwiftGodot dylibs end up here; copy each one into Godot/bin.
      let destination = godotBinDirectory.appendingPathComponent(lib.lastPathComponent)
      try fileManager.copyItem(at: lib, to: destination)
      copied.append(destination)
    }

    #if os(macOS)
      if config.codesign {
        for lib in copied {
          do {
            try runProcess(
              ["codesign", "--force", "--deep", "--sign", "-", lib.path],
              in: config.workspaceDirectory,
              suppressOutput: config.quiet
            )
          } catch {
            logger.warn("Failed to codesign \(lib.lastPathComponent)")
          }
        }
      }
    #endif
  }

  private func runHeadlessImport() throws {
    logger.info("Importing Godot resources (headless)...")
    try runProcess(
      [config.godotCommand, "--headless", "--path", godotDirectory.path, "--import"],
      in: config.workspaceDirectory,
      suppressOutput: config.quiet
    )
  }

  @discardableResult
  private func runProcess(
    _ arguments: [String],
    in directory: URL,
    captureOutput: Bool = false,
    suppressOutput: Bool = false
  ) throws -> String? {
    logger.debug("Running: \(arguments.joined(separator: " ")) (cwd: \(directory.path))")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = arguments
    process.currentDirectoryURL = directory
    let outputPipe: Pipe? = captureOutput ? Pipe() : nil
    if let pipe = outputPipe {
      // Capture stdout for commands like --show-bin-path while still streaming stderr to the console.
      process.standardOutput = pipe
    } else if suppressOutput {
      process.standardOutput = FileHandle(forWritingAtPath: "/dev/null")
    } else {
      process.standardOutput = FileHandle.standardOutput
    }
    process.standardError = FileHandle.standardError
    do {
      try process.run()
    } catch {
      throw CLIError("Unable to run command: \(arguments.first ?? "")")
    }
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      throw CLIError("Command failed: \(arguments.joined(separator: " "))")
    }

    if let pipe = outputPipe {
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      pipe.fileHandleForReading.closeFile()
      return String(data: data, encoding: .utf8)
    }

    return nil
  }
}

private struct Logger {
  let verbose: Bool
  let quiet: Bool

  func info(_ message: String) {
    guard !quiet else { return }
    print(message)
  }

  func debug(_ message: String) {
    guard verbose, !quiet else { return }
    print(message)
  }

  func warn(_ message: String) {
    fputs("warning: \(message)\n", stderr)
  }
}

private enum CacheCleaner {
  static func clean(cacheRoot: URL, logger: Logger) throws {
    let fm = FileManager.default
    if fm.fileExists(atPath: cacheRoot.path) {
      logger.info("Removing cached playgrounds at \(cacheRoot.path)...")
      try fm.removeItem(at: cacheRoot)
    } else {
      logger.info("No cache directory found at \(cacheRoot.path)")
    }
  }
}
