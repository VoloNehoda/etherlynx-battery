import Foundation

struct BTDevice: Identifiable, Equatable {
    var id: String { name }
    var name: String
    var kind: String            // Headphones, Keyboard, Mouse…
    var main: Int?
    var left: Int?
    var right: Int?
    var caseLevel: Int?
    var address: String?

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
    /// Два джерела: system_profiler (AirPods з L/R/кейсом) і реєстр IOKit (BatteryPercent) —
    /// на новій macOS лише другий віддає заряд Magic Keyboard / Trackpad / Mouse, звідти його бере й Пункт керування.
    /// system_profiler повільний (~1 с) — викликати лише з фонової черги.
    static func read() -> [BTDevice] {
        var (list, names) = readProfiler()
        for d in readIORegistry() {
            // Імʼя користувача («Magic Keyboard volo») беремо з system_profiler за адресою пристрою
            var dev = d
            if let addr = d.address, let custom = names[addr] { dev.name = custom }
            if list.contains(where: { $0.name == dev.name || $0.name.hasPrefix(dev.name) }) { continue }
            list.append(dev)
        }
        return list.sorted { ($0.lowest ?? 101) < ($1.lowest ?? 101) }
    }

    /// ioreg -r -k BatteryPercent -a: HID-пристрої Apple (і не тільки), що звітують заряд.
    private static func readIORegistry() -> [BTDevice] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        p.arguments = ["-r", "-k", "BatteryPercent", "-a"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard let arr = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]] else { return [] }
        var out: [BTDevice] = []
        for e in arr {
            guard let level = (e["BatteryPercent"] as? NSNumber)?.intValue,
                  let name = (e["Product"] as? String) ?? (e["DeviceName"] as? String) else { continue }
            let n = name.lowercased()
            let kind = n.contains("keyboard") ? "Keyboard" : n.contains("trackpad") ? "Magic Trackpad" : n.contains("mouse") ? "Mouse" : "Headphones"
            var d = BTDevice(name: name, kind: kind, main: min(100, max(0, level)))
            d.address = normalise((e["DeviceAddress"] as? String) ?? (e["SerialNumber"] as? String))
            if !out.contains(where: { $0.name == d.name && $0.address == d.address }) { out.append(d) }
        }
        return out
    }

    /// «aa-bb-cc…» і «AA:BB:CC…» — одна адреса.
    static func normalise(_ a: String?) -> String? {
        guard let a, !a.isEmpty else { return nil }
        return a.lowercased().replacingOccurrences(of: "-", with: ":")
    }

    private static func readProfiler() -> ([BTDevice], [String: String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        p.arguments = ["SPBluetoothDataType", "-json", "-detailLevel", "basic"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return ([], [:]) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ctrl = (root["SPBluetoothDataType"] as? [[String: Any]])?.first,
              let connected = ctrl["device_connected"] as? [[String: Any]] else { return ([], [:]) }

        func level(_ v: Any?) -> Int? {
            guard let s = v as? String else { return nil }
            return Int(s.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces))
        }

        var out: [BTDevice] = []
        var names: [String: String] = [:]
        for entry in connected {
            for (name, value) in entry {
                guard let info = value as? [String: Any] else { continue }
                if let addr = normalise(info["device_address"] as? String) { names[addr] = name }
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
        return (out, names)
    }
}
