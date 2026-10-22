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

    func test_matches_nameAndSuffixedNames() {
        let entry = PreviewEntry(name: "Button", kind: .macro, file: "", line: 1, testClass: "", testMethod: "", isScreen: false)

        XCTAssertTrue(entry.matches(snapshotName: "Button"))
        XCTAssertTrue(entry.matches(snapshotName: "Button-1-primary"))
        XCTAssertTrue(entry.matches(snapshotName: "Button-iPhone 15"))
        XCTAssertFalse(entry.matches(snapshotName: "ButtonRow"))
    }
}
