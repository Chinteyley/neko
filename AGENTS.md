# neko

Menu bar kitten. A click-through `NSPanel` follows the cursor and stays above every window, including fullscreen apps. `LSUIElement` is on, so there is no Dock icon.

Humans read `README.md`. This file is the map for code changes.

## Where to look

| Task | Location |
|------|----------|
| New animation state | `Neko.swift` (`NekoState` + `offset`) |
| Walk, idle, think, scratch | `Store.swift` (`nextTick`, `nextDirection`) |
| Menu bar items | `StatusBarController.swift` |
| Size or speed presets | `Settings.swift` (`NekoSize`, `NekoSpeed`) |
| Overlay window, timer, hide | `AppDelegate.swift` |
| Screen-edge clamp | `constrainNekoOrigin` in `AppDelegate.swift` |
| Launch at login | `LoginItem` in `Settings.swift` |
| Hide / show | `AppDelegate.applyHidden`, `Settings.isHidden` |
| Held sign line | `Settings.swift` (`NekoSign`, `NekoSignMetrics`) + `ContentView.swift` |
| Sprite sheet | `neko/Assets.xcassets/Neko.imageset/` |
| Menu bar icon | `neko/Assets.xcassets/MenuBarIcon.imageset/` |
| Drag-to-Applications image | `scripts/package-dmg.sh`, `.github/workflows/release.yml` |
| Tests | `nekoTests/` |

## Layout

```
neko/
├── main.swift                 # NSApplication + AppDelegate (not @main)
├── AppDelegate.swift          # Panel, timer, hide, screen recovery
├── Settings.swift             # Size, speed, hidden, sign, LoginItem
├── StatusBarController.swift  # Menu
├── Store.swift                # Direction + animation state machine
├── Neko.swift                 # Sprite view, NekoState, sheet offsets
├── NekoAnimation.swift        # Frame picker: anim[tick % count]
├── ContentView.swift          # ObservedObject wrapper + held sign
├── Info.plist
└── Assets.xcassets/
nekoTests/
├── NekoCustomizationTests.swift  # Menu, size/speed, sign, stop radius, hide
├── NekoPlacementTests.swift      # Clamp, scratch, multi-display, sign footprint
└── StoreThinkingTests.swift      # 0.6s think, idle progression
scripts/package-dmg.sh
.github/workflows/ci.yml
.github/workflows/release.yml
media/demo.webp                    # README loop
media/demo.mp4                     # compact muted source
```

Swift stays in `neko/`. No storyboards. `Settings.shared` is the settings singleton.

README uses the WebP so it autoplays. Recut from the MP4. A GIF of this wallpaper is tens of megabytes.

## Movement

`Store.nextTick` is the whole gait.

1. Direction is the nearest of eight ways, with hysteresis. Stop radius is one `NekoSize` step. Resume is 1.5 steps.
2. First step out of idle is `.alert` and does not move.
3. Walk frames fire only when the origin actually changed.
4. A blocked edge (menu bar, Dock, display gap) sets `.scratching1` / `.scratching2` and stays put.
5. True arrival thinks for 0.6s of wall time if the mouse is still, otherwise sits. Thinking is a deadline, not a tick count, so speed changes do not stretch it.
6. Idle then goes grooming, idle, yawn, sleep based on `ticksSinceLastMove`.

`constrainNekoOrigin` keeps the whole panel (sprite + sign) inside a visible frame. Empty `visibleFrames` leaves the proposed origin alone. AppDelegate passes `window.frame.size` so the bubble stays on-screen.

Unhiding and display-change recovery call `bringNekoHere()`, which recenters on the mouse's screen. Do not show the kitten on a display that is gone.

## Overlay

Window setup order matters:

1. Borderless nonactivating `NSPanel`
2. `isFloatingPanel = true`, then `level = .statusBar`. Setting the floating-panel flag later resets the level to `.floating`.
3. Collection behavior: `canJoinAllSpaces`, `fullScreenAuxiliary`, `stationary`, and `canJoinAllApplications` on macOS 13+
4. `isOpaque = false`, `backgroundColor` with alpha 0, then `ignoresMouseEvents = true` except when the cursor is over the sprite or sign
5. Host `ContentView` and start the timer. The panel is sprite-plus-sign, not sprite-only.

`makeNekoTimer` registers in `.common` and `.eventTracking`. `.common` alone does not run during menu tracking. `testAnimationTimerRunsWhileAMenuTracksEvents` fails if you drop `.eventTracking`.

No timer runs while `isHidden` is true.

## Settings

| Key | Values |
|-----|--------|
| `nekoSize` | 16 / 24 / 32 (Small / Medium / Large) |
| `nekoSpeed` | 0.24 / 0.16 / 0.10 s (Slow / Normal / Fast) |
| `nekoHidden` | bool |
| `nekoSign` | 0 / 1 / 2 (`still left-aligned` / `yelled at: 4` / `$47`) |

Speed is the timer interval, not pixels per tick. Bigger size already walks farther per tick.

Launch at login is `SMAppService.mainApp` behind `LoginItem.isSupported` (macOS 13+). It is not a UserDefaults flag. Re-read it in `menuWillOpen`. If status is `.requiresApproval`, open the Login Items pane. Unsigned builds outside `/Applications` cannot register.

Menu titles are plain names. `testStatusMenuUsesPlainSizeNamesAndOmitsDistanceAndRecovery` locks the current item list.

## Sprites

`Neko.imageset` is a 192×192 sheet. Frames are 16×16, picked with a negative offset and `.interpolation(.none)`. Add a state by extending `NekoState` and the `offset` switch together.

`MenuBarIcon` is a template imageset drawn at 16pt. Keep it on the sprite's pixel grid so it does not land on a fractional scale.

## Conventions

- Pass size and similar settings as values. Do not add a new `@Binding` for animation state.
- Timer closures capture `[weak self]`.
- Code has no comments unless the next reader would miss a non-obvious rule. The overlay order and the timer modes above are those rules.
- App category is `public.app-category.utilities` so Game Mode stays off.

## Commands

```bash
# Unsigned debug
xcodebuild -project neko.xcodeproj -scheme neko build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

# Tests
xcodebuild -project neko.xcodeproj -scheme neko \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  test \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Run
open build/Debug/neko.app

# Disk image (needs Node 20+ / npx)
scripts/package-dmg.sh path/to/neko.app neko.dmg
```

## Release

Tag `v$MARKETING_VERSION`. The workflow fails if they disagree. Bump `MARKETING_VERSION` in both configurations and `CFBundleVersion` in `Info.plist` in the same change.

`.github/workflows/release.yml` builds a universal app, signs it, notarizes and staples the app, builds the DMG with `scripts/package-dmg.sh`, signs and notarizes the DMG, then hashes it. Compute the published `.sha256` after staple. Signing and stapling rewrite the file.

Local packaging does not sign. CI signs with the Developer ID secrets.

## Tests

Run the suite above after movement, clamp, menu, timer, or settings changes.

- `NekoCustomizationTests` covers the menu shape, persist, stop/resume hysteresis, the event-tracking timer, and sign cycling.
- `NekoPlacementTests` covers visible-frame clamp, scratch vs arrive at the edge, multi-display gaps, and the wider sign footprint.
- `StoreThinkingTests` covers the 0.6s think window across speed changes.
