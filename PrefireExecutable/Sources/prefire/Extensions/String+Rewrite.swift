import Foundation

extension String {
    /// Overwriting a file with content in the specified path
    /// - Parameter path: The path to the file to overwrite
    func rewrite(toFile path: URL?) {
        guard let url = path else { fatalError("You cannot overwrite a file without a path") }

        let filePath = url.absoluteString
        let folderPath = url.deletingLastPathComponent().absoluteString

        do {
            try? FileManager.default.removeItem(atPath: filePath)
            try FileManager.default.createDirectory(atPath: folderPath, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: filePath, contents: nil)

            try self.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
}
