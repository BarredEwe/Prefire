import ArgumentParser
import Foundation

extension Prefire {
    struct Version: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Display the current version of Prefire")

        static var value: String = "2.5.1"

        func run() throws {
            print(Self.value)
        }
    }
}
