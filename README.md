![Prefire](https://i.postimg.cc/Y9cbLVY4/temp-Image-P7o5-NQ.jpg)

<p align="center">A library for easily generating automatic <b>Playbook (Demo) view</b> and <b>Tests</b> using <b>SwiftUI Preview</b></p>
<p align="center">Works with: <b>UI-components, screens and flows</b></p>
<p align="center">
<a href="https://github.com/BarredEwe/Prefire/releases/latest"><img alt="Release" src="https://img.shields.io/github/release/BarredEwe/Prefire.svg"/></a>
<a href="https://developer.apple.com/"><img alt="Platform" src="https://img.shields.io/badge/platform-iOS-green.svg"/></a>
<a href="https://developer.apple.com/swift"><img alt="Swift5" src="https://img.shields.io/badge/language-Swift_6-green.svg"/></a>
<a href="https://swift.org/package-manager"><img alt="Swift Package Manager" src="https://img.shields.io/badge/SwiftPM-compatible-yellowgreen.svg"/></a>
<img alt="Swift Package Manager" src="https://img.shields.io/badge/Xcode%20Plugins-Supported-brightgreen.svg"/>
</p>

# Prefire

<img src="https://i.ibb.co/LNYBfMw/ezgif-com-gif-maker-2.gif" alt="Playbook" width="200" align="right">

Do you like **SwiftUI Preview** and use it? Then you must try 🔥**Prefire**!

You can try 🔥**Prefire** starting from example project.

- ✅ Easy to use: Get started with the example project.
- ✅ Fully automatic generation based on [Sourcery](https://github.com/krzysztofzablocki/Sourcery)
- ✅ Generation _Playbook (Demo) views_
- ✅ Generation _Snapshot tests_ based on [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)
- ✅ Generation _Accesability Snapshot_ tests
- ✅ Support for _Xcode Plugin_

<br clear="all">

---

## Installation

**Prefire** can be installed for an `Xcode Project` or only for one `Package`.

### **Xcode Project Plugin**

You can integrate Prefire as an Xcode Build Tool Plug-in if you're working
on a project in Xcode.

1. Add `Prefire` as a package dependency to your project without linking any of the products.

<img src="https://i.postimg.cc/nhWK6D17/Screenshot-2023-01-19-at-16-31-55.png" width="800">

2. Select the target to which you want to add linting and open the `Build Phases` inspector.
Open `Run Build Tool Plug-ins` and select the `+` button.
From the list, select `PrefirePlaybookPlugin` or `PrefireTestsPlugin`, and add it to the project.

<img src="https://i.postimg.cc/VNnJNrX3/Screenshot-2023-01-19-at-16-43-44.png" width="400">

### **Swift Package Plugin**

You can integrate **Prefire** as a Swift Package Manager Plug-in if you're working with
a Swift Package with a `Package.swift` manifest.

1. Add **Prefire** as a package dependency to your `Package.swift` file.

```swift
dependencies: [
    .package(url: "https://github.com/BarredEwe/Prefire", from: "1.0.0")
]
```

2. Add **Prefire** to a target using the `plugins` parameter.

```swift
.target(
    plugins: [
        // For Playbook (Demo) view
        .plugin(name: "PrefirePlaybookPlugin", package: "Prefire")
    ]
),
.testTarget(
    plugins: [
        // For Snapshot Tests
        .plugin(name: "PrefireTestsPlugin", package: "Prefire")
    ]
)
```

---

## Usage
To generate **tests** and **playbook**, simply mark your preview using the `PrefireProvider` protocol:
```swift
struct Text_Previews: PreviewProvider, PrefireProvider {
    static var previews: some View { ... }
}
```
If you use the **`#Preview`** macro, **🔥Prefire** will automatically find it!

If you don't need it, mark view - `.prefireIgnored()`:
```swift
#Preview {
    Text("")
        .prefireIgnored()
}
```

If you want to disable the automatic get of all previews, use the setting `preview_default_enabled`: false. Then to include preview in the test, you need to call the `.prefireEnabled()`:
```swift
#Preview {
    Text("")
        .prefireEnabled()
}
```

### **Playbook (Demo) View**
To use Playbook, simply use `PlaybookView`

- If you want to see a list of all the Views, use `isComponent: true`
- If you want to sort by UserStory, use `isComponent: false`

```swift
import Prefire 

struct ContentView: View {
    var body: some View {
        PlaybookView(isComponent: true, previewModels: PreviewModels.models)
    }
}
```

### **Snapshot tests**

Just run generated tests 🚀
All tests will be generated in the DerivedData folder.

<img src="https://i.postimg.cc/XNPVPL1G/Untitled-2.gif" width="300">

Plugin `PrefireTestsPlugin` will handle everything for you 🛠️

For detailed instruction, check out [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) or examine an example project.

---

## API
**Prefire** provide new commands for previews:

- You can set the delay, precision and perceptualPrecision parameters for the snapshot:

    ```swift
    .snapshot(delay: 0.3, precision: 0.95, perceptualPrecision: 0.98)
    ```
    
    ```swift
    static var previews: some View {
        TestView()
            .snapshot(delay: 0.3, precision: 0.95, perceptualPrecision: 0.98)
    }
    ```

- Function for connecting preview together in one **Flow**:

    <img src="https://i.postimg.cc/jSh23G8W/temp-Image9a-EDKU.avif" width="350" align="right">

    ```swift
    .previewUserStory(.auth)
    ```

    ```swift
    static var previews: some View {
        PrefireView()
            .previewUserStory(.auth)
    }

    static var previews: some View {
        AuthView()
            .previewUserStory(.auth)
    }
    ```

    For example Authorization flow: `LoginView`, `OTPView` and `PincodeView`

    <br clear="all">

- If a preview contains more than one `View`, you can mark `State` for these views.

    <img src="https://i.postimg.cc/Z5JKNwTJ/temp-Imageh19pin.avif" width="350" align="right">

    ```swift
    .previewState(.loading)
    ```

    ```swift
    static var previews: some View {
        TestView("Default")

        TestView("Loading")
            .previewState(.loading)
    }
    ```

    <br clear="all">

---

## Config

To further customize **Prefire**, you can create a `.prefire.yml` file in the root directory of your project. Here's an example of its content:

```yaml
test_configuration:
  - target: PrefireExample 
  - test_file_path: PrefireExampleTests/PreviewTests.generated.swift
  - template_file_path: CustomPreviewTests.stencil
  - simulator_device: "iPhone15,2"
  - required_os: 16
  - preview_default_enabled: true
  - sources:
    - ${PROJECT_DIR}/Sources/
  - snapshot_devices:
  	- iPhone 14
  	- iPad
  - imports:
    - UIKit
    - SwiftUI
  - testable_imports:
    - Prefire

playbook_configuration:
  - preview_default_enabled: true
  - template_file_path: CustomModels.stencil
  - imports:
    - UIKit
    - Foundation
  - testable_imports:
    - SwiftUI
```
### Configuration keys and their descriptions
- `target` - Your project Target for Snapshot tests. __Default__: _FirstTarget_
- `test_file_path` - Filepath to generated file. __Default__: _DerivedData_
- `template_file_path` - Stencil file for generated file. Optional parameter.\
   For test plugin __Default__: _Templates/PreviewTests.stencil_ from the package.\
   For playbook plugin __Default__: _Templates/PreviewModels.stencil_ from the package
- `simulator_device` - Device for Snapshot testing. Optional parameter.
- `required_os` - iOS version for Snapshot testing. Optional parameter.
- `snapshot_devices` - the list of devices snapshots should be generated for. The `simulator_device` specified above will still be required and used, but snapshotting will take on the traits of the `snapshot_devices`. The `displayScale` will default to `2.0` and device specific safe areas will be `.zero`. Optional parameter.
- `preview_default_enabled` - Do I need to automatically add all previews based on the new syntax to the tests.  __Default__: true
- `imports` - Additional imports for the generated Playbook/Tests. Optional parameter.
- `testable_imports` - Additional `@testable` imports for the generated Playbook/Tests. Optional parameter.
- `sources` - Paths to swift file or directory sources. __Default__: File paths of a specific target or project

## Distribution

When preparing for distribution, you may want to exclude your `PreviewProvider` and mock data from release builds. This can be achieved by wrapping them in `#if DEBUG` compiler directives. Alternatively, you can pass a compiler flag to exclude `PreviewModels` from release builds.

To exclude `PreviewModels` using Swift Package Manager, pass the `PLAYBOOK_DISABLED` swift setting in the package that links `PrefirePlaybookPlugin`:

```swift
swiftSettings: [
    .define("PLAYBOOK_DISABLED", .when(configuration: .release)),
]
```

If you are using Xcode, you can pass the compiler flag in the Xcode build settings:

```
SWIFT_ACTIVE_COMPILATION_CONDITIONS = PLAYBOOK_DISABLED;
```

## Requirements

- Swift 5.6 or higher
- Xcode 14.0 or higher
- iOS 14 or higher

## Troubleshooting
`NavigationView` in Preview not supported for Playbook
- Consider using other views or layouts for your Playbook needs.

Running Prefire via CI
- To run Prefire via Continuous Integration (CI), you need to configure permissions:
`defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES`

Xcode is unable to generate tests in a custom path.
- To resolve this, you’ll need to disable the sandbox for file generation by running the following command in your terminal:
`defaults write com.apple.dt.Xcode IDEPackageSupportDisablePluginExecutionSandbox -bool YES`
