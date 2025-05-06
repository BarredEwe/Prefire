import Foundation

extension String {
    /// Overwriting a file with content in the specified path
    /// - Parameter path: The path to the file to overwrite
    func rewrite(toFile url: URL?) throws {
        guard let url else {
            throw NSError(domain: "❌ Invalid file path: Unable to rewrite file because path is nil.", code: 0)
        }

        let filePath = url.absoluteString
        let folderPath = url.deletingLastPathComponent().absoluteString
        
        try? FileManager.default.removeItem(atPath: filePath)
        try FileManager.default.createDirectory(atPath: folderPath, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: filePath, contents: nil)
        
        try self.write(toFile: filePath, atomically: true, encoding: .utf8)
    }
    
    /// Indents the lines in the receiver
    ///
    /// - Parameters:
    ///   - amount: A int specifies the amount of indentString for one level idnentation
    func ident(_ count: Int) -> String {
        components(separatedBy: "\n").map({ String(repeating: " ", count: count) + $0 }).joined(separator: "\n")
    }
}
