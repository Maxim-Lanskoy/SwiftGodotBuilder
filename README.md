
<a href="#"><img src="media/patterns.png?raw=true" width="210" align="right" title="Pictured: Ancient Roman seamstress at a loom, holding a shuttle."></a>

#### SwiftGodotBuilder

Declarative Godot development.


A SwiftUI-style library for building Godot games and apps using [SwiftGodot](https://github.com/migueldeicaza/SwiftGodot). Integrates with [LDtk](https://ldtk.io) and [Aseprite](https://aseprite.org).

<br>

📕 [API Documentation](https://swiftpackageindex.com/johnsusek/SwiftGodotBuilder/documentation/swiftgodotbuilder)

<br><br>

## Quick Start

### CLI

1. Download and unzip the CLI from the [latest release](https://github.com/johnsusek/SwiftGodotBuilder/releases)

2. Create a minimal `.swift` file:

```swift
import SwiftGodotBuilder

struct HelloWorld: View {
  var body: some View {
    Label$().text("Hello from SwiftGodotBuilder!")
  }
}
```

3. Run it:

```bash
./swiftgodotbuilder HelloWorld.swift
```

The CLI scaffolds a temporary project, builds your code, and launches Godot.

### Library

Add SwiftGodotBuilder to your `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/Maxim-Lanskoy/SwiftGodotBuilder", branch: "tweaks")
],
targets: [
  .target(name: "YourTarget", dependencies: ["SwiftGodotBuilder"])
]
```

Then import and use:

```swift
import SwiftGodot
import SwiftGodotBuilder

@Godot
final class Game: Node2D {
  override func _ready() {
    addChild(node: GameView().toNode())
  }
}

struct GameView: View {
  var body: some View {
    Node2D$ {
      Label$().text("Hello World")
    }
  }
}
```

## Core Features

### Builder Syntax

```swift
// $ syntax - shorthand for GNode<T>
Sprite2D$()
CharacterBody2D$()
Label$()

// With children
Node2D$ {
  Sprite2D$()
  CollisionShape2D$()
}

// Named nodes
CharacterBody2D$("Player") {
  Sprite2D$()
}

// Custom @Godot class
GNode<CustomNode>()
```

### Properties & Configuration

```swift
// Dynamic member lookup - set any property
Sprite2D$()
  .position([100, 200])
  .scale([2, 2])
  .rotation(45)
  .modulate(.red)
  .zIndex(10)

// Configure closure for imperative setup
RichTextLabel$().configure { label in
  label.pushColor(.cyan)
  label.appendText("Colored ")
  label.pop()
  label.appendText("text")
}
```

#### Explanation

The builder syntax is not magic, it's simply shorthand for `addChild`:

| SwiftGodotBuilder | SwiftGodot |
|---------|----------------------|
| <pre>Node2D$ {<br>  Label$().text("Hello")<br>}<br><br></pre> | <pre>let node = Node2D()<br>let label = Label()<br>label.text = "Hello"<br>node.addChild(node: label)</pre> |

### Resource Loading

```swift
// Load into property
Sprite2D$()
  .res(\.texture, "player.png")
  .res(\.material, "shader_material.tres")

// Custom resource loading
Sprite2D$()
  .withResource("shader.gdshader", as: Shader.self) { node, shader in
    let material = ShaderMaterial()
    material.shader = shader
    node.material = material
  }
```

### Signal Connections

```swift
// No arguments
Button$()
  .onSignal(\.pressed) { node in
    print("Pressed!")
  }

// With arguments
Area2D$()
  .onSignal(\.bodyEntered) { node, body in
    print("Body entered: \(body)")
  }

// Multiple arguments
Area2D$()
  .onSignal(\.bodyShapeEntered) { node, bodyRid, body, bodyShapeIndex, localShapeIndex in
    // Handle collision
  }
```

### Process Hooks

```swift
Node2D$()
  .onReady { node in
    print("Node ready!")
  }
  .onProcess { node, delta in
    node.position.x += 100 * Float(delta)
  }
  .onPhysicsProcess { node, delta in
    // Physics updates
  }
```

### Node References

Capture references to nodes for later use.

```swift
// On GNode - captures the node when ready
@State var playerNode: CharacterBody2D?

CharacterBody2D$()
  .ref($playerNode)

// On View - captures the root node produced by the component
@State var cameraNode: Camera2D?

CameraView()
  .ref($cameraNode)
```

### Custom Components

Create reusable components with slots.

```swift
// Component with a content slot
struct LabeledCell<Content: View>: View {
  let label: String
  let content: Content

  init(_ label: String, @ViewBuilder content: () -> Content) {
    self.label = label
    self.content = content()
  }

  var body: some View {
    VBoxContainer$ {
      Control$ { content }.minSize([64, 64])
      Label$().text(label).horizontalAlignment(.center)
    }
  }
}

// Single child
LabeledCell("Health") {
  ProgressBar$().value(80)
}

// Multiple children (automatically grouped)
LabeledCell("Stats") {
  Label$().text("HP: 100")
  Label$().text("MP: 50")
}
```

#### View Root Node Modifiers

Set properties on a custom View.s root node using `.as()`.

```swift
MyCustomView()
  .as(Node2D.self)
  .scale([2, 2])
  .rotation(0.5)
```

#### Passing State to Slots

Components can expose state to their slot content via closure parameters.

```swift
// Component exposes its state to content
struct PlayerPanel<Content: View>: View {
  var player = PlayerState()
  let content: (PlayerState) -> Content

  init(@ViewBuilder content: @escaping (PlayerState) -> Content) {
    self.content = content
  }

  var body: some View {
    PanelContainer$ {
      content($player)  // Pass state to slot
    }
  }
}

// Usage - slot content can bind to exposed state
PlayerPanel { player in
  Label$().text(player.health) { "HP: \($0)" }
  Label$().text(player.name)
}
```

## Reactive Data

### State Management

```swift
struct PlayerView: View {
  @State var health: Int = 100
  @State var position: Vector2 = .zero

  var body: some View {
    CharacterBody2D$ {
      Sprite2D$()
      ProgressBar$()
        .value($health)  // One-way binding
    }
    .position($position)  // Bind to property
    .onProcess { node, delta in
      health -= 1  // Modify state
    }
  }
}
```

#### State Binding Patterns

```swift
// One-way bind to property
ProgressBar$().value($health)

// Bind with formatter
Label$().text($score) { "Score: \($0)" }

// Bind to sub-property
Sprite2D$().bind(\.x, to: $position, \.x)

// Multi-state binding
Label$().bind(\.text, to: $health, $maxHealth) { "\($0)/\($1)" }

// Two-way bindings (form controls)
LineEdit$().text($username)
Slider$().value($volume)
CheckBox$().pressed($isEnabled)
OptionButton$().selected($selectedIndex)
```

### Dynamic Views

#### ForEach

```swift
// ForEach - dynamic lists
struct InventoryView: View {
  @State var items: [Item] = []

  var body: some View {
    VBoxContainer$ {
      ForEach($items) { item in
        HBoxContainer$ {
          Label$().text(item.wrappedValue.name)
          Button$().text("X").onSignal(\.pressed) { _ in
            items.removeAll { $0.id == item.wrappedValue.id }
          }
        }
      }
    }
  }
}
```

#### If/Else

```swift
// If - conditional rendering
struct MenuView: View {
  @State var showSettings = false

  var body: some View {
    VBoxContainer$ {
      If($showSettings) {
        Label$().text("Settings")
      }
      .Else {
        Label$().text("Main Menu")
      }
    }
  }
}

// If modes
If($condition) { /* ... */ }                 // .hide (default) - toggle visible
If($condition) { /* ... */ }.mode(.remove)   // addChild/removeChild
If($condition) { /* ... */ }.mode(.destroy)  // queueFree/rebuild
```

#### Switch/Case

```swift
// Switch/Case - multi-way branching
enum Page { case mainMenu, levelSelect, settings }

struct GameView: View {
  @State var currentPage: Page = .mainMenu

  var body: some View {
    VBoxContainer$ {
      Switch($currentPage) {
        Case(.mainMenu) {
          Label$().text("Main Menu")
          Button$().text("Start").onSignal(\.pressed) { _ in
            currentPage = .levelSelect
          }
        }
        Case(.levelSelect) {
          Label$().text("Level Select")
          Button$().text("Back").onSignal(\.pressed) { _ in
            currentPage = .mainMenu
          }
        }
        Case(.settings) {
          Label$().text("Settings")
        }
      }
      .default {
        Label$().text("Unknown page")
      }
    }
  }
}
```


### Computed Bindings

```swift
@State var score = 0
@State var health = 80
@State var maxHealth = 100

// Single state with transform
Label$().text($score) { "Score: \($0)" }

// Conditional based on state
If($score.computed { $0 > 1000 }) {
  Label$().text("New High Score!").modulate(.yellow)
}

// Multi-state binding with transform
Label$().bind(\.text, to: $health, $maxHealth) { "\($0)/\($1)" }
```

### Watchers

```swift
// Watch and react to state changes
Node2D$().watch($health) { node, health in
  node.modulate = health < 20 ? .red : .white
}
```

### ReactiveDebug

Debug utility to detect watchers firing too frequently. Useful for catching:
- `watchAny()` on objects with per-frame position updates
- Computed properties that depend on timers/positions when they shouldn't

```swift
// Enable at startup
ReactiveDebug.isEnabled = true
ReactiveDebug.warningThreshold = 30 // warn if >30 updates/sec

// Logs warnings like:
// ⚠️ [ReactiveDebug] Hot observable: 60.0/sec - EnemyState.*any*
// (This means watchAny is firing every frame - probably watching position
//  when you only care about isDying. Use a specific watch instead.)

// Print summary of all tracked state
ReactiveDebug.printSummary()
```

### Store

```swift
struct GameState {
  var health: Int = 100
  var score: Int = 0
}

enum GameEvent {
  case takeDamage(Int)
  case addScore(Int)
}

func gameReducer(state: inout GameState, event: GameEvent) {
  switch event {
  case .takeDamage(let amount):
    state.health = max(0, state.health - amount)
  case .addScore(let points):
    state.score += points
  }
}

let store = Store(initialState: GameState(), reducer: gameReducer)

// Use in views
ProgressBar$().value(store.state(\.health))
Label$().text(store.state(\.score)) { "Score: \($0)" }

// Send events
store.commit(.takeDamage(10))
store.commit(.addScore(100))

// With middleware for logging/side effects
let store = Store(
  initialState: GameState(),
  reducer: gameReducer,
  middleware: [.logging(name: "Game")]
)

// Custom middleware
let analytics = Middleware<GameState, GameEvent> { event, state, dispatch in
  print("Event: \(event)")
}
```

### EventBus

Modify parent state from children by emitting events instead of using callbacks.

```swift
enum GameEvent {
  case playerDied
  case scoreChanged(Int)
  case itemCollected(String)
}

// Subscribe via modifier
Node2D$()
  .onEvent(GameEvent.self) { node, event in
    switch event {
    case .playerDied: print("Game Over")
    case .scoreChanged(let score): print("Score: \(score)")
    case .itemCollected(let item): print("Got: \(item)")
    }
  }

// Subscribe with filter
Node2D$()
  .onEvent(GameEvent.self, match: { event in
    if case .scoreChanged = event { return true }
    return false
  }) { node, event in
    // Handle only score changes
  }

// Publish via ServiceLocator
let bus = ServiceLocator.resolve(GameEvent.self)
bus.publish(.scoreChanged(100))

// Or use EmittableEvent protocol
enum GameEvent: EmittableEvent {
  case playerDied
}
GameEvent.playerDied.emit()
```

## UI

### Layout

Shorthand modifiers for common layout properties.

```swift
// Anchor/offset presets (non-container parents)
Control$()
  .anchors(.center)
  .offsets(.topRight)
  .anchorsAndOffsets(.fullRect, margin: 10)
  .anchor(top: 0, right: 1, bottom: 1, left: 0)
  .offset(top: 12, right: -12, bottom: -12, left: 12)

// Container size flags (when inside a container)
Button$()
  .sizeH(.expandFill) // Horizontal
  .sizeV(.shrinkCenter) // Vertical
  .size(.expandFill, .shrinkCenter) // Both separate
  .size(.expandFill)  // Both same
```

### Themes

```swift
let theme = Theme([
  "Label": [
    "colors": ["fontColor": Color.white],
    "fontSizes": ["fontSize": 16]
  ]
])

VBoxContainer$ {
  Label$()
    .text("This label uses a custom theme")
}
.theme(theme)
```

#### StyleBox

```swift
PanelContainer$ {
  Label$().text("Styled Panel")
}
.panelStyle(
  StyleBoxFlat$()
    .bgColor(.black.withAlpha(0.9))
    .borderColor(.cyan)
    .borderWidth(2)
    .cornerRadius(8)
    .shadowColor(.black.withAlpha(0.5))
    .shadowSize(12)
)
```

### Builders

Declarative builders for controls with parent-child relationships.

#### ItemList

```swift
ItemList$ {
  ListItem("Apple")
  ListItem("Banana")
  ListItem("Cherry", disabled: true)
}
.onItemSelected { index in print("Selected: \(index)") }
.onItemActivated { index in print("Activated: \(index)") }
```

#### OptionButton

```swift
OptionButton$ {
  Option("Small", id: 0)
  Option("Medium", id: 1)
  Option("Large", id: 2)
  OptionSeparator()
  Option("Custom...", id: 99)
}
.onItemSelected { id in print("Selected: \(id)") }
```

#### Tabs

```swift
// TabBar only (no content)
TabBar$ {
  Tab("General")
  Tab("Audio")
  Tab("Video", disabled: true)
}
.onTabChanged { index in print("Tab: \(index)") }

// TabContainer with content
TabContainer$ {
  Tab("General") { Label$().text("General settings") }
  Tab("Audio") { HSlider$().value(80) }
}
.onTabChanged { index in print("Tab: \(index)") }
```

#### Tree

```swift
Tree$ {
  TreeNode("Root") {
    TreeNode("Child 1")
    TreeNode("Child 2", editable: true) {
      TreeNode("Grandchild")
    }
  }
}
.onItemSelected { print("Selected") }
.onItemActivated { print("Double-clicked") }
```

#### MenuBar

```swift
MenuBar$ {
  Menu("File") {
    MenuItem("New", id: 0)
    MenuItem("Open...", id: 1)
    MenuSeparator()
    SubMenu("Recent") {
      MenuItem("Project1.swift")
      MenuItem("Project2.swift")
    }
    MenuSeparator()
    MenuItem("Quit", id: 99)
  }
  .onItemPressed { id in print("File menu: \(id)") }

  Menu("Edit") {
    MenuItem("Undo", id: 0)
    MenuCheckItem("Auto-save", checked: true)
    MenuRadioItem("Tab size: 2", checked: true)
    MenuRadioItem("Tab size: 4")
  }
  .onItemPressed { id in print("Edit menu: \(id)") }
}
```

### Misc

#### Context Menus

```swift
Label$().text("Right-click me")
  .contextMenu {
    MenuItem("Cut", id: 0)
    MenuItem("Copy", id: 1)
    MenuItem("Paste", id: 2)
    MenuSeparator()
    MenuItem("Delete", id: 10)
  } onItemPressed: { id in
    print("Context action: \(id)")
  }
```

#### RichTextLabel

```swift
RichTextLabel$ {
  Bold("Important: ")
  "Normal text "
  Colored(.red, "Warning!")
  Newline()
  Italic {
    "Nested "
    Bold("formatting")
  }
  Paragraph {
    FontSize(16, "Large text")
  }
  Link("https://example.com", "Click here")
}
```

Elements: `Text`, `Bold`, `Italic`, `Underline`, `Strikethrough`, `Colored`, `FontSize`, `Link`, `Newline`, `Paragraph`

#### ColorPicker

```swift
ColorPicker$ {
  Preset(.red)
  Preset(.green)
  Preset(.blue)
  Preset(hex: "#FF6600")
  Preset(r: 128, g: 0, b: 255)
}
.onColorChanged { color in print("Color: \(color)") }

// Static presets
ColorPicker$ {
  Preset.red
  Preset.orange
  Preset.yellow
  Preset.green
  Preset.blue
  Preset.purple
}
```

#### Dialogs

Dialogs must be shown explicitly via `popup()`. Use `.ref()` to capture a reference.

```swift
@State var saveDialog: AcceptDialog?

Button$().text("Save").onSignal(\.pressed) { _ in
  saveDialog?.popupCentered()
}

AcceptDialog$ {
  DialogButton("Save", action: "save")
  DialogButton("Don't Save", action: "discard")
  CancelButton()
}
.ref($saveDialog)
.title("Unsaved Changes")
.dialogText("Save before closing?")
.onConfirmed { print("OK") }
.onCustomAction { action in print(action) }

// FileDialog
@State var fileDialog: FileDialog?

FileDialog$()
  .ref($fileDialog)
  .filter("Images", "*.png,*.jpg")
  .filter("All Files", "*")
  .onFileSelected { path in print(path) }

// Show methods: popup(), popupCentered(), popupCenteredRatio(0.5)
```

#### Wrappers

Wrapper components that add behavior to child content.

```swift
// Inset from edges
SafeArea(top: 20, right: 10, bottom: 20, left: 10) {
  Label$().text("Content with margins")
}

// Center in parent
Centered {
  Label$().text("Centered")
}
```

## Node Modifiers

### Collision (2D)

Named layer helpers.

```swift
CharacterBody2D$()
  .collisionLayer(.alpha)
  .collisionMask([.beta, .gamma])

// Available layers: .alpha, .beta, .gamma, .delta, .epsilon, .zeta, .eta, .theta,
// .iota, .kappa, .lambda, .mu, .nu, .xi, .omicron, .pi, .rho, .sigma, .tau,
// .upsilon, .phi, .chi, .psi, .omega

// Combine layers
CharacterBody2D$()
  .collisionMask([.alpha, .beta])

// Debug border visualization for collision shapes
CollisionShape2D$()
  .shape(RectangleShape2D(w: 32, h: 32))
  .debugBorder(color: .red, width: 2)
```

### Groups

```swift
Node2D$()
  .group("enemies")
  .group("damageable", persistent: true)
  .groups(["enemies", "damageable"])
```

### Scene Instancing

```swift
Node2D$()
  .fromScene("enemy.tscn") { child in
    // Configure instanced scene
  }
```

## Animation

### Tweens

```swift
// One-shot tween
btn.tween(.scale([1.1, 1.1]), duration: 0.1)
   .ease(.out).trans(.quad)

// Fade out and remove
enemy.tween(.alpha(0.0), duration: 0.3)
   .onFinished { enemy.queueFree() }

// Managed tween (kills previous)
@State var currentTween: TweenHandle?

currentTween = btn.tween(.scale([1.1, 1.1]), duration: 0.1, killing: currentTween)
   .trans(.quad).ease(.out)
```

### Sequences

```swift
// Bounce effect
btn.tween { seq in
  seq.to(.scale([1.0, 0.8]), duration: 0.05)
     .trans(.quad).ease(.out)
     .to(.scale([1.0, 1.15]), duration: 0.08)
     .trans(.quad).ease(.out)
     .to(.scale([1.0, 1.0]), duration: 0.12)
     .trans(.bounce).ease(.out)
}

// Looping pulse
icon.tween { seq in
  seq.to(.scale([1.05, 1.05]), duration: 0.5)
     .trans(.sine).ease(.inOut)
     .to(.scale([1.0, 1.0]), duration: 0.5)
     .trans(.sine).ease(.inOut)
}
.loop()

// Loop specific number of times
node.tween { seq in
  seq.to(.rotation(Float.pi * 2), duration: 1.0)
}
.loop(3)
```

### Anim Properties

- **Scale**: `.scale(Vector2)`, `.scaleX(Float)`, `.scaleY(Float)`
- **Position**: `.position(Vector2)`, `.positionX(Float)`, `.positionY(Float)`, `.globalPosition(Vector2)`
- **Rotation**: `.rotation(Float)`, `.rotationDegrees(Float)`
- **Color**: `.modulate(Color)`, `.alpha(Float)`, `.selfModulate(Color)`, `.selfAlpha(Float)`
- **Size**: `.size(Vector2)`, `.minSize(Vector2)`, `.pivotOffset(Vector2)`
- **Other**: `.skew(Float)`, `.volumeDb(Float)`, `.pitchScale(Float)`
- **Custom**: `.custom(property: String, value: Variant)`

### Reactive Tweens

Animate properties in response to state changes.

```swift
// Toggle animation - animate between two values based on bool state
@State var isHovered = false

Button$()
  .tweenToggle($isHovered, Anim.Scale.self,
               whenTrue: [1.1, 1.1], whenFalse: [1.0, 1.0],
               duration: 0.1)
  .onSignal(\.mouseEntered) { _ in isHovered = true }
  .onSignal(\.mouseExited) { _ in isHovered = false }

// Conditional animation - run different animations based on state value
@State var selectedTab = 0

Button$()
  .tweenWhen($selectedTab, equals: 0) { btn in
    btn.tween(.scale([1.1, 1.1]), duration: 0.1).ease(.out)
  } otherwise: { btn in
    btn.tween(.scale([1.0, 1.0]), duration: 0.1).ease(.out)
  }

// On change - custom handler for any state change
@State var health = 100

ProgressBar$()
  .tweenOnChange($health) { bar, newHealth in
    bar.tween(.scaleX(Float(newHealth) / 100.0), duration: 0.2).ease(.out)
  }
```

## Actors

Composable actor system for players, enemies, and NPCs with physics, combat, behaviors, and weapons.

```swift
// Basic enemy with physics and defense
Actor { state in
  AseSprite$(path: "Skeleton")
}
.collision { _ in CollisionShape2D$().shape(RectangleShape2D(w: 16, h: 16)) }
.hurtbox { _ in CollisionShape2D$().shape(RectangleShape2D(w: 14, h: 14)) }
.physics(.init(speed: 40, gravity: 400))
.defense(.init(maxHealth: 3))

// Player with attacks
Actor { state in
  AseSprite$(path: "Hero")
    .scale(state.facingScale) // flip based on direction
  Camera2D$()
}
.collision { _ in CollisionShape2D$().shape(RectangleShape2D(w: 16, h: 24)) }
.hurtbox { _ in CollisionShape2D$().shape(RectangleShape2D(w: 14, h: 22)) }
.hitbox { _, _ in CollisionShape2D$().shape(RectangleShape2D(w: 24, h: 16)) }
.physics(.init(speed: 80, jumpSpeed: 150))
.defense(.init(maxHealth: 5, invincibilityDuration: 1.0))
.attacks([.init(melee: .init(damage: 1, knockback: 80))])
.isPlayer()

// Pre-build state
var state = ActorState()
Actor(state) { ... }
```

### Actor Modifiers

Appending modifiers adds rich capabilities.

```swift
Actor { ... }
.collision { _ in ... }    // Terrain collision shape
.hurtbox { _ in ... }      // Can receive damage
.hitbox { _, _ in ... }    // Can deal damage
.targetbox { _ in ... }    // Target scanning (auto-enables targeting)
.interaction { _ in ... }  // NPC interaction zone
.collector { _ in ... }    // Item pickup area
.selectbox { _ in ... }    // Selection area (RTS-style)
.physics(config)           // Movement/gravity
.defense(config)           // Health/invincibility
.attacks([weapons])        // Weapon configs
.isPlayer()                // Won't delete on death
.behavior(initial: "state") { ... } // AI state machine
.dialog { state, dialogState in ... } // NPC dialog
.onHurt { actor, damage, knockback in ... } // Custom damage handling
.onHit { actor, targetId, damage in ... }   // When hitting a target
.onDeath { actor in ... }                  // Death callback
.onAcquiredTarget { actor, target in ... } // Target acquired
.onLostAllTargets { actor in ... }         // Lost all targets
```

### Combat Callbacks

Handle combat events with custom game logic. Events still fire for particles/sound.

```swift
Actor { state in ... }
  .onHurt { actor, damage, knockback in
    // Replaces default damage - call takeDamage manually if needed
    let reducedDamage = max(1, damage - playerArmor)
    actor.takeDamage(reducedDamage, knockback: knockback)
  }
  .onHit { actor, targetId, damage in
    comboCounter += 1
    score += damage * 10
  }
  .onDeath { actor in
    GameEvent.playerDied.emit()
  }
  .onAcquiredTarget { actor, target in
    showTargetIndicator = true
  }
  .onLostAllTargets { _ in
    showTargetIndicator = false
  }
```

### Pickups

Collectible items with typed data.

```swift
enum Item {
  case coin(value: Int)
  case health(amount: Int)
}

Pickup(.health(amount: 10)) {
  AseSprite$(path: "Items").autoplay("heart")
  CollisionShape2D$().shape(CircleShape2D(radius: 6))
} onCollected: { (item: Item, actorId) in
  if case .health(let amount) = item {
    player.heal(amount)
  }
}

// Player needs .collector() to pick up items
Actor(playerState) { ... }
  .collector { _ in CollisionShape2D$().shape(RectangleShape2D(w: 12, h: 12)) }
```

Emits `ActorEvent.collected(actorId, item, position)` for particles/sound.

### Actor Behaviors

Use `.behavior()` to compose AI behaviors for actors.

```swift
Actor { state in
  AseSprite$(path: "Enemy")
}
.physics(.init(speed: 40))
.targetbox { _ in CollisionShape2D$().shape(CircleShape2D(radius: 100)) }
.behavior(initial: "patrol") {
  During("patrol") {
    Patrol(left: 100, right: 300)
    Shoot(cooldown: 2.0) // Concurrent with patrol
  }
  .transition(to: "chase") { $0.distanceToTarget ?? .infinity < 80 }

  During("chase") {
    Chase()
    FaceTarget()
  }
  .transition(to: "patrol") { $0.distanceToTarget ?? 0 > 150 }
  .transition(to: "attack") { $0.distanceToTarget ?? .infinity < 32 }

  During("attack") {
    Idle()
  }
  .transition(to: "chase") { !($0.weapon?.attackPhase.isAttacking ?? false) }
}
```

**Built-in Behaviors:** `Patrol` (reverses on walls), `Chase`, `Charge`, `Shoot`, `JumpOnInterval`, `SineWave`, `Idle`, `FaceTarget`

### Ranged Weapons

Use `ActorProjectileSpawner` to handle projectile spawning from actors with ranged weapons.

```swift
Node2D$ {
  ActorProjectileSpawner() // Add once to scene

  Actor { state in
    AseSprite$(path: "Turret")
  }
  .attacks([.init(ranged: .init(damage: 1, speed: 200))])
  .behavior(initial: "shoot") {
    During("shoot") {
      Shoot(cooldown: 1.5)
    }
  }
}
```

Listens for `ActorEvent.projectileFired` and spawns projectiles with appropriate collision layers.

### Actor Dialog

Add dialog capability to NPCs with `.dialog {}`. Requires separate `.interaction {}` for the interaction zone.

```swift
Actor(npcState) { state in
  AseSprite$(path: "Merchant")
}
.interaction { _ in CollisionShape2D$().shape(RectangleShape2D(w: 24, h: 32)) }
.dialog { actorState, dialogState in
  Dialog(id: "merchant") {
    Branch("main") {
      if dialogState.isFirstVisit {
        Merchant ~ "Welcome to my shop!"
      } else {
        Merchant ~ "Back for more?"
      }
    }
  }
}
```

Use with `DialogManager` (see Dialog Trees section) for automatic dialog UI handling.

### Selection System

RTS-style unit selection with click and box selection.

```swift
// Make actor selectable
Actor { state in
  AseSprite$(path: "Unit")

  // Selection indicator
  if state.isSelected {
    ColorBox$([18, 18]).color(Color.green.withAlpha(0.3)).position([-9, -9])
  }
}
.collision { _ in CollisionShape2D$().shape(RectangleShape2D(w: 16, h: 16)) }
.selectbox(group: "units") { _ in
  CollisionShape2D$().shape(RectangleShape2D(w: 18, h: 18))
}

// Add SelectionBox to scene for click/drag selection
Node2D$ {
  SelectableUnit().position([100, 50])
  SelectableUnit().position([150, 50])
  SelectionBox() // Handles mouse input for selection
}
.onEvent(SelectionEvent.self) { _, event in
  switch event {
  case .selected(let actorId): print("Selected: \(actorId)")
  case .deselected(let actorId): print("Deselected: \(actorId)")
  default: break
  }
}
```

Selection groups prevent mixing different unit types in multi-selection. Shift+click toggles selection.

## Game Systems

### Dialog Trees

Screenplay-style dialog trees.

```swift
// Define speakers
let Guard = Speaker("Guard")
let Merchant = Speaker("Merchant")

// Create dialogs with branches
Dialog(id: "guard") {
  Branch("main") {
    Guard ~ "Halt! The path ahead is dangerous."

    Choice("I can handle it.") {
      Guard ~ "Ha! I like your spirit!"
    }

    Choice("Any tips?") {
      Guard ~ "Watch for patterns."
      Jump("tips")  // Jump to another branch
    }

    Choice("Bye.") {
      End
    }
  }

  Branch("tips") {
    Guard ~ "Use checkpoints!"
    Guard ~ "Good luck out there."
  }
}

// Conditional choices
Choice("Pay 10 gold", when: { game.gold >= 10 }) {
  Emit("payGold", ["amount": 10])
  Merchant ~ "Thank you!"
}

// Conditional blocks - runtime evaluated
When({ game.hasKey }) {
  Guard ~ "You have the key!"
  Jump("unlocked")
}

// Per-NPC state via DialogState
func makeDialog(state: DialogState) -> DialogDefinition {
  Dialog(id: "guard") {
    Branch("main") {
      When({ state.isFirstVisit }) {
        Guard ~ "Welcome, stranger!"
      }
      When({ state.visitCount > 1 }) {
        Guard ~ "Back again?"
      }
    }
  }
}

// Create dialog state (track visit counts in your game state)
let state = DialogState(visitCount: myGameState.getVisitCount(for: "guard"))

// Run dialog
let runner = DialogRunner(dialog: myDialog)
runner.onLine = { line in print("\(line.speaker): \(line.text)") }
runner.onChoices = { choices in /* show UI */ }
runner.onEnd = { /* close dialog */ }
runner.start()
runner.advance()           // Next line
runner.selectChoice(0)     // Pick choice

// Handle Emit() events
.onEvent(DialogBusEvent.self) { _, event in
  if case .emitted(let name, let data) = event, name == "payGold" {
    player.gold -= data?["amount"] as? Int ?? 0
  }
}
```

#### DialogManager

Self-contained dialog UI that handles dialog lifecycle automatically. Add once to your scene.

```swift
Node2D$ {
  DialogManager(speakerColors: ["Guard": .blue, "Merchant": .gold])

  // NPCs with .dialog modifier trigger automatically
  Actor(guardState) { ... }
    .interaction { _ in CollisionShape2D$().shape(RectangleShape2D(w: 24, h: 32)) }
    .dialog { _, _ in guardDialog }
}
```

Features typewriter text effect, choice buttons, and emits `DialogManagerEvent` for integration:

```swift
.onEvent(DialogManagerEvent.self) { _, event in
  switch event {
  case .dialogActive(true): pauseGame()
  case .dialogActive(false): resumeGame()
  case .dialogEnded(let actorId, let dialogId): handleDialogComplete(actorId, dialogId)
  default: break
  }
}
```

### Object Pools

#### ObjectPool

Generic pool for reusable Godot objects.

```swift
final class Bullet: Node2D, PooledObject {
  func onAcquire() { visible = true }
  func onRelease() { visible = false; position = .zero }
}

let pool = ObjectPool<Bullet>(factory: { Bullet() })
pool.preload(64)

if let bullet = pool.acquire() {
  bullet.position = spawnPos
  parent.addChild(node: bullet)
  // later:
  pool.release(bullet)
}

// Or use PoolLease for scoped usage
PoolLease(pool).using { bullet in
  // automatically released after closure
}
```

#### AreaPool

Pool for Area2D projectiles with velocity-based movement.

```swift
let bulletPool = AreaPool(
  preload: 30,
  speed: 300,
  lifetime: 3.0,
  bounds: (-50, 850, -50, 290)
) {
  Area2D$ {
    Sprite2D$().res(\.texture, "bullet.png")
    CollisionShape2D$().shape(CircleShape2D(radius: 4))
  }
  .collisionLayer(.beta)
  .collisionMask(.alpha)
}

// Call once when parent is in scene tree
bulletPool.start()

// Fire projectiles
bulletPool.fire(at: playerPos, direction: aimDir, parent: self)

// Update in _process
bulletPool.update(delta: delta)
```

#### TypedParticlePool

Multi-variant particle pool keyed by type.

```swift
enum ParticleType { case dust, spark, blood }

let particles = TypedParticlePool<ParticleType, CPUParticles2D>(
  keys: [.dust, .spark, .blood],
  config: .init(prewarmPerType: 5)
) { type in
  switch type {
  case .dust: return CPUParticles2D(.dust)
  case .spark: return CPUParticles2D(.sparkle)
  case .blood: return CPUParticles2D(.splatter)
  }
}

particles.setup(parent: self)
particles.spawn(type: .dust, at: position)
particles.spawn(type: .spark, at: hitPoint, scale: [2, 2])
```

#### ActorPool

Pool for reusing Actor nodes. One pool per actor type.

```swift
// Create pool with make and makeBehavior closures
let slimePool = ActorPool(
  prewarm: 10,
  max: 50,
  make: {
    let state = ActorState()
    let node = SlimeActor(state: state).toNode() as! CharacterBody2D
    return (node, state)
  },
  makeBehavior: { AnyBehaviorMachine(SlimeBehavior()) }
)

slimePool.setup(parent: levelNode)

// Spawn actors
slimePool.spawn(at: spawnPoint, facing: .left)

// Release via ActorEvent.died listener
.onEvent(ActorEvent.self) { _, event in
  if case let .died(actorId) = event {
    slimePool.release(actorId: actorId)
  }
}
```

Pooled actors skip `queueFree()` on death - the pool handles node lifecycle.

### Particle Effects

```swift
// Built-in presets: .explosion, .sparkle, .dust, .splatter, .smoke
CPUParticles2D$()
  .config(.explosion)
  .oneShot(true)
  .emitting(true)

// Modify presets
CPUParticles2D$()
  .config(.explosion.withColor(.red).withAmount(30))

// Custom config
CPUParticles2D$()
  .config(ParticleConfig(
    amount: 20,
    lifetime: 0.8,
    explosiveness: 1.0,
    direction: [0, -1],
    spread: 180,
    initialVelocityMin: 100,
    initialVelocityMax: 200,
    gravity: [0, 400],
    color: .orange
  ))

// Direct initialization
let particles = CPUParticles2D(.dust)
particles.emitting = true
```

### Spawners

```swift
// Damage numbers, popups
FloatingTextSpawner(ActorEvent.self) { event in
  if case let .damaged(_, amount, position) = event {
    return (text: "\(amount)", position: position, color: .red)
  }
  return nil
}

// Spawn nodes in response to events
NodeSpawner(GameEvent.self) { event in
  if case let .itemSpawned(position) = event {
    return Sprite2D$().position(position).toNode()
  }
  return nil
} resetWhen: { event in
  if case .gameReset = event { return true }
  return false
}
```

### Input Actions

```swift
// Define actions
Actions {
  Action("jump") {
    Key(.space)
    JoyButton(.a, device: 0)
  }

  Action("shoot") {
    MouseButton(1)
    Key(.leftCtrl)
  }

  // Analog axes
  ActionRecipes.axisUD(
    namePrefix: "move",
    device: 0,
    axis: .leftY,
    dz: 0.2,
    keyDown: .s,
    keyUp: .w
  )

  ActionRecipes.axisLR(
    namePrefix: "move",
    device: 0,
    axis: .leftX,
    dz: 0.2,
    keyLeft: .a,
    keyRight: .d
  )
}
.install(clearExisting: true)

// Runtime polling
if Action("jump").isJustPressed {
  player.jump()
}

if Action("shoot").isPressed {
  player.shoot(Action("shoot").strength)
}

let horizontal = RuntimeAction.axis(negative: "move_left", positive: "move_right")
let movement = RuntimeAction.vector(
  negativeX: "move_left",
  positiveX: "move_right",
  negativeY: "move_up",
  positiveY: "move_down"
)
```

## Asset Integrations

### LDtk

Complete workflow for loading LDtk levels and bridging enums.

```swift
// Define type-safe enums matching LDtk enum values
enum Item: String, LDEnum {
  case knife = "Knife"
  case boots = "Boots"
  case potion = "Potion"
}

struct GameView: View {
  let project: LDProject
  @State var inventory: [Item] = []
  @State var spawnPosition: Vector2 = .zero

  var body: some View {
    Node2D$ {
      LDLevelView(project, level: "Level_0")
        // Spawn nodes for entities
        .onEntitySpawn("Player") { entity, level, project in
          // Collision layers from LDtk
          let wallLayer = project.collisionLayer(for: "walls", in: level)
          // Typed fields
          let startItems: [Item] = entity.field("starting_items")?.asEnumArray() ?? []
          inventory.append(contentsOf: startItems)

          return CharacterBody2D$ {
            Sprite2D$()
              .res(\.texture, "player.png")
              .anchor([16, 22], within: entity.size, pivot: entity.pivotVector)
            CollisionShape2D$()
              .shape(RectangleShape2D(w: 16, h: 22))
          }
          .position(entity.positionCenter)
          .collisionMask(wallLayer)
        }
        // Side effects only (no node spawned)
        .onEntity("Enemy") { entity, _, _ in
          enemySpawnPosition = entity.positionCenter
        }
        // Post-process all spawned entities
        .onSpawned { entity, node in
          node.addChild(node: Label$().text(entity.identifier).toNode())
        }
    }
  }
}

// Usage
let project = try! LDProject.load(path: "res://game.ldtk")
addChild(node: GameView(project: project).toNode())
```

#### Reactive Level Switching

```swift
// Level changes automatically rebuild the view
LDLevelView(project, level: $state.currentLevelId)
  .onEntitySpawn("Player") { entity, level, project in
    PlayerView(entity: entity)
  }
```

#### LDtk Field Accessors

All LDtk field types are supported:

```swift
// Single values
entity.field("health")?.asInt() -> Int?
entity.field("speed")?.asDouble() -> Double?
entity.field("speed")?.asFloat() -> Float?
entity.field("locked")?.asBool() -> Bool?
entity.field("name")?.asString() -> String?
entity.field("tint")?.asColor() -> Color?
entity.field("destination")?.asPoint() -> LDPoint?
entity.field("spawn_pos")?.asVector2(gridSize: 16) -> Vector2?
entity.field("target")?.asEntityRef() -> LDEntityRef?
entity.field("item_type")?.asEnum<Item>() -> Item?

// Arrays
entity.field("scores")?.asIntArray() -> [Int]?
entity.field("distances")?.asDoubleArray() -> [Double]?
entity.field("distances")?.asFloatArray() -> [Float]?
entity.field("flags")?.asBoolArray() -> [Bool]?
entity.field("tags")?.asStringArray() -> [String]?
entity.field("waypoints")?.asPointArray() -> [LDPoint]?
entity.field("patrol")?.asVector2Array(gridSize: 16) -> [Vector2]?
entity.field("palette")?.asColorArray() -> [Color]?
entity.field("targets")?.asEntityRefArray() -> [LDEntityRef]?
entity.field("loot")?.asEnumArray<Item>() -> [Item]?
entity.field("values")?.asArray() -> [LDFieldValue]?  // Raw array
```

#### LDtk Collision Helper

```swift
// Get physics layer bit for IntGrid group name
let wallLayer = project.collisionLayer(for: "walls", in: level)
let platformLayer = project.collisionLayer(for: "platforms", in: level)

CharacterBody2D$()
  .collisionMask(wallLayer | platformLayer)
```

#### Tile Layer Handlers

Override default tile layer rendering with custom handlers.

```swift
LDLevelView(project, level: "Level_0")
  .onTileLayerSpawn("Breakable") { layer, level, project in
    LDBreakableTerrainView(layer: layer, project: project)
      .terrainCollisionLayer(.terrain)
      .detectionMask(.combat)
      .onTileDestroyed { position in
        GameEvent.terrainDestroyed(position: position).emit()
      }
  }
```

#### LDIntGridZonesView

Build Area2D collision zones from IntGrid values with identifiers.

```swift
LDIntGridZonesView(layer: hazardLayer, project: project)
  .collisionLayer(.hazard)
  .collisionMask(.player)
  .onZoneEnter { zone, body in
    if zone.identifier == "damage" {
      GameEvent.playerHit(damage: 1).emit()
    }
  }
  .onZoneExit { zone, body in
    // Handle exit
  }
```

#### LDBreakableTerrainView

Tile layer where tiles can be destroyed by collision.

```swift
LDBreakableTerrainView(layer: breakableLayer, project: project)
  .terrainCollisionLayer(.terrain)
  .detectionLayer([])
  .detectionMask(.combat)
  .onTileDestroyed { position in
    GameEvent.terrainDestroyed(position: position).emit()
  }
```

#### LDTileFieldView

Renders sprites from LDtk tile fields with automatic tiling.

```swift
// From tile counts
if let tile = entity.field("sprite")?.asTile() {
  LDTileFieldView(tile: tile, project: project, gridSize: 8, tileCountX: 4, tileCountY: 2)
}

// From pixel dimensions
LDTileFieldView(tile: tile, project: project, gridSize: 8, width: 32, height: 16)
```

### AseSprite

```swift
// Load Aseprite animations
let sprite = AseSprite(
  "character.json",
  layer: "Body",
  options: .init(
    timing: .delaysGCD,
    trimming: .applyPivotOrCenter
  ),
  autoplay: "Idle"
)

// Builder pattern
AseSprite$(path: "player", layer: "Main")
  .configure { sprite in
    sprite.play(anim: "Walk")
  }
```

### SVGSprite

Runtime SVG rendering with vertex manipulation effects.

```swift
// Basic usage
SVGSprite$()
  .path("icon.svg")
  .size(16) // Default is 32
  .colors([.red, .darkRed, .crimson]) // Per-element colors
  .stroke(.white, width: 2)

// Mixing effect types - chaining works fine
SVGSprite$()
  .colorCycle([.red, .orange, .yellow]) // color effect
  .inflate(amount: 3.0)                 // vertex effect

// Multiple vertex effects - use svgEffects builder
SVGSprite$()
  .path("icon.svg")
  .svgEffects {
    SVGInflate(amount: 3.0) // applied first
    SVGNoise(amount: 1.5)   // applied to inflated result
  }

// With reactive bindings
@State var meltProgress: Double = 0

SVGSprite$()
  .path("enemy.svg")
  .melt(progress: $meltProgress)  // Animate on death
```

**Color Effects:** `.pulse(speed, amplitude, baseSize)`, `.colorCycle(colors, speed)`, `.strokeCycle(colors, speed)`, `.dualColorCycle(fill:, stroke:)`

**Vertex Effects:** `.wobble(amount, speed)`, `.inflate(amount, speed)`, `.skew(amount, speed, animated)`, `.noise(amount, speed)`, `.ripple(amplitude, frequency, speed)`, `.twist(amount, speed)`, `.wave(amplitude, frequency, speed)`, `.explode(progress, scale)`, `.scatter(progress, scale, rotate)`, `.melt(progress, scale, waviness)`

### Bfxr

Real-time synthesis of retro sound effects from [`.bfxr`](https://www.bfxr.net) files.

```swift
// Basic sound playback
BfxrSound$("res://sounds/jump.bfxr")
  .onReady { node in
    node.playSound()
  }

// With reactive bindings
struct GameView: View {
  @State var pitch: Double = 1.0

  var body: some View {
    Node2D$ {
      BfxrSound$("res://sounds/laser.bfxr")
        .ref($laserSound)
        .frequencyStart($pitch)
    }
  }
}
```

### SpriteSheet

Reference individual sprites from a spritesheet by name.

```swift
enum ItemSprite: Int, SpriteSheet {
  case heart = 0
  case key = 1
  // tile 2 blank
  case coin = 3, coinSide = 13, coinBack = 23
  case sword = 4

  static let sheetPath = "res://items.png"
  static let tileSize: Vector2 = [16, 16]
  static let columns = 10

  // Define animations
  static let coinSpin = SpriteAnimation(frames: [.coin, .coinSide, .coinBack, .coinSide], fps: 4)
}

// Static sprite
Sprite2D$().texture(ItemSprite.heart.texture)

// Animated sprite (uses Godot's AnimatedSprite2D)
AnimatedSpriteSheet(ItemSprite.coinSpin)
```

## Built-in Views

### Layout

```swift
Spacer(16)      // Fixed height spacer
SpacerV()       // Vertical expand-fill
SpacerH()       // Horizontal expand-fill
```

### ColorBox

Polygon2D-based colored rectangle (like ColorRect for outside the UI).

```swift
ColorBox$([100, 50])
  .color(.red)
  .position([200, 300])
```

## Extensions & Utilities

### Vector2 Extensions

```swift
let pos: Vector2 = [100, 200]
let doubled = pos * 2
let scaled = pos * 1.5
```

### Color Extensions

```swift
// Create colors with alpha
let semiTransparent = Color.black.withAlpha(0.9)
let glowColor = Color.cyan.withAlpha(0.5)

### Shape Extensions

```swift
let rect = RectangleShape2D(w: 50, h: 100)
let circle = CircleShape2D(radius: 25)
let capsule = CapsuleShape2D(radius: 10, height: 50)
let segment = SegmentShape2D(a: [0, 0], b: [100, 100])
let ray = SeparationRayShape2D(length: 100)
let boundary = WorldBoundaryShape2D(normal: [0, -1], distance: 0)
```

### Node Extensions

```swift
// Typed queries
let sprites: [Sprite2D] = node.getChildren()
let firstSprite: Sprite2D? = node.getChild()
let enemySprite: Sprite2D? = node.getNode("Enemy")

// Group queries
let enemies: [Enemy] = node.getNodes(inGroup: "enemies")

// Parent chain
let parents: [Node2D] = node.getParents()

// Metadata queries (recursive)
let spawns: [Node2D] = root.queryMeta(key: "type", value: "spawn")
let valuable: [Node2D] = root.queryMeta(key: "value", value: 100)
let markers: [Node2D] = root.queryMetaKey("marker")

// Get typed metadata
let coinValue: Int? = node.getMetaValue("coin_value")
```

### Engine Extensions

```swift
if let tree = Engine.getSceneTree() {
  // ...
}

Engine.onNextFrame {
  print("Next frame!")
}

Engine.onNextPhysicsFrame {
  print("Next physics frame!")
}
```

### MsgLog

Thread-safe logging singleton.

```swift
MsgLog.shared.debug("Debug message")
MsgLog.shared.info("Info message")
MsgLog.shared.warn("Warning")
MsgLog.shared.error("Error")

// Set minimum level
MsgLog.shared.minLevel = .warn

// Custom sink
MsgLog.shared.sink = { level, message in
  print("[\(level)] \(message)")
}
```

### UserSettings

Persistable audio/display settings.

```swift
let settings = UserSettings()  // Auto-loads from disk
settings.masterVolume, settings.sfxVolume, settings.musicVolume
settings.masterVolumeDisplay  // "70%"
```

### AudioManager

Syncs volume settings with AudioServer.

```swift
AudioManager(settings: $settings) {
  BfxrSound$().bfxrPath("sounds/Jump.bfxr")
}
```

## Property Wrappers

For imperative `@Godot` classes - add `bindProps()` in `_ready()` to activate property wrappers.

```swift
@Godot
final class Player: CharacterBody2D {
  @Child("Sprite") var sprite: Sprite2D?
  @Child("Health", deep: true) var healthBar: ProgressBar?
  @Children var buttons: [Button]
  @Ancestor var level: Level?
  @Sibling("AudioPlayer") var audio: AudioStreamPlayer?
  @Autoload("GameManager") var gameManager: GameManager?
  @Group("enemies") var enemies: [Enemy]
  @Service var events: EventBus<GameEvent>?
  @Prefs("musicVolume", default: 0.5) var volume: Double

  @OnSignal("StartButton", \Button.pressed)
  func onStartPressed(_ sender: Button) {
    print("Started!")
  }

  override func _ready() {
    bindProps()

    sprite?.visible = true
    enemies.forEach { print($0) }

    // Refresh group query
    let currentEnemies = $enemies()
  }
}
```

## CLI Playground

Use the bundled `swiftgodotbuilder` CLI to preview any `View` without hand-creating a Godot project.

```bash
swift run swiftgodotbuilder MyGameView.swift \
  --assets Assets \
  --include Utils
```

Flags:

- `--include <dir>` – copy `.swift` files from directory into sources (repeatable)
- `--assets <dir>` – symlink an entire assets directory (repeatable)
- `--godot <path>` – path to Godot (defaults to `godot` in PATH, then mdfind on macOS)
- `--project <file>` – use a custom `project.godot` file (use `res://main.tscn` for main_scene)
- `--release` / `--debug` – switch the Swift build configuration (`debug` is the default)
- `--no-run` – stop after building; leaves the project ready to open manually
- `--cache <dir>` – workspace cache directory (default `~/.swiftgodotbuilder/playgrounds`)
- `--builder-path <path>` – override the SwiftGodotBuilder dependency path
- `--view <TypeName>` – specify the `View` to instantiate if auto-detection fails
- `--codesign` – codesign dylibs (macOS only, off by default)
- `--clean` – delete cached playground workspaces and exit
- `--verbose` / `--quiet` – increase or decrease CLI logging
