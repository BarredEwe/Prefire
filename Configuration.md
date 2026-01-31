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
| `template_file_path`                           | Custom template path relative to target. Optional. Defaults:‣ _PreviewTests.stencil_ for test plugin‣ _PreviewModels.stencil_ for playbook plugin                                                                                         |
| `simulator_device`                             | Device identifier used to run tests (e.g. `iPhone15,2`). Optional                                                                                                                                                                         |
| `required_os`                                  | Minimal iOS version required for preview rendering. Optional                                                                                                                                                                              |
| `snapshot_devices`                             | List of logical snapshot "targets" (used as trait collections). Each will snapshot separately. Optional                                                                                                                                   |
| `preview_default_enabled`                      | Should all detected previews be included by default? Set `false` if you want to require `.prefireEnabled()` manually. Default: `true`                                                                                                     |
| `use_grouped_snapshots`                        | Generate a single test file with all previews (`true`) or separate test files per source file (`false`). When `false`, use `{PREVIEW_FILE_NAME}` placeholder in `test_file_path`. Default: `true`                                         |
| `sources`                                      | List of Swift files or folders to scan for previews. Defaults to inferred from the target                                                                                                                                                 |
| `imports`                                      | Extra imports added to the generated test or playbook file                                                                                                                                                                                |
| `testable_imports`                             | Extra `@testable` imports added to allow test visibility                                                                                                                                                                                  |
| `draw_hierarchy_in_key_window_default_enabled` | Specifies whether to use the simulator's key window to snapshot the UI, rendering `UIAppearance` and `UIVisualEffect`. This option requires a host application for testing and does not work with framework test targets. Optional. If omitted, uses swift-snapshot-testing's default value. |

---

📌 You can define both `test_configuration` and `playbook_configuration` at once.

Prefire will use these settings when generating files either via:

- CLI: `prefire tests`, `prefire playbook`
- Plugin: attached to test or main targets in Xcode/SwiftPM

To support different configurations per module, you may also use multiple `.prefire.yml` files — one per package, if needed.
