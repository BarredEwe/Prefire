import Foundation

extension FileManager {
    /// This function recursively lists all files with a ".swift" extension within the specified directory path.
    /// - Parameter path:  The directory path to list files from.
    /// - Returns: An array of file paths with the extension ".swift" within the specified directory path.
    func listFiles(atPath path: String) -> [String] {
        do {
            let contents = try contentsOfDirectory(atPath: path)
            var paths: [String] = []

            for item in contents {
                let itemPath = "\(path)/\(item)"
                if item.hasSuffix(".swift") {
                    paths.append(itemPath)
                }

                if (try? contentsOfDirectory(atPath: itemPath)) != nil {
                    paths += listFiles(atPath: itemPath)
                }
            }

            return paths
        } catch {
            Logger.print("Error: \(error)")
            return []
        }
    }
}
