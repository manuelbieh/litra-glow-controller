import Foundation
import IOKit
import IOKit.hid

enum LitraError: Error { case notFound, writeFailed(IOReturn) }

final class Litra {
    static let vendorID: Int = 0x046D
    static let productID: Int = 0xC900

    static let brightnessMin = 20
    static let brightnessMax = 250
    static let temperatureMin = 2700
    static let temperatureMax = 6500

    private var device: IOHIDDevice?
    private let manager: IOHIDManager

    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let match: [String: Any] = [
            kIOHIDVendorIDKey: Self.vendorID,
            kIOHIDProductIDKey: Self.productID,
        ]
        IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    deinit {
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    var isConnected: Bool {
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return false }
        return !devices.isEmpty
    }

    private func resolveDevice() throws -> IOHIDDevice {
        if let d = device { return d }
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              let d = devices.first else {
            throw LitraError.notFound
        }
        IOHIDDeviceOpen(d, IOOptionBits(kIOHIDOptionsTypeNone))
        device = d
        return d
    }

    private func send(_ payload: [UInt8]) throws {
        let d = try resolveDevice()
        var report = [UInt8](repeating: 0, count: 20)
        for (i, b) in payload.enumerated() where i < report.count { report[i] = b }
        let reportID: CFIndex = CFIndex(report[0])
        let result = report.withUnsafeBufferPointer { buf -> IOReturn in
            IOHIDDeviceSetReport(d, kIOHIDReportTypeOutput, reportID, buf.baseAddress!, buf.count)
        }
        guard result == kIOReturnSuccess else { throw LitraError.writeFailed(result) }
    }

    func turnOn() throws  { try send([0x11, 0xff, 0x04, 0x1c, 0x01]) }
    func turnOff() throws { try send([0x11, 0xff, 0x04, 0x1c, 0x00]) }

    func setBrightness(_ level: Int) throws {
        let clamped = max(Self.brightnessMin, min(Self.brightnessMax, level))
        let lo = UInt8(clamped & 0xff)
        let hi = UInt8((clamped >> 8) & 0xff)
        try send([0x11, 0xff, 0x04, 0x4c, 0x00, lo, hi])
    }

    func setTemperature(_ kelvin: Int) throws {
        let clamped = max(Self.temperatureMin, min(Self.temperatureMax, kelvin))
        let hi = UInt8((clamped >> 8) & 0xff)
        let lo = UInt8(clamped & 0xff)
        try send([0x11, 0xff, 0x04, 0x9c, hi, lo])
    }
}
