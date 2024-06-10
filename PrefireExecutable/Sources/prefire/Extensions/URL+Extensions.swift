import Foundation

extension URL {
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    var fileName: String {
        lastPathComponent.split(separator: ".").first.flatMap(String.init) ?? lastPathComponent
    }
}
