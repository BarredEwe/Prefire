import Foundation

#if os(iOS) || os(tvOS) || os(macOS)
/// Keeps a preview rendering until it is ready to be captured.
///
/// Waiting runs the main run loop in place, so it has to be called from synchronous code: called
/// from a task on the main actor, such as an `async` test, the main queue is not served meanwhile,
/// and `.task` and other main actor work of the preview never run.
@MainActor
enum SnapshotWaiter {
    /// Minimum time between two checks.
    static let pollInterval: TimeInterval = 0.05

    /// How long the frame has to stay the same to count as idle. Long enough to cover a short gap
    /// between two steps of loading, short enough not to slow the snapshots down much.
    static let quietTime: TimeInterval = 0.3

    /// What a preview is waited for, once the project wide defaults are applied.
    enum Wait {
        case idle
        case conditions([SnapshotWaitCondition])
    }

    /// What `wait` asks for, given the project wide `defaults`, with its time limit, or `nil` when the
    /// preview is captured right away.
    static func resolve(_ wait: SnapshotWait?, defaults: SnapshotWaitDefaults) -> (wait: Wait, timeout: TimeInterval)? {
        switch wait {
        case nil:
            defaults.waitForIdle ? (.idle, defaults.timeout) : nil
        case let .idle(timeout):
            (.idle, timeout ?? defaults.timeout)
        case let .conditions(conditions, timeout):
            (.conditions(conditions), timeout ?? defaults.timeout)
        case .disabled:
            nil
        }
    }

    /// Spends `delay`, then renders until `wait` is over.
    ///
    /// - Parameters:
    ///   - delay: Floor of the wait: a preview that only starts working after it would otherwise
    ///            look idle right away. `timeout` covers the checks that follow it.
    ///   - frame: The preview's pixels, rendered the way it is captured.
    ///   - layout: Called before every check and once the wait is over, to let a canvas that is
    ///             sized to fit its content follow it.
    /// - Returns: Why the preview was not ready in time, or `nil` when it was.
    static func wait(
        for wait: Wait,
        timeout: TimeInterval,
        delay: TimeInterval,
        name: String,
        frame: () -> Data,
        layout: () -> Void
    ) -> String? {
        spinRunLoop(for: delay)

        switch wait {
        case .idle:
            var lastFrame: Data?
            var unchangedSince = now

            let isIdle = poll(timeout: timeout) {
                layout()

                let current = frame()
                guard current == lastFrame else {
                    lastFrame = current
                    unchangedSince = now
                    return false
                }
                return now - unchangedSince >= quietTime
            }

            guard isIdle else {
                return failure("""
                Prefire: "\(name)" never stopped changing within \(formatted(timeout))s. \
                Raise the timeout of `.snapshot(waitForIdle:timeout:)`, \
                or use `.snapshot(delay:)` if the preview animates continuously.
                """)
            }
            return nil
        case let .conditions(conditions):
            let isMet = poll(timeout: timeout) {
                layout()
                return conditions.allSatisfy { $0.isMet() }
            }

            guard isMet else {
                let locations = conditions.filter { !$0.isMet() }.map(\.location).joined(separator: ", ")
                return failure("""
                Prefire: the condition of "\(name)" (\(locations)) was still false after \(formatted(timeout))s. \
                Raise the timeout of `.snapshot(waitUntil:timeout:)`, \
                or check that the preview reaches the expected state.
                """)
            }

            // The state the conditions saw is drawn on a later pass of the run loop.
            spinRunLoop(for: pollInterval)
            layout()
            return nil
        }
    }

    // MARK: - Private functions

    /// Monotonic, unlike `Date`, so a clock change during a test does not move the deadlines.
    private static var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    /// Checks `condition`, spinning the main run loop between attempts so the preview keeps rendering.
    private static func poll(timeout: TimeInterval, until condition: () -> Bool) -> Bool {
        let deadline = now + max(timeout, 0)

        while true {
            if condition() { return true }
            guard now < deadline else { return false }

            spinRunLoop(for: pollInterval)
        }
    }

    private static func spinRunLoop(for interval: TimeInterval) {
        let deadline = now + interval

        while now < deadline {
            RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: deadline - now))
        }
    }

    /// `message`, explaining why nothing happened when the wait was called from asynchronous code.
    private static func failure(_ message: String) -> String {
        let isInTask = withUnsafeCurrentTask { $0 != nil }
        guard isInTask else { return message }

        return message + """
         The snapshot was taken from asynchronous code, where the main queue is not served while \
        Prefire waits, so `.task` and other main actor work of the preview do not run: take it from \
        a synchronous test method.
        """
    }

    private static func formatted(_ timeout: TimeInterval) -> String {
        String(format: "%g", timeout)
    }
}
#endif
