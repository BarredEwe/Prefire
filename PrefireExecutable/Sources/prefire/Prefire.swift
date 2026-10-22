@preconcurrency import ArgumentParser
import Foundation

@main
struct Prefire: AsyncParsableCommand {
    static let configuration: CommandConfiguration = .init(
        commandName: "prefire",
        abstract: "A tool to easy generation: Playbook and Snapshot/Accessibility Tests.",
        version: Version.value,
        subcommands: [
            Playbook.self,
            Tests.self,
            Render.self,
            Board.self,
            MCP.self,
            Version.self
        ]
    )
}
