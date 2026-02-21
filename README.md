# neko.app

A tiny menu bar kitten that follows your mouse on macOS.

<p align="center">
  <img alt="Demo" src="media/demo.gif">
</p>

## Features

- Animated pixel sprite that tracks the cursor.
- Always-on-top window, including fullscreen apps.
- Menu bar app only (no Dock icon).
- Three size presets, scaled with crisp pixels.

## Install

Download the [latest release](https://github.com/Chinteyley/neko/releases/latest), unzip, and move `neko.app` to your Applications folder.

Or build from source:

```bash
xcodebuild -project neko.xcodeproj -scheme neko build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

open build/Debug/neko.app
```

## Usage

- Click the menu bar icon to open controls.
- Size: Small (16 px), Medium (24 px), Large (32 px).
- Speed: Slow, Normal, Fast.
- Pause/Resume: `Cmd+Opt+P` (hides or shows the kitten).
- Quit: `Cmd+Q`.
- Settings persist between launches.

---

## Development

- App entry and window behavior: `neko/AppDelegate.swift`.
- Menu bar UI and actions: `neko/StatusBarController.swift`.
- Animation state machine: `neko/Neko.swift`.
- Frame selection logic: `neko/NekoAnimation.swift`.
- Movement logic: `neko/Store.swift`.
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
- Timer-driven updates (default 0.16s).
- Sprite sheet: 5 columns x 6 rows, base 16x16 px.

## Credits

Sprites taken from [skiftOS].

[skiftOS]: https://github.com/skiftOS/skift
