![Prefire](https://i.postimg.cc/Y9cbLVY4/temp-Image-P7o5-NQ.jpg)

<p align="center">
<a href="https://github.com/BarredEwe/Prefire/releases/latest"><img alt="Release" src="https://img.shields.io/github/release/BarredEwe/Prefire.svg"/></a>
<a href="https://developer.apple.com/"><img alt="Platform" src="https://img.shields.io/badge/platform-iOS-green.svg"/></a>
<a href="https://developer.apple.com/swift"><img alt="Swift6" src="https://img.shields.io/badge/language-Swift_6-green.svg"/></a>
<a href="https://swift.org/package-manager"><img alt="Swift Package Manager" src="https://img.shields.io/badge/SwiftPM-compatible-yellowgreen.svg"/></a>
<img alt="Swift Package Manager" src="https://img.shields.io/badge/Xcode%20Plugins-Supported-brightgreen.svg"/>
</p>

## 🔥 What is Prefire?

**Prefire** transforms your `#Preview` blocks into:
- ✅ Snapshot tests
- ✅ Playbook views
- ✅ Visual flows with states and user stories
- ✅ Living documentation — fully automated

## 🚀 Key Features

<img src="https://i.ibb.co/LNYBfMw/ezgif-com-gif-maker-2.gif" alt="Playbook" width="200" align="right">

- 🧠 **Smart Preview Parsing** — including `#Preview`, `@Previewable`
- 📸 **Snapshot Testing** — automatic test generation from previews
- 📚 **Playbook View** — auto-generated interactive component catalog
- 🏃 **Flow-aware** — build user stories from multiple preview steps
- 🧩 **UIKit Support** — support for `UIView` and `UIViewController`
- ⚙️ **SPM + Xcode Plugins** — works in CLI, Xcode build phases, or CI
- 🧠 **Fast Caching** — fingerprint-based AST and body caching avoids redundant work
- ✍️ **Stencil Templates** — customize output with your own templates

### Why Prefire? 

- 🔥 **Save Time** - Generate tests and documentation automatically
- 🔥 **Stay Consistent** - Keep previews and tests always in sync
- 🔥 **Improve Quality** - Catch visual regressions before users do
- 🔥 **Boost Collaboration** - Share living documentation with your team

<br clear="all">

---
## ⚡️ Quick Start

> 📦 Example project available at: [Prefire Example](https://github.com/BarredEwe/Prefire/tree/main/Example)

### 1. Add Prefire to Your Project

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/BarredEwe/Prefire.git", from: "4.0.0")
],
.testTarget(
    plugins: [
        // For Snapshot Tests
        .plugin(name: "PrefireTestsPlugin", package: "Prefire")
    ]
)
```

### 2. Write `#Preview`

```swift
#Preview {
    Button("Submit")
}
```

### 3. Run tests

Just run the test target 🚀 — Prefire will auto-generate snapshots based on your previews.

> 💡 If your test target is empty, Prefire will still generate files and snapshot code during build.

<img src="https://i.postimg.cc/XNPVPL1G/Untitled-2.gif" width="300">


---

## 📦 Installation

Supports:

- ✅ SPM Plugin (`Package.swift`)
- ✅ Xcode Build Tool Plugin
- ✅ CLI (`brew install prefire`)
- ✅ GitHub Actions / CI

See detailed setup in the [Installation guide](https://github.com/BarredEwe/Prefire/blob/main/Installation.md)

## 🧠 How It Works

### 🔍 1. Parses all source files

- Finds all `#Preview` and `PreviewProvider` blocks
- Supports modifiers: `.prefireEnabled()`, `.prefireIgnored()`

### 📂 2. Caches `Types` and `PreviewBodies`

- Based on file modification date + SHA-256 of inputs
- Avoids re-parsing if nothing changed

### 🔢 3. Generates Snapshot Tests

- Uses `Stencil` templates
- Respects `.prefire.yml` configuration

### 📘 4. Generates Playbook View

- Groups by `UserStory`, `State`
- Outputs `PreviewModels.generated.swift`

---

## 🛠 Advanced Usage
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

## 🧰 API Summary

| Feature | Modifier |
|--------|----------|
| Include in snapshot | `.prefireEnabled()` |
| Exclude from snapshot | `.prefireIgnored()` |
| Group in a flow | `.previewUserStory(.auth)` |
| Mark a UI state | `.previewState(.error)` |
| Customize snapshot | `.snapshot(delay: 0.3, precision: 0.95)` |

---

## 💡 Advanced: CLI Usage

```bash
# Generate snapshot tests
prefire tests

# Generate playbook models
prefire playbook
```

Run `prefire tests --help` or `prefire playbook --help` for more options.

---
## 🗂 Configuration: `.prefire.yml`

See detailed configuration in the [Configuration guide](https://github.com/BarredEwe/Prefire/blob/main/Configuration.md)

```yaml
test_configuration:
  target: MyApp

playbook_configuration:
  preview_default_enabled: true
```

---

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

---

## 🧠 Internal Architecture

- `PrefireCore` — AST + preview parsing, caching, logic
- `PrefireGenerator` — handles stencil templating + snapshot generation
- `PrefireCacheManager` — unifies caching for `Types` and `Previews`
- `PrefireTestsPlugin` / `PrefirePlaybookPlugin` — SPM/Xcode integrations
- `prefire` — CLI entry point, calls shared generator code

---

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

## 🤝 Contributing
We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch
3. Submit a Pull Request

## 📄 License
Prefire is released under the Apache License 2.0. See [LICENSE](https://github.com/BarredEwe/Prefire/blob/main/LICENSE) for details.
