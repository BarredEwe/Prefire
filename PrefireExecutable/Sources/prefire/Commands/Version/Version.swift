import ArgumentParser
import Foundation

extension Prefire {
    struct Version: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Display the current version of Prefire")

        static let value: String = "4.0.1"

        func run() throws {
            print(Self.value)
        }
    }
}
