import Foundation

extension FileManager {
    /// This function recursively lists all files with a ".swift" extension within the specified directory path.
    /// - Parameter url:  The directory url to list files from.
    /// - Parameter extension: File extension
    /// - Returns: An array of file paths with the extension within the specified directory path.
    func listFiles(atURL url: URL, withExtension extension: String) -> [String] {
        var files = [String]()
        let path = url.path()

        if let enumerator = enumerator(atPath: path) {
            for case let file as String in enumerator {
                if file.hasSuffix(`extension`) {
                    files.append(url.appending(path: file).path())
                }
            }
        }
        return files
    }
    
    /// Checks whether a directory exists at the specified URL.
    ///
    /// - Parameter url: The URL to check for the existence of a directory.
    /// - Returns: `true` if the URL points to an existing directory; otherwise, `false`.
    func checkIfDirectoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false

        if self.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            return isDirectory.boolValue
        } else {
            return false
        }
    }
}
