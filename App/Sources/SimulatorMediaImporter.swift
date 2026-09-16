import Foundation

struct IOSSimulatorDevice: Sendable {
    let name: String
    let udid: String
    let state: String
    let runtimeVersion: String

    var isBooted: Bool {
        state.caseInsensitiveCompare("Booted") == .orderedSame
    }

    var statusLabel: String {
        switch state.lowercased() {
        case "booted":
            return AppStrings.value("simulator.status.running", fallback: "Running")
        case "shutdown":
            return AppStrings.value("simulator.status.shutdown", fallback: "Shut Down")
        default:
            return state
        }
    }

    var selectionTitle: String {
        "\(name)  -  \(runtimeVersion)  -  \(statusLabel)"
    }
}

enum SimulatorMediaImporter {
    static func availableDevices() async throws -> [IOSSimulatorDevice] {
        let result = try await runSimctl(["list", "devices", "--json"])

        let listing: DeviceListing
        do {
            listing = try JSONDecoder().decode(DeviceListing.self, from: Data(result.standardOutput.utf8))
        } catch {
            throw SimulatorMediaError.invalidDeviceList(error.localizedDescription)
        }

        let devices: [IOSSimulatorDevice] = listing.devices.flatMap { runtimeIdentifier, runtimeDevices -> [IOSSimulatorDevice] in
            guard runtimeIdentifier.contains(".SimRuntime.iOS-") else { return [] }

            return runtimeDevices.compactMap { device in
                guard device.isAvailable != false, device.availabilityError?.isEmpty != false else {
                    return nil
                }

                return IOSSimulatorDevice(
                    name: device.name,
                    udid: device.udid,
                    state: device.state,
                    runtimeVersion: runtimeVersion(from: runtimeIdentifier)
                )
            }
        }
        .sorted { (lhs: IOSSimulatorDevice, rhs: IOSSimulatorDevice) in
            if lhs.isBooted != rhs.isBooted {
                return lhs.isBooted
            }
            if lhs.runtimeVersion != rhs.runtimeVersion {
                return lhs.runtimeVersion > rhs.runtimeVersion
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        guard !devices.isEmpty else {
            throw SimulatorMediaError.noAvailableIOSDevices
        }

        return devices
    }

    static func bootIfNeeded(_ device: IOSSimulatorDevice) async throws -> Bool {
        guard !device.isBooted else { return false }

        do {
            _ = try await runSimctl(["boot", device.udid])
        } catch {
            let refreshedDevices = try await availableDevices()
            guard refreshedDevices.first(where: { $0.udid == device.udid })?.isBooted == true else {
                throw error
            }
        }

        _ = try await runSimctl(["bootstatus", device.udid, "-b"])
        return true
    }

    static func addMedia(_ urls: [URL], to device: IOSSimulatorDevice) async throws {
        guard !urls.isEmpty else {
            throw SimulatorMediaError.noMediaFiles
        }

        for url in urls {
            var isDirectory = ObjCBool(false)
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
                throw SimulatorMediaError.invalidMediaPath(url.path)
            }
        }

        _ = try await runSimctl(["addmedia", device.udid] + urls.map(\.path))
    }

    private static func runtimeVersion(from runtimeIdentifier: String) -> String {
        let prefix = "com.apple.CoreSimulator.SimRuntime.iOS-"
        guard runtimeIdentifier.hasPrefix(prefix) else { return "iOS" }

        let version = runtimeIdentifier.dropFirst(prefix.count).replacingOccurrences(of: "-", with: ".")
        return "iOS \(version)"
    }

    private static func runSimctl(_ arguments: [String]) async throws -> CommandResult {
        try await Task.detached(priority: .userInitiated) {
            try Self.runSimctlSynchronously(arguments)
        }.value
    }

    private static func runSimctlSynchronously(_ arguments: [String]) throws -> CommandResult {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl"] + arguments
        process.standardOutput = standardOutput
        process.standardError = standardError

        try process.run()
        standardOutput.fileHandleForWriting.closeFile()
        standardError.fileHandleForWriting.closeFile()
        process.waitUntilExit()

        let output = String(data: standardOutput.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: standardError.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let result = CommandResult(standardOutput: output, standardError: error)

        guard process.terminationStatus == 0 else {
            throw SimulatorMediaError.commandFailed(
                command: (["xcrun", "simctl"] + arguments).joined(separator: " "),
                output: result.message
            )
        }

        return result
    }
}

private struct DeviceListing: Decodable {
    let devices: [String: [RawSimulatorDevice]]
}

private struct RawSimulatorDevice: Decodable {
    let name: String
    let udid: String
    let state: String
    let isAvailable: Bool?
    let availabilityError: String?
}

private struct CommandResult: Sendable {
    let standardOutput: String
    let standardError: String

    var message: String {
        let output = [standardError, standardOutput]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        return output.isEmpty ? "No diagnostic output was returned." : output
    }
}

enum SimulatorMediaError: LocalizedError {
    case noAvailableIOSDevices
    case noMediaFiles
    case invalidMediaPath(String)
    case invalidDeviceList(String)
    case commandFailed(command: String, output: String)

    var errorDescription: String? {
        switch self {
        case .noAvailableIOSDevices:
            return AppStrings.value(
                "simulator.error.no_available_devices",
                fallback: "No available iOS Simulators were found. Install an iOS Simulator runtime in Xcode."
            )
        case .noMediaFiles:
            return AppStrings.value("simulator.error.no_media", fallback: "There are no media files to import.")
        case .invalidMediaPath(let path):
            return AppStrings.format(
                "simulator.error.invalid_media_path",
                fallback: "The media file could not be found: %@",
                path
            )
        case .invalidDeviceList(let message):
            return AppStrings.format(
                "simulator.error.invalid_device_list",
                fallback: "Unable to read the iOS Simulator device list: %@",
                message
            )
        case .commandFailed(let command, let output):
            return AppStrings.format(
                "simulator.error.command_failed",
                fallback: "Command failed: %@\n\n%@",
                command,
                output
            )
        }
    }
}
