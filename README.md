<p align="center"><img src="https://i.ibb.co/dfXqwpn/Group-14.png" /></p>

## About

--

## Screenshots

--

## 🚀 Installation

1. Install [Sourcery](https://github.com/krzysztofzablocki/Sourcery) using _[Homebrew](https://brew.sh)_
    ```bash
    brew install sourcery
    ```
2. Install **PreFire** using _[Swift Package Manager](https://developer.apple.com/documentation/xcode/adding_package_dependencies_to_your_app)_

    Select Xcode menu `File > Swift Packages > Add Package Dependency...` and enter repository URL with GUI.
    ```
    https://github.com/BarredEwe/PreFire
    ```
3. Add Build Phase for Demo App 
    ```
    (${BUILD_DIR%Build/*}SourcePackages/checkouts/)
    ```
4. Add Build Phase for Snapshot tests 
    ```
    (${BUILD_DIR%Build/*}SourcePackages/checkouts/)
    ```

## Config

## TODO: 
- Сделать скрипт для запуска в Build Phase
- Описание, наименование и Example
- Сделать хороший Example (UserStories - Auth, Components - Button, и еще что-то)
- Детальный просмотр компонентов/экранов (Вывод доп. информации)

## TODO Features:
- Accesability
- Написать свои снапшот тесты, а не использовать библиотеку
- Использовать снапшот для отображения дизайн системы (Не уверен что нормально получится)  
- Fonts: экран с шрифтами, размерами, наименованиями
- Colors: экран с цветами и наименованиями
- Локализация (возможно переключение в рантайм)
- Темная тема (возможно переключение в рантайм)

## DONE:
- ✅ Ограничения для Snapshots (Только нужное устройство и версия ОС)
- ✅ Выбрать название (PreFire)
- ✅ Поиск компонентов
- ✅ Конфигурация Templates (устройство по умолчанию, imports)
- ✅ Группировать элементы UserStory: (auth, postings), Type: (component)
- ✅ Темная тема в Playbook приложении
- ✅ Переименовать PreviewProdiver в PreFireProvider
- ✅ Объеденить WrapperView и PreviewModel

// https://github.com/yyokii/UIPreviewCatalog
