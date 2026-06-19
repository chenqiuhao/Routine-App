import Foundation
import Observation
import SwiftUI
import UserNotifications

struct Routine: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var startMinutes: Int
    var endMinutes: Int
    var color: RoutineColor
    var notifies: Bool

    init(
        id: UUID = UUID(),
        name: String,
        startMinutes: Int,
        endMinutes: Int,
        color: RoutineColor,
        notifies: Bool = false
    ) {
        self.id = id
        self.name = name
        self.startMinutes = startMinutes.roundedToFiveMinutes
        self.endMinutes = endMinutes.roundedToFiveMinutes
        self.color = color
        self.notifies = notifies
    }

    var durationMinutes: Int {
        let raw = endMinutes - startMinutes
        return raw > 0 ? raw : raw + minutesPerDay
    }

    var midpointMinutes: Int {
        (startMinutes + durationMinutes / 2).normalizedDayMinute
    }
}

struct RoutineColor: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var hue: Double
    var saturation: Double
    var brightness: Double

    var swiftUIColor: Color {
        Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    init(id: String, name: String, hue: Double, saturation: Double, brightness: Double) {
        self.id = id
        self.name = name
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
    }

    init(from decoder: Decoder) throws {
        if let legacyValue = try? decoder.singleValueContainer().decode(String.self) {
            self = Self.color(forLegacyIdentifier: legacyValue)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        hue = try container.decode(Double.self, forKey: .hue)
        saturation = try container.decode(Double.self, forKey: .saturation)
        brightness = try container.decode(Double.self, forKey: .brightness)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(hue, forKey: .hue)
        try container.encode(saturation, forKey: .saturation)
        try container.encode(brightness, forKey: .brightness)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case hue
        case saturation
        case brightness
    }

    static let defaultPalette: [RoutineColor] = [
        RoutineColor(id: "coral", name: "珊瑚红", hue: 0.985, saturation: 0.72, brightness: 0.86),
        RoutineColor(id: "orange", name: "橙色", hue: 0.070, saturation: 0.86, brightness: 0.95),
        RoutineColor(id: "amber", name: "琥珀黄", hue: 0.125, saturation: 0.92, brightness: 0.96),
        RoutineColor(id: "lime", name: "青柠绿", hue: 0.230, saturation: 0.80, brightness: 0.82),
        RoutineColor(id: "green", name: "绿色", hue: 0.355, saturation: 0.78, brightness: 0.76),
        RoutineColor(id: "mint", name: "薄荷绿", hue: 0.450, saturation: 0.72, brightness: 0.72),
        RoutineColor(id: "teal", name: "蓝绿色", hue: 0.505, saturation: 0.82, brightness: 0.70),
        RoutineColor(id: "cyan", name: "青色", hue: 0.550, saturation: 0.76, brightness: 0.86),
        RoutineColor(id: "sky", name: "天蓝", hue: 0.575, saturation: 0.72, brightness: 0.92),
        RoutineColor(id: "blue", name: "蓝色", hue: 0.585, saturation: 0.84, brightness: 0.88),
        RoutineColor(id: "indigo", name: "靛蓝", hue: 0.675, saturation: 0.68, brightness: 0.86),
        RoutineColor(id: "violet", name: "紫色", hue: 0.740, saturation: 0.66, brightness: 0.88),
        RoutineColor(id: "grape", name: "葡萄紫", hue: 0.790, saturation: 0.62, brightness: 0.84),
        RoutineColor(id: "pink", name: "粉色", hue: 0.890, saturation: 0.58, brightness: 0.92),
        RoutineColor(id: "rose", name: "玫瑰红", hue: 0.945, saturation: 0.70, brightness: 0.90)
    ]

    static func defaultColor(at index: Int) -> RoutineColor {
        defaultPalette[index % defaultPalette.count]
    }

    static func generated(avoiding usedIdentifiers: Set<String>) -> RoutineColor {
        var seed = 0

        while true {
            let hue = (Double(seed) * 0.61803398875 + 0.17).truncatingRemainder(dividingBy: 1)
            let color = RoutineColor(
                id: "generated-\(seed)",
                name: "新颜色 \(seed + 1)",
                hue: hue,
                saturation: 0.62 + Double(seed % 3) * 0.08,
                brightness: 0.80 + Double(seed % 2) * 0.08
            )

            if !usedIdentifiers.contains(color.id) {
                return color
            }

            seed += 1
        }
    }

    private static func color(forLegacyIdentifier identifier: String) -> RoutineColor {
        let legacyMap: [String: String] = [
            "coral": "coral",
            "tangerine": "orange",
            "amber": "amber",
            "green": "green",
            "blue": "blue",
            "violet": "violet",
            "mint": "mint"
        ]

        let mappedIdentifier = legacyMap[identifier] ?? identifier
        return defaultPalette.first { $0.id == mappedIdentifier } ?? defaultPalette[0]
    }
}

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            "跟随系统"
        case .light:
            "浅色"
        case .dark:
            "夜间"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

@Observable
final class RoutineStore {
    var routines: [Routine] {
        didSet {
            save()
            refreshNotifications()
        }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode([Routine].self, from: data) {
            routines = decoded
        } else {
            routines = Self.sampleRoutines
        }

        refreshNotifications()
    }

    func addRoutine() {
        let usedColorIdentifiers = Set(routines.map(\.color.id))
        let nextColor = RoutineColor.defaultPalette.first { !usedColorIdentifiers.contains($0.id) }
            ?? RoutineColor.generated(avoiding: usedColorIdentifiers)

        routines.append(
            Routine(
                name: "新日程",
                startMinutes: 8 * 60,
                endMinutes: 9 * 60,
                color: nextColor
            )
        )
    }

    func remove(_ routine: Routine) {
        routines.removeAll { $0.id == routine.id }
    }

    func remove(atOffsets offsets: IndexSet) {
        let validOffsets = IndexSet(offsets.filter { routines.indices.contains($0) })
        routines.remove(atOffsets: validOffsets)
    }

    func move(from source: IndexSet, to destination: Int) {
        routines.move(fromOffsets: source, toOffset: destination)
    }

    func exportText() -> String {
        var lines = [
            "# Daily Routine",
            "# start\tend\tname\tnotify\tcolorID\thue\tsaturation\tbrightness"
        ]

        lines += routines.map { routine in
            [
                Self.timeString(for: routine.startMinutes),
                Self.timeString(for: routine.endMinutes),
                Self.escape(routine.name),
                routine.notifies ? "1" : "0",
                routine.color.id,
                String(format: "%.6f", routine.color.hue),
                String(format: "%.6f", routine.color.saturation),
                String(format: "%.6f", routine.color.brightness)
            ].joined(separator: "\t")
        }

        return lines.joined(separator: "\n") + "\n"
    }

    func importText(_ text: String) throws {
        routines = try Self.routines(from: text)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(routines) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    private func refreshNotifications() {
        let routines = routines
        Task {
            await RoutineNotificationScheduler.refresh(for: routines)
        }
    }

    private static let defaultsKey = "RoutineApp.routines.v1"

    private static func routines(from text: String) throws -> [Routine] {
        var imported: [Routine] = []
        var usedColorIdentifiers = Set<String>()

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            let columns = splitRoutineLine(line)
            guard columns.count >= 3,
                  let startMinutes = minutes(from: columns[0]),
                  let endMinutes = minutes(from: columns[1]) else {
                continue
            }

            let name = unescape(columns[2]).trimmingCharacters(in: .whitespacesAndNewlines)
            let notifies = columns.count > 3 ? boolValue(from: columns[3]) : false
            let color = color(from: columns, usedColorIdentifiers: usedColorIdentifiers)
            usedColorIdentifiers.insert(color.id)

            imported.append(
                Routine(
                    name: name.isEmpty ? "新日程" : name,
                    startMinutes: startMinutes,
                    endMinutes: endMinutes,
                    color: color,
                    notifies: notifies
                )
            )
        }

        guard !imported.isEmpty else {
            throw RoutineImportError.noValidRoutines
        }

        return imported
    }

    private static func splitRoutineLine(_ line: String) -> [String] {
        let separator: Character = line.contains("\t") ? "\t" : ","
        return line.split(separator: separator, omittingEmptySubsequences: false).map(String.init)
    }

    private static func timeString(for minutes: Int) -> String {
        let normalized = minutes.normalizedDayMinute
        return String(format: "%02d:%02d", normalized / 60, normalized % 60)
    }

    private static func minutes(from text: String) -> Int? {
        let parts = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0..<24).contains(hour),
              (0..<60).contains(minute) else {
            return nil
        }

        return (hour * 60 + minute).roundedToFiveMinutes
    }

    private static func boolValue(from text: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["1", "true", "yes", "y", "是", "提醒", "开启"].contains(value)
    }

    private static func color(from columns: [String], usedColorIdentifiers: Set<String>) -> RoutineColor {
        let identifier = columns.count > 4 ? columns[4].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let knownColor = RoutineColor.defaultPalette.first { $0.id == identifier }

        if columns.count > 7,
           !identifier.isEmpty,
           let hue = Double(columns[5]),
           let saturation = Double(columns[6]),
           let brightness = Double(columns[7]) {
            return RoutineColor(
                id: identifier,
                name: knownColor?.name ?? identifier,
                hue: hue,
                saturation: saturation,
                brightness: brightness
            )
        }

        if let knownColor {
            return knownColor
        }

        return RoutineColor.defaultPalette.first { !usedColorIdentifiers.contains($0.id) }
            ?? RoutineColor.generated(avoiding: usedColorIdentifiers)
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private static func unescape(_ text: String) -> String {
        var result = ""
        var isEscaping = false

        for character in text {
            if isEscaping {
                switch character {
                case "n":
                    result.append("\n")
                case "t":
                    result.append("\t")
                default:
                    result.append(character)
                }
                isEscaping = false
            } else if character == "\\" {
                isEscaping = true
            } else {
                result.append(character)
            }
        }

        if isEscaping {
            result.append("\\")
        }

        return result
    }

    private static let sampleRoutines: [Routine] = [
        Routine(name: "睡觉", startMinutes: 22 * 60, endMinutes: 6 * 60, color: RoutineColor.defaultColor(at: 0)),
        Routine(name: "跑步", startMinutes: 6 * 60, endMinutes: 8 * 60, color: RoutineColor.defaultColor(at: 1)),
        Routine(name: "吃饭", startMinutes: 8 * 60, endMinutes: 9 * 60, color: RoutineColor.defaultColor(at: 2)),
        Routine(name: "工作", startMinutes: 9 * 60, endMinutes: 14 * 60, color: RoutineColor.defaultColor(at: 4)),
        Routine(name: "休息", startMinutes: 14 * 60, endMinutes: 16 * 60, color: RoutineColor.defaultColor(at: 9)),
        Routine(name: "晚餐", startMinutes: 18 * 60, endMinutes: 19 * 60, color: RoutineColor.defaultColor(at: 11))
    ]
}

enum RoutineNotificationScheduler {
    private static let identifierPrefix = "RoutineApp.routine."

    static func refresh(for routines: [Routine]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ownedIdentifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ownedIdentifiers)

        let notificationRoutines = routines.filter(\.notifies)
        guard !notificationRoutines.isEmpty else { return }

        guard await ensureNotificationAuthorization(center: center) else {
            return
        }

        for routine in notificationRoutines {
            let content = UNMutableNotificationContent()
            content.title = routine.name
            content.sound = .default

            var components = DateComponents()
            components.calendar = Calendar.current
            components.timeZone = TimeZone.current
            components.hour = routine.startMinutes / 60
            components.minute = routine.startMinutes % 60

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: identifierPrefix + routine.id.uuidString,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    private static func ensureNotificationAuthorization(center: UNUserNotificationCenter) async -> Bool {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }
}

enum RoutineImportError: LocalizedError {
    case noValidRoutines

    var errorDescription: String? {
        switch self {
        case .noValidRoutines:
            "没有找到可导入的日程。请使用每行“开始时间<TAB>结束时间<TAB>名称”的格式。"
        }
    }
}

let minutesPerDay = 24 * 60

extension Int {
    var normalizedDayMinute: Int {
        let value = self % minutesPerDay
        return value >= 0 ? value : value + minutesPerDay
    }

    var roundedToFiveMinutes: Int {
        let rounded = Int((Double(self) / 5.0).rounded()) * 5
        return rounded.normalizedDayMinute
    }
}
