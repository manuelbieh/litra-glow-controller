import Foundation
import IOKit
import IOKit.hid

enum LitraError: Error { case noDevices, writeFailed(IOReturn) }

enum LitraTarget: Equatable {
    case all
    case serial(String)
}

struct LitraDevice {
    let serial: String
    let hidDevice: IOHIDDevice
    var displayName: String {
        let suffix = serial.suffix(4)
        return "Litra Glow (…\(suffix))"
    }
}

final class Litra {
    static let vendorID = 0x046D
    static let productID = 0xC900

    static let brightnessMin = 20
    static let brightnessMax = 250
    static let temperatureMin = 2700
    static let temperatureMax = 6500

    private let manager: IOHIDManager
    private(set) var devices: [LitraDevice] = []

    /// Invoked on the main thread whenever a Litra is plugged in or unplugged.
    var onDevicesChanged: (() -> Void)?

    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let match: [String: Any] = [
            kIOHIDVendorIDKey: Self.vendorID,
            kIOHIDProductIDKey: Self.productID,
        ]
        IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        let ctx = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { ctx, _, _, device in
            guard let ctx = ctx else { return }
            let litra = Unmanaged<Litra>.fromOpaque(ctx).takeUnretainedValue()
            litra.deviceMatched(device)
        }, ctx)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { ctx, _, _, device in
            guard let ctx = ctx else { return }
            let litra = Unmanaged<Litra>.fromOpaque(ctx).takeUnretainedValue()
            litra.deviceRemoved(device)
        }, ctx)

        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    deinit {
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    // MARK: - Device tracking

    private func serial(of device: IOHIDDevice) -> String {
        let value = IOHIDDeviceGetProperty(device, kIOHIDSerialNumberKey as CFString)
        return (value as? String) ?? "unknown"
    }

    private func deviceMatched(_ device: IOHIDDevice) {
        IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        let entry = LitraDevice(serial: serial(of: device), hidDevice: device)
        devices.append(entry)
        devices.sort { $0.serial < $1.serial }
        onDevicesChanged?()
    }

    private func deviceRemoved(_ device: IOHIDDevice) {
        devices.removeAll { $0.hidDevice == device }
        onDevicesChanged?()
    }

    // MARK: - Commands

    func turnOn(_ target: LitraTarget = .all) throws {
        try send([0x11, 0xff, 0x04, 0x1c, 0x01], to: target)
    }

    func turnOff(_ target: LitraTarget = .all) throws {
        try send([0x11, 0xff, 0x04, 0x1c, 0x00], to: target)
    }

    func setBrightness(_ level: Int, _ target: LitraTarget = .all) throws {
        let clamped = max(Self.brightnessMin, min(Self.brightnessMax, level))
        let lo = UInt8(clamped & 0xff)
        let hi = UInt8((clamped >> 8) & 0xff)
        try send([0x11, 0xff, 0x04, 0x4c, 0x00, lo, hi], to: target)
    }

    func setTemperature(_ kelvin: Int, _ target: LitraTarget = .all) throws {
        let clamped = max(Self.temperatureMin, min(Self.temperatureMax, kelvin))
        let hi = UInt8((clamped >> 8) & 0xff)
        let lo = UInt8(clamped & 0xff)
        try send([0x11, 0xff, 0x04, 0x9c, hi, lo], to: target)
    }

    // MARK: - Transport

    private func resolveTargets(_ target: LitraTarget) throws -> [LitraDevice] {
        guard !devices.isEmpty else { throw LitraError.noDevices }
        switch target {
        case .all:
            return devices
        case .serial(let s):
            let matched = devices.filter { $0.serial == s }
            // If the remembered serial is no longer connected, fall back to all.
            return matched.isEmpty ? devices : matched
        }
    }

    private func send(_ payload: [UInt8], to target: LitraTarget) throws {
        let targets = try resolveTargets(target)
        var report = [UInt8](repeating: 0, count: 20)
        for (i, b) in payload.enumerated() where i < report.count { report[i] = b }
        let reportID = CFIndex(report[0])
        for dev in targets {
            let result = report.withUnsafeBufferPointer { buf -> IOReturn in
                IOHIDDeviceSetReport(dev.hidDevice, kIOHIDReportTypeOutput, reportID, buf.baseAddress!, buf.count)
            }
            guard result == kIOReturnSuccess else { throw LitraError.writeFailed(result) }
        }
    }
}
