<!-- AUTO-MANAGED: project-description -->
# Neko.app

A macOS desktop pet application - a tiny kitten sprite that follows the mouse cursor across the screen. Uses SwiftUI and AppKit for a borderless, transparent overlay window.
<!-- END AUTO-MANAGED -->

<!-- AUTO-MANAGED: architecture -->
## Architecture

### Core Components

- `main.swift` - Application entry point (macOS 26 compatibility, replaces @main attribute)
- `AppDelegate.swift` - Window setup, animation timer, screen-edge clamp
- `Store.swift` - State management and animation logic
- `ContentView.swift` - SwiftUI view wrapping NekoAnimation
- `NekoAnimation.swift` - Animation frame selector
- `Neko.swift` - Sprite rendering component
- `Settings.swift` - User preferences (size, speed, hidden) and login-item registration
- `StatusBarController.swift` - Menu bar UI for settings, template status icon

### Window Configuration

- Borderless, transparent `NSPanel` at `.statusBar` level
- Joins all spaces (`canJoinAllSpaces`, `fullScreenAuxiliary`, `stationary`; `canJoinAllApplications` on macOS 13+)
- Ignores all mouse events (clickthrough)
- Base 16x16 size, scales 16/24/32 with settings

### Lifecycle Management

- Animation timer managed by `AppDelegate`
- `startAnimationTimer()` - Invalidates and rebuilds the timer; used on launch, speed change, and hide/show
- Timer interval determined by `Settings.shared.currentSpeed.rawValue`
- Timer is registered in `.common` and `.eventTracking` so the kitten keeps moving while a menu is open
- No timer runs while `Settings.shared.isHidden` is true
<!-- END AUTO-MANAGED -->

<!-- AUTO-MANAGED: conventions -->
## Conventions

### Application Entry Point

- Use explicit `main.swift` with manual app initialization (not `@main` attribute)
- Required for macOS 26 compatibility

### State Management

- `Store` is `ObservableObject` with `@Published` properties
- Timer interval is the speed setting (normal 0.16s, ~6.25 fps) calling `store.nextTick(_:visibleFrames:)`
- Direction and animation state updated each tick
- Walk gait is selected only when the origin moved; a blocked edge scratches; arrival thinks or sits

### Settings Architecture

- Singleton `Settings.shared` with `@Published` properties
- UserDefaults persistence for size and speed
- Settings keys: `nekoSize`, `nekoSpeed`, `nekoHidden`
- Launch at login is system state, not UserDefaults: `LoginItem` wraps `SMAppService.mainApp` (macOS 13+)
- Combine publishers for reactive menu updates

### Window Setup Order

1. Create window with borderless style
2. Set `isFloatingPanel`, then `level = .statusBar` (floating-panel flag resets level if applied after), then collection behavior
3. Initialize Store with initial positions
4. Set up ContentView and NSHostingView
5. Start animation timer
6. Configure transparency (backgroundColor with alpha 0)
7. Set ignoresMouseEvents for click-through behavior
8. Show window

**Critical**: `ignoresMouseEvents` must be set AFTER `backgroundColor` to ensure proper click-through functionality
<!-- END AUTO-MANAGED -->

<!-- AUTO-MANAGED: patterns -->
## Patterns

### Animation State Machine

- Enum-based direction tracking (`Direction`: none, northWest, north, etc.)
- Animation arrays cycled by tick count
- Idle animations triggered by `ticksSinceLastMove` counter
- State transitions: alert → moving → thinking → idle → grooming → yawning → sleeping
- Screen-edge block: scratching instead of a zero-travel walk

### SwiftUI + AppKit Integration

- `NSHostingView` wraps SwiftUI `ContentView`
- Bindings connect Store state to view updates
- Timer updates run on the main run loop in common and event-tracking modes

### Settings Observation

- `Settings.shared.$currentSize` drives window size
- `Settings.shared.$isHidden` orders the panel in or out
- Menu checkmarks update on selection, and re-sync in `menuWillOpen`
- `onSpeedChange` callback restarts the animation timer
<!-- END AUTO-MANAGED -->
