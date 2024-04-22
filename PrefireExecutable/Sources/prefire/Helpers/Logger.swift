import Foundation

/// A simple information logger
struct Logger {
    static var verbose: Bool = true

    /// Writes the textual representations of the given items into the standard
    /// output.
    static func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        Swift.print(items, separator: separator, terminator: terminator)
    }
}
