@preconcurrency import ArgumentParser
import Foundation
import PrefireCore

extension Prefire {
    struct MCP: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "mcp",
            abstract: "Run a Model Context Protocol server that lets AI agents render previews",
            discussion: """
            Speaks MCP over standard input and output, with the tools list_previews, render_previews and \
            build_board. Add it to Claude Code with `claude mcp add prefire -- prefire mcp`.
            """
        )

        @OptionGroup var setup: RenderSetupOptions

        func run() throws {
            // Standard output carries the protocol only.
            Logger.output = .standardError
            Logger.level = setup.verbose ? .verbose : .warnings

            let service = RenderService(configuration: try setup.renderConfiguration(config: setup.loadConfig()))
            MCPServer(handler: RenderToolHandler(service: service), version: Version.value).run()
        }
    }
}
