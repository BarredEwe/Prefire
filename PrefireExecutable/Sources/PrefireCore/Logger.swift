import Foundation

/// A simple information logger
public struct Logger {
    public enum Level: Int {
        case errors
        case warnings
        case info
        case verbose
    }

    /// Where the messages go.
    public enum Output {
        case standardOutput
        /// Keeps standard output clean, for commands that answer on it, like `prefire mcp`.
        case standardError
    }

    nonisolated(unsafe) public static var level: Level = .warnings
    nonisolated(unsafe) public static var output: Output = .standardOutput

    static public func verbose(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        guard Level.verbose.rawValue <= Logger.level.rawValue else { return }

        write(items, separator: separator, terminator: terminator)
    }

    static public func info(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        guard Level.info.rawValue <= Logger.level.rawValue else { return }

        write(items, separator: separator, terminator: terminator)
    }

    static public func warning(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        guard Level.warnings.rawValue <= Logger.level.rawValue else { return }

        write(items, separator: separator, terminator: terminator)
    }

    static public func error(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        guard Level.errors.rawValue <= Logger.level.rawValue else { return }

        write(items, separator: separator, terminator: terminator)
    }

    private static func write(_ items: [Any], separator: String, terminator: String) {
        let message = items.map { "\($0)" }.joined(separator: separator) + terminator

        switch output {
        case .standardOutput:
            Swift.print(message, terminator: "")
        case .standardError:
            FileHandle.standardError.write(Data(message.utf8))
        }
    }
}
