import SwiftGodot
import SwiftGodotBuilder

#initSwiftExtension(
  cdecl: "swift_entry_point",
  types: [
    ActorPlayground.self,
    LevelDesigner.self,
    AsteroidsGame.self,
    PongGame.self,
    MinimalGame.self,
    BreakoutGame.self,
    SpaceInvadersGame.self,
    PlatformerGame.self,
    SVGTest.self,
    StressTest.self,
  ] + BuilderRegistry.types
)
