import Prefire
import SwiftUI
import XCTest

final class SnapshotVariantTests: XCTestCase {
    func testVariantNamesFromConfiguration() {
        XCTAssertEqual(SnapshotVariant(name: "light"), .light)
        XCTAssertEqual(SnapshotVariant(name: "dark"), .dark)
        XCTAssertEqual(SnapshotVariant(name: "rtl"), .rightToLeft)
        XCTAssertEqual(SnapshotVariant(name: "rightToLeft"), .rightToLeft)
        XCTAssertEqual(SnapshotVariant(name: "accessibilityXXXL"), .sizeCategory(.accessibilityExtraExtraExtraLarge))
        XCTAssertEqual(SnapshotVariant(name: "extraExtraExtraLarge"), .sizeCategory(.extraExtraExtraLarge))
        XCTAssertEqual(SnapshotVariant(name: "locale_ru_RU"), .locale(Locale(identifier: "ru_RU")))
        XCTAssertNil(SnapshotVariant(name: "unknown"))

        XCTAssertEqual(SnapshotVariant.variants(named: ["light", "dark"]), [.light, .dark])
    }

    /// Prefire owns the size categories, so they stay `Sendable` on every SDK.
    func testSizeCategoriesMapToSwiftUI() {
        let categories = SnapshotVariant.SizeCategory.allCases

        XCTAssertEqual(Set(categories.map(\.contentSizeCategory)).count, categories.count)
        XCTAssertEqual(SnapshotVariant.SizeCategory.large.contentSizeCategory, .large)
        XCTAssertEqual(
            SnapshotVariant.SizeCategory.accessibilityExtraExtraExtraLarge.contentSizeCategory,
            .accessibilityExtraExtraExtraLarge
        )

        XCTAssertEqual(SnapshotVariant.SizeCategory(name: "XXXL"), .extraExtraExtraLarge)
        XCTAssertEqual(SnapshotVariant.SizeCategory(name: "extraExtraExtraLarge"), .extraExtraExtraLarge)
        XCTAssertNil(SnapshotVariant.SizeCategory(name: "huge"))
    }

    /// `.light` stays unsuffixed, so snapshots recorded before variants existed keep their name.
    func testNameSuffixes() {
        XCTAssertEqual(SnapshotVariant.light.nameSuffix, "")
        XCTAssertEqual(SnapshotVariant.dark.nameSuffix, "-dark")
        XCTAssertEqual(SnapshotVariant.rightToLeft.nameSuffix, "-rtl")
        XCTAssertEqual(SnapshotVariant.sizeCategory(.accessibilityExtraExtraExtraLarge).nameSuffix, "-accessibilityXXXL")
        XCTAssertEqual(SnapshotVariant.locale(Locale(identifier: "ru_RU")).nameSuffix, "-locale_ru_RU")
    }
}
