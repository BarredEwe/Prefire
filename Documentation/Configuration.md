## 🗂 Configuration: `.prefire.yml`

To customize **Prefire**, create a `.prefire.yml` file in the root of your project. This file defines how Prefire locates previews, generates files, and what devices or templates to use.

### 🧪 Example:

```yaml
test_configuration:
  target: PrefireExample
  test_target_path: ${PROJECT_DIR}/Tests
  test_file_path: PrefireExampleTests/PreviewTests.generated.swift
  template_file_path: CustomPreviewTests.stencil
  simulator_device: "iPhone15,2"
  required_os: 16
  preview_default_enabled: true
  use_grouped_snapshots: true
  split_snapshot_directories: false
  snapshot_wait_for_idle: true
  snapshot_wait_timeout: 2.0
  full_page_snapshots: false
  voiceover_snapshots:
    - image
    - text
  sources:
    - ${PROJECT_DIR}/Sources/
  snapshot_devices:
    - iPhone 14
    - iPad
  imports:
    - UIKit
    - SwiftUI
  testable_imports:
    - Prefire

playbook_configuration:
  preview_default_enabled: true
  template_file_path: CustomModels.stencil
  imports:
    - UIKit
    - Foundation
  testable_imports:
    - SwiftUI

render_configuration:
  scheme: PrefireExample
  workspace: PrefireExample.xcworkspace
  destination: platform=iOS Simulator,name=iPhone 16
  test_target: PrefireExampleTests
  output_dir: .prefire/render
```

`render_configuration` is used by `prefire render`, `prefire mcp` and `prefire board`. See its keys in the [AI guide](AI.md#setup).

---

### 🧾 Configuration Keys

| Key                                            | Description                                                                                                                                                                                                                               |
| ---------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `target`                                       | Target name used for snapshot generation. Default: _FirstTarget_                                                                                                                                                                          |
| `test_target_path`                             | Path to unit test directory. Snapshots will be written to its `__Snapshots__` folder. Default: target name folder                                                                                                                         |
| `test_file_path`                               | Output file path for generated tests. Default: DerivedData or resolved via plugin                                                                                                                                                         |
| `template_file_path`                           | Custom template path relative to target. Optional. Defaults:‣ _PreviewTests.stencil_ for test plugin‣ _PreviewModels.stencil_ for playbook plugin. See [Templates documentation](Templates.md) for available context and filters. |
| `simulator_device`                             | Device identifier used to run tests (e.g. `iPhone15,2`). Optional                                                                                                                                                                         |
| `required_os`                                  | Minimal iOS version required for preview rendering. Optional                                                                                                                                                                              |
| `snapshot_devices`                             | List of logical snapshot "targets" (used as trait collections). Each will snapshot separately. Optional                                                                                                                                   |
| `preview_default_enabled`                      | Should all detected previews be included by default? Set `false` if you want to require `.prefireEnabled()` manually. Default: `true`                                                                                                     |
| `use_grouped_snapshots`                        | Generate a single test file with all previews (`true`) or separate test files per source file (`false`). When `false`, use `{PREVIEW_FILE_NAME}` placeholder in `test_file_path`. Default: `true`                                         |
| `split_snapshot_directories`                   | When `use_grouped_snapshots: false`, also write snapshots into a separate `__Snapshots__/<File>Tests.generated/` folder per source file instead of one shared `__Snapshots__/PreviewTests.generated/` folder. Closes [#80](https://github.com/BarredEwe/Prefire/issues/80). Default: `false` to keep existing snapshot layouts working — opt in once you're ready to move the files.                |
| `sources`                                      | List of Swift files or folders to scan for previews. Defaults to inferred from the target                                                                                                                                                 |
| `imports`                                      | Extra imports added to the generated test or playbook file                                                                                                                                                                                |
| `testable_imports`                             | Extra `@testable` imports added to allow test visibility                                                                                                                                                                                  |
| `snapshot_wait_for_idle`                       | Wait for every preview to stop changing before it is captured, instead of relying on `.snapshot(delay:)`. Single previews opt out with `.snapshot(waitForIdle: false)`. Closes [#28](https://github.com/BarredEwe/Prefire/issues/28). Default: `false`                                                                        |
| `snapshot_wait_timeout`                        | How long a wait may take before the test fails, in seconds, counted once the `delay` of the preview is spent. Used by `.snapshot(waitForIdle:)` and `.snapshot(waitUntil:)` when they do not set their own timeout. Default: `5`                                                                                                                                          |
| `draw_hierarchy_in_key_window_default_enabled` | Specifies whether to use the simulator's key window to snapshot the UI, rendering `UIAppearance` and `UIVisualEffect`. This option requires a host application for testing and does not work with framework test targets. Optional. If omitted, uses swift-snapshot-testing's default value. |
| `full_page_snapshots` | Capture the whole scrollable content of screen previews (the default `#Preview` layout) instead of only the first screen. iOS/tvOS only. See [Full-page snapshots](#full-page-snapshots). Default: `false` |
| `voiceover_snapshots` | How previews are snapshotted for VoiceOver: a list of `image` and `text`, or `none`. iOS: AccessibilitySnapshot does not support tvOS, where the generated tests skip both strategies. See [VoiceOver snapshots](#voiceover-snapshots). Default: `image` |

---

### Full-page snapshots

With `full_page_snapshots: true`, a screen preview is laid out once more before it is snapshotted, and the canvas is stretched until the page's scroll view (`ScrollView`, `List`, `UITableView`, …) shows all of its content. The safe area and traits stay those of the device.

- Only the scroll view that follows the canvas counts. A scroll view with a fixed height nested in the page (e.g. `.frame(height: 200)`) is captured as it appears on screen.
- The extra layout hosts the preview once more, so `onAppear`, `.task` and `@StateObject` run one more time. A preview whose content differs between appearances can be measured differently from the image.
- With `.snapshot(delay:)`, the delay is waited once to measure and once more to take the image, so the test takes twice as long.
- A preview that is waited on with `.snapshot(waitForIdle:)` or `.snapshot(waitUntil:)` is measured once it settled, in the window it is captured in, so content it loads while waiting counts and it is hosted only once.
- The VoiceOver image from `AccessibilitySnapshot` uses the same height.
- The image is at most 16,384 px tall, which is about 5,461 pt at 3x.
- Previews using `.sizeThatFitsLayout` or a fixed layout are not affected.

---

### VoiceOver snapshots

Add `PrefireVoiceOver` to your **test target**, then enable text in `.prefire.yml`:

```swift
.product(name: "PrefireVoiceOver", package: "Prefire"),
```

```yaml
test_configuration:
  voiceover_snapshots:
    - text
```

| Strategy | Test target needs | Reference |
| --- | --- | --- |
| `image` | The `AccessibilitySnapshot` product of [AccessibilitySnapshot](https://github.com/cashapp/AccessibilitySnapshot) | `<test>-accessibility.1.png`: the preview with its elements and activation points marked |
| `text` | The `PrefireVoiceOver` product of Prefire | `<test>-voiceover-text.1.txt`: what VoiceOver reads, compared with SnapshotTesting's existing `.lines` strategy |

Both can be listed as `[image, text]`. `none`, `[]` or an empty value turns them off. Without the key, or when it names no known strategy, Prefire keeps the existing `image` behavior. Unknown strategies produce a warning. PNG reference names stay unchanged; text has a separate test name and counter. Text is generated on iOS only; a missing `PrefireVoiceOver` dependency is a compile error rather than a silently skipped assertion.

`PrefireVoiceOver` owns the parser, formatter and hosting/waiting pipeline. It depends on `AccessibilitySnapshotParser` from 0.13.0. The app's `Prefire` product does not depend on this module, and the module does not link SnapshotTesting. The package-level AccessibilitySnapshot dependency and its transitive package requirements still participate in resolution, including for consumers that select only `Prefire`; incompatible version pins can therefore conflict. The manifest remains tools 6.0. [SwiftPM traits](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md) require tools 6.1, and the original implementation does not exclude disabled dependencies from resolution.

A pure SwiftUI screen generally produces a flat list. SwiftUI structures such as `SettingsRow` are not UIKit views and do not become tree nodes. The text includes real UIKit ancestors and accessibility containers when the parser exposes them. The [UIKit settings example](../Example/Shared/Examples/UIKitView.swift) and its [integration assertion](../Example/PrefireExampleTests/PrefireExampleTests.swift) show this format:

```text
SettingsScreen
  [group: Settings]
    - Notifications: On
    - Language: English
```

- A leaf starts with `- ` followed by the description (label, value and traits), important custom content and hint. An element with nothing to read is a bare `-`.
- Swift-defined UIKit app views are named without their module or generic parameters. System classes are excluded by their loaded image path under `/System/Library/`, including simulator runtime paths. SwiftUI hosting classes do not imply a hierarchy of SwiftUI structures.
- Announced containers are `[list]`, `[table]`, `[tab bar]` and `[group: <label>]`. Modal views include ` (modal)`. Shared ancestors are written once, and a view that is both an element and an ancestor appears above its own phrase.
- Additional lines describe actions, non-important custom content, rotor result counts, direct interaction, frequent updates and language. Frames, identifiers and traversal numbers are omitted.
- The library explicitly enables accessibility automation before hosting, then reads every 50 ms until two reads agree, up to `snapshot_wait_timeout` after `delay`. Empty and redacted previews may legitimately produce empty text. Changing text throws a timeout through the usual preview failure path.
- Accessibility captures render anew and honor `delay`; they do not reuse the state reached by `.snapshot(waitForIdle:)` or `.snapshot(waitUntil:)`. With both strategies, text and the accessibility image share one hosting controller and spend `delay` once, separate from the normal image. Text is read before the image strategy adds its overlays, with at least two reads about 50 ms apart after the initial layout pass. Full-page measurement may add its own render as described above.
- Text follows the existing project/device semantics. Each configured device gets its own reference even when today's transcripts match, since adaptive content and accessibility order can differ between devices.
- The parser sees SwiftUI `ScrollView` content only in tests with a host application ([cashapp/AccessibilitySnapshot#245](https://github.com/cashapp/AccessibilitySnapshot/issues/245)). Without one, a scrolling screen's text can lack its content.

The existing `Trip` references demonstrate accessibility problems, not a recommended spoken interface: flight field labels and values are read separately, and decorative symbols announce phrases such as “Selected: Selected. Image.” Keep these diffs visible when improving the example's accessibility; they are not an endorsement of that behavior.

---

### macOS snapshot tests

macOS targets require no additional configuration. Use `AppKit` instead of `UIKit` in `imports:` and omit the iOS-only `simulator_device`, `required_os`, and `snapshot_devices` keys — the generated file ignores them on macOS.

**Only snapshot tests are supported on macOS.** `PlaybookView` is iOS-only, so `PrefirePlaybookPlugin` output cannot be displayed on macOS yet.

#### Canvas size

Every macOS preview is rendered at its fitting size, including a plain `#Preview` (macOS has no device canvas to fall back to). For anything larger than a small component this is rarely what you want, so pin the canvas explicitly with `fixedLayout`:

```swift
#Preview("Settings", traits: .fixedLayout(width: 900, height: 600)) {
    SettingsView()
}
```

For a `PreviewProvider`, use `.previewLayout(.fixed(width:height:))`:

```swift
struct Preferences_Previews: PreviewProvider, PrefireProvider {
    static var previews: some View {
        PreferencesView()
            .previewLayout(.fixed(width: 900, height: 600))
    }
}
```

Both apply on macOS only. On iOS/tvOS the layout is derived from the preview type.

A canvas larger than 4096 pt in either dimension is clamped to 4096 pt.

#### AppKit previews

`NSView` and `NSViewController` previews are supported through the public `ViewRepresentable` and `ViewControllerRepresentable` wrappers (the same names as on iOS).

#### Rendering and stability

Prefire hosts SwiftUI in an off-screen `NSWindow` and then uses SnapshotTesting’s `NSView.image` strategy. Effects that need a real window (including `.rotation3DEffect`) do not crash at host time. Pixel-accurate 3D compositing still depends on SnapshotTesting’s `cacheDisplay` path — it is weaker than iOS `drawHierarchyInKeyWindow`.

The backing scale factor is pinned to `2` rather than inherited from the current display, so a snapshot recorded on a Retina Mac matches one verified on a CI runner. Override it per snapshot with `DeviceConfig(size:scale:)` in a [custom template](Templates.md).

Snapshot images are still pixel-based and can differ between macOS or Xcode releases. Record and compare a baseline on the same macOS/Xcode version.

#### Re-recording all snapshots

After an Xcode update every reference usually goes stale at once. Set `SNAPSHOT_TESTING_RECORD=all` on the test scheme or the CI job and run the tests once — swift-snapshot-testing re-records every snapshot in every module. `withSnapshotTesting(record:)` works the same way. A preview marked with `.snapshot(record: true)` is always re-recorded, whatever the environment says.

#### Running from SwiftPM

Verifying snapshots works with a plain `swift test`. **Recording** new references writes into `__Snapshots__` next to your sources, which SwiftPM’s build sandbox denies — pass `--disable-sandbox` for the recording run only:

```bash
swift test --disable-sandbox
```

---

📌 You can define both `test_configuration` and `playbook_configuration` at once.

Prefire will use these settings when generating files either via:

- CLI: `prefire tests`, `prefire playbook`
- Plugin: attached to test or main targets in Xcode/SwiftPM

To support different configurations per module, you may also use multiple `.prefire.yml` files — one per package, if needed.
