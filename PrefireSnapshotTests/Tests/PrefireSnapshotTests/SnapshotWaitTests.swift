#if os(iOS)
import Prefire
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

/// Waiting on iOS, where the snapshot strategy would host the preview anew and start it over.
///
/// Every image a wait captures is compared with what `Snapshotting<AnyView, UIImage>.image` renders
/// for a preview already showing the state that was waited for: they have to match pixel for pixel.
@MainActor
final class SnapshotWaitTests: XCTestCase {
    /// Dark, so a trait override that does not reach the preview shows up in the comparison.
    private let traits = UITraitCollection(traitsFrom: [.init(displayScale: 2), .init(userInterfaceStyle: .dark)])

    private var device: DeviceConfig {
        let config = ViewImageConfig.iPhoneX
        return DeviceConfig(safeArea: config.safeArea, size: config.size, traits: config.traits)
    }

    override func tearDown() {
        SnapshotWaitDefaults.reset()
        super.tearDown()
    }

    func testWaitForIdleCapturesStateReachedInTask() throws {
        for isScreen in [false, true] {
            let (_, preferences) = snapshot(isScreen: isScreen) {
                CountingLoader().snapshot(waitForIdle: true, timeout: 3)
            }.loadViewWithPreferences()

            XCTAssertNil(preferences.waitFailure)
            let image = try XCTUnwrap(preferences.settledImage)

            try assertImage(image, matches: Phase("done"), isScreen: isScreen)
            XCTAssertNotNil(diff(image, try reference(Phase("loading"), isScreen: isScreen)))
        }
    }

    /// What the wait protects against: rendered anew, the same preview still shows its first frame.
    func testRenderingPreviewAgainStartsItOver() throws {
        let snapshot = snapshot(isScreen: false) { CountingLoader().snapshot(waitForIdle: true, timeout: 3) }
        let (view, preferences) = snapshot.loadViewWithPreferences()

        XCTAssertNotNil(preferences.settledImage)
        XCTAssertNil(diff(try render(view, isScreen: false), try reference(Phase("loading"), isScreen: false)))
    }

    func testWaitUntilConditionCapturesStateReachedInTask() throws {
        for isScreen in [false, true] {
            let start = Date()
            let (_, preferences) = snapshot(isScreen: isScreen) {
                let viewModel = LoadingViewModel()
                LoadingScreen(viewModel: viewModel).snapshotWait(until: { viewModel.isLoaded }, timeout: 3)
            }.loadViewWithPreferences()

            XCTAssertNil(preferences.waitFailure)
            XCTAssertGreaterThan(Date().timeIntervalSince(start), 0.3, "isScreen: \(isScreen)")
            try assertImage(try XCTUnwrap(preferences.settledImage), matches: Phase("done"), isScreen: isScreen)
        }
    }

    func testProjectWideIdleDefaultCapturesSettledState() throws {
        SnapshotWaitDefaults.waitForIdle = true

        let (_, preferences) = snapshot(isScreen: false) { CountingLoader() }.loadViewWithPreferences()

        XCTAssertNil(preferences.waitFailure)
        try assertImage(try XCTUnwrap(preferences.settledImage), matches: Phase("done"), isScreen: false)
    }

    /// `delay` is spent where the preview is captured, so the strategy has nothing left to wait for.
    func testDelayIsSpentBeforeCapturing() throws {
        let start = Date()
        let (_, preferences) = snapshot(isScreen: false) {
            CountingLoader().snapshot(delay: 0.5).snapshot(waitForIdle: true, timeout: 3)
        }.loadViewWithPreferences()

        XCTAssertGreaterThan(Date().timeIntervalSince(start), 0.5)
        XCTAssertEqual(preferences.resolvedDelay, 0)
        try assertImage(try XCTUnwrap(preferences.settledImage), matches: Phase("done"), isScreen: false)
    }

    func testTimeoutLeavesNothingToCompare() {
        let (_, preferences) = snapshot(isScreen: false) {
            CountingLoader().snapshotWait(until: { false }, timeout: 0.2)
        }.loadViewWithPreferences()

        XCTAssertNotNil(preferences.waitFailure)
        XCTAssertNil(preferences.settledImage)
    }

    /// Previews that do not wait keep being rendered by the snapshot strategy.
    func testPreviewWithoutWaitIsNotCaptured() {
        let (_, preferences) = snapshot(isScreen: false) { CountingLoader() }.loadViewWithPreferences()

        XCTAssertNil(preferences.waitFailure)
        XCTAssertNil(preferences.settledImage)
        XCTAssertFalse(preferences.isDelayApplied)
    }

    // MARK: Private

    private func snapshot(
        isScreen: Bool,
        @ViewBuilder _ view: @escaping @MainActor () -> some View
    ) -> PrefireSnapshot<some View> {
        PrefireSnapshot(view, name: "Loader", isScreen: isScreen, device: device, traits: traits)
    }

    private func assertImage(
        _ image: UIImage,
        matches view: some View,
        isScreen: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let expected = try reference(view, isScreen: isScreen)

        XCTAssertEqual(image.size, expected.size, "isScreen: \(isScreen)", file: file, line: line)
        XCTAssertEqual(image.scale, expected.scale, "isScreen: \(isScreen)", file: file, line: line)
        XCTAssertNil(diff(image, expected), "isScreen: \(isScreen)", file: file, line: line)
    }

    /// `view` rendered the way the generated tests render a preview that does not wait.
    private func reference(_ view: some View, isScreen: Bool) throws -> UIImage {
        let snapshot = PrefireSnapshot({ view }, name: "Reference", isScreen: isScreen, device: device, traits: traits)
        return try render(snapshot.loadViewWithPreferences().0, isScreen: isScreen)
    }

    private func render(_ view: AnyView, isScreen: Bool) throws -> UIImage {
        let strategy: Snapshotting<AnyView, UIImage> = .image(
            layout: isScreen ? .device(config: .iPhoneX) : .sizeThatFits,
            traits: traits
        )

        var image: UIImage?
        strategy.snapshot(view).run { image = $0 }
        return try XCTUnwrap(image)
    }

    private func diff(_ lhs: UIImage, _ rhs: UIImage) -> String? {
        Snapshotting<UIImage, UIImage>.image.diffing.diff(lhs, rhs)?.0
    }
}

/// Counts up in `.task`, changing every frame until it is done.
private struct CountingLoader: View {
    @State private var phase = "loading"

    var body: some View {
        Phase(phase)
            .task {
                do {
                    for step in 1...8 {
                        try await Task.sleep(nanoseconds: 30_000_000)
                        phase = "step \(step)"
                    }
                    phase = "done"
                } catch {
                    // Cancelled: the preview went away before it was done.
                }
            }
    }
}

/// Starts loading whenever it appears, like a screen fetching its data.
@MainActor
private final class LoadingViewModel: ObservableObject {
    @Published private(set) var phase = "loading"

    var isLoaded: Bool { phase == "done" }

    func load() async {
        phase = "loading"

        do {
            try await Task.sleep(nanoseconds: 300_000_000)
            phase = "done"
        } catch {
            // Cancelled: the preview went away before it was done.
        }
    }
}

private struct LoadingScreen: View {
    @ObservedObject var viewModel: LoadingViewModel

    var body: some View {
        Phase(viewModel.phase)
            .task { await viewModel.load() }
    }
}

private struct Phase: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        VStack {
            Text(text)
                .font(.title)
            Color.red
                .frame(height: 20)
        }
        .padding()
    }
}
#endif
