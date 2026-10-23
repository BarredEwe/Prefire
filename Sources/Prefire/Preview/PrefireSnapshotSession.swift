import SwiftUI

#if os(iOS) || os(tvOS)
import UIKit
#endif

#if canImport(XCTest) && !os(watchOS)
/// Simulator the snapshot tests have to run on, since references recorded elsewhere differ.
public struct PrefireSnapshotEnvironment {
    /// Simulator model the tests must run on, like `iPhone15,2`. `nil` runs them on any.
    public var simulatorDevice: String?

    /// Major OS version the tests must run on. `nil` runs them on any.
    public var osVersion: Int?

    public init(simulatorDevice: String? = nil, osVersion: Int? = nil) {
        self.simulatorDevice = simulatorDevice
        self.osVersion = osVersion
    }

    /// Stops the tests unless they run on `simulatorDevice` and `osVersion`, and turns animations off.
    @MainActor
    public func prepare() {
        #if os(iOS) || os(tvOS)
        if let simulatorDevice, let deviceModel = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] {
            guard deviceModel.contains(simulatorDevice) else {
                fatalError("Switch to using \(simulatorDevice) for these tests. (You are using \(deviceModel))")
            }
        }

        if let osVersion {
            let currentVersion = ProcessInfo().operatingSystemVersion
            guard currentVersion.majorVersion == osVersion else {
                fatalError("Switch to iOS \(osVersion) for these tests. (You are using \(currentVersion))")
            }
        }

        UIView.setAnimationsEnabled(false)
        #endif
    }
}

/// Waiting for a preview ran out of time.
public struct SnapshotWaitTimeout: Error, CustomStringConvertible {
    /// Names the preview and what it waited for.
    public let message: String

    public var description: String { message }
}

/// Settings of the generated snapshot tests, and the part of their work that does not need
/// SnapshotTesting: picking the devices and rendering the previews.
///
/// The generated tests only compare what `capture(_:)` renders, in the `verify` closure of
/// `failures(of:verify:)`.
public struct PrefireSnapshotSession {
    public var environment: PrefireSnapshotEnvironment

    /// Devices every preview is snapshotted on, by name. Empty snapshots it once, on `device`.
    public var devices: [String]

    /// Whether to snapshot in the simulator's key window, rendering `UIAppearance` and
    /// `UIVisualEffect`.
    public var drawHierarchyInKeyWindow: Bool

    /// Whether screen previews are snapshotted at the height of their whole scrollable content.
    public var fullPage: Bool

    /// How previews that do not say so themselves wait.
    public var waitDefaults: SnapshotWaitDefaults

    /// Canvas of previews that do not name a device.
    public var device: DeviceConfig

    /// Renders the previews into a directory instead of comparing them, when `prefire render` asks
    /// for it. Read from the `PREFIRE_RENDER` environment variable by default.
    public var render: PrefireRenderOptions?

    public init(
        simulatorDevice: String? = nil,
        osVersion: Int? = nil,
        devices: [String] = [],
        drawHierarchyInKeyWindow: Bool = false,
        fullPage: Bool = false,
        waitDefaults: SnapshotWaitDefaults = .init(),
        device: DeviceConfig = .defaultSnapshotDevice,
        render: PrefireRenderOptions? = .fromEnvironment()
    ) {
        environment = PrefireSnapshotEnvironment(simulatorDevice: simulatorDevice, osVersion: osVersion)
        self.devices = devices
        self.drawHierarchyInKeyWindow = drawHierarchyInKeyWindow
        self.fullPage = fullPage
        self.waitDefaults = waitDefaults
        self.device = device
        self.render = render
    }

    /// Prepares `environment` for the tests. Call it from `setUp`.
    ///
    /// Rendering for `prefire render` runs on any simulator, so it only turns animations off.
    @MainActor
    public func prepareEnvironment() {
        if render != nil {
            PrefireSnapshotEnvironment().prepare()
        } else {
            environment.prepare()
        }
    }

    /// Snapshot of a `PreviewProvider` preview, on the device it names or on `device`.
    @MainActor
    public func snapshot(of preview: _Preview, testName: String = #function) -> PrefireSnapshot<AnyView> {
        PrefireSnapshot(preview, testName: testName, device: preview.device.flatMap { DeviceConfig.named($0.rawValue) } ?? device)
    }

    /// `snapshot` once for each of `devices`, named after the device, or `snapshot` itself when
    /// there are none.
    @MainActor
    public func variants<Content: View>(of snapshot: PrefireSnapshot<Content>) -> [PrefireSnapshot<Content>] {
        namedVariants(of: snapshot).map(\.snapshot)
    }

    /// `variants(of:)`, with the name of the device each one is on.
    ///
    /// The devices `render` asks for are rendered as they are, with their safe area and display
    /// scale, since nothing is compared with references recorded elsewhere.
    @MainActor
    private func namedVariants<Content: View>(of snapshot: PrefireSnapshot<Content>) -> [(device: String?, snapshot: PrefireSnapshot<Content>)] {
        #if os(iOS) || os(tvOS)
        let renderDevices = render?.devices ?? []
        let deviceNames = renderDevices.isEmpty ? devices : renderDevices
        let renderTraits = render?.traits

        guard !deviceNames.isEmpty else {
            var variant = snapshot
            if let renderTraits {
                variant.traits = UITraitCollection(traitsFrom: [variant.traits, renderTraits])
            }
            return [(nil, variant)]
        }

        return deviceNames.map { deviceName in
            guard let device = DeviceConfig.named(deviceName) else {
                fatalError("Unknown device name from configuration file: \(deviceName). Supported devices: \(DeviceConfig.supportedNames.joined(separator: ", "))")
            }

            var variant = snapshot
            variant.name = "\(snapshot.name)-\(deviceName)"
            variant.device = device
            if renderDevices.isEmpty {
                // Ignore specific device safe area
                variant.device.safeArea = .zero
                // Ignore specific device display scale
                variant.traits = UITraitCollection(displayScale: 2.0)
            }
            if let renderTraits {
                variant.traits = UITraitCollection(traitsFrom: [variant.traits, renderTraits])
            }
            return (deviceName, variant)
        }
        #else
        var variant = snapshot
        #if os(macOS)
        variant.renderOptions = render
        #endif
        return [(nil, variant)]
        #endif
    }

    /// Captures every variant of `snapshot` and compares it with `verify`.
    ///
    /// - Parameter verify: Compares a capture with its reference, returning why it does not match.
    /// - Returns: Why variants failed: the message of `verify`, or of a wait that timed out.
    @MainActor
    public func failures<Content: View>(
        of snapshot: PrefireSnapshot<Content>,
        verify: (PrefireSnapshotCapture) -> String?
    ) -> [String] {
        if let render {
            PrefireRenderWriter.markRun(options: render)
            guard render.includes(snapshot.name) else { return [] }
            return namedVariants(of: snapshot).compactMap { device, variant in
                renderSnapshot(variant, device: device, options: render)
            }
        }

        return variants(of: snapshot).compactMap { variant -> String? in
            do throws(SnapshotWaitTimeout) {
                return verify(try capture(variant))
            } catch {
                return error.message
            }
        }
    }

    /// Renders `snapshot`, waiting for it when it asks for it, and tells how to compare the result.
    ///
    /// Waiting runs the main run loop in place: call it from a synchronous test method.
    ///
    /// - Throws: `SnapshotWaitTimeout` when the preview did not get ready in time.
    @MainActor
    public func capture<Content: View>(_ snapshot: PrefireSnapshot<Content>) throws(SnapshotWaitTimeout) -> PrefireSnapshotCapture {
        #if os(iOS) || os(tvOS)
        let (view, preferences) = snapshot.loadViewWithPreferences(
            drawHierarchyInKeyWindow: drawHierarchyInKeyWindow,
            fullPage: fullPage,
            waitDefaults: waitDefaults
        )

        var capture: PrefireSnapshotCapture
        var fullPageHeight: CGFloat?

        switch preferences.waitResult {
        case let .timedOut(message):
            throw SnapshotWaitTimeout(message: message)
        case let .settled(image):
            // Compared as captured where it settled: a snapshot strategy would host the preview in a
            // window of its own and start it over.
            capture = PrefireSnapshotCapture(name: snapshot.name, view: view, comparison: .image(image), preferences: preferences)
            fullPageHeight = image.size.height
        case nil:
            let device = fullPage ? snapshot.fullPageDevice(delay: preferences.delay) : snapshot.device
            capture = PrefireSnapshotCapture(
                name: snapshot.name,
                view: view,
                comparison: .view(layout: snapshot.isScreen ? device : nil),
                preferences: preferences
            )
            fullPageHeight = device.size?.height
        }

        capture.traits = snapshot.traits
        capture.accessibilityHeight = fullPage && snapshot.isScreen ? fullPageHeight : nil
        return capture
        #elseif os(macOS)
        let (view, preferences) = snapshot.loadViewWithPreferences(waitDefaults: waitDefaults)

        if case let .timedOut(message) = preferences.waitResult {
            throw SnapshotWaitTimeout(message: message)
        }

        var capture = PrefireSnapshotCapture(name: snapshot.name, view: view, comparison: .view(size: snapshot.device.size), preferences: preferences)
        // A preview that was waited on has spent its delay already.
        if preferences.waitResult != nil {
            capture.delay = 0
        }
        return capture
        #endif
    }

    /// Renders `snapshot` into `options.directory`, next to a record of it.
    ///
    /// - Returns: Why it could not be rendered, or `nil`.
    @MainActor
    private func renderSnapshot<Content: View>(_ snapshot: PrefireSnapshot<Content>, device: String?, options: PrefireRenderOptions) -> String? {
        var record = PrefireRenderRecord(
            runID: options.runID,
            name: snapshot.name,
            device: device,
            colorScheme: options.colorScheme,
            dynamicType: options.dynamicType,
            isScreen: snapshot.isScreen
        )
        var png: Data?

        do throws(SnapshotWaitTimeout) {
            let capture = try capture(snapshot)
            record.userStory = capture.userStory
            record.state = capture.state

            #if os(iOS) || os(tvOS)
            let image: UIImage
            switch capture.comparison {
            case let .image(captured):
                image = captured
            case let .view(layout):
                let canvas = SnapshotCanvas(
                    view: capture.view,
                    isScreen: layout != nil,
                    device: layout ?? snapshot.device,
                    traits: capture.traits,
                    drawHierarchyInKeyWindow: drawHierarchyInKeyWindow
                )
                defer { canvas.dispose() }
                if capture.delay > 0 {
                    RunLoop.main.run(until: Date(timeIntervalSinceNow: capture.delay))
                }
                image = canvas.capture()
            }
            png = image.pngData()
            record.width = Double(image.size.width)
            record.height = Double(image.size.height)
            record.scale = Double(image.scale)
            #elseif os(macOS)
            if capture.delay > 0 {
                RunLoop.main.run(until: Date(timeIntervalSinceNow: capture.delay))
            }
            let size: CGSize?
            switch capture.comparison {
            case let .view(comparedSize):
                size = comparedSize
            }
            png = prefireRenderPNG(of: capture.view, size: size)
            let renderedSize = size ?? capture.view.bounds.size
            record.width = Double(renderedSize.width)
            record.height = Double(renderedSize.height)
            record.scale = Double(snapshot.device.scale)
            #endif

            if png == nil {
                record.error = "Prefire could not render \(snapshot.name): the preview has no size."
            }
        } catch {
            record.error = error.message
        }

        return PrefireRenderWriter.write(png: png, record: record, options: options) ?? record.error
    }
}

/// A rendered preview, and how SnapshotTesting compares it.
public struct PrefireSnapshotCapture {
    public enum Comparison {
        #if os(iOS) || os(tvOS)
        /// The preview settled where it was waited on: compare this image as it is.
        case image(UIImage)
        /// Snapshot `view` on this canvas, or at the size that fits it when `nil`.
        case view(layout: DeviceConfig?)
        #elseif os(macOS)
        /// Snapshot `view` at this size, or at the size that fits it when `nil`.
        case view(size: CGSize?)
        #endif
    }

    /// Name of the reference image.
    public let name: String

    /// The preview, as SnapshotTesting takes it.
    public let view: PrefireSnapshotView

    public let comparison: Comparison

    /// The percentage of pixels that must match.
    public let precision: Float

    /// The percentage a pixel must match the source pixel to be considered a match.
    public let perceptualPrecision: Float

    /// Whether to record the reference anew.
    public let record: Bool

    /// Time to let `view` settle before snapshotting it.
    public internal(set) var delay: TimeInterval

    /// `previewUserStory(_:)` of the preview.
    public let userStory: PreviewModel.UserStory?

    /// `previewState(_:)` of the preview.
    public let state: PreviewModel.State?

    #if os(iOS) || os(tvOS)
    public internal(set) var traits = UITraitCollection()

    /// Height of a full page, which the accessibility snapshot is taken at.
    var accessibilityHeight: CGFloat?
    #endif

    init(name: String, view: PrefireSnapshotView, comparison: Comparison, preferences: PreferenceKeys) {
        self.name = name
        self.view = view
        self.comparison = comparison
        precision = preferences.precision
        perceptualPrecision = preferences.perceptualPrecision
        record = preferences.record
        delay = preferences.delay
        userStory = preferences.userStory
        state = preferences.state
    }

    #if os(iOS) || os(tvOS)
    /// `view` hosted on the screen, for an accessibility snapshot.
    ///
    /// Renders the preview anew, so a preview that is waited on is captured as it starts, after `delay`.
    @MainActor
    public func accessibilityController() -> UIViewController {
        let controller = UIHostingController(rootView: view)
        controller.view.frame = UIScreen.main.bounds
        if let accessibilityHeight {
            controller.view.frame.size.height = accessibilityHeight
        }
        return controller
    }
    #endif
}
#endif
