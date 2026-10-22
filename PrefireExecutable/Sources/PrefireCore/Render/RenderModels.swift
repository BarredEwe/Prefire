import Foundation

/// What the generated tests render, passed to them as JSON in the `PREFIRE_RENDER` environment
/// variable. Mirrors `PrefireRenderOptions` of the Prefire library.
public struct RenderOptions: Codable, Equatable, Sendable {
    public static let environmentKey = "PREFIRE_RENDER"

    /// `xcodebuild` passes variables with this prefix on to the test runner, without the prefix.
    public static let testRunnerEnvironmentKey = "TEST_RUNNER_PREFIRE_RENDER"

    public var directory: String
    public var runID: String
    public var previews: [String]
    public var devices: [String]
    public var colorScheme: String?
    public var dynamicType: String?

    public init(
        directory: String,
        runID: String,
        previews: [String] = [],
        devices: [String] = [],
        colorScheme: String? = nil,
        dynamicType: String? = nil
    ) {
        self.directory = directory
        self.runID = runID
        self.previews = previews
        self.devices = devices
        self.colorScheme = colorScheme
        self.dynamicType = dynamicType
    }
}

/// What the generated tests write next to each rendered image. Mirrors `PrefireRenderRecord` of the
/// Prefire library.
public struct RenderRecord: Codable, Equatable, Sendable {
    public var runID: String
    public var name: String
    public var image: String?
    public var device: String?
    public var colorScheme: String?
    public var dynamicType: String?
    public var isScreen: Bool
    public var width: Double
    public var height: Double
    public var scale: Double
    public var userStory: String?
    public var state: String?
    public var error: String?

    public init(
        runID: String,
        name: String,
        image: String? = nil,
        device: String? = nil,
        colorScheme: String? = nil,
        dynamicType: String? = nil,
        isScreen: Bool = false,
        width: Double = 0,
        height: Double = 0,
        scale: Double = 1,
        userStory: String? = nil,
        state: String? = nil,
        error: String? = nil
    ) {
        self.runID = runID
        self.name = name
        self.image = image
        self.device = device
        self.colorScheme = colorScheme
        self.dynamicType = dynamicType
        self.isScreen = isScreen
        self.width = width
        self.height = height
        self.scale = scale
        self.userStory = userStory
        self.state = state
        self.error = error
    }
}

/// A rendered preview in `manifest.json`: its record, and where it is declared.
public struct RenderedPreview: Codable, Equatable, Sendable {
    public var record: RenderRecord

    /// `#Preview` or `PreviewProvider` the snapshot comes from, when it was found in the sources.
    public var source: PreviewEntry?

    public init(record: RenderRecord, source: PreviewEntry?) {
        self.record = record
        self.source = source
    }
}

/// `manifest.json` of a render directory: every preview the last run rendered.
public struct RenderManifest: Codable, Equatable, Sendable {
    public static let fileName = "manifest.json"

    public var runID: String
    public var createdAt: Date
    public var destination: String?
    public var previews: [RenderedPreview]

    public init(runID: String, createdAt: Date = Date(), destination: String?, previews: [RenderedPreview]) {
        self.runID = runID
        self.createdAt = createdAt
        self.destination = destination
        self.previews = previews
    }

    public static func read(from directory: URL) throws -> RenderManifest {
        let data = try Data(contentsOf: directory.appendingPathComponent(fileName))
        return try decoder.decode(RenderManifest.self, from: data)
    }

    public func write(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoded().write(to: directory.appendingPathComponent(Self.fileName), options: .atomic)
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
