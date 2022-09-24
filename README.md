![Prefire](https://i.postimg.cc/BQWJZPJs/Frame-16.jpg)

## About

A library for easy automatic **Playbook (Demo) app** generation and **Test** generation. Supports both work with UI-components and work with screens and their flow.

For snapshot testing we use [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing).

## Screenshots

--

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

### **Playbook (Demo) App**
For generating Playbook you should first:
 - Add **Build Phase** for generating Demo App:
    ```bash
    export PATH="$PATH:${BUILD_DIR%Build/*}SourcePackages/checkouts/PreFire"
    prefire playbook --sources <sources path> --output <output path>
    ```
- Build your project
- Add genereted file to your project

### **Snapshot tests**
For generating tests you should first:
- Add **Build Phase** for generating Snapshot tests:
    ```bash
    export PATH="$PATH:${BUILD_DIR%Build/*}SourcePackages/checkouts/PreFire"
    prefire tests --sources <sources path> --output <output path> --target <test target>
    ```
- Build your project
- For runnug test you should add genereted file to your project in testTarget.

## Config

- `--sources` - Path to a source swift files or directories where was placed Views. 
- `--output` - Path to output file.
- `--target` - Your project Target for Snapshot tests.
- `--sourcery` - Custom path to Sourcery.
- ⚠️ Есть еще настройки для тестов (не успел описать) 

## Usage
For generating tests an playbook, just mark your preview using `protocol PrefireProvider`:
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

For detailed instruction you should see [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)




<br><br/>
<br><br/>
<br><br/>

## Draft Detail description
()-- you need preview models. Theese models located in generated file.

# Draft ⚠️
## TODO: 
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
