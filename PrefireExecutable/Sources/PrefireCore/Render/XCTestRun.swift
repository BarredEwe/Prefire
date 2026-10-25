import Foundation

/// A test target of the `.xctestrun` file `xcodebuild build-for-testing` writes: what `xcodebuild`
/// would launch to run it.
struct XCTestRunTarget: Equatable, Sendable {
    var name: String
    var moduleName: String
    /// `TestHostPath`, with `__TESTROOT__` resolved. `nil` for a test bundle without a host app.
    var testHostPath: String?
    var testHostBundleIdentifier: String?
    /// `TestBundlePath`, still holding `__TESTHOST__`, which only an installed host resolves.
    var testBundlePath: String
    var isAppHosted: Bool
    var isUITest: Bool
    var environment: [String: String]
    var testingEnvironment: [String: String]
    var commandLineArguments: [String]
}

/// Reads `.xctestrun` files, in format 1 (a scheme without a test plan) and 2 (with test plans).
enum XCTestRun {
    static func targets(in url: URL) throws -> [XCTestRunTarget] {
        let data = try Data(contentsOf: url)
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return [] }
        let testRoot = url.deletingLastPathComponent().path

        let dictionaries: [(name: String, values: [String: Any])]
        if let configurations = plist["TestConfigurations"] as? [[String: Any]] {
            // Format 2: the targets of the first configuration; the others differ in settings only.
            let targets = configurations.first?["TestTargets"] as? [[String: Any]] ?? []
            dictionaries = targets.compactMap { target in
                (target["BlueprintName"] as? String).map { ($0, target) }
            }
        } else {
            dictionaries = plist
                .filter { $0.key != "__xctestrun_metadata__" }
                .compactMap { key, value in (value as? [String: Any]).map { (key, $0) } }
                .sorted { ($0.values["RunOrder"] as? Int ?? 0) < ($1.values["RunOrder"] as? Int ?? 0) }
        }

        return dictionaries.compactMap { name, values in
            guard let bundlePath = values["TestBundlePath"] as? String else { return nil }
            let resolve = { (path: String) in path.replacingOccurrences(of: "__TESTROOT__", with: testRoot) }
            return XCTestRunTarget(
                name: name,
                moduleName: values["ProductModuleName"] as? String ?? name,
                testHostPath: (values["TestHostPath"] as? String).map(resolve),
                testHostBundleIdentifier: values["TestHostBundleIdentifier"] as? String,
                testBundlePath: resolve(bundlePath),
                isAppHosted: values["IsAppHostedTestBundle"] as? Bool ?? (values["TestHostPath"] != nil),
                isUITest: values["IsUITestBundle"] as? Bool ?? false,
                environment: (values["EnvironmentVariables"] as? [String: String] ?? [:]).mapValues(resolve),
                testingEnvironment: (values["TestingEnvironmentVariables"] as? [String: String] ?? [:]).mapValues(resolve),
                commandLineArguments: values["CommandLineArguments"] as? [String] ?? []
            )
        }
    }

    /// Environment that has the host app at `container` load and run the test bundle of `target`,
    /// as `xcodebuild` sets it up, without what only Xcode's tools use.
    ///
    /// - Parameters:
    ///   - container: Path of the installed host app, which `__TESTHOST__` stands for.
    ///   - executable: Path of the host app's executable in `container`.
    ///   - platforms: `Platforms` folder of the developer directory, which `__PLATFORMS__` stands for.
    static func launchEnvironment(
        for target: XCTestRunTarget,
        container: String,
        executable: String,
        platforms: String
    ) -> [String: String] {
        let resolve = { (value: String) in
            value
                .replacingOccurrences(of: "__TESTHOST__", with: container)
                .replacingOccurrences(of: "__PLATFORMS__", with: platforms)
        }
        // Profiling, diagnostics and the main thread checker are Xcode's: they slow the launch down.
        let isXcodeOnly = { (key: String) in key.hasPrefix("PERFC_") || key == "DYLD_INSERT_LIBRARIES" || key == "XCInjectBundleInto" }

        var environment: [String: String] = [:]
        for (key, value) in target.environment where !isXcodeOnly(key) {
            environment[key] = resolve(value)
        }
        for (key, value) in target.testingEnvironment where !isXcodeOnly(key) {
            environment[key] = resolve(value)
        }

        let inject = (target.testingEnvironment["DYLD_INSERT_LIBRARIES"] ?? "")
            .split(separator: ":")
            .map(String.init)
            .first { $0.hasSuffix("libXCTestBundleInject.dylib") }
            .map(resolve)
        environment["DYLD_INSERT_LIBRARIES"] = inject ?? "\(container)/Frameworks/libXCTestBundleInject.dylib"
        environment["XCInjectBundleInto"] = executable
        environment["XCTestBundlePath"] = resolve(target.testBundlePath)
        return environment
    }

    /// `-XCTest` selectors of tests named like `-only-testing:` identifiers, `Target/Class/method`.
    ///
    /// - Returns: `Module.Class/method` for each, or an empty list to run every test of the bundle.
    static func selectors(for identifiers: [String], target: XCTestRunTarget) -> [String] {
        identifiers.compactMap { identifier in
            let parts = identifier.split(separator: "/").map(String.init)
            guard parts.count >= 2, parts[0] == target.name else { return nil }
            return ([target.moduleName + "." + parts[1]] + parts.dropFirst(2)).joined(separator: "/")
        }
    }
}
