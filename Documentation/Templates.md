# ✍️ Stencil Templates

Prefire generates both snapshot tests and Playbook models by rendering a [Stencil](https://stencil.fuller.li/) template with a context built from your project. The default templates cover the most common case, but every team has its own conventions — you can fully replace either template with your own `.stencil` file.

This page describes the template engine, the variables available inside templates, the filters you can use, and how to wire a custom template into your project.

---

## 1. Configuration

Point Prefire at a custom template through `template_file_path` in `.prefire.yml`. The path is resolved relative to your target — `test_target_path` for the tests plugin, `target` for the playbook plugin. If the key is omitted, Prefire uses its built-in template.

```yaml
# .prefire.yml

test_configuration:
  target: MyApp
  test_target_path: ${PROJECT_DIR}/MyAppTests
  test_file_path: MyAppTests/PreviewTests.generated.swift
  template_file_path: MyAppTests/CustomPreviewTests.stencil

playbook_configuration:
  target: ${PROJECT_DIR}/MyApp
  template_file_path: MyApp/CustomPreviewModels.stencil
```

Notes:

- The path is relative to the resolved `test_target_path` / `target` directory, **not** to the location of `.prefire.yml`.
- Both `test_configuration.template_file_path` and `playbook_configuration.template_file_path` are independent — you can override one and keep the default for the other.
- The same `template_file_path` can be reused by multiple targets if the relative path resolves correctly from each.

---

## 2. Template engine

Prefire uses the Stencil templating language with the Swift-oriented filters from [StencilSwiftKit](https://github.com/SwiftGen/StencilSwiftKit) and a few of its own. If you've written a SwiftGen or Sourcery template before, the syntax will feel familiar.

- [Stencil syntax](https://stencil.fuller.li/) — `{% ... %}` for logic, `{{ ... }}` for output, `{# ... #}` for comments.
- [StencilSwiftKit filters](https://github.com/SwiftGen/StencilSwiftKit/blob/master/Documentation/filters.md) — string helpers for Swift code generation.

Runs of blank lines left behind by `{% if %}` and `{% for %}` blocks are collapsed before the file is written, so a template can be laid out for readability without padding the generated output.

The context rendered into your template has three top-level objects: `argument`, `types`, and (implicitly) the `previewsMacrosDict` array attached to `argument`.

---

## 3. Context reference

### 3.1 `argument.*` — configuration values

These keys are produced by `GenerateTestsCommand` and `GeneratePlaybookCommand` and are always available inside templates:

| Key                                      | Type                   | Plugin | Description                                                                                              |
| ---------------------------------------- | ---------------------- | ------ | -------------------------------------------------------------------------------------------------------- |
| `argument.imports`                       | `[String]` (or absent) | both   | Extra `import` lines from `imports:` in the config.                                                      |
| `argument.testableImports`               | `[String]` (or absent) | both   | Extra `@testable import` lines from `testable_imports:` in the config.                                   |
| `argument.mainTarget`                    | `String` (or absent)   | tests  | The `target:` value; emitted as `@testable import {{ argument.mainTarget }}`.                            |
| `argument.file`                          | `String` (or absent)   | tests  | Resolved output path for the generated test file; used as the `file:` argument of `assertSnapshot`.      |
| `argument.simulatorDevice`               | `String` (or absent)   | tests  | Device model identifier (e.g. `iPhone15,2`) from `simulator_device:`.                                    |
| `argument.simulatorOSVersion`            | `String` (or absent)   | tests  | Major iOS version from `required_os:`.                                                                   |
| `argument.snapshotDevices`               | `String` (or absent)   | tests  | Snapshot device names joined by `\|`. Iterate by applying `\|split:"\|"`. See §4.                        |
| `argument.drawHierarchyInKeyWindowDefaultEnabled` | `String` `"true"`/`"false"` (or absent) | tests | Value of `draw_hierarchy_in_key_window_default_enabled:` as a string. |
| `argument.globalConfiguration`           | `String` (or absent)   | both   | Type name from `global_configuration:`, or the single `PrefireGlobalConfiguration` conformer found in the sources. Absent when neither applies. |
| `argument.previewsMacrosDict`            | `[[String: Any]]`      | both   | Array of `#Preview` macro models. See §3.3.                                                              |

`NSNull` values (i.e. when a config key is missing) should be guarded with `{% if argument.foo %}` — Stencil treats both `nil` and `NSNull` as falsy.

### 3.2 `types.*` — `PreviewProvider`-based previews

`types` comes from Prefire's own scan of the sources. The default templates iterate over it to generate one `func test_*()` per `PreviewProvider`/`PrefireProvider` type:

```stencil
{% for type in types.types where type.kind != "protocol" and type.kind != "extension" and (type.implements.PrefireProvider or type.based.PrefireProvider or type|annotated:"PrefireProvider") %}
func test_{{ type.name|lowerFirstLetter|replace:"_Previews", "" }}() {
    for preview in {{ type.name }}._allPreviews {
        // ...
    }
}
{% endfor %}
```

Skip `protocol` and `extension` kinds: an intermediate `protocol TeamProvider: PrefireProvider` is itself "based on" `PrefireProvider`, but `TeamProvider._allPreviews` does not compile.

Fields on a `type`:

| Field            | Description                                                                                     |
| ---------------- | ----------------------------------------------------------------------------------------------- |
| `name`           | Fully-qualified type name, e.g. `Outer.Inner`.                                                  |
| `localName`      | Short (unqualified) name of the type.                                                            |
| `implements.X`   | Truthy if the type conforms to a protocol named `X` that is declared in the scanned sources.     |
| `based.X`        | Truthy if the type inherits from anything named `X`, whether or not `X` itself is in the sources. Use this for protocols declared in another module, such as `PrefireProvider`. |
| `inherits.X`     | Truthy if the type inherits from a class named `X` declared in the scanned sources.              |
| `inheritedTypes` | The names written in the declaration's inheritance clause, as an array.                          |
| `kind`           | `struct`, `class`, `enum`, `actor`, `protocol`, or `extension` for a conformance added to a type declared elsewhere. |
| `isExtension`    | `true` when the type is only known through an `extension` (no declaration in the scanned sources). |
| `accessLevel`    | `open`, `public`, `package`, `internal`, `fileprivate` or `private`.                              |
| `annotations`    | Dictionary of `// prefire:` / `// sourcery:` annotations on the declaration.                      |

`implements`, `based` and `inherits` are resolved transitively and include conformances added by an `extension`, in any scanned file. Given `protocol TeamProvider: PrefireProvider` and `struct Panel_Previews: TeamProvider`, `based.PrefireProvider` is truthy.

Besides `types.types` (every scanned declaration, including protocols and extension-only placeholders), the collection also offers `types.all` (declarations excluding protocols), `types.protocols`, `types.classes`, `types.structs`, `types.enums`, `types.extensions`, and the `types.based.X` / `types.implementing.X` / `types.inheriting.X` lookups.

Types are visited in sorted source-file order, so the generated declarations keep a stable order between runs.

### 3.3 `macroModel.*` — `#Preview` macro models

When the source file contains `#Preview { ... }` blocks, each one is parsed into a `RawPreviewModel` and exposed as a dictionary inside `argument.previewsMacrosDict`. The default templates iterate over the array and emit one test per element:

```stencil
{% for macroModel in argument.previewsMacrosDict %}
func test_{{ macroModel.componentTestName }}_Preview() {
    // ...
    {{ macroModel.body|indent:12 }}
    // ...
}
{% endfor %}
```

Each element of `previewsMacrosDict` has the following keys (see `RawPreviewModel.makeStencilDict()`):

| Key                   | Type      | Description                                                                                                       |
| --------------------- | --------- | ----------------------------------------------------------------------------------------------------------------- |
| `displayName`         | `String`  | Human-readable name of the preview, derived from the first string literal in the macro (e.g. `"Default" → Default`). |
| `componentTestName`   | `String`  | Sanitized identifier (non-alphanumerics stripped). Safe to embed in Swift identifiers.                            |
| `isScreen`            | `Bool`    | `true` if the preview contains the `.device` trait, `false` otherwise.                                            |
| `fixedLayoutSize`     | `String?` | `CGSize` expression from `.fixedLayout(width:height:)`, or absent when the trait is not set.                       |
| `body`                | `String`  | The Swift body of the preview, as a raw string. Use `\|indent:N` to align it inside a generated closure.         |
| `properties`          | `String?` | Captured `@Previewable` property declarations (joined with newlines), or `nil` if there are none.                 |
| `traits`              | `[String]`| Raw trait tokens, e.g. `["device"]`, `[".myTrait(\"x\")"]`.                                                       |

---

## 4. Filters reference

Only filters that the default templates actually use are listed below. For the complete set, see the [Stencil built-in filters](https://stencil.fuller.li/) and the [StencilSwiftKit filters](https://github.com/SwiftGen/StencilSwiftKit/blob/master/Documentation/filters.md). Prefire additionally provides `count`, `isEmpty`, `toArray`, `last` and `reversed`.

| Filter                | Origin   | Purpose                                                                 | Example                                                        |
| --------------------- | -------- | ----------------------------------------------------------------------- | -------------------------------------------------------------- |
| `lowerFirstLetter`    | StencilSwiftKit | Lowercase the first character (for test function names).        | `{{ type.name\|lowerFirstLetter }}` → `myView` from `MyView`   |
| `replace:OLD,NEW`     | StencilSwiftKit | Replace literal substring `OLD` with `NEW`.                     | `{{ type.name\|replace:"_Previews", "" }}`                     |
| `split:SEP`           | Stencil  | Split a string by `SEP` and emit a Swift array literal.                | `{{ argument.snapshotDevices\|split:"\|" }}` → `["iPhone 14"]` |
| `indent:N`            | Stencil  | Indent every line of the input by `N` spaces.                           | `{{ macroModel.body\|indent:12 }}`                             |
| `default:VALUE`       | Stencil  | Use `VALUE` when the variable is missing.                               | `{{ argument.simulatorDevice\|default:nil }}`                 |
| `annotated:NAME`      | Prefire  | Boolean on a single type, or a filtered list when applied to an array. Supports `NAME = VALUE`. | `{% for type in types.types where type\|annotated:"PrefireProvider" %}` or `{% for type in types.types\|annotated:"PrefireProvider" %}` |
| `based:NAME`          | Prefire  | Filter form of `type.based.NAME`. `implements:` and `inherits:` work the same way. Boolean or filtered list. | `{% for type in types.types where type\|based:"PrefireProvider" %}` |
| `forloop.last`        | Stencil  | `true` on the last iteration of a `{% for %}` loop. Useful for separators. | `{%- if not forloop.last %}\n\n{% endif %}`               |

---

## 5. Default templates

The built-in templates are the most useful starting point — copy them, change what you need, and reference the new file from `.prefire.yml`.

- **Tests template** — `EmbeddedTemplates.previewTests` in [`PrefireExecutable/Sources/PrefireCore/Templates/PreviewTestsTemplate.swift`](../PrefireExecutable/Sources/PrefireCore/Templates/PreviewTestsTemplate.swift)
- **Playbook template** — `EmbeddedTemplates.previewModels` in [`PrefireExecutable/Sources/PrefireCore/Templates/PreviewModelsTemplates.swift`](../PrefireExecutable/Sources/PrefireCore/Templates/PreviewModelsTemplates.swift)

Key blocks worth studying:

- **Class-name placeholder** — the tests template references `{PREVIEW_FILE_NAME}` so the same file works for both `use_grouped_snapshots: true` and `use_grouped_snapshots: false` modes:
  ```stencil
  @MainActor class {PREVIEW_FILE_NAME}Tests: XCTestCase {
  ```
  When `use_grouped_snapshots: false`, Prefire replaces `{PREVIEW_FILE_NAME}` in **both** the output path and the template body with the source-file name before rendering. The same placeholder is also valid in `test_file_path`.
- **`snapshotDevices` array** — the config stores a pipe-joined string; the template splits it back into a Swift array:
  ```stencil
  private let snapshotDevices: [String]{% if argument.snapshotDevices %} = {{ argument.snapshotDevices|split:"|" }}{% else %} = []{% endif %}
  ```
- **Per-device iteration** — guarded by an empty-check, so a single test runs once on the default device and once per `snapshot_devices` entry:
  ```stencil
  {% if argument.file %}
  private var file: StaticString { .init(stringLiteral: "{{ argument.file }}") }
  {% endif %}
  ```
- **`@Previewable` properties** — captured as raw Swift source and embedded verbatim into a generated `PreviewWrapper` view:
  ```stencil
  {% if macroModel.properties %}
  struct PreviewWrapper{{ macroModel.componentTestName }}: SwiftUI.View {
      {{ macroModel.properties }}
      var body: some View {
          {{ macroModel.body|indent:12 }}
      }
  }
  {% endif %}
  ```
- **Macro/preview-provider coexistence** — the `{% if argument.previewsMacrosDict %}` guard is required; an empty array still produces a `for` block, but the guard skips it cleanly when there are no `#Preview` macros in the file.

---

## 6. Worked example

Suppose you don't use AccessibilitySnapshot and you want a leaner tests file. Save the following as `MyAppTests/MinimalPreviewTests.stencil`:

```stencil
// swiftlint:disable all
// swiftformat:disable all

import XCTest
import SwiftUI
import Prefire
{% for import in argument.imports %}
import {{ import }}
{% endfor %}
{% if argument.mainTarget %}
@testable import {{ argument.mainTarget }}
{% endif %}
{% for import in argument.testableImports %}
@testable import {{ import }}
{% endfor %}
import SnapshotTesting

@MainActor class {PREVIEW_FILE_NAME}Tests: XCTestCase {
    private let deviceConfig: DeviceConfig = ViewImageConfig.iPhoneX.deviceConfig

    {% if argument.previewsMacrosDict %}
    {% for macroModel in argument.previewsMacrosDict %}
    func test_{{ macroModel.componentTestName }}_Preview() {
        let prefireSnapshot = PrefireSnapshot(
            {
                {{ macroModel.body|indent:12 }}
            },
            name: "{{ macroModel.displayName }}",
            isScreen: {% if macroModel.isScreen == 1 %}true{% else %}false{% endif %},
            device: deviceConfig
        )

        if let failure = assertSnapshot(of: prefireSnapshot.loadViewWithPreferences().0, as: .image) {
            XCTFail(failure)
        }
    }
    {% endfor %}
    {% endif %}
}
```

Wire it up in `.prefire.yml`:

```yaml
test_configuration:
  target: MyApp
  test_target_path: ${PROJECT_DIR}/MyAppTests
  test_file_path: MyAppTests/PreviewTests.generated.swift
  template_file_path: MyAppTests/MinimalPreviewTests.stencil
  imports:
    - UIKit
```

For a preview like:

```swift
#Preview("Default") {
    Button("Submit") { }
}
```

Prefire will produce (skeleton):

```swift
import XCTest
import SwiftUI
import Prefire
import UIKit
@testable import MyApp
import SnapshotTesting

@MainActor class PreviewTests: XCTestCase {
    private let deviceConfig: DeviceConfig = ViewImageConfig.iPhoneX.deviceConfig

    func test_Default_Preview() {
        let prefireSnapshot = PrefireSnapshot(
            {
                Button("Submit") { }
            },
            name: "Default",
            isScreen: false,
            device: deviceConfig
        )

        if let failure = assertSnapshot(of: prefireSnapshot.loadViewWithPreferences().0, as: .image) {
            XCTFail(failure)
        }
    }
}
```

---

## 7. Caveats and tips

- **Required imports** are not auto-added. For tests you almost always need `XCTest`, `SwiftUI`, `Prefire`, and `SnapshotTesting`; for playbook you need `SwiftUI` and `Prefire`. Add them at the top of your template literally.
- **`{PREVIEW_FILE_NAME}` is a real placeholder.** It is replaced in the template string *and* in `test_file_path` *only* when `use_grouped_snapshots: false`. The class declared in your template must be named `{PREVIEW_FILE_NAME}Tests`, otherwise the generated file won't compile.
- **`snapshotDevices` is a pipe-joined string**, not an array. Use `|split:"|"`. Forgetting the filter produces `snapshotDevices = iPhone 14|iPad` in the generated file.
- **Guard `previewsMacrosDict`.** An empty array will still produce a (broken) `for` block. Always wrap the macro loop in `{% if argument.previewsMacrosDict %}`.
- **`globalConfiguration` names a type in the user's module.** Resolve it once at file scope — `private let prefireGlobalConfiguration: (any PrefireGlobalConfiguration.Type)? = {{ argument.globalConfiguration }}.self` — and pass that constant to each `PrefireSnapshot` / `PreviewModel`. The user's type is usually internal, so any function referencing it cannot be `@inlinable`.
- **Cache invalidation.** `PrefireCacheManager` keys the cache on source content. When you change a template, delete `~/.prefire-cache/` to force a full re-render.
- **`isScreen` is a `Bool` but Stencil may serialize it as `1`/`0`.** Compare with `{% if macroModel.isScreen == 1 %}` rather than `{% if macroModel.isScreen %}`, as in the default template.
- **Stuck on a syntax error?** Run `prefire tests` once with the default template and look at the generated file — it's the fastest way to see which context keys actually have values for your project.
