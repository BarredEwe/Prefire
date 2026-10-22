import Foundation
import SwiftUI

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

#if canImport(XCTest) && !os(watchOS)
/// Asks the generated snapshot tests to render previews into a directory instead of comparing them
/// with their references, so a person or an agent can look at them.
///
/// `prefire render` passes it to the tests as JSON in the `PREFIRE_RENDER` environment variable.
/// Each rendered preview is written as `<name>.png`, next to a `<name>.json` `PrefireRenderRecord`.
public struct PrefireRenderOptions: Codable, Equatable, Sendable {
    /// Environment variable `prefire render` sets. `xcodebuild` passes it on as `TEST_RUNNER_PREFIRE_RENDER`.
    public static let environmentKey = "PREFIRE_RENDER"

    /// Directory the images and their records are written to.
    public var directory: String

    /// Identifies the run. Records carry it, so images left from an earlier run are told apart.
    public var runID: String

    /// Names of the previews to render. Empty renders all of them.
    ///
    /// A preview is rendered when its name is one of these, or starts with one of these and `-`,
    /// like the snapshots of a preview with `arguments:`.
    public var previews: [String]

    /// Devices to render screen previews on, by name. Empty renders them as the tests snapshot them.
    public var devices: [String]

    /// `light` or `dark`, or `nil` to render with the system appearance.
    public var colorScheme: String?

    /// Dynamic Type size, named like `DynamicTypeSize`: `xSmall` ... `xxxLarge`, `accessibility1` ...
    /// `accessibility5`. `nil` renders with the default size.
    public var dynamicType: String?

    public init(
        directory: String,
        runID: String = UUID().uuidString,
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

    /// Options `prefire render` passed in `environment`, or `nil` when the tests run as usual.
    public static func fromEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> PrefireRenderOptions? {
        guard let json = environment[environmentKey], !json.isEmpty else { return nil }
        return try? JSONDecoder().decode(PrefireRenderOptions.self, from: Data(json.utf8))
    }

    /// Whether the preview snapshotted as `name` is to be rendered.
    public func includes(_ name: String) -> Bool {
        previews.isEmpty || previews.contains { name == $0 || name.hasPrefix($0 + "-") }
    }
}

/// What `prefire render` learns about a rendered preview, written next to its image.
public struct PrefireRenderRecord: Codable, Equatable, Sendable {
    /// `runID` of the options the preview was rendered with.
    public var runID: String

    /// Name of the snapshot, like the name of its reference image.
    public var name: String

    /// File name of the image in the render directory, or `nil` when it could not be rendered.
    public var image: String?

    /// Device it was rendered on, when one of `PrefireRenderOptions.devices`.
    public var device: String?

    public var colorScheme: String?
    public var dynamicType: String?

    /// Whether the preview is a screen rather than a component.
    public var isScreen: Bool

    /// Size of the image, in points.
    public var width: Double
    public var height: Double

    /// Pixels per point of the image.
    public var scale: Double

    /// `previewUserStory(_:)` of the preview.
    public var userStory: String?

    /// `previewState(_:)` of the preview.
    public var state: String?

    /// Why the preview could not be rendered.
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

/// Writes rendered previews and their records into `PrefireRenderOptions.directory`.
enum PrefireRenderWriter {
    /// Writes `png` and `record` under a file name made of `record.name`.
    ///
    /// A name already written in this run gets a number, so two previews named alike both stay.
    /// - Returns: Why the files could not be written, or `nil`.
    static func write(png: Data?, record: PrefireRenderRecord, options: PrefireRenderOptions) -> String? {
        let directory = URL(fileURLWithPath: options.directory, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let baseName = availableBaseName(for: record.name, in: directory, runID: options.runID)
            var record = record
            if let png {
                record.image = baseName + ".png"
                try png.write(to: directory.appendingPathComponent(baseName + ".png"), options: .atomic)
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(record).write(to: directory.appendingPathComponent(baseName + ".json"), options: .atomic)
            return nil
        } catch {
            return "Prefire could not write the render of \(record.name) to \(directory.path): \(error)"
        }
    }

    /// `name` reduced to characters that are safe in a file name.
    static func fileName(for name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let scalars = name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let fileName = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return fileName.isEmpty ? "preview" : fileName
    }

    private static func availableBaseName(for name: String, in directory: URL, runID: String) -> String {
        let fileName = fileName(for: name)
        var candidate = fileName
        var index = 2
        while isWritten(candidate, in: directory, runID: runID) {
            candidate = "\(fileName)-\(index)"
            index += 1
        }
        return candidate
    }

    /// Whether a record named `baseName` was written in this run already. Ones of earlier runs are
    /// overwritten.
    private static func isWritten(_ baseName: String, in directory: URL, runID: String) -> Bool {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(baseName + ".json")),
              let record = try? JSONDecoder().decode(PrefireRenderRecord.self, from: data) else { return false }
        return record.runID == runID
    }
}

// MARK: - Appearance

#if os(iOS) || os(tvOS)
extension PrefireRenderOptions {
    /// Traits of `colorScheme` and `dynamicType`, put over those of the snapshot.
    var traits: UITraitCollection? {
        var traits: [UITraitCollection] = []
        switch colorScheme {
        case "dark": traits.append(UITraitCollection(userInterfaceStyle: .dark))
        case "light": traits.append(UITraitCollection(userInterfaceStyle: .light))
        default: break
        }
        if let category = dynamicType.flatMap(Self.contentSizeCategory) {
            traits.append(UITraitCollection(preferredContentSizeCategory: category))
        }
        return traits.isEmpty ? nil : UITraitCollection(traitsFrom: traits)
    }

    private static func contentSizeCategory(_ name: String) -> UIContentSizeCategory? {
        switch name {
        case "xSmall": .extraSmall
        case "small": .small
        case "medium": .medium
        case "large": .large
        case "xLarge": .extraLarge
        case "xxLarge": .extraExtraLarge
        case "xxxLarge": .extraExtraExtraLarge
        case "accessibility1": .accessibilityMedium
        case "accessibility2": .accessibilityLarge
        case "accessibility3": .accessibilityExtraLarge
        case "accessibility4": .accessibilityExtraExtraLarge
        case "accessibility5": .accessibilityExtraExtraExtraLarge
        default: nil
        }
    }
}
#elseif os(macOS)
extension PrefireRenderOptions {
    /// `content` with `colorScheme` and `dynamicType` put into its environment.
    @MainActor
    func applyingAppearance(to content: AnyView) -> AnyView {
        var view = content
        switch colorScheme {
        case "dark": view = AnyView(view.environment(\.colorScheme, .dark))
        case "light": view = AnyView(view.environment(\.colorScheme, .light))
        default: break
        }
        if let size = dynamicType.flatMap(Self.dynamicTypeSize) {
            view = AnyView(view.environment(\.dynamicTypeSize, size))
        }
        return view
    }

    private static func dynamicTypeSize(_ name: String) -> DynamicTypeSize? {
        switch name {
        case "xSmall": .xSmall
        case "small": .small
        case "medium": .medium
        case "large": .large
        case "xLarge": .xLarge
        case "xxLarge": .xxLarge
        case "xxxLarge": .xxxLarge
        case "accessibility1": .accessibility1
        case "accessibility2": .accessibility2
        case "accessibility3": .accessibility3
        case "accessibility4": .accessibility4
        case "accessibility5": .accessibility5
        default: nil
        }
    }
}

/// PNG of `view` as it is on screen, the way SnapshotTesting renders an `NSView`.
@MainActor
func prefireRenderPNG(of view: NSView) -> Data? {
    view.layoutSubtreeIfNeeded()
    guard view.bounds.width > 0, view.bounds.height > 0,
          let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
    view.cacheDisplay(in: view.bounds, to: representation)
    return representation.representation(using: .png, properties: [:])
}
#endif
#endif
