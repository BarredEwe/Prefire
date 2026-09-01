import Prefire
import XCTest

final class PrefireDeviceIdentifierTests: XCTestCase {
    func testNameForKnownIdentifier() {
        XCTAssertEqual(PrefireDeviceIdentifier.name(for: "iPhone17,1"), "iPhone 16 Pro")
        XCTAssertEqual(PrefireDeviceIdentifier.name(for: "iPhone14,3"), "iPhone 13 Pro Max")
        XCTAssertEqual(PrefireDeviceIdentifier.name(for: "iPad14,1"), "iPad mini (6th generation)")
        XCTAssertEqual(PrefireDeviceIdentifier.name(for: "AppleTV11,1"), "Apple TV 4K (2nd generation)")
    }

    /// Identifiers sharing a device, such as the Wi-Fi and cellular models, resolve to one name.
    func testIdentifierAliasesShareOneName() {
        XCTAssertEqual(PrefireDeviceIdentifier.name(for: "iPhone9,1"), PrefireDeviceIdentifier.name(for: "iPhone9,3"))
    }

    func testNameForUnknownIdentifier() {
        XCTAssertNil(PrefireDeviceIdentifier.name(for: "iPhone999,1"))
    }

    func testDescribeAddsTheName() {
        XCTAssertEqual(PrefireDeviceIdentifier.describe("iPhone17,1"), "iPhone 16 Pro (iPhone17,1)")
    }

    func testDescribePrefersTheNameFromTheEnvironment() {
        XCTAssertEqual(
            PrefireDeviceIdentifier.describe("iPhone17,1", name: "My Simulator"),
            "My Simulator (iPhone17,1)"
        )
    }

    func testDescribeFallsBackToTheTableWhenTheEnvironmentReportsNothing() {
        XCTAssertEqual(PrefireDeviceIdentifier.describe("iPhone17,1", name: "  "), "iPhone 16 Pro (iPhone17,1)")
    }

    func testDescribeFallsBackToTheIdentifier() {
        XCTAssertEqual(PrefireDeviceIdentifier.describe("iPhone999,1"), "iPhone999,1")
        XCTAssertEqual(PrefireDeviceIdentifier.describe("iPhone999,1", name: "  "), "iPhone999,1")
        XCTAssertEqual(PrefireDeviceIdentifier.describe("iPhone999,1", name: "iPhone999,1"), "iPhone999,1")
    }
}
