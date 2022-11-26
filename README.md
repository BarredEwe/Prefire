![Prefire](https://i.postimg.cc/BQWJZPJs/Frame-16.jpg)

<p align="center">A library for easy automatic <b>Playbook (Demo) view</b> and <b>Test</b> generation using <b>SwiftUI Preview</b></p>
<p align="center">Works with: <b>UI-components, screens and flows</b></p>

# Prefire

<img src="https://i.ibb.co/LNYBfMw/ezgif-com-gif-maker-2.gif" alt="Playbook" width="200" align="right" style="border-radius: 20px 20px; box-shadow: 0px 0px 15px gray;">

<a href="https://developer.apple.com/swift"><img alt="Swift5" src="https://img.shields.io/badge/language-Swift5-orange.svg"/></a>
<a href="https://swift.org/package-manager"><img alt="Swift Package Manager" src="https://img.shields.io/badge/SwiftPM-compatible-yellowgreen.svg"/></a>

Do you like **SwiftUI Preview** and use it? Then you must trying 🔥**Prefire**!

You can try 🔥**Prefire** starting from example project.

- Easy to use
- Fully automatic generation based on [Sourcery](https://github.com/krzysztofzablocki/Sourcery)
- Generation:
    - Playbook (Demo) view
    - Snapshot tests based on [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)
    - Accesability Snapshot tests

<br clear="all">

---

## Installation

1. Install [Sourcery](https://github.com/krzysztofzablocki/Sourcery) using _[Homebrew](https://brew.sh)_
```bash
brew install sourcery
```
2. Install **Prefire** using _[Swift Package Manager](https://developer.apple.com/documentation/xcode/adding_package_dependencies_to_your_app)_

    Select Xcode menu `File > Swift Packages > Add Package Dependency...` and enter repository URL with GUI.
```
https://github.com/BarredEwe/Prefire
```

Подсмотреть у https://github.com/realm/SwiftLint#plug-in-support
// - Доделать конфигурацию для тестов
// - Проверить на Seller проекте
// - Дописать доку
// - Сделать релиз
---

## Setup

### **Playbook (Demo) View**
For generating Playbook you should first:
 - Add **Build Phase** to main target for generating Demo App:
```bash
export PATH="$PATH:${BUILD_DIR%Build/*}SourcePackages/checkouts/Prefire"
prefire playbook --sources <sources path> --output <output path>
```
- Fill `<sources path>` and `<output path>`.
Example:
```bash
prefire playbook --sources ./ -- output Sources/PreviewModel.generated.swift
```
- _Uncheck_ mark ```✅ Based on dependecy analysis```.
- Build your project
- Add genereted file to your project

### **Snapshot tests**
For generating tests you should first:
- Add **Build Phase** to test target for generating Snapshot tests:
```bash
export PATH="$PATH:${BUILD_DIR%Build/*}SourcePackages/checkouts/Prefire"
prefire tests --sources <sources path> --output <output path> --target <test target>
```
- Fill `<sources path>`, `<output path>` and `<test target>`. Example:
```bash
prefire tests --sources ./ -- output Tests/PrefireTests.generated.swift --target MyProject
```
- _Uncheck_ mark ```✅ Based on dependecy analysis```.
- Build (__CMD + B__) your project
- For runnug test you should add genereted file to your project in testTarget.

---

## Usage
For generating **tests** and **playbook**, just mark your preview using `protocol PrefireProvider`:
```swift
struct Text_Previews: PreviewProvider, PrefireProvider {
    static var previews: some View { ... }
}
```

### **Playbook (Demo) View**
For using Playbook just use `PlaybookView`

```swift
import Prefire 

struct ContentView: View {
    var body: some View {
        PlaybookView(isComponent: true, previewModels: PreviewModels.models)
    }
}
```

### **Snapshot tests**
Just run generated test 🚀

For detailed instruction you can see [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)

---

## API
New commands for previews:

- Function for connecting preview together in one **Flow**:
    ```swift
    .previewUserStory(.auth)
    ```
    For example Authorization flow (LoginView, OTPView, PincodeView)

- If a preview contains more than one View, you can mark State for these views.
    ```swift
    .previewState(.loading)
    ```
    ```swift
    static var previews: some View {
        Text("Default")

        Text("Loading")
            .previewState(.loading)
    }
    ```
---

## Config
**prefire** script configs:
- `--sources`<span style="color:red">*</span> - Path to a source swift files or directories with Views. 
- `--output`<span style="color:red">*</span> - Path to output file.
- `--target` - Your project Target for Snapshot tests. __Default__: _empty_
- `--sourcery` - Custom path to Sourcery. __Default__: path from `brew`.
- `--device` - Device for Snapshot testing. __Default__: _iPhone 14 Pro_
- `--os_version` - iOS version for Snapshot testing. __Default__: _iOS 16_    ```

## Requirements

- Swift 5.1+
- Xcode 11.0+
- iOS 14+


## Previews Troubleshooting
- Don't forget remove ```#IF DEBUG``` for yours SwiftUI Previews. Xcode automatically removed Preview code, when you build release version.
- NavigationView in Preview is not supported
