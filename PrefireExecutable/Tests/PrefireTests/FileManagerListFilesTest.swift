import Foundation
@testable import prefire
import XCTest

class FileManagerListFilesTest: XCTestCase {
    let sourceDirectoryURL = URL(fileURLWithPath: #file)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Binaries")

    func testListFiles() {
        let files = FileManager.default.listFiles(atPath: sourceDirectoryURL.path(), withExtension: "")
            .filter({ !$0.hasSuffix(".DS_Store") })

        XCTAssertEqual(files.count, 5)
    }
}
