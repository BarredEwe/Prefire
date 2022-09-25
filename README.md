![Prefire](https://i.postimg.cc/BQWJZPJs/Frame-16.jpg)

## About

A library for easy automatic **Playbook (Demo) view** generation and **Test** generation. Works with UI-components 🔘, screens 📺 and flows 🌊

For snapshot testing we use [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing).

## Screenshots

<img src="https://i.ibb.co/LZnMpJ0/iphone14.png" width="200" /> <img src="https://i.ibb.co/SnHLBRN/iphone14-2.png" width="200" />

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
prefire playbook --sources ./ -- output Tests/PrefireTests.generated.swift
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
- Fill `<sources path>`, `<output path>` and `<output path>`
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

- If one preview contains more than one View, you can mark State for theese views.
    ```swift
    .previewState(.loading)
    ```
    ```swift
    static var previews: some View {
        Text("Default")

        Text("Default")
            .previewState(.loading)
    }
    ```

## Previews Troubleshooting
- Don't forget remove ```#IF DEBUG``` for yours SwiftUI Previews. Xcode automatically removed Preview code, when you build release version.
- NavigationView in Preview is not supported

<br><br/>
<br><br/>
<br><br/>

## Draft Detail description
()-- you need preview models. Theese models located in generated file.

# Draft ⚠️
## TODO: 
- UserStory - переименовать в flow
- Accesability
- Скрипт в Build Phase для тестов сделать настройку тестов (device, os и тд)
- Описание, наименование и Example
- Сделать хороший Example (UserStories - Auth, Components - Button, и еще что-то)
- Детальный просмотр компонентов/экранов (Вывод доп. информации)

## TODO Features:
- Использовать Sourcery через SPM
- Сделать Plugin (https://github.com/krzysztofzablocki/Sourcery/pull/1093)
- Написать своб генерацию
- Написать свои снапшот тесты, а не использовать библиотеку (https://github.com/yyokii/UIPreviewCatalog)
- Использовать снапшот для отображения дизайн системы (Не уверен что нормально получится)  
- Fonts: экран с шрифтами, размерами, наименованиями
- Colors: экран с цветами и наименованиями
- Локализация (возможно переключение в рантайм)
- Темная тема (возможно переключение в рантайм)

## DONE:
- ✅ Исправить баг - в UserStories показывается только первая вью
- ✅ Переименовать PreFire -> Prefire
- ✅ Cделать скрипт для запуска в Build Phase Tests
- ✅ Сделать скрипт для запуска в Build Phase DemoApp
- ✅ Ограничения для Snapshots (Только нужное устройство и версия ОС)
- ✅ Выбрать название (PreFire)
- ✅ Поиск компонентов
- ✅ Конфигурация Templates (устройство по умолчанию, imports)
- ✅ Группировать элементы UserStory: (auth, postings), Type: (component)
- ✅ Темная тема в Playbook приложении
- ✅ Переименовать PreviewProdiver в PreFireProvider
- ✅ Объеденить WrapperView и PreviewModel
