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
///
/// Sized to fit, both measure the preview the same way, so the images also have the same size on
/// simulators whose screen scale differs from the one of the snapshot traits.
@MainActor
final class SnapshotWaitTests: XCTestCase {
    /// Dark, so a trait override that does not reach the preview shows up in the comparison.
    private let traits = UITraitCollection(traitsFrom: [.init(displayScale: 2), .init(userInterfaceStyle: .dark)])

    private var device: DeviceConfig {
        let config = ViewImageConfig.iPhoneX
        return DeviceConfig(safeArea: config.safeArea, size: config.size, traits: config.traits)
    }

    func testWaitForIdleCapturesStateReachedInTask() throws {
        for isScreen in [false, true] {
            let (_, preferences) = snapshot(isScreen: isScreen) {
                CountingLoader().snapshot(waitForIdle: true, timeout: 3)
            }.loadViewWithPreferences()

            let image = try XCTUnwrap(preferences.settledImage, preferences.failure ?? "")

            try assertImage(image, matches: Phase("done"), isScreen: isScreen)
            XCTAssertNotNil(diff(image, try reference(Phase("loading"), isScreen: isScreen)))
        }
    }

    /// What the wait protects against: rendered anew, the same preview still shows its first frame.
    func testRenderingPreviewAgainStartsItOver() throws {
        let snapshot = snapshot(isScreen: false) { CountingLoader().snapshot(waitForIdle: true, timeout: 3) }
        let (view, preferences) = snapshot.loadViewWithPreferences()

        XCTAssertNotNil(preferences.settledImage)
        let fresh = try render(view, layout: .sizeThatFits)
        XCTAssertNil(diff(fresh, try reference(Phase("loading"), isScreen: false)))
    }

    /// Rows loaded while the preview is waited on make the page taller, and it is captured at that height.
    func testFullPageMeasuresContentLoadedWhileWaiting() throws {
        let snapshot = snapshot(isScreen: true) {
            let viewModel = LoadingViewModel()
            LoadingList(viewModel: viewModel).snapshot(waitUntil: { viewModel.isLoaded }, timeout: 3)
        }
        let (_, preferences) = snapshot.loadViewWithPreferences(fullPage: true)

        let image = try XCTUnwrap(preferences.settledImage, preferences.failure ?? "")
        let height = LoadingList.rowHeight * CGFloat(LoadingList.loadedRows) + device.safeArea.top + device.safeArea.bottom
        XCTAssertEqual(image.size.width, device.size?.width)
        XCTAssertEqual(image.size.height, height)

        // What the strategy renders for the loaded list on a device that tall.
        var expected = device
        expected.size?.height = height
        let reference = PrefireSnapshot({ LoadingList.Rows(count: LoadingList.loadedRows) }, name: "Reference", isScreen: true, device: expected, traits: traits)
        let config = ViewImageConfig(safeArea: expected.safeArea, size: expected.size, traits: expected.traits)
        XCTAssertNil(diff(image, try render(reference.loadViewWithPreferences().0, layout: .device(config: config))))
    }

    func testFullPageKeepsDeviceForContentFittingOneScreen() throws {
        let (_, preferences) = snapshot(isScreen: true) {
            CountingLoader().snapshot(waitForIdle: true, timeout: 3)
        }.loadViewWithPreferences(fullPage: true)

        XCTAssertEqual(try XCTUnwrap(preferences.settledImage).size, device.size)
    }

    func testWaitUntilConditionCapturesStateReachedInTask() throws {
        for isScreen in [false, true] {
            let start = Date()
            let (_, preferences) = snapshot(isScreen: isScreen) {
                let viewModel = LoadingViewModel()
                LoadingScreen(viewModel: viewModel).snapshot(waitUntil: { viewModel.isLoaded }, timeout: 3)
            }.loadViewWithPreferences()

            XCTAssertNil(preferences.failure)
            XCTAssertGreaterThan(Date().timeIntervalSince(start), 0.3, "isScreen: \(isScreen)")
            try assertImage(try XCTUnwrap(preferences.settledImage), matches: Phase("done"), isScreen: isScreen)
        }
    }

    func testProjectWideIdleDefaultCapturesSettledState() throws {
        let (_, preferences) = snapshot(isScreen: false) { CountingLoader() }
            .loadViewWithPreferences(waitDefaults: SnapshotWaitDefaults(waitForIdle: true))

        try assertImage(try XCTUnwrap(preferences.settledImage), matches: Phase("done"), isScreen: false)
    }

    /// `delay` is spent where the preview is captured, so the strategy has nothing left to wait for.
    func testDelayIsSpentBeforeCapturing() throws {
        let start = Date()
        let (_, preferences) = snapshot(isScreen: false) {
            CountingLoader().snapshot(delay: 0.5).snapshot(waitForIdle: true, timeout: 3)
        }.loadViewWithPreferences()

        XCTAssertGreaterThan(Date().timeIntervalSince(start), 0.5)
        try assertImage(try XCTUnwrap(preferences.settledImage), matches: Phase("done"), isScreen: false)
    }

    func testTimeoutLeavesNothingToCompare() {
        let (_, preferences) = snapshot(isScreen: false) {
            CountingLoader().snapshot(waitUntil: { false }, timeout: 0.2)
        }.loadViewWithPreferences()

        XCTAssertNotNil(preferences.failure)
        XCTAssertNil(preferences.settledImage)
    }

    /// Previews that do not wait keep being rendered by the snapshot strategy.
    func testPreviewWithoutWaitIsNotCaptured() {
        let (_, preferences) = snapshot(isScreen: false) { CountingLoader() }.loadViewWithPreferences()

        XCTAssertNil(preferences.waitResult)
    }

    /// The preview is waited on where it was first hosted, so it appears once and starts its work once.
    func testWaitedPreviewIsHostedOnce() throws {
        let appearances = AppearanceCounter()
        let (_, preferences) = snapshot(isScreen: false) {
            CountingLoader()
                .onAppear { appearances.count += 1 }
                .snapshot(waitForIdle: true, timeout: 3)
        }.loadViewWithPreferences()

        XCTAssertNotNil(preferences.settledImage)
        XCTAssertEqual(appearances.count, 1)
    }

    /// A view controller wrapped in a representable leaves the canvas once captured, so the preview
    /// can be hosted again, as the accessibility snapshot does.
    func testWaitedViewControllerLeavesTheCanvas() throws {
        let viewController = LabelViewController()
        let snapshot = PrefireSnapshot({ viewController }, name: "Controller", isScreen: true, device: device, traits: traits)

        let (view, preferences) = snapshot.loadViewWithPreferences(waitDefaults: SnapshotWaitDefaults(waitForIdle: true))

        XCTAssertNotNil(preferences.settledImage, preferences.failure ?? "")
        XCTAssertNil(viewController.parent)

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(rootView: view)
        window.isHidden = false
        window.rootViewController?.view.layoutIfNeeded()
        XCTAssertNotNil(viewController.parent)

        window.rootViewController = nil
        window.isHidden = true
    }

    /// Rows the stretched canvas brings in load in their turn, and are waited for before the capture.
    func testFullPageWaitsForRowsBroughtInByStretching() throws {
        let (_, preferences) = snapshot(isScreen: true) {
            LazyLoadingList(isPreloaded: false).snapshot(waitForIdle: true, timeout: 5)
        }.loadViewWithPreferences(fullPage: true)

        let image = try XCTUnwrap(preferences.settledImage, preferences.failure ?? "")
        let height = LazyLoadingList.rowHeight * CGFloat(LazyLoadingList.rows) + device.safeArea.top + device.safeArea.bottom
        XCTAssertEqual(image.size.height, height)

        var expected = device
        expected.size?.height = height
        let reference = PrefireSnapshot({ LazyLoadingList(isPreloaded: true) }, name: "Reference", isScreen: true, device: expected, traits: traits)
        let config = ViewImageConfig(safeArea: expected.safeArea, size: expected.size, traits: expected.traits)
        XCTAssertNil(diff(image, try render(reference.loadViewWithPreferences().0, layout: .device(config: config))))
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
        let layout: SwiftUISnapshotLayout = isScreen ? .device(config: .iPhoneX) : .sizeThatFits

        return try render(snapshot.loadViewWithPreferences().0, layout: layout)
    }

    private func render(_ view: AnyView, layout: SwiftUISnapshotLayout) throws -> UIImage {
        let strategy: Snapshotting<AnyView, UIImage> = .image(layout: layout, traits: traits)

        var image: UIImage?
        strategy.snapshot(view).run { image = $0 }
        return try XCTUnwrap(image)
    }

    private func diff(_ lhs: UIImage, _ rhs: UIImage) -> String? {
        Snapshotting<UIImage, UIImage>.image.diffing.diff(lhs, rhs)?.0
    }
}

private extension PreferenceKeys {
    var settledImage: UIImage? {
        if case let .settled(image) = waitResult { image } else { nil }
    }

    var failure: String? {
        if case let .timedOut(message) = waitResult { message } else { nil }
    }
}

@MainActor
private final class AppearanceCounter {
    var count = 0
}

private final class LabelViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let label = UILabel()
        label.text = "Controller"
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
}

/// Rows that only show their content once they appeared and loaded, like rows fetching an image.
private struct LazyLoadingList: View {
    static let rowHeight: CGFloat = 50
    static let rows = 40

    let isPreloaded: Bool

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<Self.rows, id: \.self) { index in
                    Row(index: index, isLoaded: isPreloaded)
                }
            }
        }
    }

    private struct Row: View {
        let index: Int
        @State var isLoaded: Bool

        var body: some View {
            Text(isLoaded ? "Row \(index)" : "…")
                .frame(maxWidth: .infinity, minHeight: LazyLoadingList.rowHeight, maxHeight: LazyLoadingList.rowHeight)
                .task {
                    guard !isLoaded else { return }
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    isLoaded = true
                }
        }
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

/// One row while loading, `loadedRows` once loaded: far more than a screen holds.
private struct LoadingList: View {
    static let rowHeight: CGFloat = 50
    static let loadedRows = 40

    @ObservedObject var viewModel: LoadingViewModel

    var body: some View {
        Rows(count: viewModel.isLoaded ? Self.loadedRows : 1)
            .task { await viewModel.load() }
    }

    struct Rows: View {
        let count: Int

        var body: some View {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(0..<count, id: \.self) { index in
                        Text("Row \(index)")
                            .frame(maxWidth: .infinity, minHeight: LoadingList.rowHeight, maxHeight: LoadingList.rowHeight)
                    }
                }
            }
        }
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
