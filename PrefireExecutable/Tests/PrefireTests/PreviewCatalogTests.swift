import PathKit
@testable import PrefireCore
import XCTest

final class PreviewCatalogTests: XCTestCase {
    private let source = """
    import SwiftUI

    #Preview("Sign in") {
        SignInView()
    }

    #Preview(traits: .sizeThatFitsLayout) {
        Text("Unnamed")
    }

    struct Card_Previews: PreviewProvider, PrefireProvider {
        static var previews: some View { CardView() }
    }
    """

    func test_entries_findMacrosAndProvidersWithTheirLines() {
        let entries = PreviewCatalog.entries(in: source, file: Path("/App/Views/SignIn.swift"), defaultEnabled: true, useGroupedSnapshots: true)

        XCTAssertEqual(entries, [
            PreviewEntry(name: "Sign in", kind: .macro, file: "/App/Views/SignIn.swift", line: 3, testClass: "PreviewTests", testMethod: "test_Signin_Preview", isScreen: true),
            PreviewEntry(name: "SignIn_1", kind: .macro, file: "/App/Views/SignIn.swift", line: 7, testClass: "PreviewTests", testMethod: "test_SignIn_1_Preview", isScreen: false),
            PreviewEntry(name: "Card_Previews", kind: .provider, file: "/App/Views/SignIn.swift", line: 11, testClass: "PreviewTests", testMethod: "test_card", isScreen: false),
        ])
    }

    func test_entries_useTheClassOfTheFile_whenSnapshotsAreNotGrouped() {
        let entries = PreviewCatalog.entries(in: source, file: Path("SignIn.swift"), defaultEnabled: true, useGroupedSnapshots: false)

        XCTAssertEqual(entries.map(\.testClass), ["SignInTests", "SignInTests", "PreviewTests"])
    }

    func test_entries_testProvidersInAGeneratedClass_whenSnapshotsAreNotGrouped() throws {
        let directory = Path(NSTemporaryDirectory()) + "PreviewCatalogTests-\(UUID().uuidString)"
        try directory.mkpath()
        defer { try? directory.delete() }
        try (directory + "A.swift").write("#Preview(\"Alpha\") { Text(\"A\") }\n")
        try (directory + "B.swift").write(source)

        let entries = try PreviewCatalog.entries(sources: [directory], defaultEnabled: true, useGroupedSnapshots: false)

        XCTAssertEqual(entries.first { $0.kind == .provider }?.testClass, "ATests")
    }

    func test_entries_findProvidersThatConformThroughAProtocol() throws {
        let directory = Path(NSTemporaryDirectory()) + "PreviewCatalogTests-\(UUID().uuidString)"
        try directory.mkpath()
        defer { try? directory.delete() }
        try (directory + "Providers.swift").write("protocol MyProvider: PrefireProvider {}\n")
        try (directory + "Card.swift").write("struct Card_Previews: PreviewProvider, MyProvider {\n    static var previews: some View { Text(\"Card\") }\n}\n")

        let entries = try PreviewCatalog.entries(sources: [directory], defaultEnabled: true, useGroupedSnapshots: true)

        XCTAssertEqual(entries.map(\.name), ["Card_Previews"])
        XCTAssertEqual(entries.first?.line, 1)
        XCTAssertEqual(entries.first?.testMethod, "test_card")
    }

    func test_entries_skipHiddenAndBuildFolders() throws {
        let directory = Path(NSTemporaryDirectory()) + "PreviewCatalogTests-\(UUID().uuidString)"
        defer { try? directory.delete() }
        for folder in ["Views", ".prefire/.derived-data/SourcePackages", "DerivedData/Build", "Pods/Lib"] {
            try (directory + folder).mkpath()
            try (directory + folder + "View.swift").write("#Preview(\"\(folder)\") { Text(\"A\") }\n")
        }

        let entries = try PreviewCatalog.entries(sources: [directory], defaultEnabled: true, useGroupedSnapshots: true)

        XCTAssertEqual(entries.map(\.name), ["Views"])
    }

    func test_matches_nameAndSuffixedNames() {
        let entry = PreviewEntry(name: "Button", kind: .macro, file: "", line: 1, testClass: "", testMethod: "", isScreen: false)

        XCTAssertTrue(entry.matches(snapshotName: "Button"))
        XCTAssertTrue(entry.matches(snapshotName: "Button-1-primary"))
        XCTAssertTrue(entry.matches(snapshotName: "Button-iPhone 15"))
        XCTAssertFalse(entry.matches(snapshotName: "ButtonRow"))
    }
}
