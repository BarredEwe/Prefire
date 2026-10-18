#if os(macOS)
import Prefire
import SwiftUI
import XCTest

/// Waiting is exercised on macOS, where the view Prefire waits on is the one being captured.
@MainActor
final class SnapshotWaitTests: XCTestCase {
    func testPreviewWithoutWaitIsCapturedImmediately() {
        let start = Date()
        let (_, preferences) = snapshot { Ticking(interval: 0.01).snapshot(delay: 0.3) }.loadViewWithPreferences()

        XCTAssertNil(preferences.waitResult)
        XCTAssertEqual(preferences.delay, 0.3)
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.3)
    }

    /// A preview that keeps changing is captured once it stops, not after a fixed delay.
    func testWaitForIdleReturnsWhenPreviewStopsChanging() {
        let start = Date()
        let (_, preferences) = snapshot { Ticking(interval: 0.02, ticks: 10).snapshot(waitForIdle: true, timeout: 5) }
            .loadViewWithPreferences()

        XCTAssertTrue(preferences.isSettled)
        // It changes for 0.2s, then has to stay the same for 0.3s.
        XCTAssertGreaterThan(Date().timeIntervalSince(start), 0.5)
        XCTAssertLessThan(Date().timeIntervalSince(start), 2)
    }

    func testWaitForIdleFailsWithTimeoutMessage() throws {
        let (_, preferences) = snapshot { Ticking(interval: 0.01).snapshot(waitForIdle: true, timeout: 0.3) }
            .loadViewWithPreferences()

        let failure = try XCTUnwrap(preferences.failure)
        XCTAssertTrue(failure.contains("\"Endless\""), failure)
        XCTAssertTrue(failure.contains("never stopped changing within 0.3s"), failure)
        XCTAssertFalse(failure.contains("asynchronous code"), failure)
    }

    /// `delay` is the floor of the wait: work starting after it is still waited for.
    func testDelayIsSpentBeforeFramesAreCompared() {
        let start = Date()
        let (_, preferences) = snapshot {
            Ticking(interval: 0.02, ticks: 10, startsAfter: 0.5)
                .snapshot(delay: 0.6)
                .snapshot(waitForIdle: true, timeout: 5)
        }.loadViewWithPreferences()

        XCTAssertTrue(preferences.isSettled)
        // Without the floor the preview looks idle after 0.3s, before it starts changing at 0.5s. With
        // it, it changes until 0.7s and is idle 0.3s later.
        XCTAssertGreaterThan(Date().timeIntervalSince(start), 0.95)
    }

    func testTimeoutFallsBackToProjectWideDefault() throws {
        let (_, preferences) = snapshot { Ticking(interval: 0.01).snapshot(waitForIdle: true) }
            .loadViewWithPreferences(waitDefaults: SnapshotWaitDefaults(timeout: 0.3))

        let failure = try XCTUnwrap(preferences.failure)
        XCTAssertTrue(failure.contains("within 0.3s"), failure)
    }

    /// An explicit timeout is used as is, even `0`, rather than being taken for "not set".
    func testExplicitZeroTimeoutIsNotReplacedByDefault() throws {
        let (_, preferences) = snapshot { Text("Prefire").snapshot(waitUntil: { false }, timeout: 0) }
            .loadViewWithPreferences()

        let failure = try XCTUnwrap(preferences.failure)
        XCTAssertTrue(failure.contains("was still false after 0s"), failure)
    }

    func testWaitUntilConditionReturnsWhenConditionIsMet() {
        let deadline = Date().addingTimeInterval(0.2)
        let (_, preferences) = snapshot { Text("Prefire").snapshot(waitUntil: { Date() >= deadline }, timeout: 5) }
            .loadViewWithPreferences()

        XCTAssertTrue(preferences.isSettled)
        XCTAssertGreaterThanOrEqual(Date(), deadline)
    }

    func testWaitUntilConditionFailsWithTimeoutMessage() throws {
        let (_, preferences) = snapshot { Text("Prefire").snapshot(waitUntil: { false }, timeout: 0.2) }
            .loadViewWithPreferences()

        let failure = try XCTUnwrap(preferences.failure)
        XCTAssertTrue(failure.contains("was still false after 0.2s"), failure)
        // The call site of the modifier is part of the message.
        XCTAssertTrue(failure.contains("SnapshotWaitTests.swift:"), failure)
    }

    func testProjectWideDefaultsAreUsedWhenPreviewDoesNotWait() throws {
        let (_, preferences) = snapshot { Ticking(interval: 0.01) }
            .loadViewWithPreferences(waitDefaults: SnapshotWaitDefaults(waitForIdle: true, timeout: 0.3))

        let failure = try XCTUnwrap(preferences.failure)
        XCTAssertTrue(failure.contains("within 0.3s"), failure)
    }

    func testPreviewPreferenceWinsOverProjectWideDefault() {
        let (_, preferences) = snapshot { Ticking(interval: 0.01).snapshot(waitForIdle: false) }
            .loadViewWithPreferences(waitDefaults: SnapshotWaitDefaults(waitForIdle: true))

        XCTAssertNil(preferences.waitResult)
    }

    // MARK: Waits of several views

    /// A condition says when the preview is ready, so it is waited for over idle.
    func testConditionOfOneViewWinsOverIdleOfAnother() {
        let (_, preferences) = snapshot {
            VStack {
                Ticking(interval: 0.01).snapshot(waitForIdle: true, timeout: 0.3)
                Text("Ready").snapshot(waitUntil: { true })
            }
        }.loadViewWithPreferences()

        XCTAssertTrue(preferences.isSettled)
    }

    /// Opting a view out does not cancel what another view of the preview waits for.
    func testOptOutOfOneViewKeepsTheWaitOfAnother() {
        let deadline = Date().addingTimeInterval(0.2)
        let (_, preferences) = snapshot {
            VStack {
                Text("Loading").snapshot(waitUntil: { Date() >= deadline }, timeout: 5)
                Text("Static").snapshot(waitForIdle: false)
            }
        }.loadViewWithPreferences()

        XCTAssertTrue(preferences.isSettled)
        XCTAssertGreaterThanOrEqual(Date(), deadline)
    }

    /// A view that does not set a timeout does not take away the one another view set.
    func testTimeoutOfOneViewIsKeptWhenAnotherSetsNone() throws {
        let (_, preferences) = snapshot {
            VStack {
                Ticking(interval: 0.01).snapshot(waitForIdle: true, timeout: 0.3)
                Text("Static").snapshot(waitForIdle: true)
            }
        }.loadViewWithPreferences()

        let failure = try XCTUnwrap(preferences.failure)
        XCTAssertTrue(failure.contains("within 0.3s"), failure)
    }

    func testEveryConditionHasToBeMet() throws {
        let (_, preferences) = snapshot {
            VStack {
                Text("Ready").snapshot(waitUntil: { true })
                Text("Never").snapshot(waitUntil: { false }, timeout: 0.2)
            }
        }.loadViewWithPreferences()

        let failure = try XCTUnwrap(preferences.failure)
        // Only the condition that is still false is named.
        XCTAssertEqual(failure.components(separatedBy: "SnapshotWaitTests.swift:").count, 2, failure)
    }

    // MARK: Asynchronous code

    /// From a task, the main queue is not served while the run loop is spun, so `.task` never runs.
    func testTimeoutFromAsynchronousCodeExplainsWhy() async throws {
        let (_, preferences) = snapshot { Text("Prefire").snapshot(waitUntil: { false }, timeout: 0.1) }
            .loadViewWithPreferences()

        let failure = try XCTUnwrap(preferences.failure)
        XCTAssertTrue(failure.contains("asynchronous code"), failure)
    }

    // MARK: Canvas size

    /// A canvas that fits the content follows it while it loads, instead of keeping its first size.
    func testCanvasFittingContentGrowsWithItWhileWaitingForIdle() {
        let (view, preferences) = PrefireSnapshot(
            { Growing(model: GrowingModel()).snapshot(waitForIdle: true, timeout: 3) },
            name: "Growing",
            isScreen: false,
            device: DeviceConfig()
        ).loadViewWithPreferences()

        XCTAssertTrue(preferences.isSettled)
        XCTAssertEqual(view.frame.height, GrowingModel.loadedHeight)
    }

    func testCanvasFittingContentGrowsWithItWhileWaitingForCondition() {
        let (view, preferences) = PrefireSnapshot(
            {
                let model = GrowingModel()
                Growing(model: model).snapshot(waitUntil: { model.isLoaded }, timeout: 3)
            },
            name: "Growing",
            isScreen: false,
            device: DeviceConfig()
        ).loadViewWithPreferences()

        XCTAssertTrue(preferences.isSettled)
        XCTAssertEqual(view.frame.height, GrowingModel.loadedHeight)
    }

    // MARK: Private

    private func snapshot(@ViewBuilder _ view: @escaping @MainActor () -> some View) -> PrefireSnapshot<some View> {
        PrefireSnapshot(view, name: "Endless", isScreen: false, device: DeviceConfig(size: CGSize(width: 120, height: 40)))
    }
}

private extension PreferenceKeys {
    var isSettled: Bool {
        if case .settled = waitResult { true } else { false }
    }

    var failure: String? {
        if case let .timedOut(message) = waitResult { message } else { nil }
    }
}

/// Redraws itself on a timer, so consecutive frames differ until `ticks` is reached.
private struct Ticking: View {
    let interval: TimeInterval
    var ticks: Int = .max
    var startsAfter: TimeInterval = 0

    @State private var tick = 0
    @State private var isStarted = false

    var body: some View {
        Text("tick \(tick)")
            .onReceive(Timer.publish(every: interval, on: .main, in: .common).autoconnect()) { _ in
                guard isStarted, tick < ticks else { return }
                tick += 1
            }
            .task {
                try? await Task.sleep(nanoseconds: UInt64(startsAfter * 1_000_000_000))
                isStarted = true
            }
    }
}

/// Grows in steps once loading starts, faster than frames are compared, until it is loaded.
@MainActor
private final class GrowingModel: ObservableObject {
    static let loadedHeight: CGFloat = 200

    @Published private(set) var height: CGFloat = 20

    var isLoaded: Bool { height == Self.loadedHeight }

    func load() async {
        for step in 1...6 {
            try? await Task.sleep(nanoseconds: 30_000_000)
            height = 20 + CGFloat(step) * 30
        }
    }
}

/// Short at first, then as tall as what `model` loads in `.task`.
private struct Growing: View {
    @ObservedObject var model: GrowingModel

    var body: some View {
        Color.red
            .frame(width: 100, height: model.height)
            .task { await model.load() }
    }
}
#endif
