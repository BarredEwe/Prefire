import Foundation
@testable import PrefireCore
import XCTest

final class DirectLaunchTests: XCTestCase {
    private var directory: URL!
    private var products: URL!
    private var deviceSet: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("DirectLaunchTests-\(UUID().uuidString)")
        products = directory.appendingPathComponent("Products")
        try FileManager.default.createDirectory(at: products, withIntermediateDirectories: true)
        deviceSet = directory.appendingPathComponent("Devices")
        let device = deviceSet.appendingPathComponent("BOOTED")
        try FileManager.default.createDirectory(at: device, withIntermediateDirectories: true)
        let plist: [String: Any] = ["UDID": "BOOTED", "name": "iPhone 16", "runtime": "com.apple.CoreSimulator.SimRuntime.iOS-26-1", "state": 3]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: device.appendingPathComponent("device.plist"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - .xctestrun

    func test_targets_readFormat1() throws {
        let url = try writeTestRun()

        let target = try XCTUnwrap(XCTestRun.targets(in: url).first)

        XCTAssertEqual(target.name, "AppTests")
        XCTAssertEqual(target.moduleName, "AppTests")
        XCTAssertEqual(target.testHostPath, products.path + "/Debug-iphonesimulator/App.app")
        XCTAssertEqual(target.testHostBundleIdentifier, "com.example.app")
        XCTAssertEqual(target.testBundlePath, "__TESTHOST__/PlugIns/AppTests.xctest")
        XCTAssertTrue(target.isAppHosted)
        XCTAssertFalse(target.isUITest)
    }

    func test_targets_readFormat2() throws {
        let url = products.appendingPathComponent("App_Plan_iphonesimulator26.0-arm64.xctestrun")
        let plist: [String: Any] = [
            "__xctestrun_metadata__": ["FormatVersion": 2],
            "TestConfigurations": [[
                "Name": "Default",
                "TestTargets": [[
                    "BlueprintName": "AppSnapshotTests",
                    "ProductModuleName": "AppSnapshotTests",
                    "TestBundlePath": "__TESTHOST__/PlugIns/AppSnapshotTests.xctest",
                    "TestHostPath": "__TESTROOT__/Debug-iphonesimulator/App.app",
                    "IsAppHostedTestBundle": true,
                ]],
            ]],
        ]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: url)

        let targets = try XCTestRun.targets(in: url)

        XCTAssertEqual(targets.map(\.name), ["AppSnapshotTests"])
        XCTAssertEqual(targets.first?.testHostPath, products.path + "/Debug-iphonesimulator/App.app")
    }

    func test_launchEnvironment_injectsTheBundle_withoutXcodeTools() throws {
        let target = try XCTUnwrap(XCTestRun.targets(in: writeTestRun()).first)

        let environment = XCTestRun.launchEnvironment(
            for: target,
            container: "/sim/App.app",
            executable: "/sim/App.app/App",
            platforms: "/Xcode/Platforms"
        )

        XCTAssertEqual(environment["DYLD_INSERT_LIBRARIES"], "/sim/App.app/Frameworks/libXCTestBundleInject.dylib")
        XCTAssertEqual(environment["XCInjectBundleInto"], "/sim/App.app/App")
        XCTAssertEqual(environment["XCTestBundlePath"], "/sim/App.app/PlugIns/AppTests.xctest")
        XCTAssertEqual(environment["DYLD_FRAMEWORK_PATH"], "\(products.path)/Debug-iphonesimulator:/Xcode/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks")
        XCTAssertEqual(environment["SCHEME_VALUE"], "1")
        XCTAssertNil(environment["PERFC_ENABLE_PROFILE_MODE"])
    }

    func test_selectors_qualifyClassesWithTheModule() throws {
        let target = try XCTUnwrap(XCTestRun.targets(in: writeTestRun()).first)

        XCTAssertEqual(
            XCTestRun.selectors(for: ["AppTests/PreviewTests/test_Button_Preview", "AppTests/LoginTests", "OtherTests/X/test"], target: target),
            ["AppTests.PreviewTests/test_Button_Preview", "AppTests.LoginTests"]
        )
        XCTAssertEqual(XCTestRun.selectors(for: ["AppTests"], target: target), [])
    }

    // MARK: - Simulator

    private let devices = Data("""
    {"devices": {
      "com.apple.CoreSimulator.SimRuntime.iOS-18-2": [
        {"udid": "OLD", "name": "iPhone 16", "state": "Shutdown", "isAvailable": true}
      ],
      "com.apple.CoreSimulator.SimRuntime.iOS-26-1": [
        {"udid": "NEW", "name": "iPhone 16", "state": "Shutdown", "isAvailable": true},
        {"udid": "BOOTED", "name": "iPhone 16", "state": "Booted", "isAvailable": true}
      ],
      "com.apple.CoreSimulator.SimRuntime.tvOS-26-1": [
        {"udid": "TV", "name": "Apple TV", "state": "Shutdown", "isAvailable": true}
      ]
    }}
    """.utf8)

    func test_device_prefersTheNewestSystem_andABootedOne() {
        XCTAssertEqual(SimulatorTestLauncher.device(for: "platform=iOS Simulator,name=iPhone 16", in: devices)?.udid, "BOOTED")
        XCTAssertEqual(SimulatorTestLauncher.device(for: "platform=iOS Simulator,name=iPhone 16,OS=18.2", in: devices)?.udid, "OLD")
        XCTAssertEqual(SimulatorTestLauncher.device(for: "platform=iOS Simulator,id=NEW", in: devices)?.udid, "NEW")
        XCTAssertEqual(SimulatorTestLauncher.device(for: "platform=tvOS Simulator,name=Apple TV", in: devices)?.udid, "TV")
    }

    func test_devices_areReadFromTheDeviceSet() {
        XCTAssertEqual(
            SimulatorTestLauncher.devices(inDeviceSet: deviceSet),
            [SimulatorDevice(udid: "BOOTED", name: "iPhone 16", runtime: "com.apple.CoreSimulator.SimRuntime.iOS-26-1", isBooted: true)]
        )
    }

    func test_device_isNil_forAMacOrAnUnknownName() {
        XCTAssertNil(SimulatorTestLauncher.device(for: "platform=macOS", in: devices))
        XCTAssertNil(SimulatorTestLauncher.device(for: "platform=iOS Simulator,name=iPhone 99", in: devices))
    }

    func test_testsFinished_waitsForTheSummaryOfTheWholeRun() {
        let suite = "Test Suite 'UpgradeViewTests' passed at 2026-10-26 00:21:42.087.\n\t Executed 1 test, with 0 failures (0 unexpected) in 0.05 seconds\n"
        let top = "Test Suite 'Selected tests' passed at 2026-10-26 00:21:42.087.\n"

        XCTAssertFalse(SimulatorTestLauncher.testsFinished(suite))
        XCTAssertFalse(SimulatorTestLauncher.testsFinished(suite + top))
        XCTAssertTrue(SimulatorTestLauncher.testsFinished(suite + top + "\t Executed 1 test, with 0 failures (0 unexpected) in 0.05 seconds\n"))
        XCTAssertTrue(SimulatorTestLauncher.testsFinished("Test Suite 'All tests' failed at 1.\n\t Executed 2 tests, with 1 failure (0 unexpected) in 1 seconds\n"))
    }

    func test_status_readsTheLastSummary() {
        XCTAssertEqual(SimulatorTestLauncher.status(ofTestOutput: "\t Executed 3 tests, with 0 failures (0 unexpected) in 0.1 seconds\n"), 0)
        XCTAssertEqual(SimulatorTestLauncher.status(ofTestOutput: "\t Executed 3 tests, with 1 failure (0 unexpected) in 0.1 seconds\n"), 1)
        XCTAssertEqual(SimulatorTestLauncher.status(ofTestOutput: "Test Case '-[A b]' started.\n"), 1)
    }

    // MARK: - Render

    func test_render_buildsOnce_andLaunchesTheTestsOnTheSimulator() throws {
        let log = CallLog()
        let source = directory.appendingPathComponent("Button.swift")
        try Data("#Preview(\"Button\") { Text(\"Button\") }\n".utf8).write(to: source)
        var service = RenderService(
            configuration: RenderConfiguration(
                scheme: "App", project: "App.xcodeproj", destination: "platform=iOS Simulator,name=iPhone 16",
                testTarget: "AppTests", outputDirectory: directory.appendingPathComponent("render"), sources: [source.path]
            ),
            runner: simulatorRunner(log: log),
            makeRunID: { "run" }
        )
        service.simulatorDeviceSet = deviceSet

        let result = try service.render(RenderRequest(previews: ["Button"]))

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.manifest.previews.map(\.record.name), ["Button"])

        let build = try XCTUnwrap(log.runs.first { $0.arguments.contains("build-for-testing") })
        XCTAssertTrue(build.arguments.contains("-disableAutomaticPackageResolution"))
        XCTAssertNil(build.environment["PREFIRE_RENDER"], "The options change on every render and would have Xcode plan the build anew")
        XCTAssertFalse(log.runs.contains { $0.arguments.contains("test") || $0.arguments.contains("test-without-building") })
        XCTAssertTrue(log.runs.contains { $0.arguments.starts(with: ["simctl", "install", "BOOTED"]) })

        let launch = try XCTUnwrap(log.runs.first { $0.arguments.starts(with: ["simctl", "launch"]) })
        XCTAssertEqual(Array(launch.arguments.suffix(2)), ["-XCTest", "AppTests.PreviewTests/test_Button_Preview"])
        XCTAssertNotNil(launch.environment["SIMCTL_CHILD_PREFIRE_RENDER"])
        XCTAssertTrue(launch.environment["SIMCTL_CHILD_XCInjectBundleInto"]?.hasSuffix("/Devices/BOOTED/data/Containers/Bundle/Application/NEW/App.app/App") == true)
    }

    func test_render_copiesChangedFiles_intoAnInstalledApp() throws {
        let log = CallLog()
        try writeTestRun()
        let installed = deviceSet.appendingPathComponent("BOOTED/data/Containers/Bundle/Application/ABC/App.app")
        try FileManager.default.createDirectory(at: installed, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: products.appendingPathComponent("Debug-iphonesimulator/App.app/Info.plist"),
            to: installed.appendingPathComponent("Info.plist")
        )
        var service = RenderService(
            configuration: RenderConfiguration(
                scheme: "App", destination: "platform=iOS Simulator,name=iPhone 16",
                testTarget: "AppTests", outputDirectory: directory.appendingPathComponent("render")
            ),
            runner: simulatorRunner(log: log),
            makeRunID: { "run" }
        )
        service.simulatorDeviceSet = deviceSet

        _ = try service.render(RenderRequest(previews: ["Button"]))

        XCTAssertTrue(log.runs.contains { $0.arguments.first == "-a" && $0.arguments.last?.hasSuffix("/Application/ABC/App.app/") == true })
        XCTAssertFalse(log.runs.contains { $0.arguments.starts(with: ["simctl", "install"]) })
    }

    func test_render_runsTestWithoutBuilding_onAMac() throws {
        let log = CallLog()
        var service = RenderService(
            configuration: RenderConfiguration(
                scheme: "App", destination: "platform=macOS",
                testTarget: "AppTests", outputDirectory: directory.appendingPathComponent("render")
            ),
            runner: simulatorRunner(log: log, rendersOn: ["test-without-building"]),
            makeRunID: { "run" }
        )
        service.simulatorDeviceSet = deviceSet

        let result = try service.render(RenderRequest(previews: ["Button"]))

        XCTAssertEqual(result.manifest.previews.count, 1)
        let run = try XCTUnwrap(log.runs.first { $0.arguments.contains("test-without-building") })
        XCTAssertTrue(run.arguments.contains("-xctestrun"))
        XCTAssertNotNil(run.environment["TEST_RUNNER_PREFIRE_RENDER"])
    }

    func test_render_resolvesPackages_whenPackageResolvedIsOutOfDate() throws {
        let log = CallLog()
        var builds = 0
        let base = simulatorRunner(log: log)
        let runner = FakeRunner(
            run: { arguments, environment, logFile in
                if arguments.contains("build-for-testing") {
                    builds += 1
                    if builds == 1 {
                        log.runs.append((arguments, environment))
                        try Data("error: Package.resolved is out of date\n".utf8).write(to: logFile)
                        return 74
                    }
                }
                return try base.run(executable: "", arguments: arguments, environment: environment, logFile: logFile)
            },
            capture: base.captureBody
        )
        var service = RenderService(
            configuration: RenderConfiguration(
                scheme: "App", destination: "platform=iOS Simulator,name=iPhone 16",
                testTarget: "AppTests", outputDirectory: directory.appendingPathComponent("render")
            ),
            runner: runner,
            makeRunID: { "run" }
        )
        service.simulatorDeviceSet = deviceSet

        _ = try service.render(RenderRequest(previews: ["Button"]))

        let buildRuns = log.runs.filter { $0.arguments.contains("build-for-testing") }
        XCTAssertEqual(buildRuns.count, 2)
        XCTAssertFalse(buildRuns[1].arguments.contains("-disableAutomaticPackageResolution"))
    }

    func test_render_reportsABrokenBuild_withoutRunningTheTests() throws {
        let log = CallLog()
        let runner = FakeRunner(
            run: { arguments, environment, _ in
                log.runs.append((arguments, environment))
                return 65
            },
            capture: { _ in (1, "") }
        )
        var service = RenderService(
            configuration: RenderConfiguration(scheme: "App", testTarget: "AppTests", outputDirectory: directory.appendingPathComponent("render")),
            runner: runner
        )
        service.simulatorDeviceSet = deviceSet

        XCTAssertThrowsError(try service.render(RenderRequest())) { error in
            guard case RenderError.nothingRendered(65, _) = error else { return XCTFail("Unexpected error \(error)") }
        }
        XCTAssertEqual(log.runs.count, 1)
    }

    func test_testIdentifiers_listTheTestsToRun_whenSomeAreSkipped() {
        let catalog = [
            PreviewEntry(name: "A", kind: .macro, file: "", line: 1, testClass: "ATests", testMethod: "test_A_Preview", isScreen: false),
            PreviewEntry(name: "Card_Previews", kind: .provider, file: "", line: 1, testClass: "ATests", testMethod: "test_card", isScreen: false),
            PreviewEntry(name: "B", kind: .macro, file: "", line: 1, testClass: "BTests", testMethod: "test_B_Preview", isScreen: false),
        ]
        let plan = RenderService.plan(for: RenderRequest(), catalog: catalog, testTarget: "T")

        XCTAssertEqual(plan.skipTesting, ["T/BTests/test_card"])
        XCTAssertEqual(
            RenderService.testIdentifiers(for: plan, catalog: catalog, testTarget: "T"),
            ["T/ATests/test_A_Preview", "T/ATests/test_card", "T/BTests/test_B_Preview"]
        )
    }

    func test_symroot_isReadFromTheBuildSettings() {
        XCTAssertEqual(RenderService.symroot(inBuildSettings: "Build settings for action build:\n    SDKROOT = /sdk\n    SYMROOT = /Derived/Build/Products\n"), "/Derived/Build/Products")
    }

    // MARK: - Helpers

    private final class CallLog: @unchecked Sendable {
        var runs: [(arguments: [String], environment: [String: String])] = []
    }

    /// A runner that acts like `xcodebuild` and `simctl`: the build writes an `.xctestrun`, and the
    /// launch (or `rendersOn`) writes a record and the run marker.
    private func simulatorRunner(log: CallLog, rendersOn: [String] = ["launch"]) -> FakeRunner {
        let products = products!
        let deviceSet = deviceSet!
        return FakeRunner(
            run: { arguments, environment, logFile in
                log.runs.append((arguments, environment))
                if arguments.contains("build-for-testing") {
                    _ = try self.writeTestRun()
                }
                if arguments.starts(with: ["simctl", "install"]) {
                    let app = deviceSet.appendingPathComponent("\(arguments[2])/data/Containers/Bundle/Application/NEW/App.app")
                    try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
                    try FileManager.default.copyItem(at: URL(fileURLWithPath: arguments[3]).appendingPathComponent("Info.plist"), to: app.appendingPathComponent("Info.plist"))
                }
                if arguments.contains(where: rendersOn.contains) {
                    let json = environment["SIMCTL_CHILD_PREFIRE_RENDER"] ?? environment["TEST_RUNNER_PREFIRE_RENDER"] ?? ""
                    let options = try JSONDecoder().decode(RenderOptions.self, from: Data(json.utf8))
                    let output = URL(fileURLWithPath: options.directory)
                    try Data(options.runID.utf8).write(to: output.appendingPathComponent(RenderOptions.runMarkerFileName))
                    try JSONEncoder().encode(RenderRecord(runID: options.runID, name: "Button", image: "Button.png")).write(to: output.appendingPathComponent("Button.json"))
                    try Data([0x89]).write(to: output.appendingPathComponent("Button.png"))
                    try Data("\t Executed 1 test, with 0 failures (0 unexpected) in 0.1 seconds\n".utf8).write(to: logFile)
                }
                return 0
            },
            capture: { command in
                switch Array(command.dropFirst()).prefix(2) {
                case ["xcodebuild", "-showBuildSettings"]:
                    return (0, "    SYMROOT = \(products.path)\n")
                case ["simctl", "list"]:
                    return (0, String(decoding: self.devices, as: UTF8.self))
                default:
                    return command.first == "/usr/bin/xcode-select" ? (0, "/Xcode") : (1, "")
                }
            }
        )
    }

    @discardableResult
    private func writeTestRun() throws -> URL {
        let app = products.appendingPathComponent("Debug-iphonesimulator/App.app")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        try PropertyListSerialization.data(fromPropertyList: ["CFBundleExecutable": "App", "CFBundleIdentifier": "com.example.app"], format: .xml, options: 0)
            .write(to: app.appendingPathComponent("Info.plist"))

        let url = products.appendingPathComponent("App_iphonesimulator26.0-arm64.xctestrun")
        let plist: [String: Any] = [
            "__xctestrun_metadata__": ["FormatVersion": 1],
            "AppTests": [
                "ProductModuleName": "AppTests",
                "TestBundlePath": "__TESTHOST__/PlugIns/AppTests.xctest",
                "TestHostPath": "__TESTROOT__/Debug-iphonesimulator/App.app",
                "TestHostBundleIdentifier": "com.example.app",
                "IsAppHostedTestBundle": true,
                "EnvironmentVariables": ["PERFC_ENABLE_PROFILE_MODE": "1", "SCHEME_VALUE": "1", "DYLD_INSERT_LIBRARIES": "/usr/lib/libRPAC.dylib"],
                "TestingEnvironmentVariables": [
                    "DYLD_FRAMEWORK_PATH": "__TESTROOT__/Debug-iphonesimulator:__PLATFORMS__/iPhoneSimulator.platform/Developer/Library/Frameworks",
                    "DYLD_INSERT_LIBRARIES": "__TESTHOST__/Frameworks/libXCTestBundleInject.dylib:__SIMRUNTIMEROOT__/usr/lib/libMainThreadChecker.dylib",
                    "XCInjectBundleInto": "unused",
                ],
            ],
        ]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: url)
        return url
    }
}
