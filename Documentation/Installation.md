## 📦 Installation

Supports:
- ✅ SPM Plugin (`Package.swift`)
- ✅ Xcode Build Tool Plugin
- ✅ CLI (`brew install prefire`)
- ✅ GitHub Actions / CI


---

### Xcode Build Tool Plugin

You can integrate Prefire as an Xcode Build Tool Plug-in if you're working on a project in Xcode.

1. Add `Prefire` as a package dependency to your project. You don’t need to link any of the products directly.

<img src="https://i.postimg.cc/nhWK6D17/Screenshot-2023-01-19-at-16-31-55.png" width="800">

2. Create or select a **unit test target**. Snapshot tests will be generated into this target.

> 💡 If your project doesn't have a test target yet, create one via "File → New → Target → Unit Testing Bundle".

3. Select the target to which you want to add linting and open the `Build Phases` inspector.

4. Locate `Run Build Tool Plug-ins` and click the `+` button. Select `PrefireTestsPlugin` from the list.

5. When you build this target — even if it’s empty — Prefire will scan your sources and automatically generate snapshot tests for all previews.

<img src="https://i.postimg.cc/VNnJNrX3/Screenshot-2023-01-19-at-16-43-44.png" width="400">

You can also attach `PrefirePlaybookPlugin` to another build target to generate preview-based component models.

---

### Swift Package Manager Plugin

You can integrate Prefire as a Swift Package Manager Plug-in if you're working with a Swift package using a `Package.swift` manifest.

1. Add **Prefire** as a package dependency:

```swift
dependencies: [
    .package(url: "https://github.com/BarredEwe/Prefire", from: "4.0.0")
]
```

2. Add **Prefire** plugins to your targets:

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

3. When you build the test target, Prefire will automatically generate snapshots.

---

### Command Line Interface (CLI)

Prefire provides a command-line interface for generating snapshot tests from your previews.

### Installation
Download Prefire from brew:
```bash
brew tap barredewe/prefire
brew install prefire
```

#### Usage

```bash
prefire tests
prefire playbook
```

Use `--help` with any command to see available options:

```bash
prefire tests --help
prefire playbook --help
```