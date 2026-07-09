import XCTest
import Foundation
import PathKit
import SourceryRuntime
@testable import PrefireCore

final class PrefireCacheManagerTests: XCTestCase {

    func testCacheManagerPersistsAndReloads() async throws {
        let tmp = Path("/tmp/cache_test/\(UUID().uuidString)")
        try tmp.mkpath()

        let file = tmp + "Example.swift"
        try file.write("""
        struct Example {}
        #Preview {
            Text("Hello")
        }
        """)

        let template = "ABC"
        let manager = PrefireCacheManager(version: "test-1", cacheBasePath: tmp)

        var parsed = false
        var previewsParsed = false

        // First parse (generates cache)
        let (firstTypes, firstPreviews) = try await manager.loadOrGenerate(
            sources: [file],
            template: template,
            parseTypes: {
                parsed = true
                return Types(types: [])
            },
            parsePreviews: {
                previewsParsed = true
                return PreviewLoader.previewModels(from: try file.read(.utf8), filename: "Example", defaultEnabled: true) ?? [:]
            }
        )

        XCTAssertTrue(parsed)
        XCTAssertTrue(previewsParsed)
        XCTAssertEqual(firstPreviews["Example_0"]?.body, "Text(\"Hello\")")

        parsed = false
        previewsParsed = false

        // Second parse (should use cache)
        let (cachedTypes, cachedPreviews) = try await manager.loadOrGenerate(
            sources: [file],
            template: template,
            parseTypes: {
                XCTFail("Should not re-parse types if cache is valid")
                return Types(types: [])
            },
            parsePreviews: {
                XCTFail("Should not re-parse previews if cache is valid")
                return [:]
            }
        )

        XCTAssertEqual(cachedPreviews, firstPreviews)

        // Touch the file (simulate source change)
        try file.write(try file.read(), encoding: .utf8)

        let (updatedTypes, updatedPreviews) = try await manager.loadOrGenerate(
            sources: [file],
            template: template,
            parseTypes: {
                Types(types: [])
            },
            parsePreviews: {
                PreviewLoader.previewModels(from: """
                #Preview {
                    Text("Updated")
                }
                """, filename: "Example", defaultEnabled: true) ?? [:]
            }
        )

        XCTAssertEqual(updatedPreviews["Example_0"]?.body, "Text(\"Updated\")")
    }
}
