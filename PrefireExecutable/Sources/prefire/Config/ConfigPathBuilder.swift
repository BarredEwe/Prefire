import Foundation

enum ConfigPathBuilder {
    private static let configFileName = ".prefire.yml"

    /// Unifying the format of the config path and creating additional possible paths
    /// - Parameter configPath: The current path to the config, or `nil` if not provided
    /// - Parameter testTargetPath: Path to Snapshot Tests Target
    /// - Parameter packagePath: Path to SPM package
    /// - Returns: An array of possible paths for the configuration file
    static func possibleConfigPaths(for configPath: String?, testTargetPath: String?, packagePath: String?) -> [String] {
        var possibleConfigPaths = [String]()

        for path in [testTargetPath, configPath, packagePath] {
            guard let path else {
                continue
            }

            // Decode any percent-encoded characters in the input path
            let decodedPath = path.removingPercentEncoding ?? path

            // This will build the absolute path relative to the current directory
            var configURL = URL(filePath: decodedPath)

            // Add the config file name if not provided
            if configURL.lastPathComponent != configFileName {
                configURL.append(component: configFileName)
            }

            possibleConfigPaths.append(configURL.absoluteURL.path(percentEncoded: false))
        }

        // Add the default path
        let configURL = URL(filePath: configFileName) // Relative to the current directory
        possibleConfigPaths.append(configURL.absoluteURL.path(percentEncoded: false))

        return possibleConfigPaths
    }
}
