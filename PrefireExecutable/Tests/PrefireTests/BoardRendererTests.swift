import Foundation
@testable import PrefireCore
import XCTest

final class BoardRendererTests: XCTestCase {
    private func preview(_ name: String, story: String?, state: String? = nil, image: String? = nil, error: String? = nil) -> RenderedPreview {
        RenderedPreview(
            record: RenderRecord(runID: "run", name: name, image: image ?? "\(name).png", width: 375, height: 812, userStory: story, state: state, error: error),
            source: PreviewEntry(name: name, kind: .macro, file: "/App/\(name).swift", line: 4, testClass: "PreviewTests", testMethod: "test", isScreen: true)
        )
    }

    func test_stories_keepTheOrderOfThePreviews_andPutThoseWithoutAStoryLast() {
        let stories = BoardRenderer.stories(of: [
            preview("Settings", story: nil),
            preview("SignIn", story: "Auth"),
            preview("Cart", story: "Checkout"),
            preview("SignUp", story: "Auth"),
            preview("Profile", story: ""),
        ])

        XCTAssertEqual(stories.map(\.name), ["Auth", "Checkout", nil])
        XCTAssertEqual(stories.map { $0.previews.map(\.record.name) }, [["SignIn", "SignUp"], ["Cart"], ["Settings", "Profile"]])
    }

    func test_html_showsPreviewsWithTheirStatesAndEscapesText() {
        let manifest = RenderManifest(runID: "run", createdAt: Date(timeIntervalSince1970: 0), destination: "iPhone <16>", previews: [
            preview("SignIn", story: "Auth & Login", state: "Empty"),
            preview("Broken", story: "Auth & Login", image: nil, error: "Timed out <5s>"),
        ])

        let html = BoardRenderer.html(for: manifest) { "images/" + $0 }

        XCTAssertTrue(html.contains("<h2>Auth &amp; Login <span class=\"count\">2</span></h2>"))
        XCTAssertTrue(html.contains(#"<img src="images/SignIn.png" alt="SignIn""#))
        XCTAssertTrue(html.contains(#"<span class="state">Empty</span>"#))
        XCTAssertTrue(html.contains("Timed out &lt;5s&gt;"))
        XCTAssertTrue(html.contains("iPhone &lt;16&gt;"))
        XCTAssertTrue(html.contains("SignIn.swift:4"))
        XCTAssertTrue(html.contains("prefers-color-scheme: dark"))
        XCTAssertFalse(html.contains("<16>"))
    }

    func test_write_embedsImages() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("BoardRendererTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try RenderManifest(runID: "run", destination: nil, previews: [preview("SignIn", story: "Auth")]).write(to: directory)
        try Data([1, 2, 3]).write(to: directory.appendingPathComponent("SignIn.png"))

        let linked = try String(contentsOf: BoardRenderer.write(directory: directory, embedImages: false), encoding: .utf8)
        XCTAssertTrue(linked.contains(#"src="SignIn.png""#))

        let embedded = try String(contentsOf: BoardRenderer.write(directory: directory, embedImages: true), encoding: .utf8)
        XCTAssertTrue(embedded.contains(#"src="data:image/png;base64,AQID""#))
    }

    func test_escape() {
        XCTAssertEqual(BoardRenderer.escape(#"<a href="x">'&'</a>"#), "&lt;a href=&quot;x&quot;&gt;&#39;&amp;&#39;&lt;/a&gt;")
    }
}
