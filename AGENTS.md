# NEKO — macOS Desktop Pet

**Generated:** 2026-01-05  
**Commit:** d26dc5e  
**Branch:** master

## OVERVIEW

Menu bar app — animated cat follows mouse cursor, floats above all windows including fullscreen.

## STRUCTURE

```
neko/
├── AppDelegate.swift      # Entry point, window + timer setup
├── Settings.swift         # NekoSize enum, UserDefaults persistence
├── StatusBarController.swift  # Menu bar UI
├── Store.swift            # Movement logic, direction state machine
├── Neko.swift             # Sprite view, NekoState enum (27 states)
├── NekoAnimation.swift    # Animation frame selector
├── ContentView.swift      # SwiftUI wrapper
└── Assets.xcassets/Neko.imageset/  # 5×6 sprite sheet (1x/2x/3x)
```

## WHERE TO LOOK

| Task | Location |
|------|----------|
| Add new animation state | `Neko.swift` (NekoState enum + offset switch) |
| Change movement behavior | `Store.swift` (nextTick, nextDirection) |
| Add menu bar options | `StatusBarController.swift` |
| Modify size presets | `Settings.swift` (NekoSize enum) |
| Window behavior | `AppDelegate.swift` (window.level, collectionBehavior) |

## CONVENTIONS

- **Flat structure**: All Swift in `neko/`, no subfolders
- **No comments**: Code is self-documenting
- **Singleton settings**: `Settings.shared`
- **Timer-driven**: 0.16s interval (6.25 fps), not display link
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
- Window at `CGWindowLevelForKey(.maximumWindow)` for true overlay

## COMMANDS

```bash
# Build (unsigned)
xcodebuild -project neko.xcodeproj -scheme neko build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

# Run
open build/Debug/neko.app
```

## NOTES

- `LSUIElement=true` → Menu bar only, no dock icon
- Category: `public.app-category.utilities` (not games, avoids Game Mode)
- Sprite sheet: 5 cols × 6 rows, base 16×16px
- 5 size presets: 16/32/48/64/96px (all multiples of 16)
