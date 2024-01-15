import Foundation

extension Array<String> {
    func makeArgs(name: String) -> [String] {
        var values = self

        // It is used so that sourcery can determine the type of the parameter as an array
        values.append("last")
        let arguments = values.map { name + "=" + $0 }.joined(separator: ",")

        return ["--args", arguments]
    }
}
