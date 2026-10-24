import Foundation
import SwiftUI

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
#if canImport(SceneKit) && !os(watchOS)
import SceneKit
#endif
#if canImport(SpriteKit) && !os(watchOS)
import SpriteKit
#endif
#if canImport(WebKit) && (os(iOS) || os(macOS))
import WebKit
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

    /// File in `directory` the tests write `runID` to as soon as one runs in render mode, whether or not
    /// it renders anything. Without it `prefire render` knows the tests did not take the options.
    public static let runMarkerFileName = ".prefire-render-run"

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
    ///
    /// - Parameter testName: Test of a `PreviewProvider` the snapshot is made in, like `test_card`.
    ///   `prefire render` asks for a provider by its test, since its snapshots are named by its previews.
    public func includes(_ name: String, testName: String? = nil) -> Bool {
        previews.isEmpty || previews.contains { name == $0 || name.hasPrefix($0 + "-") || $0 == testName }
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
            let imageURL = directory.appendingPathComponent(baseName + ".png")
            if let png {
                record.image = imageURL.lastPathComponent
                try png.write(to: imageURL, options: .atomic)
            } else {
                // An image of an earlier run under this name would outlive the record that named it.
                try? FileManager.default.removeItem(at: imageURL)
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(record).write(to: directory.appendingPathComponent(baseName + ".json"), options: .atomic)
            return nil
        } catch {
            return "Prefire could not write the render of \(record.name) to \(directory.path): \(error)"
        }
    }

    /// Tells `prefire render` the tests run in render mode, by writing `options.runID` to
    /// `PrefireRenderOptions.runMarkerFileName`.
    static func markRun(options: PrefireRenderOptions) {
        let directory = URL(fileURLWithPath: options.directory, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? Data(options.runID.utf8).write(to: directory.appendingPathComponent(PrefireRenderOptions.runMarkerFileName), options: .atomic)
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

/// PNG of `view` the way SnapshotTesting's `.image(size:)` takes it: at `size` when one is given, and
/// with `SKView`, `SCNView` and `WKWebView` drawn as images, which `cacheDisplay` leaves blank.
@MainActor
func prefireRenderPNG(of view: NSView, size: CGSize?) -> Data? {
    let initialSize = view.frame.size
    if let size {
        view.frame.size = size
    }
    defer { view.frame.size = initialSize }

    view.layoutSubtreeIfNeeded()
    guard view.bounds.width > 0, view.bounds.height > 0 else { return nil }

    let images = PrefireRenderedViews.drawAsImages(in: view)
    defer { images.forEach { $0.removeFromSuperview() } }

    guard let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
    view.cacheDisplay(in: view.bounds, to: representation)
    return representation.representation(using: .png, properties: [:])
}

#endif

// MARK: - Views drawn elsewhere

#if os(iOS) || os(tvOS)
typealias PrefireRenderedView = UIView
typealias PrefireRenderedImage = UIImage
#elseif os(macOS)
typealias PrefireRenderedView = NSView
typealias PrefireRenderedImage = NSImage
#endif

/// Views that draw with Metal or out of process, so `cacheDisplay` and `layer.render(in:)` leave
/// them blank.
///
/// Mirrors `addImagesForRenderedViews` of SnapshotTesting, so a render looks like the reference image
/// of the preview.
@MainActor
enum PrefireRenderedViews {
    /// Most time to wait for a `WKWebView` to load and snapshot.
    static let webViewTimeout: TimeInterval = 10

    /// Puts an image of each such view in `view` above it.
    /// - Returns: The image views, to remove once `view` is captured.
    static func drawAsImages(in view: PrefireRenderedView) -> [PrefireRenderedView] {
        view.subviews.flatMap { subview -> [PrefireRenderedView] in
            guard let image = image(of: subview) else { return drawAsImages(in: subview) }

            #if os(iOS) || os(tvOS)
            let imageView = UIImageView(image: image)
            imageView.frame = subview.frame
            subview.superview?.insertSubview(imageView, aboveSubview: subview)
            #elseif os(macOS)
            let imageView = NSImageView()
            imageView.image = image
            imageView.frame = subview.frame
            subview.superview?.addSubview(imageView, positioned: .above, relativeTo: subview)
            #endif
            return [imageView]
        }
    }

    private static func image(of view: PrefireRenderedView) -> PrefireRenderedImage? {
        #if canImport(SceneKit)
        if let sceneView = view as? SCNView {
            return inWindow(view) { sceneView.snapshot() }
        }
        #endif
        #if canImport(SpriteKit)
        if let spriteView = view as? SKView {
            guard let scene = spriteView.scene,
                  let image = inWindow(view, { spriteView.texture(from: scene)?.cgImage() }) else { return nil }
            #if os(iOS) || os(tvOS)
            return UIImage(cgImage: image)
            #elseif os(macOS)
            return NSImage(cgImage: image, size: spriteView.bounds.size)
            #endif
        }
        #endif
        #if canImport(WebKit) && (os(iOS) || os(macOS))
        if let webView = view as? WKWebView {
            return image(of: webView)
        }
        #endif
        return nil
    }

    #if canImport(WebKit) && (os(iOS) || os(macOS))
    private static func image(of webView: WKWebView) -> PrefireRenderedImage? {
        let deadline = Date(timeIntervalSinceNow: webViewTimeout)
        while webView.isLoading, Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        guard webView.frame.width > 0, webView.frame.height > 0 else { return PrefireRenderedImage() }

        var image: PrefireRenderedImage?
        var isDone = false
        inWindow(webView) {
            let configuration = WKSnapshotConfiguration()
            configuration.afterScreenUpdates = false
            webView.takeSnapshot(with: configuration) { snapshot, _ in
                image = snapshot
                isDone = true
            }
        }
        while !isDone, Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        return image
    }
    #endif

    #if os(iOS) || os(tvOS)
    /// SnapshotTesting takes these images where the view is on iOS and tvOS.
    private static func inWindow<T>(_ view: UIView, _ perform: () -> T) -> T {
        perform()
    }
    #elseif os(macOS)
    /// Runs `perform` with `view` in a window of its own, as SnapshotTesting does, then puts it back.
    private static func inWindow<T>(_ view: NSView, _ perform: () -> T) -> T {
        let superview = view.superview
        defer { superview?.addSubview(view) }

        let window = ScaledWindow()
        window.contentView = NSView()
        window.contentView?.addSubview(view)
        window.makeKey()
        return perform()
    }

    /// A window drawn at 2x whatever screen there is, like the one SnapshotTesting uses.
    private final class ScaledWindow: NSWindow {
        override var backingScaleFactor: CGFloat { 2 }
    }
    #endif
}
#endif
