![Prefire](https://i.postimg.cc/BQWJZPJs/Frame-16.jpg)

## About

A library for easy automatic **Playbook (Demo) app** generation and **Test** generation. Supports both work with UI-components and work with screens and their flow.

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
### **Playbook (Demo) App**
For using demo app:
 - Add **Build Phase** for generating Demo App 
    ```bash
    export PATH="$PATH:${BUILD_DIR%Build/*}SourcePackages/checkouts/PreFire"
    prefire playbook --sources <sources path> --output <output path>
    ```

### **Snapshot tests**
For using test:
- Add **Build Phase** for generating Snapshot tests
    ```bash
    export PATH="$PATH:${BUILD_DIR%Build/*}SourcePackages/checkouts/PreFire"
    prefire tests --sources <sources path> --output <output path> --target <test target>
    ```
## Config

Something about configuration 🤡

----
----
----
----
----
----
----
----
----
----
----
----
----
----
----
----
----
----
----
----
----
## TODO: 
- Accesability
- Переименовать PreFire -> Prefire
- Скрипт в Build Phase для тестов сделать настройку тестов (device, os и тд)
- Описание, наименование и Example
- Сделать хороший Example (UserStories - Auth, Components - Button, и еще что-то)
- Детальный просмотр компонентов/экранов (Вывод доп. информации)

## TODO Features:
- Сделать Plugin (https://github.com/krzysztofzablocki/Sourcery/pull/1093)
- Написать своб генерацию
- Написать свои снапшот тесты, а не использовать библиотеку
- Использовать снапшот для отображения дизайн системы (Не уверен что нормально получится)  
- Fonts: экран с шрифтами, размерами, наименованиями
- Colors: экран с цветами и наименованиями
- Локализация (возможно переключение в рантайм)
- Темная тема (возможно переключение в рантайм)

## DONE:
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

// https://github.com/yyokii/UIPreviewCatalog
