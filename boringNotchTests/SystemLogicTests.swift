//
//  SystemLogicTests.swift
//  boringNotchTests
//

import XCTest
@testable import boringNotch

final class DeviceBatteryParserTests: XCTestCase {
    func testSystemProfilerConnectedDevices() {
        let json = """
        {"SPBluetoothDataType": [{
          "device_connected": [
            {"LOGI M241": {"device_minorType": "Mouse", "device_batteryLevelMain": "64%"}},
            {"AirPods Pro": {"device_minorType": "Headphones", "device_batteryLevelLeft": "80%",
                             "device_batteryLevelRight": "35%", "device_batteryLevelCase": "10%"}},
            {"iPhone": {"device_minorType": "Phone"}}
          ],
          "device_not_connected": [{"Old Keyboard": {"device_batteryLevelMain": "5%"}}]
        }]}
        """
        let devices = DeviceBatteryParser.parseSystemProfiler(Data(json.utf8))
        XCTAssertEqual(devices.map(\.name).sorted(), ["AirPods Pro", "LOGI M241"])
        XCTAssertEqual(devices.first { $0.name == "AirPods Pro" }?.percent, 35)
        XCTAssertEqual(devices.first { $0.name == "LOGI M241" }?.symbol, "computermouse.fill")
    }

    func testIORegistryPlist() throws {
        let items: [[String: Any]] = [["Product": "Magic Keyboard", "BatteryPercent": 12], ["Product": "No battery"]]
        let data = try PropertyListSerialization.data(fromPropertyList: items, format: .xml, options: 0)
        let devices = DeviceBatteryParser.parseIORegistry(data)
        XCTAssertEqual(devices, [DeviceBattery(name: "Magic Keyboard", kind: "Magic Keyboard", percent: 12)])
    }

    func testMergeKeepsFirstSourcePerName() {
        let a = [DeviceBattery(name: "Mouse", kind: "", percent: 50)]
        let b = [DeviceBattery(name: "Mouse", kind: "", percent: 49), DeviceBattery(name: "Buds", kind: "", percent: 90)]
        XCTAssertEqual(DeviceBatteryParser.merge([a, b]).map(\.percent), [90, 50])
    }
}

final class CallIslandTests: XCTestCase {
    func testFrontmostCallAppWins() {
        let id = CallIslandManager.pickCallApp(frontmost: "us.zoom.xos", running: ["com.apple.FaceTime", "us.zoom.xos"])
        XCTAssertEqual(id, "us.zoom.xos")
    }

    func testFallsBackToRunningCallApp() {
        XCTAssertEqual(CallIslandManager.pickCallApp(frontmost: "com.apple.Safari", running: ["com.hnc.Discord"]), "com.hnc.Discord")
        XCTAssertNil(CallIslandManager.pickCallApp(frontmost: "com.apple.Safari", running: ["com.apple.Notes"]))
    }
}

final class SnapZoneTests: XCTestCase {
    func testZoneSlots() {
        let bar: ClosedRange<CGFloat> = 0...500
        XCTAssertEqual(SnapZone.zone(atX: 10, in: bar), .leftHalf)
        XCTAssertEqual(SnapZone.zone(atX: 250, in: bar), .maximize)
        XCTAssertEqual(SnapZone.zone(atX: 500, in: bar), .rightHalf)
        XCTAssertNil(SnapZone.zone(atX: 600, in: bar))
    }

    func testFramesAndAXConversion() {
        let visible = CGRect(x: 0, y: 0, width: 1500, height: 900)
        XCTAssertEqual(SnapZone.rightThird.frame(in: visible), CGRect(x: 1000, y: 0, width: 500, height: 900))
        // Visible area 900 tall under a 30pt menu bar on a 930pt screen.
        let ax = SnapZone.axRect(SnapZone.leftHalf.frame(in: visible), primaryHeight: 930)
        XCTAssertEqual(ax, CGRect(x: 0, y: 30, width: 750, height: 900))
    }
}
