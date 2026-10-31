import CoreBluetooth
import Foundation

/// Заряд пристроїв через стандартний Bluetooth Battery Service (GATT 0x180F / рівень 0x2A19).
/// Так iPhone, iPad і багато навушників (Sony, Bose, Logitech…) віддають заряд спареному Mac.
/// Потрібен дозвіл на Bluetooth — macOS спитає один раз.
/// Сканування навмання свідомо немає: поруч iPhone анонімні, і ми б підключались до чужих телефонів.
/// Читаємо лише те, що вже з'єднане з цим Mac.
final class BLEBattery: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private let batteryService = CBUUID(string: "180F")
    private let batteryLevel = CBUUID(string: "2A19")
    private var central: CBCentralManager?
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var levels: [UUID: (name: String, level: Int, seen: Date)] = [:]
    private var timer: Timer?
    var onChange: (() -> Void)?

    var devices: [BTDevice] {
        levels.values
            .filter { Date().timeIntervalSince($0.seen) < 600 }
            .map { BTDevice(name: $0.name, kind: Self.kind(for: $0.name), main: $0.level) }
    }

    var state: CBManagerState { central?.state ?? .unknown }

    func start() {
        guard central == nil else { return }
        central = CBCentralManager(delegate: self, queue: .main)
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.poll() }
    }

    func poll() {
        guard let c = central, c.state == .poweredOn else { return }
        Self.trace("poll: \(c.retrieveConnectedPeripherals(withServices: [batteryService]).count) connected with Battery Service")
        // Пристрої, які вже тримає система (iPhone через Continuity, навушники) і які мають Battery Service
        for p in c.retrieveConnectedPeripherals(withServices: [batteryService]) {
            if peripherals[p.identifier] == nil {
                peripherals[p.identifier] = p
                p.delegate = self
                Self.trace("found \(p.name ?? p.identifier.uuidString)")
            }
            if p.state == .connected { p.discoverServices([batteryService]) }
            else { c.connect(p) }
        }
    }

    func centralManager(_ c: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        Self.trace("connect failed \(p.name ?? "?"): \(error?.localizedDescription ?? "-")")
        peripherals[p.identifier] = nil
    }

    func centralManagerDidUpdateState(_ c: CBCentralManager) {
        Self.trace("state \(c.state.rawValue) (5 = on, 3 = unauthorized), auth \(CBManager.authorization.rawValue)")
        poll()
    }

    func centralManager(_ c: CBCentralManager, didConnect p: CBPeripheral) {
        p.discoverServices([batteryService])
    }

    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        Self.trace("services \(p.name ?? "?"): \(p.services?.map(\.uuid.uuidString) ?? []) \(error?.localizedDescription ?? "")")
        for s in p.services ?? [] where s.uuid == batteryService {
            p.discoverCharacteristics([batteryLevel], for: s)
        }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
        for ch in s.characteristics ?? [] where ch.uuid == batteryLevel {
            p.readValue(for: ch)
            if ch.properties.contains(.notify) { p.setNotifyValue(true, for: ch) }
        }
    }

    func peripheral(_ p: CBPeripheral, didUpdateValueFor ch: CBCharacteristic, error: Error?) {
        guard ch.uuid == batteryLevel, let v = ch.value?.first else { return }
        levels[p.identifier] = (p.name ?? "Bluetooth device", Int(min(v, 100)), Date())
        Self.trace("\(p.name ?? "?") \(v)%")
        onChange?()
    }

    /// Короткий лог у ~/Library/Application Support/Etherlynx Battery/ble.log — щоб бачити, що знайшлось.
    static func trace(_ s: String) {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Etherlynx Battery", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("ble.log")
        let line = "[\(Date())] \(s)\n"
        if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close() }
        else { try? line.write(to: url, atomically: true, encoding: .utf8) }
    }

    static func kind(for name: String) -> String {
        let n = name.lowercased()
        if n.contains("iphone") { return "Phone" }
        if n.contains("ipad") { return "Tablet" }
        if n.contains("watch") { return "Watch" }
        return "Headphones"
    }
}
