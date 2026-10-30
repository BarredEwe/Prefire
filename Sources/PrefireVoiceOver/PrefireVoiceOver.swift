#if os(iOS) && canImport(XCTest)
import Prefire
import UIKit

@MainActor
extension PrefireSnapshotCapture {
    /// Renders and reads a preview after enabling accessibility automation and waiting for stable text.
    /// Legal empty or redacted previews return an empty transcript. Changing text throws on timeout.
    /// `accessibilityImage` can snapshot the same host after reading, without another render or delay.
    ///
    /// - Parameter elements: What VoiceOver focuses in the hosted view, in any order. The generated
    ///   tests parse it with `AccessibilityHierarchyParser` of AccessibilitySnapshot, so this module
    ///   does not depend on that package.
    public func voiceOverTranscript(
        elements: (UIView) -> [VoiceOverTranscript.Element],
        timeout: TimeInterval = SnapshotWaitDefaults().timeout,
        accessibilityImage: ((UIViewController) throws -> Void)? = nil
    ) throws -> String {
        try readVoiceOver(timeout: timeout, accessibilityImage: accessibilityImage) { view in
            VoiceOverTranscript.text(of: elements(view))
        }
    }

    func readVoiceOver<Value: Equatable>(
        timeout: TimeInterval = SnapshotWaitDefaults().timeout,
        accessibilityImage: ((UIViewController) throws -> Void)? = nil,
        _ read: (UIView) -> Value
    ) throws -> Value {
        try enableVoiceOverAutomation()
        let controller = accessibilityController()
        let window = UIWindow(frame: controller.view.frame)
        window.rootViewController = controller
        window.isHidden = false
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        controller.view.layoutIfNeeded()
        // SwiftUI builds its accessibility elements on a later pass of the run loop than the layout.
        spinRunLoop(for: max(delay, 0.05))
        controller.view.layoutIfNeeded()

        let deadline = ProcessInfo.processInfo.systemUptime + max(timeout, 0)
        var last = read(controller.view)
        while ProcessInfo.processInfo.systemUptime < deadline {
            spinRunLoop(for: 0.05)
            controller.view.layoutIfNeeded()

            let current = read(controller.view)
            if current == last {
                // AccessibilitySnapshot reparents the view to add overlays; read text before that.
                try accessibilityImage?(controller)
                return current
            }
            last = current
        }
        throw VoiceOverReadError(message: """
        Prefire: what VoiceOver reads in "\(name)" kept changing for \(String(format: "%g", timeout))s. \
        Raise `snapshot_wait_timeout`, or check that the preview stops changing.
        """)
    }
}

/// The parser's Objective-C +load enabler can be stripped from static links. Enable it explicitly
/// before hosting SwiftUI, using the same system automation entry point as AccessibilitySnapshot.
@MainActor
private func enableVoiceOverAutomation() throws {
    let root = ProcessInfo.processInfo.environment["IPHONE_SIMULATOR_ROOT"] ?? ""
    guard let handle = dlopen(root + "/usr/lib/libAccessibility.dylib", RTLD_LOCAL) else {
        throw VoiceOverAutomationError()
    }
    defer { dlclose(handle) }
    guard let symbol = dlsym(handle, "_AXSSetAutomationEnabled") else {
        throw VoiceOverAutomationError()
    }
    unsafeBitCast(symbol, to: (@convention(c) (Int32) -> Void).self)(1)
}

private struct VoiceOverReadError: Error, CustomStringConvertible {
    let message: String
    var description: String {
        message
    }
}

private struct VoiceOverAutomationError: Error, CustomStringConvertible {
    var description: String {
        "Prefire: could not enable accessibility automation for the VoiceOver transcript."
    }
}

@MainActor
private func spinRunLoop(for interval: TimeInterval) {
    let deadline = ProcessInfo.processInfo.systemUptime + interval
    while ProcessInfo.processInfo.systemUptime < deadline {
        let remaining = deadline - ProcessInfo.processInfo.systemUptime
        RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: remaining))
    }
}
#endif
