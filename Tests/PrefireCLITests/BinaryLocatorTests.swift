import XCTest
@testable import PrefireCLI

final class BinaryLocatorTests: XCTestCase {
    func testFirstExecutableFindsEmbeddedBinary() throws {
        let bundleURL = try XCTUnwrap(
            Bundle.module.resourceURL?.appendingPathComponent(BinaryLocator.bundleName, isDirectory: true),
            "PrefireCLI must ship with the bundled PrefireBinary artifact"
        )
        let bin = try XCTUnwrap(BinaryLocator.firstExecutable(in: bundleURL), "expected an executable inside the bundled artifact")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: bin), "\(bin) must be executable")
    }

    func testFirstExecutableReturnsNilForEmptyDirectory() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("PrefireCLITests-empty-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        XCTAssertNil(BinaryLocator.firstExecutable(in: dir))
    }

    func testFindBinaryPrefersEnvOverride() {
        let bin = BinaryLocator.findBinary(
            env: ["PREFIRE_BINARY_PATH": "/usr/bin/true"],
            resourceURL: nil,
            cwd: "/nonexistent-\(UUID().uuidString)"
        )
        XCTAssertEqual(bin, "/usr/bin/true")
    }

    func testFindBinaryIgnoresEmptyEnvOverride() throws {
        let bundleURL = try XCTUnwrap(Bundle.module.resourceURL?.appendingPathComponent(BinaryLocator.bundleName, isDirectory: true))
        let bin = BinaryLocator.findBinary(env: ["PREFIRE_BINARY_PATH": ""], resourceURL: bundleURL.deletingLastPathComponent(), cwd: "/tmp")
        XCTAssertNotNil(bin, "empty override must fall through to resource lookup")
    }

    func testFindBinaryFindsViaResourceURL() {
        let bin = BinaryLocator.findBinary(env: [:], resourceURL: Bundle.module.resourceURL, cwd: "/nonexistent-\(UUID().uuidString)")
        XCTAssertNotNil(bin)
    }

    func testFindBinaryReturnsNilWhenNothingAvailable() {
        let bin = BinaryLocator.findBinary(
            env: [:],
            resourceURL: URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)/Resources"),
            cwd: "/nonexistent-\(UUID().uuidString)"
        )
        XCTAssertNil(bin)
    }

    func testCandidateBundleURLsAlwaysIncludesCwdFallback() {
        let urls = BinaryLocator.candidateBundleURLs(resourceURL: nil, cwd: "/tmp")
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls[0].path, "/tmp/Binaries/\(BinaryLocator.bundleName)")
    }
}
