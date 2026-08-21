# NEKO — macOS Desktop Pet

**Generated:** 2026-08-20  
**Branch:** feature/overlay-edge-sizes

## OVERVIEW

Menu bar app — animated cat follows mouse cursor, floats above all windows including fullscreen.

## STRUCTURE

```
neko/
├── AppDelegate.swift      # Entry point, window + timer setup
├── Settings.swift         # NekoSize enum, UserDefaults persistence
├── StatusBarController.swift  # Menu bar UI
├── Store.swift            # Movement logic, direction state machine
├── Neko.swift             # Sprite view, NekoState enum
├── NekoAnimation.swift    # Animation frame selector
├── ContentView.swift      # SwiftUI wrapper
└── Assets.xcassets/Neko.imageset/  # 6×5 sprite sheet (1x/2x/3x)
```

## WHERE TO LOOK

| Task | Location |
|------|----------|
| Add new animation state | `Neko.swift` (NekoState enum + offset switch) |
| Change movement behavior | `Store.swift` (nextTick, nextDirection) |
| Add menu bar options | `StatusBarController.swift` |
| Modify size presets | `Settings.swift` (NekoSize enum) |
| Window behavior | `AppDelegate.swift` (window.level, collectionBehavior) |
| Hide / show the kitten | `AppDelegate.swift` (applyHidden), `Settings.swift` (isHidden) |
| Launch at login | `Settings.swift` (LoginItem) |
| Screen-edge clamp | `AppDelegate.swift` (constrainNekoOrigin) |

## CONVENTIONS

- **Flat structure**: All Swift in `neko/`, no subfolders
- **No comments**: Code is self-documenting
- **Singleton settings**: `Settings.shared`
- **Timer-driven**: speed setting is the interval (normal 0.16s, ~6.25 fps), not display link
- **Hybrid AppKit/SwiftUI**: NSWindow hosts SwiftUI view

## ANTI-PATTERNS

- **NO `@Binding` for animation state** — Pass values directly, not bindings
- **NO strong self in Timer** — Always `[weak self]`
- **NO type suppressions** — No `as any`, `@ts-ignore` equivalents
- **NO storyboards** — Fully programmatic

## UNIQUE STYLES

- Pixel-perfect scaling: `.interpolation(.none)` preserves crispy pixels
- Sprite selection via negative offset on scaled spritesheet
- Movement speed proportional to size (bigger = faster)
- Window at `.statusBar` with `.fullScreenAuxiliary` (and `.canJoinAllApplications` on macOS 13+) for overlay including fullscreen apps. Set `isFloatingPanel` before `level`; `isFloatingPanel = true` resets the level to `.floating`.
- Walk frames only when the origin actually moved; edge blocks scratch, true arrival thinks/sits
- Animation timer is registered in `.common` **and** `.eventTracking`; `.common` alone stops during menu tracking

## COMMANDS

```bash
# Build (unsigned)
xcodebuild -project neko.xcodeproj -scheme neko build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

# Test
xcodebuild -project neko.xcodeproj -scheme neko \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  test \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Run
open build/Debug/neko.app
```

## NOTES

- `LSUIElement=true` → Menu bar only, no dock icon
- Category: `public.app-category.utilities` (not games, avoids Game Mode)
- Sprite sheet: 6 cols × 5 rows, base 16×16px
- 3 size presets: 16/24/32px
- Settings keys: `nekoSize`, `nekoSpeed`, `nekoHidden`
- Launch at login uses `SMAppService.mainApp` (macOS 13+), gated behind `LoginItem.isSupported`
- Menu bar icon is a template imageset (`MenuBarIcon`) drawn at 16pt from the sprite's outline
