#if os(iOS)
import Prefire
import SwiftUI
import UIKit
import XCTest

@MainActor
final class FullPageDeviceTests: XCTestCase {
    private let safeArea = UIEdgeInsets(top: 44, left: 0, bottom: 34, right: 0)
    private lazy var device = DeviceConfig(
        safeArea: safeArea,
        size: CGSize(width: 375, height: 812),
        traits: UITraitCollection(displayScale: 3)
    )

    func testScrollViewTallerThanScreenGrowsToItsContent() {
        let snapshot = PrefireSnapshot({ RowsScrollView(count: 40) }, name: "Rows", isScreen: true, device: device)

        let height = snapshot.fullPageDevice().size?.height

        XCTAssertEqual(height, 40 * Row.height + safeArea.top + safeArea.bottom)
    }

    func testContentShorterThanScreenKeepsTheDevice() {
        let snapshot = PrefireSnapshot({ RowsScrollView(count: 3) }, name: "Rows", isScreen: true, device: device)

        XCTAssertEqual(snapshot.fullPageDevice().size, device.size)
    }

    func testListGrowsToShowEveryRow() {
        let snapshot = PrefireSnapshot(
            {
                List(0..<30, id: \.self) { index in
                    Text("Item \(index)")
                        .frame(height: 100)
                        .listRowInsets(EdgeInsets())
                }
                .listStyle(.plain)
            },
            name: "List",
            isScreen: true,
            device: device
        )

        let height = snapshot.fullPageDevice().size?.height ?? 0

        // Separators come from the system, so allow up to a point per row for them.
        let rows = 30 * 100 + safeArea.top + safeArea.bottom
        XCTAssertGreaterThanOrEqual(height, rows)
        XCTAssertLessThanOrEqual(height, rows + 30)
    }

    func testFixedHeightScrollViewInsideThePageDoesNotStopIt() {
        let snapshot = PrefireSnapshot(
            {
                ScrollView {
                    VStack(spacing: 0) {
                        Rows(range: 0..<20)
                        // Overflows by far more than the page, but its viewport never grows.
                        RowsScrollView(count: 200).frame(height: 200)
                        Rows(range: 20..<40)
                    }
                }
            },
            name: "Nested",
            isScreen: true,
            device: device
        )

        let height = snapshot.fullPageDevice().size?.height

        XCTAssertEqual(height, 40 * Row.height + 200 + safeArea.top + safeArea.bottom)
    }

    func testTableViewControllerGrowsToItsRows() {
        let viewController = RowsTableViewController(style: .plain)
        let snapshot = PrefireSnapshot({ viewController }, name: "Table", isScreen: true, device: device)

        let height = snapshot.fullPageDevice().size?.height

        XCTAssertEqual(height, 40 * RowsTableViewController.rowHeight + safeArea.top + safeArea.bottom)
        // The snapshot hosts the same view controller next, so measuring must not keep it as a child.
        XCTAssertNil(viewController.parent)
        XCTAssertNil(viewController.view.superview)
    }

    func testRowsAddedDuringTheDelayAreMeasured() {
        let snapshot = PrefireSnapshot({ DelayedRowsView() }, name: "Delayed", isScreen: true, device: device)

        let height = snapshot.fullPageDevice(delay: 0.5).size?.height

        XCTAssertEqual(height, 40 * Row.height + safeArea.top + safeArea.bottom)
    }

    func testHeightIsCappedInPixels() {
        let snapshot = PrefireSnapshot({ RowsScrollView(count: 1_000) }, name: "Long", isScreen: true, device: device)

        let height = snapshot.fullPageDevice().size?.height ?? 0

        XCTAssertGreaterThan(height, device.size?.height ?? 0)
        XCTAssertLessThanOrEqual(height * 3, 16_384)
    }
}

private struct Row: View {
    static let height: CGFloat = 44

    var index: Int

    var body: some View {
        Text("Row \(index)").frame(maxWidth: .infinity).frame(height: Self.height)
    }
}

private struct Rows: View {
    var range: Range<Int>

    var body: some View {
        ForEach(range, id: \.self) { Row(index: $0) }
    }
}

private struct RowsScrollView: View {
    var count: Int

    var body: some View {
        ScrollView {
            VStack(spacing: 0) { Rows(range: 0..<count) }
        }
    }
}

private struct DelayedRowsView: View {
    @State private var count = 3

    var body: some View {
        RowsScrollView(count: count)
            .task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                count = 40
            }
    }
}

private final class RowsTableViewController: UITableViewController {
    static let rowHeight: CGFloat = 50

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 40 }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = "Cell \(indexPath.row)"
        return cell
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        Self.rowHeight
    }
}
#endif
