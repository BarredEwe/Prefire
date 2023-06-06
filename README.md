![Prefire](https://i.postimg.cc/BQWJZPJs/Frame-16.jpg)

<p align="center">A library for easily generating automatic <b>Playbook (Demo) view</b> and <b>Tests</b> using <b>SwiftUI Preview</b></p>
<p align="center">Works with: <b>UI-components, screens and flows</b></p>
<p align="center">
<a href="https://github.com/BarredEwe/Prefire/releases/latest"><img alt="Release" src="https://img.shields.io/github/release/BarredEwe/Prefire.svg"/></a>
<a href="https://developer.apple.com/"><img alt="Platform" src="https://img.shields.io/badge/platform-iOS-green.svg"/></a>
<a href="https://developer.apple.com/swift"><img alt="Swift5" src="https://img.shields.io/badge/language-Swift_5-orange.svg"/></a>
<a href="https://swift.org/package-manager"><img alt="Swift Package Manager" src="https://img.shields.io/badge/SwiftPM-compatible-yellowgreen.svg"/></a>
<img alt="Swift Package Manager" src="https://img.shields.io/badge/Xcode%20Plugins-Supported-brightgreen.svg"/>
</p>

# Prefire

<img src="https://i.ibb.co/LNYBfMw/ezgif-com-gif-maker-2.gif" alt="Playbook" width="200" align="right" style="border-radius: 20px 20px; box-shadow: 0px 0px 15px gray;">

Do you like **SwiftUI Preview** and use it? Then you must try 🔥**Prefire**!

You can try 🔥**Prefire** starting from example project.

- ✅ Easy to use
- ✅ Fully automatic generation based on [Sourcery](https://github.com/krzysztofzablocki/Sourcery)
- ✅ Generation Playbook (Demo) view
- ✅ Generation Snapshot tests based on [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)
- ✅ Generation Accesability Snapshot tests
- ✅ Xcode Plugin supported

<br clear="all">

---

## Installation

**Prefire** can be install for an `Xcode Project` or only for one `Package`.

### **Xcode Project Plugin**

You can integrate Prefire as an Xcode Build Tool Plug-in if you're working
on a project in Xcode.

1. Add `Prefire` as a package dependency to your project without linking any of the products.

<img src="https://i.postimg.cc/nhWK6D17/Screenshot-2023-01-19-at-16-31-55.png" height="500">

2. Select the target to which you want to add linting and open the `Build Phases` inspector.
Open `Run Build Tool Plug-ins` and select the `+` button.
From the list, select `PrefirePlaybookPlugin` or `PrefireTestsPlugin`, and add it to the project.

<img src="https://i.postimg.cc/VNnJNrX3/Screenshot-2023-01-19-at-16-43-44.png" height="500">

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
For generate **tests** and **playbook**, simply mark your preview using protocol - `PrefireProvider`:
```swift
struct Text_Previews: PreviewProvider, PrefireProvider {
    static var previews: some View { ... }
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

For detailed instruction you can see [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)

---

## API
New commands for previews:

- Function for connecting preview together in one **Flow**:

    <img src="https://i.postimg.cc/13psFbHt/Group-48095410-2.jpg" height="400" align="right">

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

    <img src="https://i.postimg.cc/wB8ndkSs/Group-48095410.jpg" height="405" align="right">

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

You can additionaly configure **Prefire** by adding a `.prefire.yml` file to root folder. For example:

```yaml
test_configuration:
  - target: PrefireExample 
  - test_file_path: PrefireExampleTests/PreviewTests.generated.swift
  - simulator_device: "iPhone15,2"
  - required_os: 16
```
- `target` - Your project Target for Snapshot tests. __Default__: _FirstTarget_
- `test_file_path` - Filepath to generated file. __Default__: _DeriveData_
- `simulator_device` - Device for Snapshot testing. __Default__: _iPhone 14 Pro_
- `required_os` - iOS version for Snapshot testing. __Default__: _iOS 16_

## Requirements

- Swift 5.6+
- Xcode 14.0+
- iOS 14+

## Previews Troubleshooting
- Don't forget remove ```#IF DEBUG``` for yours SwiftUI Previews. Xcode automatically removed Preview code, when you build release version.
- NavigationView in Preview is not supported
