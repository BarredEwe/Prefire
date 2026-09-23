<p align="center">
  <img src="Documentation/Assets/prefire-readme.png" alt="Prefire — Preview. Prove. Ship. Turn your SwiftUI previews into snapshot tests and an interactive component catalog." width="100%">
</p>

<p align="center">
  <a href="https://github.com/BarredEwe/Prefire/releases/latest"><img src="https://img.shields.io/github/v/release/BarredEwe/Prefire?style=flat&label=release&color=FF6A35&labelColor=17181C" alt="Latest release"></a>
  <a href="#requirements"><img src="https://img.shields.io/badge/Swift-6.0%2B-FFB629?style=flat&labelColor=17181C" alt="Swift 6.0 or later"></a>
  <a href="Documentation/Installation.md"><img src="https://img.shields.io/badge/SwiftPM-build%20plugins-FF6A35?style=flat&labelColor=17181C" alt="Swift Package Manager build plugins"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache%202.0-F5F0E7?style=flat&labelColor=17181C" alt="Apache 2.0 license"></a>
</p>

<p align="center">
  <a href="https://prefire.ru">Website</a> ·
  <a href="#quick-start">Quick start</a> ·
  <a href="Documentation/Configuration.md">Configuration</a> ·
  <a href="Example">Example project</a>
</p>

**Prefire turns the SwiftUI previews you already write into snapshot tests and a browsable Playbook.** Reuse the same UI states for development, visual regression checks, and team demos.

| Preview | Snapshot tests | Playbook |
| :--- | :--- | :--- |
| <img src="Documentation/Assets/preview-small.svg" alt="A preview definition renders a UI component" width="240"> | <img src="Documentation/Assets/snapshot-small.svg" alt="Reference and changed render with the button shift highlighted" width="240"> | <img src="Documentation/Assets/playbook-small.svg" alt="Default, loading, and error states together in a catalog" width="240"> |
| Define your UI states once. | Catch changes against a reference. | Browse states in one catalog. |

Prefire supports `#Preview`, `@Previewable`, parameterized previews, and opted-in `PreviewProvider` types. It runs through Xcode and SwiftPM build plugins or the CLI. Tests use [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing); [custom templates](Documentation/Templates.md) control the generated code.

## Quick start

### 1. Connect your test target

For an **Xcode project**:

1. Add [Prefire](https://github.com/BarredEwe/Prefire) and [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) as package dependencies.
2. Link the `Prefire` product to your app target. Link `Prefire` and `SnapshotTesting` to your unit test target.
3. In the unit test target, open **Build Phases → Run Build Tool Plug-ins** and add **PrefireTestsPlugin**.

For a **Swift package**, use this manifest as a starting point. Replace `MyUI` and `MyUITests` with your target names.

<details>
<summary><strong>Show Package.swift</strong></summary>

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyUI",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MyUI", targets: ["MyUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/BarredEwe/Prefire.git", from: "5.8.1"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.18.0")
    ],
    targets: [
        .target(
            name: "MyUI",
            dependencies: [.product(name: "Prefire", package: "Prefire")]
        ),
        .testTarget(
            name: "MyUITests",
            dependencies: [
                "MyUI",
                .product(name: "Prefire", package: "Prefire"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            plugins: [.plugin(name: "PrefireTestsPlugin", package: "Prefire")]
        )
    ]
)
```

</details>

### 2. Write a preview

Add a preview to your app or library sources. Prefire discovers `#Preview` blocks automatically.

```swift
import SwiftUI
import Prefire

#Preview("Submit button", traits: .sizeThatFitsLayout) {
    Button("Submit", action: {})
        .buttonStyle(.borderedProminent)
        .padding()
}
```

### 3. Run and review

Run the unit test target in Xcode (**⌘U**) with an iOS Simulator selected. The plugin generates the tests during the build.

The first run records missing reference images and reports a test failure so you can review them. Commit the approved `__Snapshots__` images, then run again to compare against that baseline. Keep the simulator model and OS version consistent between local runs and CI.

For a complete setup, open the [example project](Example). For other installation options, see the [installation guide](Documentation/Installation.md).

## Add a Playbook

Attach **PrefirePlaybookPlugin** to your iOS app or UI target, then display the generated models:

```swift
import SwiftUI
import Prefire

struct ComponentCatalog: View {
    var body: some View {
        PlaybookView(
            isComponent: true,
            previewModels: PreviewModels.models
        )
    }
}
```

Use `isComponent: true` to browse components, or `false` to group previews by user story. Add `.previewUserStory(.auth)` to connect screens in an authentication flow and `.previewState(.loading)` to label a state.

**Playbook is iOS-only.** On macOS, use Prefire for snapshot tests.

### User stories in Playbook

<table>
<tr>
<td width="34%" valign="top">

<img src="https://i.postimg.cc/jSh23G8W/temp-Image9a-EDKU.avif" alt="Prefire Playbook screenshot showing screens grouped into a user story" width="280">

</td>
<td valign="top">

Connect related screens with `.previewUserStory(.auth)` to browse an authentication flow, such as login, one-time password, and PIN entry.

```swift
#Preview("Login") {
    LoginView()
        .previewUserStory(.auth)
}

#Preview("One-time password") {
    OTPView()
        .previewUserStory(.auth)
}
```

`LoginView` and `OTPView` stand for your own screen views. Display the catalog with `isComponent: false` to browse by user story.

</td>
</tr>
</table>

### Component states in Playbook

<table>
<tr>
<td width="34%" valign="top">

<img src="https://i.postimg.cc/Z5JKNwTJ/temp-Imageh19pin.avif" alt="Prefire Playbook screenshot showing default and loading component states" width="280">

</td>
<td valign="top">

Label variations with `.previewState(...)` to make loading and error states easy to find alongside the default UI.

```swift
#Preview("Default") {
    Text("Your content")
}

#Preview("Loading") {
    ProgressView("Loading")
        .previewState(.loading)
}
```

</td>
</tr>
</table>

## Control what gets generated

| Intent | API |
| --- | --- |
| Exclude a `#Preview` | `.prefireIgnored()` |
| Include a `#Preview` when automatic discovery is disabled | `.prefireEnabled()` |
| Group previews into a user story | `.previewUserStory(.auth)` |
| Label a UI state | `.previewState(.loading)` |
| Adjust snapshot rendering and comparison | `.snapshot(delay: 0.3, precision: 0.95, perceptualPrecision: 0.98)` |

For example, exclude a preview that depends on a live service:

```swift
#Preview {
    Text("Live service demo")
        .prefireIgnored()
}
```

To include only explicitly marked previews, set `preview_default_enabled: false` in the relevant configuration section and add `.prefireEnabled()` to the previews you want.

<details>
<summary><strong>Using PreviewProvider</strong></summary>

Opt in by adding `PrefireProvider` conformance:

```swift
struct Greeting_Previews: PreviewProvider, PrefireProvider {
    static var previews: some View {
        Text("Hello, Prefire")
            .padding()
    }
}
```

</details>

<details>
<summary><strong>Using parameterized previews</strong></summary>

With a toolchain that supports parameterized SwiftUI previews, each argument becomes a separate snapshot and Playbook preview:

```swift
#Preview("Greeting", traits: .sizeThatFitsLayout, arguments: ["Alex", "Sam"]) { name in
    Text("Hello, \(name)")
        .padding()
}
```

</details>

## Configuration

Use `.prefire.yml` to set the source target, select previews, and customize generation. For Xcode projects, place it in the project root. For SwiftPM plugins, place it in the source target's directory.

```yaml
test_configuration:
  target: MyUI
  preview_default_enabled: true

playbook_configuration:
  preview_default_enabled: true
```

The [configuration guide](Documentation/Configuration.md) covers source paths, snapshot devices, imports, per-file output, and [macOS rendering](Documentation/Configuration.md#macos-snapshot-tests). To change the generated Swift code, see [custom templates](Documentation/Templates.md).

## Command line

Install with Homebrew:

```sh
brew tap barredewe/prefire
brew install prefire
```

Generate tests or Playbook models from your project directory:

```sh
prefire tests
prefire playbook
```

Run `prefire tests --help` or `prefire playbook --help` for options.

<details>
<summary><strong>Install with Mint (beta)</strong></summary>

```sh
mint install BarredEwe/Prefire
```

The CLI wrapper includes the Prefire binary as a SwiftPM resource. For local generator development, set `PREFIRE_BINARY_PATH` to the absolute path of your own `prefire` executable.

</details>

## Requirements

- **Swift 6.0+ and Xcode 16.0+.** Individual preview APIs may require a newer SDK or deployment target.
- **iOS 14+, macOS 13+ or watchOS 7+** for the Prefire library. The quick-start example uses iOS 17.
- **Snapshot tests:** iOS and macOS; the generator also includes tvOS snapshot support. watchOS is not supported: SnapshotTesting cannot render images there.
- **Playbook:** iOS only. `NavigationView` previews are not supported in Playbook.

## Release builds and CI

Wrap previews and mock data in `#if DEBUG` when they should be excluded from release builds. To disable generated Playbook models in release builds, add this setting to the target using `PrefirePlaybookPlugin`:

```swift
swiftSettings: [
    .define("PLAYBOOK_DISABLED", .when(configuration: .release))
]
```

In Xcode, add `PLAYBOOK_DISABLED` to **Active Compilation Conditions** for the Release configuration. Guard code that references `PreviewModels` with the same condition.

For CI, install the required packages, allow the Prefire build plugin to run, and use the same simulator and OS as your recorded references. On macOS, see the [recording and sandbox instructions](Documentation/Configuration.md#running-from-swiftpm).

## Documentation

- [Installation](Documentation/Installation.md) — Xcode, SwiftPM, and CLI setup.
- [Configuration](Documentation/Configuration.md) — generation options and platform details.
- [Templates](Documentation/Templates.md) — customize generated tests and models.
- [Example project](Example) — previews, plugins, and a Playbook in one app.
- [Releases](https://github.com/BarredEwe/Prefire/releases) — changes by version.

## Contributing

Bug reports and pull requests are welcome. For a bug, include a minimal preview, your configuration, and your Xcode and OS versions. To contribute code, fork the repository, create a branch, and open a pull request.

## Also by the author

[**Mewmori**](https://mewmori.com/?src=prefire) is a pixel cat for your Mac desktop, built with Swift, AppKit, and SwiftUI. It reacts to your screen and remembers your conversations using a local model.

<a href="https://mewmori.com/?src=prefire"><img src="https://mewmori.com/assets/press/gifs/en/01-hello.gif" alt="Mewmori pixel cat greeting you on the Mac desktop" width="300"></a>

## License

Prefire is available under the [Apache License 2.0](LICENSE).
