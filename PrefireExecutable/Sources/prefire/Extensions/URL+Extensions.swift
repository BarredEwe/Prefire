import Foundation

extension URL {
    var fileName: String {
        lastPathComponent.split(separator: ".").first.flatMap(String.init) ?? lastPathComponent
    }
}
