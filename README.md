# neko.app

A tiny menu bar kitten that follows your mouse on macOS.

<p align="center">
  <img alt="Demo" src="media/demo.gif">
</p>

## Features

- Animated eight-direction pixel sprite that follows the cursor along a direct path.
- Crisp, step-based movement with immediate direction changes between movement gaits.
- Brief thinking animation when the kitten arrives.
- Screen-aware recovery when displays change.
- Three built-in color themes.
- Always-on-top window, including fullscreen apps.
- Menu bar app only (no Dock icon).
- Three size presets, scaled with crisp pixels.

## Install

Download the macOS ZIP from the [latest release](https://github.com/Chinteyley/neko/releases/latest), unzip it, and move `neko.app` to your Applications folder. The ZIP includes a universal build for Apple silicon and Intel Macs. Use the matching `.sha256` file to verify the download with `shasum -a 256 -c`.

Releases are signed with Developer ID and notarized by Apple.

Or build from source:

```bash
xcodebuild -project neko.xcodeproj -scheme neko build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  MACOSX_DEPLOYMENT_TARGET=12.0

open build/Debug/neko.app
```

## Usage

- Click the menu bar icon to open controls.
- Size: Small, Medium, Large.
- Speed: Slow, Normal, Fast.
- Theme: Classic, Ginger, Blue-Gray.
- Pause/Resume: `Cmd+Opt+P` (hides or shows the kitten).
- Quit: `Cmd+Q`.
- Settings persist between launches.

---

## Development

- App entry and window behavior: `neko/AppDelegate.swift`.
- Menu bar UI and actions: `neko/StatusBarController.swift`.
- Movement and direction state machine: `neko/Store.swift`.
- Sprite states and frame selection: `neko/Neko.swift` and `neko/NekoAnimation.swift`.
- Settings and persistence: `neko/Settings.swift`.
- SwiftUI wrapper: `neko/ContentView.swift`.
- Sprite sheet assets: `neko/Assets.xcassets/Neko.imageset`.

Conventions:

- Programmatic UI only, no storyboards.
- Default to value passing, avoid `@Binding` for animation state.
- Use `[weak self]` in timer callbacks.
- Keep code comment-free unless intent is non-obvious.

## Project Notes

- Swift + SwiftUI, no storyboards.
- Timer-driven movement updates (default 0.16s).
- Position advances toward the cursor by one size-scaled step per update.
- Sprite gait uses the nearest of eight directions while preserving straight movement paths.
- Sprite sheet: 5 columns x 6 rows, base 16x16 px.

## Credits

- Maintained by Chinteyley.
- Original sprites are taken from [skiftOS].

[skiftOS]: https://github.com/skiftOS/skift
