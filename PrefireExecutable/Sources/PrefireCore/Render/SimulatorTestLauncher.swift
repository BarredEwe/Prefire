import Foundation

/// A simulator `simctl` lists.
struct SimulatorDevice: Equatable, Sendable {
    var udid: String
    var name: String
    /// Like `com.apple.CoreSimulator.SimRuntime.iOS-26-1`.
    var runtime: String
    var isBooted: Bool

    /// `26.1` of `...SimRuntime.iOS-26-1`.
    var version: [Int] {
        let suffix = runtime.split(separator: ".").last.map(String.init) ?? ""
        return suffix.split(separator: "-").dropFirst().compactMap { Int($0) }
    }
}

/// Launches app-hosted tests on a simulator with `simctl`, the way `xcodebuild` has the host app
/// load the test bundle, but without the test session `xcodebuild` sets up around it, which takes
/// most of the time of a render.
struct SimulatorTestLauncher {
    /// Simulators `simctl` manages by default.
    static let defaultDeviceSet = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Developer/CoreSimulator/Devices", isDirectory: true)

    let runner: any ProcessRunning
    /// Folder of the simulators, read directly: every `simctl` command takes over a second.
    var deviceSet: URL = defaultDeviceSet

    /// Simulator a `-destination` names among the `devices` of `simctl list devices --json`, or
    /// `nil` when it names none, like a Mac.
    static func device(for destination: String, in devicesJSON: Data) -> SimulatorDevice? {
        guard let json = try? JSONSerialization.jsonObject(with: devicesJSON) as? [String: Any],
              let byRuntime = json["devices"] as? [String: [[String: Any]]] else { return nil }
        let devices = byRuntime.flatMap { runtime, devices in
            devices.compactMap { device -> SimulatorDevice? in
                guard device["isAvailable"] as? Bool ?? true,
                      let udid = device["udid"] as? String, let name = device["name"] as? String else { return nil }
                return SimulatorDevice(udid: udid, name: name, runtime: runtime, isBooted: device["state"] as? String == "Booted")
            }
        }
        return device(for: destination, among: devices)
    }

    /// Simulators in `deviceSet`, read from their `device.plist`.
    static func devices(inDeviceSet deviceSet: URL) -> [SimulatorDevice] {
        let folders = (try? FileManager.default.contentsOfDirectory(at: deviceSet, includingPropertiesForKeys: nil)) ?? []
        return folders.compactMap { folder in
            guard let data = try? Data(contentsOf: folder.appendingPathComponent("device.plist")),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  plist["isDeleted"] as? Bool != true,
                  let udid = plist["UDID"] as? String, let name = plist["name"] as? String,
                  let runtime = plist["runtime"] as? String else { return nil }
            // CoreSimulator's state 3 is booted.
            return SimulatorDevice(udid: udid, name: name, runtime: runtime, isBooted: plist["state"] as? Int == 3)
        }
    }

    /// Simulator a `-destination` names among `devices`, or `nil` when it names none, like a Mac.
    static func device(for destination: String, among devices: [SimulatorDevice]) -> SimulatorDevice? {
        var keys: [String: String] = [:]
        for part in destination.split(separator: ",") {
            let pair = part.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if pair.count == 2 { keys[pair[0].lowercased()] = pair[1] }
        }
        guard let platform = keys["platform"], platform.hasSuffix("Simulator") else { return nil }
        let os = platform.replacingOccurrences(of: " Simulator", with: "")

        if let id = keys["id"] {
            return devices.first { $0.udid == id }
        }
        guard let name = keys["name"] else { return nil }
        let wantedVersion = keys["os"].flatMap { $0 == "latest" ? nil : $0.split(separator: ".").compactMap { Int($0) } }
        return devices
            .filter { $0.name == name && $0.runtime.contains("SimRuntime.\(os)-") }
            .filter { device in wantedVersion.map { Array(device.version.prefix($0.count)) == $0 } ?? true }
            // The newest system, and a booted one first: it starts right away.
            .max { lhs, rhs in
                lhs.version != rhs.version ? lhs.version.lexicographicallyPrecedes(rhs.version) : (!lhs.isBooted && rhs.isBooted)
            }
    }

    /// Installs the host app of `target` on the simulator and runs the tests `selectors` names in
    /// it, all of them when empty, writing their output to `logFile`.
    ///
    /// - Returns: Exit status: not 0 when a test failed or the host app stopped before the tests
    ///   finished. `nil` when the tests could not be launched this way.
    func run(
        target: XCTestRunTarget,
        destination: String,
        selectors: [String],
        environment: [String: String],
        logFile: URL
    ) throws -> Int32? {
        guard target.isAppHosted, !target.isUITest,
              let hostPath = target.testHostPath, let bundleID = target.testHostBundleIdentifier,
              let executableName = Self.executableName(ofApp: hostPath),
              let developerDirectory = try capture(["/usr/bin/xcode-select", "-p"]),
              let device = try device(for: destination) else { return nil }

        let started = Date()
        let step = { (name: String) in Logger.verbose(String(format: "  %@: %.1f s", name, Date().timeIntervalSince(started))) }
        step("Found \(device.name), \(device.udid)")

        if !device.isBooted {
            _ = try runner.run(executable: "/usr/bin/xcrun", arguments: ["simctl", "boot", device.udid], environment: [:], logFile: logFile)
            _ = try runner.run(executable: "/usr/bin/xcrun", arguments: ["simctl", "bootstatus", device.udid, "-b"], environment: [:], logFile: logFile)
        }
        guard let container = try install(app: hostPath, bundleID: bundleID, on: device.udid, logFile: logFile) else { return nil }
        step("Installed the host app")

        let launchEnvironment = XCTestRun.launchEnvironment(
            for: target,
            container: container,
            executable: "\(container)/\(executableName)",
            platforms: "\(developerDirectory)/Platforms"
        ).merging(environment) { _, rendered in rendered }

        var processEnvironment = ProcessInfo.processInfo.environment
        for (key, value) in launchEnvironment {
            processEnvironment["SIMCTL_CHILD_" + key] = value
        }
        var arguments = ["simctl", "launch", "--console-pty", "--terminate-running-process", device.udid, bundleID]
        if !selectors.isEmpty {
            arguments += ["-XCTest", selectors.joined(separator: ",")]
        }
        arguments += target.commandLineArguments

        // The host app takes a second to quit after the tests; their summary is all a render needs.
        _ = try runner.run(executable: "/usr/bin/xcrun", arguments: arguments, environment: processEnvironment, logFile: logFile, until: Self.testsFinished)
        step("Ran the tests")
        return Self.status(ofTestOutput: (try? String(contentsOf: logFile, encoding: .utf8)) ?? "")
    }

    /// Simulator `destination` names, from the device set, or from `simctl` when that has none.
    private func device(for destination: String) throws -> SimulatorDevice? {
        if let device = Self.device(for: destination, among: Self.devices(inDeviceSet: deviceSet)) {
            return device
        }
        guard let list = try capture(["/usr/bin/xcrun", "simctl", "list", "devices", "available", "--json"]) else { return nil }
        return Self.device(for: destination, in: Data(list.utf8))
    }

    /// Path of the app `bundleID` installed on simulator `udid`, read from its containers.
    func installedApp(bundleID: String, udid: String) -> String? {
        let applications = deviceSet.appendingPathComponent("\(udid)/data/Containers/Bundle/Application", isDirectory: true)
        let containers = (try? FileManager.default.contentsOfDirectory(at: applications, includingPropertiesForKeys: nil)) ?? []
        for container in containers {
            let apps = (try? FileManager.default.contentsOfDirectory(at: container, includingPropertiesForKeys: nil)) ?? []
            for app in apps where app.pathExtension == "app" {
                guard let data = try? Data(contentsOf: app.appendingPathComponent("Info.plist")),
                      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                      plist["CFBundleIdentifier"] as? String == bundleID else { continue }
                return app.path
            }
        }
        return nil
    }

    /// Puts the host app at `path` on the simulator.
    ///
    /// `simctl install` copies and registers the whole app, which takes seconds. Once the app is
    /// installed, only the files a build changed are copied into its container; a changed
    /// `Info.plist` needs registering again, so it gets a full install.
    ///
    /// - Returns: Path of the installed app.
    private func install(app path: String, bundleID: String, on udid: String, logFile: URL) throws -> String? {
        let containerCommand = ["/usr/bin/xcrun", "simctl", "get_app_container", udid, bundleID]
        if let installed = installedApp(bundleID: bundleID, udid: udid), Self.sameInfoPlist(path, installed),
           try runner.run(executable: "/usr/bin/rsync", arguments: ["-a", "--delete", path + "/", installed + "/"], environment: [:], logFile: logFile) == 0 {
            return installed
        }
        guard try runner.run(executable: "/usr/bin/xcrun", arguments: ["simctl", "install", udid, path], environment: [:], logFile: logFile) == 0 else { return nil }
        return try installedApp(bundleID: bundleID, udid: udid) ?? capture(containerCommand)
    }

    private static func sameInfoPlist(_ lhs: String, _ rhs: String) -> Bool {
        let plist = { (app: String) in try? Data(contentsOf: URL(fileURLWithPath: app).appendingPathComponent("Info.plist")) }
        guard let lhs = plist(lhs) else { return false }
        return lhs == plist(rhs)
    }

    /// Whether `output` holds the summary of the whole test run: the line after its top suite ends.
    static func testsFinished(_ output: String) -> Bool {
        let lines = output.components(separatedBy: .newlines)
        guard let end = lines.lastIndex(where: {
            $0.hasPrefix("Test Suite 'Selected tests'") || $0.hasPrefix("Test Suite 'All tests'")
        }), lines[end].contains(" passed at ") || lines[end].contains(" failed at ") else { return false }
        return lines[(end + 1)...].contains { $0.contains("Executed ") && $0.contains(" with ") }
    }

    /// 0 when the output ends with tests that all passed, 1 when one failed or they never finished.
    static func status(ofTestOutput output: String) -> Int32 {
        guard let summary = output.components(separatedBy: .newlines).last(where: { $0.contains("Executed ") && $0.contains(" with ") }) else {
            return 1
        }
        return summary.contains("with 0 failures") ? 0 : 1
    }

    private static func executableName(ofApp path: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path).appendingPathComponent("Info.plist")),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return nil }
        return plist["CFBundleExecutable"] as? String
    }

    /// Output of `command` without its trailing newline, or `nil` when it failed.
    private func capture(_ command: [String]) throws -> String? {
        let result = try runner.capture(executable: command[0], arguments: Array(command.dropFirst()))
        guard result.status == 0 else { return nil }
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return output.isEmpty ? nil : output
    }
}
