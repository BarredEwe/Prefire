import Foundation

extension Array<String> {
    /// Creating an array of arguments for further transmission to Sourcery
    /// - Parameter name: The name of the argument
    /// - Returns: Array of arguments in the Sourcery format
    func makeSourceryArgs(name: String) -> [String] {
        var values = self

        // It is used so that sourcery can determine the type of the parameter as an array
        values.append("last")
        let arguments = values.map { name + "=" + $0 }

        return ["--args", arguments.joined(separator: ",")]
    }
}
