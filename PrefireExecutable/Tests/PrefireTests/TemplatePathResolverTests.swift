@testable import prefire
import XCTest

final class TemplatePathResolverTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appending(path: "Tests"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func touch(_ path: String) throws {
        try Data().write(to: root.appending(path: path))
    }

    func test_absolutePathIsKept() {
        var config = Config()
        config.configDirectory = root.path(percentEncoded: false)
        XCTAssertEqual(config.resolveTemplatePath("/abs/T.stencil", targetPath: nil), "/abs/T.stencil")
    }

    func test_prefersTargetPathWhenFileExists() throws {
        try touch("Tests/T.stencil")
        try touch("T.stencil")
        var config = Config()
        config.configDirectory = root.path(percentEncoded: false)
        let result = config.resolveTemplatePath("T.stencil", targetPath: root.appending(path: "Tests").path(percentEncoded: false))
        XCTAssertEqual(result, root.appending(path: "Tests/T.stencil").standardizedFileURL.path(percentEncoded: false))
    }

    func test_fallsBackToConfigDirectory() throws {
        try touch("T.stencil")
        var config = Config()
        config.configDirectory = root.path(percentEncoded: false)
        let result = config.resolveTemplatePath("T.stencil", targetPath: root.appending(path: "Tests").path(percentEncoded: false))
        XCTAssertEqual(result, root.appending(path: "T.stencil").standardizedFileURL.path(percentEncoded: false))
    }

    func test_supportsParentRelativePaths() throws {
        try touch("T.stencil")
        var config = Config()
        config.configDirectory = root.appending(path: "Tests").path(percentEncoded: false)
        let result = config.resolveTemplatePath("../T.stencil", targetPath: nil)
        XCTAssertEqual(result, root.appending(path: "T.stencil").standardizedFileURL.path(percentEncoded: false))
    }
}
