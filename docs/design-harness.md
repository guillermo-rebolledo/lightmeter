# Design harness: the meter screen in the Simulator

The Simulator has no capture device. `CameraLightSource` therefore never produces
a reading, `MeterViewModel` lands on `.unavailable`, and the meter screen never
renders — which historically meant every design iteration had to be built to a
phone.

The design harness removes that block. Launched with `-design-harness`, a debug
build drives the meter from a **scripted light source** at a scene EV you choose,
and draws a **stand-in scene** behind the UI in place of the camera preview.
Nothing downstream is special-cased: `MeterViewModel` and `ExposureEngine` run
exactly the code they run on a phone.

Everything under `Lightmeter/DesignHarness/` is wrapped in `#if DEBUG` at file
scope, so a Release build compiles none of it. The only production-code
concession is `ContentView`'s optional `source:` parameter, which is `nil` in
Release and leaves behaviour exactly as it was.

## Launch arguments

| Argument | Values | Default |
| --- | --- | --- |
| `-design-harness` | *(flag)* — nothing else has any effect without it | off |
| `-harness-scene` | `blown-sky`, `dim-interior`, `mixed-contrast` | `blown-sky` |
| `-harness-ev` | any number — the scene's EV@ISO 100 | the scene's own nominal EV |

A mistyped value falls back rather than failing to launch, so a typo still gives
a running screen to look at.

### The scenes

| Scene | Nominal EV | What it is for |
| --- | --- | --- |
| `blown-sky` | 15 | Sunny-16 daylight. Most of the HUD sits over the brightest part of the frame; a near-black treeline cuts across the drawer. |
| `dim-interior` | 6 | A lamp-lit room. Almost all shadow — where a dark scrim risks vanishing into the scene behind it. Also the state that raises the tripod advisory. |
| `mixed-contrast` | 12 | A dark room with a blown window, placed so the drawer's surface carries near-white and near-black at once. |

The scenes are **drawn**, not photographed: a drawn scene renders identically on
every run (which is what makes two screenshots comparable), reviews in a diff,
and carries no licensing. What glass needs from a backdrop is luminance
structure — a hard edge, a hot spot, a deep shadow — and that is what they carry.

## Taking a screenshot, end to end

From the repository root. Substitute any available simulator name.

```sh
DEVICE="iPhone 17 Pro"
BUNDLE_ID=dev.gortiz.Lightmeter
DERIVED=/tmp/lightmeter-harness

# 1. Build the debug app for the Simulator.
xcodebuild \
  -project Lightmeter.xcodeproj \
  -scheme Lightmeter \
  -destination "platform=iOS Simulator,name=$DEVICE,OS=latest" \
  -derivedDataPath "$DERIVED" \
  build

# 2. Boot the simulator and wait for it.
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b

# 3. Install.
xcrun simctl install "$DEVICE" \
  "$DERIVED/Build/Products/Debug-iphonesimulator/Lightmeter.app"

# 4. Launch under the harness.
xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$DEVICE" "$BUNDLE_ID" \
  -design-harness -harness-scene blown-sky

# 5. Screenshot, once the first reading has landed.
sleep 3
xcrun simctl io "$DEVICE" screenshot meter-blown-sky.png
```

Steps 4–5 are the loop you repeat per scene — the build and install only need
redoing when the code changes:

```sh
for scene in blown-sky dim-interior mixed-contrast; do
  xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$DEVICE" "$BUNDLE_ID" -design-harness -harness-scene "$scene"
  sleep 3
  xcrun simctl io "$DEVICE" screenshot "meter-$scene.png"
done
```

To pin a specific reading rather than the scene's own light:

```sh
xcrun simctl launch "$DEVICE" "$BUNDLE_ID" \
  -design-harness -harness-scene mixed-contrast -harness-ev 9.5
```

## Running it from Xcode instead

Product ▸ Scheme ▸ Edit Scheme ▸ Run ▸ Arguments, and add
`-design-harness`, `-harness-scene`, `blown-sky` as separate entries. Uncheck
them to get an ordinary run back.

## What the harness does not reproduce

- **The camera preview itself**, obviously — including its rotation handling and
  its device-point conversion. The stand-in draws its own approximation of the
  spot reticle so spot mode stays inspectable, matched to the shipped UIKit one
  by eye rather than by shared code.
- **Live light.** The scene EV is fixed for the launch, so the meter reads a
  steady value. Freeze, priority, compensation and the dial are all fully
  drivable on top of it.
