import Foundation
import PathKit

/// Runs a program to its end.
public protocol ProcessRunning: Sendable {
    /// Runs `executable` with `arguments` and `environment`, adding its output to `logFile`.
    /// - Returns: Exit status of the program.
    func run(executable: String, arguments: [String], environment: [String: String], logFile: URL) throws -> Int32

    /// Runs `executable` with `arguments` and returns its standard output.
    func capture(executable: String, arguments: [String]) throws -> (status: Int32, output: String)

    /// `run`, stopping the program once `isFinished` is true of its output so far.
    func run(
        executable: String,
        arguments: [String],
        environment: [String: String],
        logFile: URL,
        until isFinished: @escaping @Sendable (String) -> Bool
    ) throws -> Int32
}

public extension ProcessRunning {
    func run(
        executable: String,
        arguments: [String],
        environment: [String: String],
        logFile: URL,
        until isFinished: @escaping @Sendable (String) -> Bool
    ) throws -> Int32 {
        try run(executable: executable, arguments: arguments, environment: environment, logFile: logFile)
    }
}

/// Runs programs with `Process`.
public struct ProcessRunner: ProcessRunning {
    public init() {}

    public func run(executable: String, arguments: [String], environment: [String: String], logFile: URL) throws -> Int32 {
        try FileManager.default.createDirectory(at: logFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: logFile.path) {
            _ = FileManager.default.createFile(atPath: logFile.path, contents: nil)
        }
        let log = try FileHandle(forWritingTo: logFile)
        defer { try? log.close() }
        try log.seekToEnd()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = log
        process.standardError = log
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    public func run(
        executable: String,
        arguments: [String],
        environment: [String: String],
        logFile: URL,
        until isFinished: @escaping @Sendable (String) -> Bool
    ) throws -> Int32 {
        try FileManager.default.createDirectory(at: logFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: logFile.path) {
            _ = FileManager.default.createFile(atPath: logFile.path, contents: nil)
        }
        let log = try FileHandle(forWritingTo: logFile)
        defer { try? log.close() }
        try log.seekToEnd()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()

        // Read on this thread until the output says it is done or the program ends.
        var output = ""
        let reader = pipe.fileHandleForReading
        while true {
            let data = reader.availableData
            if data.isEmpty { break }
            log.write(data)
            output += String(decoding: data, as: UTF8.self)
            if isFinished(output) {
                // simctl waits for the app to quit on SIGTERM; nothing it does after this is needed.
                kill(process.processIdentifier, SIGKILL)
                break
            }
        }
        process.waitUntilExit()
        return process.terminationReason == .uncaughtSignal ? 0 : process.terminationStatus
    }

    public func capture(executable: String, arguments: [String]) throws -> (status: Int32, output: String) {
        let output = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        // Read before waiting: a full pipe would block the program.
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}

/// Where and how `prefire render` builds and runs the snapshot tests.
public struct RenderConfiguration: Equatable, Sendable {
    public static let defaultDestination = "platform=iOS Simulator,name=iPhone 16"
    public static let defaultOutputDirectory = ".prefire/render"

    public var scheme: String
    public var workspace: String?
    public var project: String?
    /// `-destination` of `xcodebuild`.
    public var destination: String
    /// Target of the generated snapshot tests. Lets `xcodebuild` run only the tests of the previews asked for.
    public var testTarget: String?
    /// Directory the images, their records and `manifest.json` are written to.
    public var outputDirectory: URL
    /// Sources the previews are looked for in, as `prefire tests` does.
    public var sources: [String]
    public var previewDefaultEnabled: Bool
    public var useGroupedSnapshots: Bool
    /// Passed to `xcodebuild` after the arguments Prefire sets, like `-derivedDataPath`.
    public var xcodebuildArguments: [String]
    /// Whether the tests are named as the default template names them, so single ones can be run.
    /// `false` with a `template_file_path` of one's own.
    public var testsHaveDefaultNames: Bool
    /// Whether the tests are built with `build-for-testing` and run without the test session of
    /// `xcodebuild test`: on a simulator they are launched with `simctl`. Needs `testTarget`.
    public var launchesTestsDirectly: Bool
    /// Whether renders build into derived data of their own, in the output directory, with settings
    /// for quicker builds, instead of sharing Xcode's.
    public var usesOwnDerivedData: Bool

    public init(
        scheme: String,
        workspace: String? = nil,
        project: String? = nil,
        destination: String = defaultDestination,
        testTarget: String? = nil,
        outputDirectory: URL,
        sources: [String] = [],
        previewDefaultEnabled: Bool = true,
        useGroupedSnapshots: Bool = true,
        xcodebuildArguments: [String] = [],
        testsHaveDefaultNames: Bool = true,
        launchesTestsDirectly: Bool = true,
        usesOwnDerivedData: Bool = false
    ) {
        self.scheme = scheme
        self.workspace = workspace
        self.project = project
        self.destination = destination
        self.testTarget = testTarget
        self.outputDirectory = outputDirectory
        self.sources = sources
        self.previewDefaultEnabled = previewDefaultEnabled
        self.useGroupedSnapshots = useGroupedSnapshots
        self.xcodebuildArguments = xcodebuildArguments
        self.testsHaveDefaultNames = testsHaveDefaultNames
        self.launchesTestsDirectly = launchesTestsDirectly
        self.usesOwnDerivedData = usesOwnDerivedData
    }

    /// Whether `destination` is a Mac, where screens are not rendered on devices.
    var rendersOnMac: Bool {
        destination.replacingOccurrences(of: " ", with: "").lowercased().contains("platform=macos")
    }
}

/// Previews to render, and how.
public struct RenderRequest: Equatable, Sendable {
    public static let colorSchemes = ["light", "dark"]
    public static let dynamicTypeSizes = [
        "xSmall", "small", "medium", "large", "xLarge", "xxLarge", "xxxLarge",
        "accessibility1", "accessibility2", "accessibility3", "accessibility4", "accessibility5",
    ]

    /// Names of the previews. Empty renders all of them.
    public var previews: [String]
    /// Devices to render screens on, like `iPhone 15` or `iPad`. Empty renders them as the tests snapshot them.
    public var devices: [String]
    /// One of `colorSchemes`, or `nil` for the system appearance.
    public var colorScheme: String?
    /// One of `dynamicTypeSizes`, or `nil` for the default size.
    public var dynamicType: String?

    public init(previews: [String] = [], devices: [String] = [], colorScheme: String? = nil, dynamicType: String? = nil) {
        self.previews = previews
        self.devices = devices
        self.colorScheme = colorScheme
        self.dynamicType = dynamicType
    }

    func validate() throws {
        if let colorScheme, !Self.colorSchemes.contains(colorScheme) {
            throw RenderError.invalidOption("Unknown color scheme '\(colorScheme)'. Use one of: \(Self.colorSchemes.joined(separator: ", ")).")
        }
        if let dynamicType, !Self.dynamicTypeSizes.contains(dynamicType) {
            throw RenderError.invalidOption("Unknown Dynamic Type size '\(dynamicType)'. Use one of: \(Self.dynamicTypeSizes.joined(separator: ", ")).")
        }
    }
}

/// What a render produced.
public struct RenderResult: Sendable {
    public var manifest: RenderManifest
    /// Directory `manifest.json` and the images are in.
    public var directory: URL
    /// Output of `xcodebuild`.
    public var logFile: URL
    /// Exit status of `xcodebuild`. Not 0 when a preview failed to render, too.
    public var status: Int32
    /// What was asked for but not done, like preview names that matched nothing.
    public var warnings: [String] = []

    /// Absolute path of the image of `preview`, when it has one.
    public func imageURL(of preview: RenderedPreview) -> URL? {
        preview.record.image.map { directory.appendingPathComponent($0) }
    }
}

public enum RenderError: Error, CustomStringConvertible, Equatable {
    case invalidOption(String)
    case nothingRendered(status: Int32, logFile: String)
    /// `xcodebuild` succeeded, but no snapshot test ran in render mode.
    case notInRenderMode(logFile: String)

    public var description: String {
        switch self {
        case let .invalidOption(message):
            message
        case let .nothingRendered(status, logFile):
            "xcodebuild exited with \(status) and rendered no previews. See its output in \(logFile)."
        case let .notInRenderMode(logFile):
            """
            xcodebuild succeeded, but no snapshot test ran in render mode. Either the scheme did not run \
            the generated snapshot tests (check `scheme` and `test_target`), or they were generated by a \
            Prefire without render mode: update the Prefire package and its PrefireTestsPlugin. \
            See the output of xcodebuild in \(logFile).
            """
        }
    }
}

/// Renders previews by running the generated snapshot tests in render mode.
///
/// The tests are built anew by `xcodebuild` on every run, on the destination asked for, so the
/// images show the code as it is.
public struct RenderService: Sendable {
    public static let logFileName = "xcodebuild.log"

    public var configuration: RenderConfiguration
    /// Folder of the simulators the tests may be launched on.
    var simulatorDeviceSet = SimulatorTestLauncher.defaultDeviceSet
    private let runner: any ProcessRunning
    private let makeRunID: @Sendable () -> String

    public init(
        configuration: RenderConfiguration,
        runner: any ProcessRunning = ProcessRunner(),
        makeRunID: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        self.configuration = configuration
        self.runner = runner
        self.makeRunID = makeRunID
    }

    /// Previews in `configuration.sources`, in source order.
    public func catalog() throws -> [PreviewEntry] {
        try PreviewCatalog.entries(
            sources: configuration.sources.map { Path($0) },
            defaultEnabled: configuration.previewDefaultEnabled,
            useGroupedSnapshots: configuration.useGroupedSnapshots
        )
    }

    /// Builds and runs the snapshot tests to render `request`, and writes `manifest.json`.
    ///
    /// - Throws: `RenderError.nothingRendered` when `xcodebuild` fails before rendering anything,
    ///   like when the build breaks.
    public func render(_ request: RenderRequest) throws -> RenderResult {
        try request.validate()

        let directory = configuration.outputDirectory.standardizedFileURL
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Two renders into one directory would remove the records of each other.
        let lock = try RenderLock(directory: directory)
        defer { lock.unlock() }

        let catalog = (try? catalog()) ?? []
        let plan = Self.plan(
            for: request,
            catalog: catalog,
            testTarget: configuration.testTarget,
            testsHaveDefaultNames: configuration.testsHaveDefaultNames
        )
        let options = RenderOptions(
            directory: directory.path,
            runID: makeRunID(),
            previews: plan.runtimeFilter,
            devices: request.devices,
            colorScheme: request.colorScheme,
            dynamicType: request.dynamicType
        )

        let logFile = directory.appendingPathComponent(Self.logFileName)
        // Each render writes a log of its own; the steps of one add to it.
        try? FileManager.default.removeItem(at: logFile)
        Logger.info("Rendering with xcodebuild, its output goes to \(logFile.path)")
        let environment = try environment(for: options)
        let status: Int32
        if let directStatus = try runDirectly(plan: plan, catalog: catalog, options: options, environment: environment, logFile: logFile) {
            status = directStatus
        } else {
            status = try runner.run(
                executable: "/usr/bin/xcrun",
                arguments: xcodebuildArguments(onlyTesting: plan.onlyTesting, skipTesting: plan.skipTesting),
                environment: environment,
                logFile: logFile
            )
        }

        // The images of the last render stay until a run renders anew, so a broken build keeps them.
        let testsRan = Self.testsRan(in: directory, runID: options.runID)
        let manifest = try Self.collect(
            in: directory,
            runID: options.runID,
            catalog: catalog,
            destination: configuration.destination,
            removingOtherRuns: testsRan
        )
        // The manifest lists what the directory holds: written whenever the files of other runs went.
        if testsRan || !manifest.previews.isEmpty {
            try manifest.write(to: directory)
        }
        if manifest.previews.isEmpty {
            if status != 0 {
                throw RenderError.nothingRendered(status: status, logFile: logFile.path)
            }
            // Tests that ignore the options pass as usual and leave nothing, like when no preview matched.
            if !testsRan {
                throw RenderError.notInRenderMode(logFile: logFile.path)
            }
        }

        var result = RenderResult(manifest: manifest, directory: directory, logFile: logFile, status: status)
        result.warnings = warnings(for: request, catalog: catalog, manifest: manifest)
        return result
    }

    // MARK: - Direct launch

    /// Builds the tests with `build-for-testing` and runs them from the `.xctestrun` it writes:
    /// app-hosted tests on a simulator with `simctl`, others with `xcodebuild test-without-building`.
    ///
    /// The test session of `xcodebuild test` takes most of a render: launched directly, a
    /// simulator runs the tests in seconds.
    ///
    /// - Returns: Exit status, or `nil` to run `xcodebuild test` instead.
    func runDirectly(plan: Plan, catalog: [PreviewEntry], options: RenderOptions, environment: [String: String], logFile: URL) throws -> Int32? {
        guard configuration.launchesTestsDirectly, let testTarget = configuration.testTarget else { return nil }
        let started = Date()
        let step = { (name: String) in Logger.verbose(String(format: "%@: %.1f s", name, Date().timeIntervalSince(started))) }

        // Xcode takes the environment into the build settings, so options that change on every render
        // would have it plan the build anew each time. The tests get them when they run.
        var buildEnvironment = environment
        buildEnvironment[RenderOptions.environmentKey] = nil
        buildEnvironment[RenderOptions.testRunnerEnvironmentKey] = nil

        var status = try runner.run(
            executable: "/usr/bin/xcrun",
            arguments: buildForTestingArguments(testTarget: testTarget, resolvingPackages: false),
            environment: buildEnvironment,
            logFile: logFile
        )
        if status != 0, Self.needsPackageResolution(logFile: logFile) {
            status = try runner.run(
                executable: "/usr/bin/xcrun",
                arguments: buildForTestingArguments(testTarget: testTarget, resolvingPackages: true),
                environment: buildEnvironment,
                logFile: logFile
            )
        }
        step("Built for testing")
        // A broken build is the answer: running the tests would only build it again.
        guard status == 0 else { return status }

        guard let products = try productsDirectory(),
              let testRun = Self.latestTestRun(in: products, scheme: configuration.scheme, since: started),
              let target = try? XCTestRun.targets(in: testRun).first(where: { $0.name == testTarget }) else { return nil }
        step("Read \(testRun.lastPathComponent)")

        let identifiers = Self.testIdentifiers(for: plan, catalog: catalog, testTarget: testTarget)
        let launcher = SimulatorTestLauncher(runner: runner, deviceSet: simulatorDeviceSet)
        if let launched = try launcher.run(
            target: target,
            destination: configuration.destination,
            selectors: XCTestRun.selectors(for: identifiers, target: target),
            environment: [RenderOptions.environmentKey: environment[RenderOptions.environmentKey] ?? ""],
            logFile: logFile
        ), Self.testsRan(in: URL(fileURLWithPath: options.directory), runID: options.runID) {
            return launched
        }

        Logger.info("Running the tests with xcodebuild test-without-building")
        return try runner.run(
            executable: "/usr/bin/xcrun",
            arguments: testWithoutBuildingArguments(testRun: testRun, plan: plan),
            environment: environment,
            logFile: logFile
        )
    }

    /// Arguments of `xcrun`, building the tests of `testTarget` for `test-without-building`.
    ///
    /// - Parameter resolvingPackages: Lets `xcodebuild` resolve the packages again, which takes
    ///   seconds on every run. Needed only when `Package.resolved` is out of date.
    func buildForTestingArguments(testTarget: String, resolvingPackages: Bool) -> [String] {
        var arguments = ["xcodebuild", "build-for-testing"] + projectArguments
        arguments += ["-destination", configuration.destination, "-only-testing:\(testTarget)"]
        if !resolvingPackages {
            arguments += ["-disableAutomaticPackageResolution", "-skipPackageUpdates"]
        }
        arguments += configuration.xcodebuildArguments
        return arguments
    }

    /// Arguments of `xcrun`, running the tests `plan` names from `testRun` without building them.
    func testWithoutBuildingArguments(testRun: URL, plan: Plan) -> [String] {
        var arguments = ["xcodebuild", "test-without-building", "-xctestrun", testRun.path, "-destination", configuration.destination]
        arguments += buildsIntoOwnDerivedData ? ["-derivedDataPath", derivedDataDirectory.path] : []
        arguments += ["-parallel-testing-enabled", "NO"]
        arguments += plan.onlyTesting.map { "-only-testing:\($0)" }
        arguments += plan.skipTesting.map { "-skip-testing:\($0)" }
        arguments += configuration.xcodebuildArguments
        return arguments
    }

    static func needsPackageResolution(logFile: URL) -> Bool {
        let log = ((try? String(contentsOf: logFile, encoding: .utf8)) ?? "").lowercased()
        return log.contains("package.resolved") || log.contains("resolve package")
    }

    /// Tests to run, as `Target/Class/method`, or only the target to run all of them.
    ///
    /// A run of the whole target that skips tests lists the others instead, since `simctl` can
    /// only name the tests to run.
    static func testIdentifiers(for plan: Plan, catalog: [PreviewEntry], testTarget: String) -> [String] {
        guard plan.onlyTesting == [testTarget], !plan.skipTesting.isEmpty else { return plan.onlyTesting }
        var identifiers: [String] = []
        for entry in catalog {
            let identifier = "\(testTarget)/\(entry.testClass)/\(entry.testMethod)"
            if !identifiers.contains(identifier), !plan.skipTesting.contains(identifier) {
                identifiers.append(identifier)
            }
        }
        return identifiers
    }

    /// Newest `.xctestrun` of `scheme` in `directory` written since `date`.
    static func latestTestRun(in directory: URL, scheme: String, since date: Date) -> URL? {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return files
            .filter { $0.pathExtension == "xctestrun" && $0.lastPathComponent.hasPrefix(scheme + "_") }
            .compactMap { file -> (URL, Date)? in
                guard let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                      modified >= date.addingTimeInterval(-2) else { return nil }
                return (file, modified)
            }
            .max { $0.1 < $1.1 }?
            .0
    }

    /// `Build/Products` of the scheme in its derived data, where `.xctestrun` files go.
    ///
    /// Asking `xcodebuild` takes seconds, so the answer is kept in the output directory for the
    /// same arguments.
    func productsDirectory() throws -> URL? {
        var arguments = ["xcodebuild", "-showBuildSettings"] + projectArguments
        arguments += ["-destination", configuration.destination, "-disableAutomaticPackageResolution", "-skipPackageUpdates"]
        arguments += configuration.xcodebuildArguments

        let cache = configuration.outputDirectory.standardizedFileURL.appendingPathComponent(Self.productsCacheFileName)
        let key = arguments.joined(separator: "\u{1F}")
        if let cached = try? JSONDecoder().decode([String: String].self, from: Data(contentsOf: cache)),
           cached["key"] == key, let path = cached["path"], FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path, isDirectory: true)
        }

        let result = try runner.capture(executable: "/usr/bin/xcrun", arguments: arguments)
        guard result.status == 0, let path = Self.symroot(inBuildSettings: result.output) else { return nil }
        try? JSONEncoder().encode(["key": key, "path": path]).write(to: cache, options: .atomic)
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    static let productsCacheFileName = ".prefire-products.json"

    /// `SYMROOT` in the output of `xcodebuild -showBuildSettings`.
    static func symroot(inBuildSettings output: String) -> String? {
        output.components(separatedBy: .newlines).lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.hasPrefix("SYMROOT = ") }
            .map { String($0.dropFirst("SYMROOT = ".count)) }
    }

    private var projectArguments: [String] {
        var arguments = ["-scheme", configuration.scheme]
        if let workspace = configuration.workspace {
            arguments += ["-workspace", workspace]
        } else if let project = configuration.project {
            arguments += ["-project", project]
        }
        return arguments + derivedDataArguments
    }

    /// Derived data of the renders when `usesOwnDerivedData`, apart from Xcode's, so a render builds
    /// with settings of its own without rebuilding what Xcode built, and never waits for a build of
    /// Xcode to finish. A first render builds the whole project into it, though.
    var derivedDataDirectory: URL {
        configuration.outputDirectory.standardizedFileURL.appendingPathComponent(".derived-data", isDirectory: true)
    }

    /// Whether renders build into `derivedDataDirectory`: asked for, and `xcodebuild_args` does not
    /// pick the derived data.
    private var buildsIntoOwnDerivedData: Bool {
        configuration.usesOwnDerivedData && !configuration.xcodebuildArguments.contains("-derivedDataPath")
    }

    /// Builds into `derivedDataDirectory` without an index, which only Xcode reads and which takes
    /// up to a third of a clean build, and with implicit modules, quicker for one changed file of a
    /// small project. With Xcode's derived data, its settings stay, or every build would redo the other's.
    private var derivedDataArguments: [String] {
        guard buildsIntoOwnDerivedData else { return [] }
        return ["-derivedDataPath", derivedDataDirectory.path, "COMPILER_INDEX_STORE_ENABLE=NO", "SWIFT_ENABLE_EXPLICIT_MODULES=NO"]
    }

    // MARK: - xcodebuild

    /// Arguments of `xcrun`, running `xcodebuild test` for the tests `onlyTesting` names, except those
    /// `skipTesting` names.
    func xcodebuildArguments(onlyTesting: [String], skipTesting: [String] = []) -> [String] {
        var arguments = ["xcodebuild", "test"] + projectArguments
        arguments += ["-destination", configuration.destination]
        // Clones of the simulator would write into the same directory at the same time.
        arguments += ["-parallel-testing-enabled", "NO"]
        arguments += onlyTesting.map { "-only-testing:\($0)" }
        arguments += skipTesting.map { "-skip-testing:\($0)" }
        arguments += configuration.xcodebuildArguments
        return arguments
    }

    /// Environment of `xcodebuild`, passing `options` on to the tests.
    func environment(for options: RenderOptions, base: [String: String] = ProcessInfo.processInfo.environment) throws -> [String: String] {
        let json = String(decoding: try JSONEncoder().encode(options), as: UTF8.self)
        var environment = base
        environment[RenderOptions.environmentKey] = json
        environment[RenderOptions.testRunnerEnvironmentKey] = json
        return environment
    }

    /// Tests to run, and the names the tests filter previews by.
    struct Plan: Equatable {
        /// `-only-testing:` identifiers. Empty runs every test of the scheme.
        var onlyTesting: [String]
        /// `-skip-testing:` identifiers.
        var skipTesting: [String] = []
        var runtimeFilter: [String]
    }

    /// Runs only the tests of the previews asked for when every name is found in `catalog`.
    /// Otherwise runs all snapshot tests, which skip the previews not asked for.
    ///
    /// - Parameter testsHaveDefaultNames: Whether `catalog` names the tests as they are. A template of
    ///   one's own may name them otherwise, so then the whole target runs and the tests filter.
    static func plan(for request: RenderRequest, catalog: [PreviewEntry], testTarget: String?, testsHaveDefaultNames: Bool = true) -> Plan {
        guard testsHaveDefaultNames else {
            return Plan(onlyTesting: testTarget.map { [$0] } ?? [], runtimeFilter: request.previews)
        }
        let runtimeFilter = runtimeFilter(for: request.previews, catalog: catalog)
        guard let testTarget else {
            return Plan(onlyTesting: [], runtimeFilter: runtimeFilter)
        }

        var tests: [String] = []
        for name in request.previews {
            guard let entry = entry(named: name, in: catalog) else {
                tests = []
                break
            }
            let test = "\(testTarget)/\(entry.testClass)/\(entry.testMethod)"
            if !tests.contains(test) {
                tests.append(test)
            }
        }
        guard tests.isEmpty else {
            return Plan(onlyTesting: tests, runtimeFilter: runtimeFilter)
        }
        return Plan(
            onlyTesting: [testTarget],
            skipTesting: duplicateProviderTests(in: catalog, testTarget: testTarget),
            runtimeFilter: runtimeFilter
        )
    }

    /// Names the tests filter snapshots by: a `PreviewProvider` by its test, since its snapshots are
    /// named by its previews rather than by the type.
    static func runtimeFilter(for previews: [String], catalog: [PreviewEntry]) -> [String] {
        previews.map { name in
            guard let entry = entry(named: name, in: catalog), entry.kind == .provider else { return name }
            return entry.testMethod
        }
    }

    /// Tests of a `PreviewProvider` in every class but its own. Without `use_grouped_snapshots`
    /// each generated class tests every provider, which would render each of its previews again.
    static func duplicateProviderTests(in catalog: [PreviewEntry], testTarget: String) -> [String] {
        var classes: [String] = []
        for entry in catalog where entry.kind == .macro && !classes.contains(entry.testClass) {
            classes.append(entry.testClass)
        }
        return catalog
            .filter { $0.kind == .provider }
            .flatMap { provider in
                classes
                    .filter { $0 != provider.testClass }
                    .map { "\(testTarget)/\($0)/\(provider.testMethod)" }
            }
    }

    /// What `request` asked for that the render could not do.
    func warnings(for request: RenderRequest, catalog: [PreviewEntry], manifest: RenderManifest) -> [String] {
        var warnings: [String] = []
        let unmatched = request.previews.filter { name in
            guard Self.entry(named: name, in: catalog) == nil else { return false }
            return !manifest.previews.contains { $0.record.name == name || $0.record.name.hasPrefix(name + "-") }
        }
        if !unmatched.isEmpty {
            warnings.append("No preview is named \(unmatched.map { "'\($0)'" }.joined(separator: ", ")). Run `prefire render --list` for the names.")
        }
        if !request.devices.isEmpty, configuration.rendersOnMac {
            warnings.append("Devices are ignored on macOS: previews render at their own size.")
        }
        return warnings
    }

    /// Preview `name` is a snapshot of: a `#Preview` it is named after, or a `PreviewProvider` type.
    static func entry(named name: String, in catalog: [PreviewEntry]) -> PreviewEntry? {
        catalog
            .filter { $0.kind == .provider ? $0.name == name : $0.matches(snapshotName: name) }
            .max { $0.name.count < $1.name.count }
    }

    // MARK: - Records

    /// Manifest of the records of run `runID` in `directory`.
    ///
    /// - Parameter removingOtherRuns: Removes the records and images of other runs.
    static func collect(
        in directory: URL,
        runID: String,
        catalog: [PreviewEntry],
        destination: String?,
        removingOtherRuns: Bool = true
    ) throws -> RenderManifest {
        let decoder = JSONDecoder()
        var records: [RenderRecord] = []

        for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        where file.pathExtension == "json" && file.lastPathComponent != RenderManifest.fileName {
            guard let data = try? Data(contentsOf: file),
                  let record = try? decoder.decode(RenderRecord.self, from: data) else { continue }

            if record.runID == runID {
                records.append(record)
            } else if removingOtherRuns {
                // A record and its image share their base name, so a record this run did not
                // overwrite names an image this run did not write.
                try? FileManager.default.removeItem(at: file)
                if let image = record.image, image == URL(fileURLWithPath: image).lastPathComponent {
                    try? FileManager.default.removeItem(at: directory.appendingPathComponent(image))
                }
            }
        }

        // Previews keep the order of their sources; ones not found in them go last.
        let previews = records.map { record in
            let index = entry(forSnapshot: record.name, in: catalog)
            return (order: index ?? .max, preview: RenderedPreview(record: record, source: index.map { catalog[$0] }))
        }
        let sorted = previews.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            let (lhs, rhs) = (lhs.preview, rhs.preview)
            if lhs.record.name != rhs.record.name { return lhs.record.name < rhs.record.name }
            return (lhs.record.image ?? "") < (rhs.record.image ?? "")
        }
        return RenderManifest(runID: runID, destination: destination, previews: sorted.map { $0.preview })
    }

    /// Whether a snapshot test of run `runID` ran in render mode, by the marker it writes.
    static func testsRan(in directory: URL, runID: String) -> Bool {
        let marker = directory.appendingPathComponent(RenderOptions.runMarkerFileName)
        return (try? String(contentsOf: marker, encoding: .utf8)) == runID
    }

    /// Index in `catalog` of the `#Preview` a snapshot named `name` comes from.
    static func entry(forSnapshot name: String, in catalog: [PreviewEntry]) -> Int? {
        catalog.indices
            .filter { catalog[$0].kind == .macro && catalog[$0].matches(snapshotName: name) }
            .max { catalog[$0].name.count < catalog[$1].name.count }
    }
}
