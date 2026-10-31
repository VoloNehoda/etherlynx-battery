import Foundation

/// Спільне для апки й root-хелпера: налаштування ліміту (пише апка) і стан (пише хелпер).
enum ChargePaths {
    static let dir = "/Library/Application Support/Etherlynx Battery"
    static let config = dir + "/charge-config.json"
    static let status = dir + "/charge-status.json"
    static let label = "xyz.etherlynx.battery.helper"
    static let helperBinary = "/Library/PrivilegedHelperTools/xyz.etherlynx.battery.helper"
    static let daemonPlist = "/Library/LaunchDaemons/xyz.etherlynx.battery.helper.plist"
}

struct ChargeConfig: Codable, Equatable {
    var enabled = false
    var limit = 80            // 50…100
    var sailing = true
    var sailRange = 5         // 2…20: повертаємо заряд лише нижче limit − sailRange
    var heatProtection = true
    var heatMax = 35.0        // °C, як радить AlDente з посиланням на Apple
    var sleepUntilLimit = false
    var magsafeLED = false
    var discharge = true      // автоматично розряджати до ліміту, якщо заряд вищий
    var topUp = false         // один раз до 100 %, потім назад до ліміту
    /// Запит на режим енергозбереження (ПКМ по іконці): хелпер застосовує pmset без пароля.
    var lowPower = false
    var lowPowerRequestAt: Date?

    /// Хелпер працює від root і читає файл, який може правити користувач, — тож лише перевірені межі.
    func sanitized() -> ChargeConfig {
        var c = self
        c.limit = min(100, max(50, c.limit))
        c.sailRange = min(20, max(2, c.sailRange))
        c.heatMax = min(45, max(30, c.heatMax))
        return c
    }
}

struct ChargeStatus: Codable, Equatable {
    enum Mode: String, Codable {
        case off, charging, holding, discharging, heat, topUp, lowSafety, unsupported
    }
    var updated = Date()
    var mode: Mode = .off
    var percent = 0
    var temperature: Double?
    var adapterPaused = false
    var chargingPaused = false
    /// Що вміє цей Mac: "charge-inhibit" (CHTE / CH0B+CH0C), "adapter" (CHIE / CH0I), "led" (ACLC).
    var capabilities: [String] = []
    var note: String?
}
