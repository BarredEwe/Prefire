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
```

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
| `draw_hierarchy_in_key_window_default_enabled` | Specifies whether to use the simulator's key window to snapshot the UI, rendering `UIAppearance` and `UIVisualEffect`. This option requires a host application for testing and does not work with framework test targets. Optional. If omitted, uses swift-snapshot-testing's default value. |

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
