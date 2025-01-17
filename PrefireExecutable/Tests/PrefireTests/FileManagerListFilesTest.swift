import Foundation
@testable import prefire
import XCTest

class FileManagerListFilesTest: XCTestCase {
    let sourceDirectoryURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Binaries")

    func testListFiles() {
        let files = FileManager.default.listFiles(atURL: sourceDirectoryURL, withExtension: "")
            .filter({ !$0.hasSuffix(".DS_Store") })

        XCTAssertEqual(files.count, 5)
    }
}
