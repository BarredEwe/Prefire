![Prefire](https://i.postimg.cc/BQWJZPJs/Frame-16.jpg)

## About

Do you like **SwiftUI Preview** and use it? Then you must trying 🔥**Prefire**!

A library for easy automatic **Playbook (Demo) view** generation and **Test** generation. Works with UI-components 🔘, screens 📺 and flows 🌊

You can try 🔥**Prefire** starting from example project.

## Screenshots

<img src="https://i.ibb.co/LZnMpJ0/iphone14.png" width="270" /> <img src="https://i.ibb.co/SnHLBRN/iphone14-2.png" width="270" />

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

## Setup

### **Playbook (Demo) View**
For generating Playbook you should first:
 - Add **Build Phase** to main target for generating Demo App:
```bash
export PATH="$PATH:${BUILD_DIR%Build/*}SourcePackages/checkouts/Prefire"
prefire playbook --sources <sources path> --output <output path>
```
- Fill `<sources path>` and `<output path>`
```bash
# Example:
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
- Fill `<sources path>`, `<output path>` and `<test target>`
```bash
# Example:
prefire tests --sources ./ -- output Tests/PrefireTests.generated.swift --target MyProject
```
- _Uncheck_ mark ```✅ Based on dependecy analysis```.
- Build (__CMD + B__) your project
- For runnug test you should add genereted file to your project in testTarget.

## Config
**prefire** script configs:
- `--sources`<span style="color:red">*</span> - Path to a source swift files or directories with Views. 
- `--output`<span style="color:red">*</span> - Path to output file.
- `--target` - Your project Target for Snapshot tests. __Default__: _empty_
- `--sourcery` - Custom path to Sourcery. __Default__: path from `brew`.
- `--device` - Device for Snapshot testing. __Default__: _iPhone 12_
- `--os_version` - iOS version for Snapshot testing. __Default__: _iOS 15_

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

## API
New commands for previews:

- Function for connecting preview together in one Flow:
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

## Previews Troubleshooting
- Don't forget remove ```#IF DEBUG``` for yours SwiftUI Previews. Xcode automatically removed Preview code, when you build release version.
- NavigationView in Preview is not supported

## Draft Detail description
()-- you need preview models. Theese models located in generated file.

For snapshot testing we use [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing).

<br><br/>
<br><br/>
## Road map:
- Make animation: 
    - Installation
        1) Connect SPM
    - PlayBook
        1) Add Build Phase 
        3) Mark Preview 
        4) Build
        5) Showing PlayBook 
    - Tests
        1) Add Build Phase 
        3) Mark Preview 
        4) Build
        5) Showing Tests 
- UserStory - rename to flow
- Accesability
- Script for Build Phase for tests - make test settings (device, os and etc)
- Description and Example
- Make a good Example: (UserStories - Auth, Components - Button, and maybe something else)
- Detail info

## TODO Features:
- Dragger size of view
- Using Sourcery with SPM
- Make a Plugin (https://github.com/krzysztofzablocki/Sourcery/pull/1093)
- Write own generation
- Write own snapshot tests. Example: (https://github.com/yyokii/UIPreviewCatalog) 
- Fonts: screen with fonts, sizes and name
- Colors: screen with colors and names
- Localization (maybe runtime chosing)
- Dark theme (maybe runtime chosing)
