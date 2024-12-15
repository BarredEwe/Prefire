import Foundation

extension FileManager {
    /// This function recursively lists all files with a ".swift" extension within the specified directory path.
    /// - Parameter path:  The directory path to list files from.
    /// - Parameter extension: File extension
    /// - Returns: An array of file paths with the extension within the specified directory path.
    func listFiles(atPath path: String, withExtension extension: String) -> [String] {
        var files = [String]()

        if let enumerator = enumerator(atPath: path) {
            for case let file as String in enumerator {
                if file.hasSuffix(`extension`) {
                    files.append(file)
                }
            }
        }
        return files
    }
}
