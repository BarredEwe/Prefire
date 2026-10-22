import Foundation

/// What the tools of `MCPServer` do.
public protocol MCPToolHandling: Sendable {
    /// Previews in the sources, in source order.
    func listPreviews() throws -> [PreviewEntry]
    /// Builds and runs the snapshot tests to render `request`.
    func render(_ request: RenderRequest) throws -> RenderResult
    /// Writes the board of the last render.
    func buildBoard(embedImages: Bool) throws -> URL
}

/// `RenderService` and `BoardRenderer` as the tools of `MCPServer`.
public struct RenderToolHandler: MCPToolHandling {
    public var service: RenderService

    public init(service: RenderService) {
        self.service = service
    }

    public func listPreviews() throws -> [PreviewEntry] {
        try service.catalog()
    }

    public func render(_ request: RenderRequest) throws -> RenderResult {
        try service.render(request)
    }

    public func buildBoard(embedImages: Bool) throws -> URL {
        try BoardRenderer.write(directory: service.configuration.outputDirectory.standardizedFileURL, embedImages: embedImages)
    }
}

/// A Model Context Protocol server over standard input and output, letting an agent render previews
/// and look at them.
///
/// Messages are JSON-RPC 2.0, one per line.
public struct MCPServer: Sendable {
    static let protocolVersions = ["2025-06-18", "2025-03-26", "2024-11-05"]
    static let defaultMaxImages = 6

    private let handler: any MCPToolHandling
    private let version: String
    private let readImage: @Sendable (URL) -> Data?

    public init(
        handler: any MCPToolHandling,
        version: String,
        readImage: @escaping @Sendable (URL) -> Data? = { try? Data(contentsOf: $0) }
    ) {
        self.handler = handler
        self.version = version
        self.readImage = readImage
    }

    /// Answers the messages read from standard input until it closes.
    public func run() {
        while let line = readLine(strippingNewline: true) {
            guard let response = handle(line: line) else { continue }
            FileHandle.standardOutput.write(Data((response + "\n").utf8))
        }
    }

    /// Answer to a message, or `nil` for a notification.
    public func handle(line: String) -> String? {
        guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        guard let message = try? JSONDecoder().decode(JSONValue.self, from: Data(line.utf8)),
              case .object = message else {
            return encode(error(id: .null, code: -32700, message: "Parse error"))
        }
        guard let response = handle(message: message) else { return nil }
        return encode(response)
    }

    func handle(message: JSONValue) -> JSONValue? {
        guard let method = message["method"]?.stringValue else {
            // A response to a request the server did not send, or an invalid message.
            return message["id"].map { error(id: $0, code: -32600, message: "Invalid Request") }
        }
        // Notifications, like `notifications/initialized`, have no `id` and get no answer.
        guard let id = message["id"] else { return nil }
        let params = message["params"] ?? [:]

        switch method {
        case "initialize":
            return result(id: id, initialize(params: params))
        case "ping":
            return result(id: id, [:])
        case "tools/list":
            return result(id: id, ["tools": .array(Self.tools)])
        case "tools/call":
            guard let name = params["name"]?.stringValue else {
                return error(id: id, code: -32602, message: "Missing tool name")
            }
            guard Self.tools.contains(where: { $0["name"]?.stringValue == name }) else {
                return error(id: id, code: -32602, message: "Unknown tool: \(name)")
            }
            return result(id: id, callTool(name, arguments: params["arguments"] ?? [:]))
        default:
            return error(id: id, code: -32601, message: "Method not found: \(method)")
        }
    }

    // MARK: - Methods

    private func initialize(params: JSONValue) -> JSONValue {
        let requested = params["protocolVersion"]?.stringValue
        let version = requested.flatMap { Self.protocolVersions.contains($0) ? $0 : nil } ?? Self.protocolVersions[0]
        return [
            "protocolVersion": .string(version),
            "capabilities": ["tools": [:]],
            "serverInfo": ["name": "prefire", "version": .string(self.version)],
            "instructions": """
            Renders SwiftUI previews with Prefire: the generated snapshot tests are built and run by xcodebuild \
            on a simulator, so each render shows the current code on the device asked for. Call list_previews to \
            find preview names, render_previews to look at them, build_board for an HTML board of the last render. \
            A render builds the project and can take minutes.
            """,
        ]
    }

    private func callTool(_ name: String, arguments: JSONValue) -> JSONValue {
        do {
            switch name {
            case "list_previews":
                return toolResult([.object(["type": "text", "text": .string(try json(handler.listPreviews()))])])
            case "render_previews":
                return try renderPreviews(arguments: arguments)
            default:
                let url = try handler.buildBoard(embedImages: arguments["embed_images"]?.boolValue ?? false)
                return toolResult([["type": "text", "text": .string("Board written to \(url.path)")]])
            }
        } catch {
            return toolResult([["type": "text", "text": .string("\(error)")]], isError: true)
        }
    }

    private func renderPreviews(arguments: JSONValue) throws -> JSONValue {
        let request = RenderRequest(
            previews: arguments["previews"]?.stringsValue ?? [],
            devices: arguments["devices"]?.stringsValue ?? [],
            colorScheme: arguments["color_scheme"]?.stringValue,
            dynamicType: arguments["dynamic_type"]?.stringValue
        )
        let maxImages = max(0, arguments["max_images"]?.intValue ?? Self.defaultMaxImages)
        let result = try handler.render(request)

        let summaries: [JSONValue] = result.manifest.previews.map { preview in
            let record = preview.record
            var summary: [String: JSONValue] = [
                "name": .string(record.name),
                "width": .number(record.width),
                "height": .number(record.height),
            ]
            summary["image"] = result.imageURL(of: preview).map { .string($0.path) }
            summary["device"] = record.device.map(JSONValue.string)
            summary["userStory"] = record.userStory.map(JSONValue.string)
            summary["state"] = record.state.map(JSONValue.string)
            summary["error"] = record.error.map(JSONValue.string)
            summary["source"] = preview.source.map { .string("\($0.file):\($0.line)") }
            return .object(summary)
        }

        var content: [JSONValue] = []
        var images = 0
        for preview in result.manifest.previews where images < maxImages {
            guard let url = result.imageURL(of: preview), let data = readImage(url) else { continue }
            content.append(["type": "text", "text": .string(preview.record.name + (preview.record.device.map { " on \($0)" } ?? ""))])
            content.append(["type": "image", "data": .string(data.base64EncodedString()), "mimeType": "image/png"])
            images += 1
        }

        var notes: [String] = []
        let rendered = result.manifest.previews.filter { $0.record.image != nil }.count
        if rendered > images {
            notes.append("\(rendered - images) more image(s) are not attached; read them from their paths or raise max_images.")
        }
        if result.manifest.previews.isEmpty {
            notes.append("No preview matched. Call list_previews for the names.")
        }
        if result.status != 0 {
            notes.append("xcodebuild exited with \(result.status). Its output is in \(result.logFile.path).")
        }
        let summary: JSONValue = [
            "directory": .string(result.directory.path),
            "previews": .array(summaries),
            "notes": .array(notes.map(JSONValue.string)),
        ]
        content.insert(["type": "text", "text": .string(try json(summary))], at: 0)

        let failed = result.manifest.previews.isEmpty || result.manifest.previews.allSatisfy { $0.record.image == nil }
        return toolResult(content, isError: failed)
    }

    // MARK: - Tools

    static let tools: [JSONValue] = [
        [
            "name": "list_previews",
            "description": "Lists the SwiftUI previews Prefire renders: name, kind, source file and line, and whether it is a screen.",
            "inputSchema": ["type": "object", "properties": [:]],
        ],
        [
            "name": "render_previews",
            "description": """
            Builds the app and renders SwiftUI previews to PNG on a simulator, returning the images. \
            Use it to check how a view looks after changing it. Takes minutes, as it builds the project.
            """,
            "inputSchema": [
                "type": "object",
                "properties": [
                    "previews": [
                        "type": "array", "items": ["type": "string"],
                        "description": "Names of the previews to render, from list_previews. Empty renders all.",
                    ],
                    "devices": [
                        "type": "array", "items": ["type": "string"],
                        "description": "Devices to render screens on, like \"iPhone 16 Pro\" or \"iPad\".",
                    ],
                    "color_scheme": ["type": "string", "enum": .array(RenderRequest.colorSchemes.map(JSONValue.string))],
                    "dynamic_type": ["type": "string", "enum": .array(RenderRequest.dynamicTypeSizes.map(JSONValue.string))],
                    "max_images": [
                        "type": "integer", "minimum": 0,
                        "description": .string("Most images to return; the rest are listed by path. Defaults to \(defaultMaxImages)."),
                    ],
                ],
            ],
        ],
        [
            "name": "build_board",
            "description": "Writes an HTML board of the last render: previews grouped by user story, in source order, with their states.",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "embed_images": ["type": "boolean", "description": "Puts the images into the page."],
                ],
            ],
        ],
    ]

    // MARK: - JSON-RPC

    private func result(id: JSONValue, _ result: JSONValue) -> JSONValue {
        ["jsonrpc": "2.0", "id": id, "result": result]
    }

    private func error(id: JSONValue, code: Int, message: String) -> JSONValue {
        ["jsonrpc": "2.0", "id": id, "error": ["code": .number(Double(code)), "message": .string(message)]]
    }

    private func toolResult(_ content: [JSONValue], isError: Bool = false) -> JSONValue {
        ["content": .array(content), "isError": .bool(isError)]
    }

    private func json<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    private func encode(_ value: JSONValue) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? String(decoding: encoder.encode(value), as: UTF8.self)) ?? ""
    }
}
