import ArgumentParser
import Foundation

extension Prefire {
    struct Version: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Display the current version of Prefire")

        static var value: String = "3.3.0"

        func run() throws {
            print(Self.value)
        }
    }
}
