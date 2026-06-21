import Foundation
#if !WIDGET_EXTENSION
import Observation
import UserNotifications
#endif
import SwiftUI
import WidgetKit

struct Routine: Identifiable, Codable, Equatable, Hashable {
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

enum RoutineSharedStorage {
    static let appGroupIdentifier = "group.com.codex.cyclist"
    static let routinesKey = "Cyclist.routines.v1"
    static let liveActivityEnabledKey = "Cyclist.liveActivity.enabled"

    private static let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier)
    static let defaults: UserDefaults = appGroupDefaults ?? .standard

    private static func registerDefaults() {
        defaults.register(defaults: [liveActivityEnabledKey: false])
    }

    static func loadRoutines() -> [Routine] {
        registerDefaults()

        if let data = defaults.data(forKey: routinesKey),
           let decoded = try? JSONDecoder().decode([Routine].self, from: data) {
            return decoded
        }

        if let data = UserDefaults.standard.data(forKey: routinesKey),
           let decoded = try? JSONDecoder().decode([Routine].self, from: data) {
            save(decoded, reloadWidgets: false)
            return decoded
        }

        save(sampleRoutines, reloadWidgets: false)
        return sampleRoutines
    }

    static func loadLiveActivityEnabled() -> Bool {
        registerDefaults()

        if defaults.object(forKey: liveActivityEnabledKey) != nil {
            return defaults.bool(forKey: liveActivityEnabledKey)
        }

        return UserDefaults.standard.bool(forKey: liveActivityEnabledKey)
    }

    static func saveLiveActivityEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: liveActivityEnabledKey)
    }

    static func save(_ routines: [Routine], reloadWidgets: Bool) {
        guard let data = try? JSONEncoder().encode(routines) else { return }
        defaults.set(data, forKey: routinesKey)
        guard reloadWidgets else { return }
        Self.reloadWidgets()
    }

    static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    static let sampleRoutines: [Routine] = [
        Routine(name: "睡觉", startMinutes: 22 * 60, endMinutes: 6 * 60, color: RoutineColor.defaultColor(at: 0)),
        Routine(name: "跑步", startMinutes: 6 * 60, endMinutes: 8 * 60, color: RoutineColor.defaultColor(at: 1)),
        Routine(name: "吃饭", startMinutes: 8 * 60, endMinutes: 9 * 60, color: RoutineColor.defaultColor(at: 2)),
        Routine(name: "工作", startMinutes: 9 * 60, endMinutes: 14 * 60, color: RoutineColor.defaultColor(at: 4)),
        Routine(name: "休息", startMinutes: 14 * 60, endMinutes: 16 * 60, color: RoutineColor.defaultColor(at: 9)),
        Routine(name: "晚餐", startMinutes: 18 * 60, endMinutes: 19 * 60, color: RoutineColor.defaultColor(at: 11))
    ]
}

struct RoutineStatusSnapshot: Codable, Hashable {
    var title: String
    var caption: String
    var progress: Double
    var remainingText: String
    var remainingMinuteText: String
    var compactRemainingMinuteText: String
    var startTimeText: String
    var endTimeText: String
    var nextTitle: String
    var tint: RoutineColor?
    var startDate: Date?
    var endDate: Date?

    var tintColor: Color {
        tint?.swiftUIColor ?? .secondary
    }
}

func routineStatusSnapshot(at date: Date, routines: [Routine]) -> RoutineStatusSnapshot {
    guard !routines.isEmpty else {
        return RoutineStatusSnapshot(
            title: "暂无日程",
            caption: "当前",
            progress: 0,
            remainingText: "--:--:--",
            remainingMinuteText: "--",
            compactRemainingMinuteText: "--",
            startTimeText: "--:--",
            endTimeText: "--:--",
            nextTitle: "无",
            tint: nil,
            startDate: nil,
            endDate: nil
        )
    }

    let seconds = secondsSinceStartOfDay(for: date)

    if let current = routines.first(where: { $0.contains(daySecond: seconds) }) {
        let elapsed = current.elapsedSeconds(at: seconds)
        let duration = max(current.durationMinutes * 60, 1)
        let remaining = max(duration - elapsed, 0)
        let interval = activeInterval(for: current, containing: date)
        let next = nextRoutine(after: seconds, routines: routines, excluding: current.id)

        return RoutineStatusSnapshot(
            title: routineDisplayName(for: current),
            caption: "当前日程",
            progress: min(max(Double(elapsed) / Double(duration), 0), 1),
            remainingText: routineCountdownString(seconds: remaining),
            remainingMinuteText: routineMinuteCountdownString(seconds: remaining),
            compactRemainingMinuteText: routineCompactMinuteCountdownString(seconds: remaining),
            startTimeText: routineTimeString(minutes: current.startMinutes),
            endTimeText: routineTimeString(minutes: current.endMinutes),
            nextTitle: next.map { routineDisplayNameWithDuration(for: $0.routine) } ?? "无",
            tint: current.color,
            startDate: interval?.start,
            endDate: interval?.end
        )
    }

    let next = nextRoutine(after: seconds, routines: routines)

    return RoutineStatusSnapshot(
        title: "空闲",
        caption: next.map { "距离 \(routineDisplayName(for: $0.routine)) 开始" } ?? "当前",
        progress: 0,
        remainingText: routineCountdownString(seconds: next?.remaining ?? 0),
        remainingMinuteText: routineMinuteCountdownString(seconds: next?.remaining ?? 0),
        compactRemainingMinuteText: routineCompactMinuteCountdownString(seconds: next?.remaining ?? 0),
        startTimeText: "--:--",
        endTimeText: next.map { routineTimeString(minutes: $0.routine.startMinutes) } ?? "--:--",
        nextTitle: next.map { routineDisplayNameWithDuration(for: $0.routine) } ?? "无",
        tint: nil,
        startDate: nil,
        endDate: next.map { date.addingTimeInterval(TimeInterval($0.remaining)) }
    )
}

func routineStatusTimelineDates(
    from date: Date,
    routines: [Routine],
    horizon: TimeInterval = 26 * 60 * 60,
    limit: Int = 64
) -> [Date] {
    guard limit > 0 else { return [] }

    var dates = [date]
    var cursor = date
    let endDate = date.addingTimeInterval(horizon)

    while dates.count < limit,
          let nextChangeDate = nextRoutineStatusChangeDate(after: cursor, routines: routines) {
        let entryDate = nextChangeDate.addingTimeInterval(1)
        guard entryDate <= endDate else { break }

        if let lastDate = dates.last,
           entryDate.timeIntervalSince(lastDate) > 0.5 {
            dates.append(entryDate)
        }

        cursor = entryDate
    }

    return dates
}

func nextRoutineStatusChangeDate(after date: Date, routines: [Routine]) -> Date? {
    let boundaryDates = routineBoundaryDates(around: date, routines: routines)
    let threshold = date.addingTimeInterval(0.5)
    return boundaryDates
        .filter { $0 > threshold }
        .min()
}

func routineDisplayName(for routine: Routine) -> String {
    let trimmed = routine.name.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "新日程" : trimmed
}

func routineDisplayNameWithDuration(for routine: Routine) -> String {
    "\(routineDisplayName(for: routine)) \(routineDurationText(minutes: routine.durationMinutes))"
}

func routineDurationText(minutes: Int) -> String {
    if minutes < 60 {
        return "\(minutes) min"
    }

    let hours = minutes / 60
    let remainingMinutes = minutes % 60

    if remainingMinutes == 0 {
        return "\(hours) h"
    }

    return "\(hours) h \(remainingMinutes) min"
}

func routineTimeString(minutes: Int) -> String {
    let normalized = minutes.normalizedDayMinute
    return String(format: "%02d:%02d", normalized / 60, normalized % 60)
}

func routineCountdownInterval(startDate: Date?, endDate: Date, now: Date = .now) -> ClosedRange<Date>? {
    let lowerBound = min(startDate ?? now, now)
    let upperBound = max(endDate, now.addingTimeInterval(1))
    guard lowerBound <= upperBound else { return nil }
    return lowerBound...upperBound
}

private func nextRoutine(
    after seconds: Int,
    routines: [Routine],
    excluding excludedID: Routine.ID? = nil
) -> (routine: Routine, remaining: Int)? {
    routines
        .filter { $0.id != excludedID }
        .map { routine in (routine: routine, remaining: secondsUntilStart(of: routine, from: seconds)) }
        .min { $0.remaining < $1.remaining }
}

private func routineBoundaryDates(around date: Date, routines: [Routine]) -> [Date] {
    let calendar = Calendar.current
    let dayStart = calendar.startOfDay(for: date)

    return routines.flatMap { routine -> [Date] in
        guard routine.startMinutes.normalizedDayMinute != routine.endMinutes.normalizedDayMinute else {
            return []
        }

        return (-1...2).flatMap { dayOffset -> [Date] in
            guard let boundaryDay = calendar.date(byAdding: .day, value: dayOffset, to: dayStart) else {
                return []
            }

            return [routine.startMinutes, routine.endMinutes].compactMap { minutes in
                calendar.date(byAdding: .minute, value: minutes.normalizedDayMinute, to: boundaryDay)
            }
        }
    }
}

private func secondsSinceStartOfDay(for date: Date) -> Int {
    let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
    return ((components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60 + (components.second ?? 0)) % (minutesPerDay * 60)
}

private func secondsUntilStart(of routine: Routine, from seconds: Int) -> Int {
    let startSeconds = routine.startMinutes.normalizedDayMinute * 60
    let raw = startSeconds - seconds
    return raw >= 0 ? raw : raw + minutesPerDay * 60
}

private func routineCountdownString(seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let seconds = seconds % 60
    return String(format: "%d:%02d:%02d", hours, minutes, seconds)
}

private func routineMinuteCountdownString(seconds: Int) -> String {
    let minutes = remainingWholeMinutes(seconds: seconds)
    return routineDurationText(minutes: minutes)
}

private func routineCompactMinuteCountdownString(seconds: Int) -> String {
    let minutes = remainingWholeMinutes(seconds: seconds)
    guard minutes >= 60 else { return "\(minutes) m" }

    let hours = minutes / 60
    let remainingMinutes = minutes % 60
    return remainingMinutes == 0 ? "\(hours) h" : "\(hours) h \(remainingMinutes) m"
}

private func remainingWholeMinutes(seconds: Int) -> Int {
    guard seconds > 0 else { return 0 }
    return max(1, Int(ceil(Double(seconds) / 60.0)))
}

private func activeInterval(for routine: Routine, containing date: Date) -> (start: Date, end: Date)? {
    let calendar = Calendar.current
    let dayStart = calendar.startOfDay(for: date)
    guard let startToday = calendar.date(byAdding: .minute, value: routine.startMinutes.normalizedDayMinute, to: dayStart) else {
        return nil
    }

    let duration = TimeInterval(routine.durationMinutes * 60)
    let candidates = [
        startToday,
        calendar.date(byAdding: .day, value: -1, to: startToday),
        calendar.date(byAdding: .day, value: 1, to: startToday)
    ].compactMap { $0 }

    return candidates
        .map { start in (start: start, end: start.addingTimeInterval(duration)) }
        .first { date >= $0.start && date < $0.end }
}

extension Routine {
    func contains(daySecond: Int) -> Bool {
        let start = startMinutes.normalizedDayMinute * 60
        let end = endMinutes.normalizedDayMinute * 60

        if start == end {
            return true
        }

        if start < end {
            return daySecond >= start && daySecond < end
        }

        return daySecond >= start || daySecond < end
    }

    func elapsedSeconds(at daySecond: Int) -> Int {
        let start = startMinutes.normalizedDayMinute * 60
        let raw = daySecond - start
        return raw >= 0 ? raw : raw + minutesPerDay * 60
    }
}

#if !WIDGET_EXTENSION
@Observable
final class RoutineStore {
    var routines: [Routine] {
        didSet {
            save()
            scheduleExternalRefresh(previousRoutines: oldValue)
        }
    }

    @ObservationIgnored private var externalRefreshTask: Task<Void, Never>?

    init() {
        routines = RoutineSharedStorage.loadRoutines()

        if routines.contains(where: \.notifies) {
            scheduleNotificationRefresh(for: routines, after: 1_500_000_000)
        }
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

    func resetColorsInOrder() {
        var usedColorIdentifiers = Set<String>()
        let recoloredRoutines = routines.enumerated().map { index, routine in
            var updatedRoutine = routine
            let color: RoutineColor

            if RoutineColor.defaultPalette.indices.contains(index) {
                color = RoutineColor.defaultPalette[index]
            } else {
                color = RoutineColor.generated(avoiding: usedColorIdentifiers)
            }

            usedColorIdentifiers.insert(color.id)
            updatedRoutine.color = color
            return updatedRoutine
        }

        guard recoloredRoutines != routines else { return }
        routines = recoloredRoutines
    }

    var allRoutinesNotify: Bool {
        !routines.isEmpty && routines.allSatisfy(\.notifies)
    }

    func toggleAllNotifications() {
        setAllNotifications(!allRoutinesNotify)
    }

    private func setAllNotifications(_ enabled: Bool) {
        let updatedRoutines = routines.map { routine in
            var updatedRoutine = routine
            updatedRoutine.notifies = enabled
            return updatedRoutine
        }

        guard updatedRoutines != routines else { return }
        routines = updatedRoutines
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
            "# Cyclist",
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
        RoutineSharedStorage.save(routines, reloadWidgets: false)
    }

    private func scheduleExternalRefresh(previousRoutines: [Routine]) {
        externalRefreshTask?.cancel()
        let routines = routines
        let shouldRefreshNotifications = Self.notificationSignature(for: previousRoutines) != Self.notificationSignature(for: routines)

        externalRefreshTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }

            RoutineSharedStorage.reloadWidgets()
            guard shouldRefreshNotifications else { return }
            await RoutineNotificationScheduler.refresh(for: routines)
        }
    }

    private func scheduleNotificationRefresh(for routines: [Routine], after delay: UInt64) {
        Task {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled else { return }
            }

            await RoutineNotificationScheduler.refresh(for: routines)
        }
    }

    private static func notificationSignature(for routines: [Routine]) -> Set<RoutineNotificationInfo> {
        Set(
            routines.filter(\.notifies).map {
                RoutineNotificationInfo(
                    id: $0.id,
                    startMinutes: $0.startMinutes,
                    name: routineDisplayName(for: $0),
                    notifies: $0.notifies
                )
            }
        )
    }

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

}

enum RoutineNotificationScheduler {
    private static let identifierPrefix = "Cyclist.routine."

    static func refresh(for routines: [Routine]) async {
        let notificationRoutines = routines.filter(\.notifies)
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ownedIdentifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ownedIdentifiers)

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

private struct RoutineNotificationInfo: Hashable {
    var id: Routine.ID
    var startMinutes: Int
    var name: String
    var notifies: Bool
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
#endif

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
