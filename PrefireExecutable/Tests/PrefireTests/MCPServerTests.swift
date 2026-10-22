import Foundation
@testable import PrefireCore
import XCTest

final class MCPServerTests: XCTestCase {
    private func server(_ handler: FakeToolHandler = FakeToolHandler()) -> MCPServer {
        MCPServer(handler: handler, version: "1.0.0") { url in Data(url.lastPathComponent.utf8) }
    }

    private func call(_ server: MCPServer, _ message: String) throws -> JSONValue {
        let line = try XCTUnwrap(server.handle(line: message))
        return try JSONDecoder().decode(JSONValue.self, from: Data(line.utf8))
    }

    func test_initialize_answersWithTheRequestedVersionAndTools() throws {
        let response = try call(server(), #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05"}}"#)

        XCTAssertEqual(response["id"], 1)
        XCTAssertEqual(response["result"]?["protocolVersion"], "2024-11-05")
        XCTAssertEqual(response["result"]?["capabilities"]?["tools"], [:])
        XCTAssertEqual(response["result"]?["serverInfo"]?["name"], "prefire")
    }

    func test_initialize_answersWithTheLatestVersion_forAnUnknownOne() throws {
        let response = try call(server(), #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"1999-01-01"}}"#)

        XCTAssertEqual(response["result"]?["protocolVersion"], .string(MCPServer.protocolVersions[0]))
    }

    func test_notificationsGetNoAnswer() {
        XCTAssertNil(server().handle(line: #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#))
        XCTAssertNil(server().handle(line: ""))
    }

    func test_ping_unknownMethods_andParseErrors() throws {
        XCTAssertEqual(try call(server(), #"{"jsonrpc":"2.0","id":"a","method":"ping"}"#)["result"], [:])
        XCTAssertEqual(try call(server(), #"{"jsonrpc":"2.0","id":2,"method":"resources/list"}"#)["error"]?["code"], -32601)
        XCTAssertEqual(try call(server(), "{not json")["error"]?["code"], -32700)
        XCTAssertEqual(try call(server(), #"{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"nope"}}"#)["error"]?["code"], -32602)
    }

    func test_toolsList() throws {
        let response = try call(server(), #"{"jsonrpc":"2.0","id":1,"method":"tools/list"}"#)

        guard case let .array(tools) = response["result"]?["tools"] else { return XCTFail("No tools") }
        XCTAssertEqual(tools.compactMap { $0["name"]?.stringValue }, ["list_previews", "render_previews", "build_board"])
        XCTAssertTrue(tools.allSatisfy { $0["inputSchema"]?["type"] == "object" })
    }

    func test_listPreviews() throws {
        let response = try call(server(), #"{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"list_previews"}}"#)

        XCTAssertEqual(response["result"]?["isError"], false)
        let text = try XCTUnwrap(response["result"]?["content"].flatMap(firstText))
        XCTAssertTrue(text.contains(#""name" : "Button""#))
    }

    func test_renderPreviews_passesArguments_andReturnsImagesUpToTheLimit() throws {
        let handler = FakeToolHandler()
        let response = try call(server(handler), #"""
        {"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"render_previews","arguments":
        {"previews":["Button"],"devices":"iPad","color_scheme":"dark","dynamic_type":"xxLarge","max_images":1}}}
        """#.replacingOccurrences(of: "\n", with: ""))

        XCTAssertEqual(handler.requests.value, [RenderRequest(previews: ["Button"], devices: ["iPad"], colorScheme: "dark", dynamicType: "xxLarge")])
        guard case let .array(content) = response["result"]?["content"] else { return XCTFail("No content") }

        XCTAssertEqual(content.map { $0["type"] }, ["text", "text", "image"])
        XCTAssertEqual(content[1]["text"], "Button on iPad")
        XCTAssertEqual(content[2]["data"], .string(Data("Button.png".utf8).base64EncodedString()))
        XCTAssertEqual(content[2]["mimeType"], "image/png")

        let summary = try XCTUnwrap(content[0]["text"]?.stringValue)
        XCTAssertTrue(summary.contains("/render/Button-2.png"))
        XCTAssertTrue(summary.contains("1 more image(s)"))
        XCTAssertEqual(response["result"]?["isError"], false)
    }

    func test_toolErrorsAreReportedAsResults() throws {
        let handler = FakeToolHandler()
        handler.error = RenderError.invalidOption("Unknown color scheme 'sepia'.")

        let response = try call(server(handler), #"{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"render_previews","arguments":{"color_scheme":"sepia"}}}"#)

        XCTAssertEqual(response["result"]?["isError"], true)
        XCTAssertEqual(response["result"]?["content"].flatMap(firstText), "Unknown color scheme 'sepia'.")
    }

    func test_buildBoard() throws {
        let response = try call(server(), #"{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"build_board","arguments":{"embed_images":true}}}"#)

        XCTAssertEqual(response["result"]?["content"].flatMap(firstText), "Board written to /render/board-embedded.html")
    }

    private func firstText(_ content: JSONValue) -> String? {
        guard case let .array(blocks) = content else { return nil }
        return blocks.first?["text"]?.stringValue
    }
}

private final class FakeToolHandler: MCPToolHandling, @unchecked Sendable {
    let requests = Box<[RenderRequest]>([])
    var error: Error?

    func listPreviews() throws -> [PreviewEntry] {
        [PreviewEntry(name: "Button", kind: .macro, file: "/App/Button.swift", line: 3, testClass: "PreviewTests", testMethod: "test_Button_Preview", isScreen: false)]
    }

    func render(_ request: RenderRequest) throws -> RenderResult {
        if let error { throw error }
        requests.value.append(request)
        let previews = ["Button", "Button-2"].map { name in
            RenderedPreview(record: RenderRecord(runID: "run", name: name, image: "\(name).png", device: "iPad"), source: nil)
        }
        let directory = URL(fileURLWithPath: "/render")
        return RenderResult(
            manifest: RenderManifest(runID: "run", destination: nil, previews: previews),
            directory: directory,
            logFile: directory.appendingPathComponent("xcodebuild.log"),
            status: 0
        )
    }

    func buildBoard(embedImages: Bool) throws -> URL {
        URL(fileURLWithPath: embedImages ? "/render/board-embedded.html" : "/render/board.html")
    }
}

private final class Box<Value>: @unchecked Sendable {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
