import Foundation

/// A simple information logger
public struct Logger {
    public enum Level: Int {
        case errors
        case warnings
        case info
        case verbose
    }

    nonisolated(unsafe) public static var level: Level = .warnings

    static public func verbose(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        guard Level.verbose.rawValue <= Logger.level.rawValue else { return }

        Swift.print(items, separator: separator, terminator: terminator)
    }

    static public func info(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        guard Level.info.rawValue <= Logger.level.rawValue else { return }

        Swift.print(items, separator: separator, terminator: terminator)
    }

    static public func warning(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        guard Level.warnings.rawValue <= Logger.level.rawValue else { return }

        Swift.print(items, separator: separator, terminator: terminator)
    }

    static public func error(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        guard Level.errors.rawValue <= Logger.level.rawValue else { return }

        Swift.print(items, separator: separator, terminator: terminator)
    }
}
