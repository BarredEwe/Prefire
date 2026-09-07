import XCTest
@testable import PrefireCore

final class GlobalConfigurationResolverTests: XCTestCase {
    private func graph(_ source: String) -> TypeGraph {
        TypeGraph(types: TypeScanner.merge([TypeScanner.scan(contents: source)]))
    }

    private func resolvedName(_ source: String, arguments: [String: NSObject] = [:]) throws -> String? {
        let resolved = try GlobalConfigurationResolver.resolve(arguments: arguments, graph: graph(source))
        return resolved[GlobalConfigurationResolver.argumentKey] as? String
    }

    func test_detectsTheSingleConformingType() throws {
        let name = try resolvedName("enum MyPrefireSetup: PrefireGlobalConfiguration {}")

        XCTAssertEqual(name, "MyPrefireSetup")
    }

    func test_detectsConformanceThroughAnotherProtocol() throws {
        let name = try resolvedName(
            """
            protocol TeamSetup: PrefireGlobalConfiguration {}
            enum MyPrefireSetup: TeamSetup {}
            """
        )

        XCTAssertEqual(name, "MyPrefireSetup")
    }

    func test_detectsModuleQualifiedConformance() throws {
        let name = try resolvedName("enum MyPrefireSetup: Prefire.PrefireGlobalConfiguration {}")

        XCTAssertEqual(name, "MyPrefireSetup")
    }

    func test_nestedTypeIsDetectedByQualifiedName() throws {
        let name = try resolvedName(
            """
            enum DesignSystem {
                enum Previews: PrefireGlobalConfiguration {}
            }
            """
        )

        XCTAssertEqual(name, "DesignSystem.Previews", "The generated file has to be able to name the type")
    }

    func test_noConformingTypeLeavesArgumentsUntouched() throws {
        XCTAssertNil(try resolvedName("struct Panel_Previews: PreviewProvider {}"))
    }

    /// The explicit key stays the escape hatch: a type declared in the test target is invisible to
    /// the scan, so a configured name must never be overridden by what was found.
    func test_configuredNameWins() throws {
        let name = try resolvedName(
            "enum ScannedSetup: PrefireGlobalConfiguration {}",
            arguments: [GlobalConfigurationResolver.argumentKey: "TestTargetSetup" as NSString]
        )

        XCTAssertEqual(name, "TestTargetSetup")
    }

    func test_ambiguousConformanceFails() {
        let source = """
        enum FirstSetup: PrefireGlobalConfiguration {}
        enum SecondSetup: PrefireGlobalConfiguration {}
        """

        XCTAssertThrowsError(try resolvedName(source)) { error in
            let message = (error as? LocalizedError)?.errorDescription ?? ""
            XCTAssertTrue(message.contains("FirstSetup"), message)
            XCTAssertTrue(message.contains("SecondSetup"), message)
            XCTAssertTrue(message.contains("global_configuration"), message)
        }
    }

    /// A `private` type would produce a compile error inside the generated file, so it is skipped.
    func test_unreachableTypeIsNotDetected() throws {
        XCTAssertNil(try resolvedName("private enum MyPrefireSetup: PrefireGlobalConfiguration {}"))
    }

    func test_unreachableTypeDoesNotMakeDetectionAmbiguous() throws {
        let name = try resolvedName(
            """
            private enum HiddenSetup: PrefireGlobalConfiguration {}
            enum VisibleSetup: PrefireGlobalConfiguration {}
            """
        )

        XCTAssertEqual(name, "VisibleSetup")
    }

    func test_protocolItselfIsNotACandidate() throws {
        XCTAssertNil(try resolvedName("protocol TeamSetup: PrefireGlobalConfiguration {}"))
    }
}
