import Foundation

#if os(iOS) || os(tvOS)
import UIKit

/// View the wait observes: the hosting controller's view on iOS/tvOS, the hosting `NSView` on macOS.
typealias SnapshotWaitView = UIView
#elseif os(macOS)
import AppKit

/// View the wait observes: the hosting controller's view on iOS/tvOS, the hosting `NSView` on macOS.
typealias SnapshotWaitView = NSView
#endif

#if os(iOS) || os(tvOS) || os(macOS)
/// Keeps a preview rendering until it is ready to be captured.
@MainActor
enum SnapshotWaiter {
    /// Minimum time between two checks. Also the minimum distance between two compared frames.
    static let pollInterval: TimeInterval = 0.05

    /// How many times in a row a frame has to repeat itself to count as idle.
    static let requiredStableFrames = 2

    /// Waits for `preferences.resolvedWait`, spending `delay` first.
    ///
    /// A timeout is reported through `preferences.waitFailure` instead of an assertion,
    /// so the generated test decides how to fail.
    ///
    /// - Parameter layout: Called before every frame is compared, to let a canvas that is sized to
    ///                     fit its content follow it.
    static func wait(
        for preferences: PreferenceKeys,
        in view: SnapshotWaitView,
        name: String,
        layout: () -> Void = {}
    ) {
        guard let wait = preferences.resolvedWait else { return }

        let timeout = preferences.resolvedTimeout

        // `delay` is the floor of the wait: a preview that only starts working after it would
        // otherwise look idle right away. The timeout covers the checks that follow it.
        spinRunLoop(for: preferences.delay)

        switch wait {
        case .idle:
            var previousFrame: Data?
            var stableFrames = 0

            let isIdle = poll(timeout: timeout) {
                layout()

                let frame = frameData(of: view)
                defer { previousFrame = frame }

                guard frame == previousFrame else {
                    stableFrames = 0
                    return false
                }

                stableFrames += 1
                return stableFrames >= requiredStableFrames
            }

            if !isIdle {
                preferences.waitFailure = """
                Prefire: "\(name)" never stopped changing within \(formatted(timeout))s. \
                Raise the timeout of `.snapshot(waitForIdle:timeout:)`, \
                or use `.snapshot(delay:)` if the preview animates continuously.
                """
            }
        case let .condition(id, condition):
            if !poll(timeout: timeout, until: condition) {
                preferences.waitFailure = """
                Prefire: the condition of "\(name)" (\(id)) was still false after \(formatted(timeout))s. \
                Raise the timeout of `.snapshotWait(until:timeout:)`, \
                or check that the preview reaches the expected state.
                """
            }
        case .disabled:
            // Never returned by `resolvedWait`.
            break
        }
    }

    // MARK: - Private functions

    /// Checks `condition`, spinning the main run loop between attempts so the preview keeps rendering.
    private static func poll(timeout: TimeInterval, until condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(max(timeout, 0))

        while true {
            if condition() { return true }
            guard Date() < deadline else { return false }

            spinRunLoop(for: pollInterval)
        }
    }

    private static func spinRunLoop(for interval: TimeInterval) {
        let deadline = Date().addingTimeInterval(interval)

        while Date() < deadline {
            RunLoop.main.run(mode: .default, before: deadline)
        }
    }

    /// Pixels of `view`, compared as is: encoding them would cost more than the comparison.
    private static func frameData(of view: SnapshotWaitView) -> Data {
        #if os(iOS) || os(tvOS)
        view.layoutIfNeeded()

        // Scale 1 is enough to spot changes and keeps the comparison cheap.
        let width = Int(view.bounds.width.rounded(.up))
        let height = Int(view.bounds.height.rounded(.up))

        guard width > 0, height > 0, let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return Data() }

        view.layer.render(in: context)

        guard let pixels = context.data else { return Data() }
        return Data(bytes: pixels, count: context.bytesPerRow * height)
        #elseif os(macOS)
        view.layoutSubtreeIfNeeded()

        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0,
              let representation = view.bitmapImageRepForCachingDisplay(in: bounds) else { return Data() }
        view.cacheDisplay(in: bounds, to: representation)

        guard let pixels = representation.bitmapData else { return Data() }
        return Data(bytes: pixels, count: representation.bytesPerRow * representation.pixelsHigh)
        #endif
    }

    private static func formatted(_ timeout: TimeInterval) -> String {
        String(format: "%g", timeout)
    }
}
#endif
