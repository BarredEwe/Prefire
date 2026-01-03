import Foundation
@testable import prefire
import XCTest

class ConfigPathResolverTests: XCTestCase {
    // MARK: - Target Placeholder Tests

    func test_resolve_replacesTargetPlaceholder() {
        let path = "${PROJECT_DIR}/${TARGET}/Tests"
        let result = ConfigPathResolver.resolve(path, target: "MyApp")

        XCTAssertEqual(result, "${PROJECT_DIR}/MyApp/Tests")
    }

    func test_resolve_replacesTargetPlaceholder_multipleOccurrences() {
        let path = "${TARGET}/Sources/${TARGET}/Tests"
        let result = ConfigPathResolver.resolve(path, target: "CoreModule")

        XCTAssertEqual(result, "CoreModule/Sources/CoreModule/Tests")
    }

    func test_resolve_doesNotReplaceTargetPlaceholder_whenTargetIsNil() {
        let path = "${PROJECT_DIR}/${TARGET}/Tests"
        let result = ConfigPathResolver.resolve(path, target: nil)

        XCTAssertEqual(result, "${PROJECT_DIR}/${TARGET}/Tests")
    }

    // MARK: - TestTarget Placeholder Tests

    func test_resolve_replacesTestTargetPlaceholder() {
        let path = "${PROJECT_DIR}/Tests/${TEST_TARGET}"
        let result = ConfigPathResolver.resolve(path, testTarget: "MyAppTests")

        XCTAssertEqual(result, "${PROJECT_DIR}/Tests/MyAppTests")
    }

    func test_resolve_replacesTestTargetPlaceholder_multipleOccurrences() {
        let path = "${TEST_TARGET}/Snapshots/${TEST_TARGET}"
        let result = ConfigPathResolver.resolve(path, testTarget: "UnitTests")

        XCTAssertEqual(result, "UnitTests/Snapshots/UnitTests")
    }

    func test_resolve_doesNotReplaceTestTargetPlaceholder_whenTestTargetIsNil() {
        let path = "${PROJECT_DIR}/Tests/${TEST_TARGET}"
        let result = ConfigPathResolver.resolve(path, testTarget: nil)

        XCTAssertEqual(result, "${PROJECT_DIR}/Tests/${TEST_TARGET}")
    }

    // MARK: - Combined Placeholder Tests

    func test_resolve_replacesBothPlaceholders() {
        let path = "${PROJECT_DIR}/${TARGET}/Tests/${TEST_TARGET}"
        let result = ConfigPathResolver.resolve(
            path,
            target: "FeatureA",
            testTarget: "FeatureATests"
        )

        XCTAssertEqual(result, "${PROJECT_DIR}/FeatureA/Tests/FeatureATests")
    }

    func test_resolve_replacesBothPlaceholders_complexPath() {
        let path = "Modules/${TARGET}/Testing/${TEST_TARGET}/Snapshots/${TARGET}"
        let result = ConfigPathResolver.resolve(
            path,
            target: "ShoppingCart",
            testTarget: "ShoppingCartUnitTests"
        )

        XCTAssertEqual(result, "Modules/ShoppingCart/Testing/ShoppingCartUnitTests/Snapshots/ShoppingCart")
    }

    func test_resolve_doesNotReplacePlaceholders_whenBothParametersAreNil() {
        let path = "${PROJECT_DIR}/${TARGET}/Tests/${TEST_TARGET}"
        let result = ConfigPathResolver.resolve(path, target: nil, testTarget: nil)

        XCTAssertEqual(result, "${PROJECT_DIR}/${TARGET}/Tests/${TEST_TARGET}")
    }

    // MARK: - Edge Cases

    func test_resolve_noPlaceholders_returnsOriginalPath() {
        let path = "${PROJECT_DIR}/Tests/Snapshots"
        let result = ConfigPathResolver.resolve(path, target: "MyApp", testTarget: "MyAppTests")

        XCTAssertEqual(result, "${PROJECT_DIR}/Tests/Snapshots")
    }

    func test_resolve_emptyPath_returnsEmptyPath() {
        let result = ConfigPathResolver.resolve("", target: "MyApp")

        XCTAssertEqual(result, "")
    }

    func test_resolve_emptyTargetValue_doesNotReplace() {
        let path = "${TARGET}/Tests"
        let result = ConfigPathResolver.resolve(path, target: "")

        XCTAssertEqual(result, "/Tests")
    }

    func test_resolve_emptyTestTargetValue_doesNotReplace() {
        let path = "Tests/${TEST_TARGET}"
        let result = ConfigPathResolver.resolve(path, testTarget: "")

        XCTAssertEqual(result, "Tests/")
    }

    func test_resolve_pathWithSpaces() {
        let path = "My Project/${TARGET}/My Tests"
        let result = ConfigPathResolver.resolve(path, target: "My App")

        XCTAssertEqual(result, "My Project/My App/My Tests")
    }

    func test_resolve_pathWithSpecialCharacters() {
        let path = "Project-${TARGET}_Tests/${TEST_TARGET}.snapshot"
        let result = ConfigPathResolver.resolve(
            path,
            target: "Core-Module",
            testTarget: "Core_Tests"
        )

        XCTAssertEqual(result, "Project-Core-Module_Tests/Core_Tests.snapshot")
    }

    // MARK: - No Parameters

    func test_resolve_withNoParameters_returnsOriginalPath() {
        let path = "${PROJECT_DIR}/${TARGET}/Tests/${TEST_TARGET}"
        let result = ConfigPathResolver.resolve(path)

        XCTAssertEqual(result, "${PROJECT_DIR}/${TARGET}/Tests/${TEST_TARGET}")
    }

    func test_resolve_onlyTarget_leavesTestTargetPlaceholder() {
        let path = "${TARGET}/Tests/${TEST_TARGET}"
        let result = ConfigPathResolver.resolve(path, target: "MyApp")

        XCTAssertEqual(result, "MyApp/Tests/${TEST_TARGET}")
    }

    func test_resolve_onlyTestTarget_leavesTargetPlaceholder() {
        let path = "${TARGET}/Tests/${TEST_TARGET}"
        let result = ConfigPathResolver.resolve(path, testTarget: "MyTests")

        XCTAssertEqual(result, "${TARGET}/Tests/MyTests")
    }
}
