import Foundation
import PathKit

/// Runs a program to its end.
public protocol ProcessRunning: Sendable {
    /// Runs `executable` with `arguments` and `environment`, writing its output to `logFile`.
    /// - Returns: Exit status of the program.
    func run(executable: String, arguments: [String], environment: [String: String], logFile: URL) throws -> Int32
}

/// Runs programs with `Process`.
public struct ProcessRunner: ProcessRunning {
    public init() {}

    public func run(executable: String, arguments: [String], environment: [String: String], logFile: URL) throws -> Int32 {
        try FileManager.default.createDirectory(at: logFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        _ = FileManager.default.createFile(atPath: logFile.path, contents: nil)
        let log = try FileHandle(forWritingTo: logFile)
        defer { try? log.close() }

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

    public init(
        scheme: String,
        workspace: String? = nil,
        project: String? = nil,
        destination: String = defaultDestination,
        testTarget: String? = nil,
        outputDirectory: URL,
        sources: [String] = [],
        previewDefaultEnabled: Bool = true,
        useGroupedSnapshots: Bool = true
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

        let catalog = (try? catalog()) ?? []
        let plan = Self.plan(for: request, catalog: catalog, testTarget: configuration.testTarget)
        let options = RenderOptions(
            directory: directory.path,
            runID: makeRunID(),
            previews: plan.runtimeFilter,
            devices: request.devices,
            colorScheme: request.colorScheme,
            dynamicType: request.dynamicType
        )

        let logFile = directory.appendingPathComponent(Self.logFileName)
        Logger.info("Rendering with xcodebuild, its output goes to \(logFile.path)")
        let status = try runner.run(
            executable: "/usr/bin/xcrun",
            arguments: xcodebuildArguments(onlyTesting: plan.onlyTesting),
            environment: try environment(for: options),
            logFile: logFile
        )

        let manifest = try Self.collect(in: directory, runID: options.runID, catalog: catalog, destination: configuration.destination)
        if manifest.previews.isEmpty {
            if status != 0 {
                throw RenderError.nothingRendered(status: status, logFile: logFile.path)
            }
            // Tests that ignore the options pass as usual and leave nothing, like when no preview matched.
            if !Self.testsRan(in: directory, runID: options.runID) {
                throw RenderError.notInRenderMode(logFile: logFile.path)
            }
        }
        try manifest.write(to: directory)
        return RenderResult(manifest: manifest, directory: directory, logFile: logFile, status: status)
    }

    // MARK: - xcodebuild

    /// Arguments of `xcrun`, running `xcodebuild test` for the tests `onlyTesting` names.
    func xcodebuildArguments(onlyTesting: [String]) -> [String] {
        var arguments = ["xcodebuild", "test", "-scheme", configuration.scheme]
        if let workspace = configuration.workspace {
            arguments += ["-workspace", workspace]
        } else if let project = configuration.project {
            arguments += ["-project", project]
        }
        arguments += ["-destination", configuration.destination]
        // Clones of the simulator would write into the same directory at the same time.
        arguments += ["-parallel-testing-enabled", "NO"]
        arguments += onlyTesting.map { "-only-testing:\($0)" }
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
        var runtimeFilter: [String]
    }

    /// Runs only the tests of the previews asked for when every name is found in `catalog`.
    /// Otherwise runs all snapshot tests, which skip the previews not asked for.
    static func plan(for request: RenderRequest, catalog: [PreviewEntry], testTarget: String?) -> Plan {
        guard let testTarget else {
            return Plan(onlyTesting: [], runtimeFilter: request.previews)
        }
        guard !request.previews.isEmpty else {
            return Plan(onlyTesting: [testTarget], runtimeFilter: [])
        }

        var entries: [PreviewEntry] = []
        for name in request.previews {
            guard let entry = entry(named: name, in: catalog) else {
                return Plan(onlyTesting: [testTarget], runtimeFilter: request.previews)
            }
            entries.append(entry)
        }

        var tests: [String] = []
        for entry in entries {
            let test = "\(testTarget)/\(entry.testClass)/\(entry.testMethod)"
            if !tests.contains(test) {
                tests.append(test)
            }
        }
        // Snapshots of a `PreviewProvider` are named by its previews, not by the type, so a
        // filter by the type name would skip them all.
        let hasProvider = entries.contains { $0.kind == .provider }
        return Plan(onlyTesting: tests, runtimeFilter: hasProvider ? [] : request.previews)
    }

    /// Preview `name` is a snapshot of: a `#Preview` it is named after, or a `PreviewProvider` type.
    static func entry(named name: String, in catalog: [PreviewEntry]) -> PreviewEntry? {
        catalog
            .filter { $0.kind == .provider ? $0.name == name : $0.matches(snapshotName: name) }
            .max { $0.name.count < $1.name.count }
    }

    // MARK: - Records

    /// Manifest of the records of run `runID` in `directory`. Records and images of other runs are removed.
    static func collect(in directory: URL, runID: String, catalog: [PreviewEntry], destination: String?) throws -> RenderManifest {
        let decoder = JSONDecoder()
        var records: [RenderRecord] = []

        for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        where file.pathExtension == "json" && file.lastPathComponent != RenderManifest.fileName {
            guard let data = try? Data(contentsOf: file),
                  let record = try? decoder.decode(RenderRecord.self, from: data) else { continue }

            if record.runID == runID {
                records.append(record)
            } else {
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
