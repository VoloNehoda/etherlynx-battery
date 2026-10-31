import Foundation

struct BTDevice: Identifiable, Equatable {
    var id: String { name }
    var name: String
    var kind: String            // Headphones, Keyboard, Mouse…
    var main: Int?
    var left: Int?
    var right: Int?
    var caseLevel: Int?

    init(name: String, kind: String, main: Int? = nil, left: Int? = nil, right: Int? = nil, caseLevel: Int? = nil) {
        self.name = name; self.kind = kind; self.main = main; self.left = left; self.right = right; self.caseLevel = caseLevel
    }

    /// Найнижчий рівень — за ним сортуємо й сповіщаємо.
    var lowest: Int? { [main, left, right].compactMap { $0 }.min() }

    var symbol: String {
        let k = kind.lowercased(), n = name.lowercased()
        if k == "phone" || n.contains("iphone") { return "iphone" }
        if k == "tablet" || n.contains("ipad") { return "ipad" }
        if k == "watch" { return "applewatch" }
        if n.contains("airpods pro") { return "airpodspro" }
        if n.contains("airpods max") { return "airpodsmax" }
        if n.contains("airpods") { return "airpods" }
        if k.contains("keyboard") { return "keyboard" }
        if k.contains("trackpad") { return "rectangle.and.hand.point.up.left" }
        if k.contains("mouse") { return "magicmouse" }
        if k.contains("headphone") || k.contains("headset") { return "headphones" }
        if k.contains("game") { return "gamecontroller" }
        return "dot.radiowaves.left.and.right"
    }
}

enum DeviceReader {
    /// system_profiler повільний (~1 с) — викликати лише з фонової черги.
    static func read() -> [BTDevice] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        p.arguments = ["SPBluetoothDataType", "-json", "-detailLevel", "basic"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ctrl = (root["SPBluetoothDataType"] as? [[String: Any]])?.first,
              let connected = ctrl["device_connected"] as? [[String: Any]] else { return [] }

        func level(_ v: Any?) -> Int? {
            guard let s = v as? String else { return nil }
            return Int(s.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces))
        }

        var out: [BTDevice] = []
        for entry in connected {
            for (name, value) in entry {
                guard let info = value as? [String: Any] else { continue }
                let dev = BTDevice(
                    name: name,
                    kind: info["device_minorType"] as? String ?? "",
                    main: level(info["device_batteryLevelMain"] ?? info["device_batteryLevel"]),
                    left: level(info["device_batteryLevelLeft"]),
                    right: level(info["device_batteryLevelRight"]),
                    caseLevel: level(info["device_batteryLevelCase"])
                )
                if dev.lowest != nil || dev.caseLevel != nil { out.append(dev) }
            }
        }
        return out.sorted { ($0.lowest ?? 101) < ($1.lowest ?? 101) }
    }
}
