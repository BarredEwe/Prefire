import Foundation

enum ConfigPathBuilder {
    private static let configFileName = ".prefire.yml"

    static func possibleConfigPaths(for configPath: String?) -> [String] {
        var possibleConfigPaths = [String]()

        if var configPath = configPath {
            if configPath.hasPrefix("/") {
                configPath.removeFirst()
            }
            if configPath.hasSuffix("/") {
                configPath.removeLast()
            }

            possibleConfigPaths.append(configPath)
            possibleConfigPaths.append(FileManager.default.currentDirectoryPath + "/\(configPath)")

            if !configPath.hasSuffix(configFileName) {
                possibleConfigPaths = possibleConfigPaths.map { $0 + "/\(configFileName)" }
            }
        } else {
            possibleConfigPaths.append(FileManager.default.currentDirectoryPath + "/\(configFileName)")
        }

        return possibleConfigPaths
    }
}
