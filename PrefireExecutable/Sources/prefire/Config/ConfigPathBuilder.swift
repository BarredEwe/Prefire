import Foundation

enum ConfigPathBuilder {
    private static let configFileName = ".prefire.yml"
    
    /// Unifying the format of the config path and creating additional possible paths
    /// - Parameter configPath: The current path to the config, or `nil` if not provided
    /// - Returns: An array of possible paths for the configuration file
    static func possibleConfigPaths(for configPath: String?) -> [String] {
        var possibleConfigPaths = [String]()

        if var configPath = configPath {
            // Check if the provided path is absolute and remove leading slash if so
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
            // Add the default path if no specific one is provided
            possibleConfigPaths.append(FileManager.default.currentDirectoryPath + "/\(configFileName)")
        }

        return possibleConfigPaths
    }
}
