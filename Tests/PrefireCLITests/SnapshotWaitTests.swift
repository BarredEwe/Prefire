#if os(macOS)
import Prefire
import SwiftUI
import XCTest

/// Waiting is exercised on macOS, where the view Prefire waits on is the one being captured.
@MainActor
final class SnapshotWaitTests: XCTestCase {
    override func tearDown() {
        SnapshotWaitDefaults.reset()
        super.tearDown()
    }

    func testPreviewWithoutWaitIsCapturedImmediately() {
        let start = Date()
        let (_, preferences) = snapshot { Ticking(interval: 0.01).snapshot(delay: 0.3) }.loadViewWithPreferences()

        XCTAssertNil(preferences.wait)
        XCTAssertNil(preferences.waitFailure)
        XCTAssertEqual(preferences.delay, 0.3)
        XCTAssertEqual(preferences.resolvedDelay, 0.3)
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.3)
    }

    func testWaitForIdleReadsPreferences() {
        let (_, preferences) = snapshot { Text("Prefire").snapshot(waitForIdle: true, timeout: 2) }.loadViewWithPreferences()

        XCTAssertEqual(preferences.wait, .idle)
        XCTAssertEqual(preferences.waitTimeout, 2)
        XCTAssertEqual(preferences.resolvedTimeout, 2)
        XCTAssertNil(preferences.waitFailure)
    }

    /// A preview that keeps changing is captured once it stops, not after a fixed delay.
    func testWaitForIdleReturnsWhenPreviewStopsChanging() {
        let start = Date()
        let (_, preferences) = snapshot { Ticking(interval: 0.02, ticks: 10).snapshot(waitForIdle: true, timeout: 5) }
            .loadViewWithPreferences()

        XCTAssertNil(preferences.waitFailure)
        XCTAssertGreaterThan(Date().timeIntervalSince(start), 0.2)
    }

    func testWaitForIdleFailsWithTimeoutMessage() throws {
        let (_, preferences) = snapshot { Ticking(interval: 0.01).snapshot(waitForIdle: true, timeout: 0.3) }
            .loadViewWithPreferences()

        let failure = try XCTUnwrap(preferences.waitFailure)
        XCTAssertTrue(failure.contains("\"Endless\""), failure)
        XCTAssertTrue(failure.contains("never stopped changing within 0.3s"), failure)
    }

    /// `delay` is the floor of the wait: work starting after it is still waited for.
    func testDelayIsSpentBeforeFramesAreCompared() {
        let start = Date()
        let (_, preferences) = snapshot {
            Ticking(interval: 0.02, ticks: 10, startsAfter: 0.25)
                .snapshot(delay: 0.3)
                .snapshot(waitForIdle: true, timeout: 5)
        }.loadViewWithPreferences()

        XCTAssertNil(preferences.waitFailure)
        // Without the floor the preview looks idle after ~0.1s, before it starts changing at 0.25s.
        XCTAssertGreaterThan(Date().timeIntervalSince(start), 0.45)
        // The delay was spent on the view being captured, so the strategy must not spend it again.
        XCTAssertTrue(preferences.isDelayApplied)
        XCTAssertEqual(preferences.resolvedDelay, 0)
    }

    func testTimeoutFallsBackToProjectWideDefault() {
        SnapshotWaitDefaults.timeout = 0.3

        let (_, preferences) = snapshot { Text("Prefire").snapshot(waitForIdle: true) }.loadViewWithPreferences()

        XCTAssertNil(preferences.waitTimeout)
        XCTAssertEqual(preferences.resolvedTimeout, 0.3)
    }

    /// An explicit timeout is used as is, even `0`, rather than being taken for "not set".
    func testExplicitZeroTimeoutIsNotReplacedByDefault() throws {
        let (_, preferences) = snapshot { Text("Prefire").snapshotWait(until: { false }, timeout: 0) }
            .loadViewWithPreferences()

        XCTAssertEqual(preferences.resolvedTimeout, 0)
        let failure = try XCTUnwrap(preferences.waitFailure)
        XCTAssertTrue(failure.contains("was still false after 0s"), failure)
    }

    func testDefaultsAreRestoredForEverySuite() {
        SnapshotWaitDefaults.waitForIdle = true
        SnapshotWaitDefaults.timeout = 0.3

        SnapshotWaitDefaults.reset()

        XCTAssertFalse(SnapshotWaitDefaults.waitForIdle)
        XCTAssertEqual(SnapshotWaitDefaults.timeout, 5)
    }

    func testWaitUntilConditionReturnsWhenConditionIsMet() {
        let deadline = Date().addingTimeInterval(0.2)
        let (_, preferences) = snapshot { Text("Prefire").snapshotWait(until: { Date() >= deadline }, timeout: 5) }
            .loadViewWithPreferences()

        XCTAssertNil(preferences.waitFailure)
        XCTAssertGreaterThanOrEqual(Date(), deadline)
    }

    func testWaitUntilConditionFailsWithTimeoutMessage() throws {
        let (_, preferences) = snapshot { Text("Prefire").snapshotWait(until: { false }, timeout: 0.2) }
            .loadViewWithPreferences()

        let failure = try XCTUnwrap(preferences.waitFailure)
        XCTAssertTrue(failure.contains("was still false after 0.2s"), failure)
        // The call site of the modifier is part of the message.
        XCTAssertTrue(failure.contains("SnapshotWaitTests.swift:"), failure)
    }

    func testProjectWideDefaultsAreUsedWhenPreviewDoesNotWait() {
        SnapshotWaitDefaults.waitForIdle = true
        SnapshotWaitDefaults.timeout = 0.3

        let (_, preferences) = snapshot { Ticking(interval: 0.01) }.loadViewWithPreferences()

        XCTAssertNil(preferences.wait)
        XCTAssertEqual(preferences.resolvedWait, .idle)
        XCTAssertEqual(preferences.resolvedTimeout, 0.3)
        XCTAssertNotNil(preferences.waitFailure)
    }

    func testPreviewPreferenceWinsOverProjectWideDefault() {
        SnapshotWaitDefaults.waitForIdle = true

        let (_, preferences) = snapshot { Ticking(interval: 0.01).snapshot(waitForIdle: false) }.loadViewWithPreferences()

        XCTAssertNil(preferences.resolvedWait)
        XCTAssertNil(preferences.waitFailure)
    }

    /// A canvas that fits the content follows it while it loads, instead of keeping its first size.
    func testCanvasFittingContentGrowsWithItWhileWaitingForIdle() {
        let (view, preferences) = PrefireSnapshot(
            { Growing(model: GrowingModel()).snapshot(waitForIdle: true, timeout: 3) },
            name: "Growing",
            isScreen: false,
            device: DeviceConfig()
        ).loadViewWithPreferences()

        XCTAssertNil(preferences.waitFailure)
        XCTAssertEqual(view.frame.height, GrowingModel.loadedHeight)
    }

    func testCanvasFittingContentGrowsWithItWhileWaitingForCondition() {
        let (view, preferences) = PrefireSnapshot(
            {
                let model = GrowingModel()
                Growing(model: model).snapshotWait(until: { model.isLoaded }, timeout: 3)
            },
            name: "Growing",
            isScreen: false,
            device: DeviceConfig()
        ).loadViewWithPreferences()

        XCTAssertNil(preferences.waitFailure)
        XCTAssertEqual(view.frame.height, GrowingModel.loadedHeight)
    }

    // MARK: Private

    private func snapshot(@ViewBuilder _ view: @escaping @MainActor () -> some View) -> PrefireSnapshot<some View> {
        PrefireSnapshot(view, name: "Endless", isScreen: false, device: DeviceConfig(size: CGSize(width: 120, height: 40)))
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
