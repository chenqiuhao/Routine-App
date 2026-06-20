import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var store: RoutineStore
    @Binding var themeMode: AppThemeMode
    @Binding var liveActivityEnabled: Bool
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var importErrorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("日程") {
                    ForEach(store.routines) { routine in
                        RoutineEditorRow(routine: binding(for: routine.id))
                            .listRowInsets(.init(top: 3, leading: 16, bottom: 3, trailing: 12))
                    }
                    .onDelete { offsets in
                        store.remove(atOffsets: offsets)
                    }
                    .onMove { source, destination in
                        store.move(from: source, to: destination)
                    }

                    Button {
                        store.resetColorsInOrder()
                    } label: {
                        Label("按顺序重设颜色", systemImage: "paintpalette")
                    }
                    .disabled(store.routines.isEmpty)

                    Button {
                        store.toggleAllNotifications()
                    } label: {
                        Label(
                            store.allRoutinesNotify ? "关闭所有日程提醒" : "打开所有日程提醒",
                            systemImage: store.allRoutinesNotify ? "bell.slash" : "bell"
                        )
                    }
                    .disabled(store.routines.isEmpty)
                }

                Section("外观") {
                    ThemeModePicker(selection: $themeMode)
                }

                Section("锁屏") {
                    Toggle("实时活动窗口", isOn: $liveActivityEnabled)
                }

                Section("数据") {
                    Button {
                        isImporting = true
                    } label: {
                        Label("导入 TXT", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        isExporting = true
                    } label: {
                        Label("导出 TXT", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.defaultMinListRowHeight, 1)
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle("配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.addRoutine()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .accessibilityLabel("添加日程")
                }
            }
        }
        .tint(.primary)
        .scrollDismissesKeyboard(.interactively)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.plainText, .text],
            allowsMultipleSelection: false,
            onCompletion: importRoutines
        )
        .fileExporter(
            isPresented: $isExporting,
            document: RoutineTextDocument(text: store.exportText()),
            contentType: .plainText,
            defaultFilename: "DailyRoutine.txt"
        ) { _ in }
        .alert("导入失败", isPresented: importErrorIsPresented) {
            Button("好", role: .cancel) { importErrorMessage = nil }
        } message: {
            Text(importErrorMessage ?? "")
        }
    }

    private var importErrorIsPresented: Binding<Bool> {
        Binding(
            get: { importErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    importErrorMessage = nil
                }
            }
        )
    }

    private func binding(for id: Routine.ID) -> Binding<Routine> {
        Binding(
            get: {
                store.routines.first { $0.id == id } ?? Routine(
                    id: id,
                    name: "",
                    startMinutes: 0,
                    endMinutes: 5,
                    color: RoutineColor.defaultColor(at: 0)
                )
            },
            set: { updatedRoutine in
                guard let index = store.routines.firstIndex(where: { $0.id == id }) else { return }
                guard store.routines[index] != updatedRoutine else { return }
                store.routines[index] = updatedRoutine
            }
        )
    }

    private func importRoutines(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let canAccess = url.startAccessingSecurityScopedResource()
            defer {
                if canAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let text = try String(contentsOf: url, encoding: .utf8)
            try store.importText(text)
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }
}

private struct ThemeModePicker: View {
    @Binding var selection: AppThemeMode

    var body: some View {
        Picker(selection: $selection) {
            ForEach(AppThemeMode.allCases) { mode in
                        Text(mode.title)
                    .tag(mode)
            }
        } label: {
                Text("夜间模式")
                .foregroundStyle(.primary)
        }
        .pickerStyle(.menu)
    }
}

private struct RoutineTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

private struct RoutineEditorRow: View {
    @Binding var routine: Routine

    var body: some View {
        HStack(spacing: 7) {
            colorMenu

            TimePillPicker(minutes: $routine.startMinutes)
                .frame(width: 68, height: 30)
                .accessibilityLabel("开始时间")

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            TimePillPicker(minutes: $routine.endMinutes)
                .frame(width: 68, height: 30)
                .accessibilityLabel("结束时间")

            TextField("名称", text: $routine.name)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .submitLabel(.done)
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(1)
                .frame(minWidth: 46, maxWidth: .infinity, alignment: .leading)
                .onSubmit {
                    hideKeyboard()
                }
                .accessibilityLabel("日程名称")

            Toggle("", isOn: $routine.notifies)
                .labelsHidden()
                .tint(.green)
                .frame(width: 48)
                .accessibilityLabel("通知提醒")
        }
        .padding(.vertical, 0)
        .frame(height: 36)
        .contentShape(Rectangle())
    }

    private var colorMenu: some View {
        Menu {
            ForEach(colorChoices) { color in
                Button {
                    routine.color = color
                } label: {
                    Label(color.name, systemImage: color.id == routine.color.id ? "checkmark.circle.fill" : "circle.fill")
                }
            }
        } label: {
            Circle()
                .fill(routine.color.swiftUIColor)
                .frame(width: 18, height: 18)
                .contentShape(Circle())
        }
        .accessibilityLabel("选择颜色")
    }

    private var colorChoices: [RoutineColor] {
        var choices = RoutineColor.defaultPalette
        if !choices.contains(where: { $0.id == routine.color.id }) {
            choices.append(routine.color)
        }
        return choices
    }
}

private struct TimePillPicker: UIViewRepresentable {
    @Binding var minutes: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .compact
        picker.minuteInterval = 5
        picker.locale = Locale(identifier: "en_GB")
        picker.backgroundColor = .clear
        picker.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        context.coordinator.parent = self
        picker.minuteInterval = 5
        picker.locale = Locale(identifier: "en_GB")
        picker.backgroundColor = .clear

        let roundedMinutes = minutes.roundedToFiveMinutes
        if roundedMinutes != minutes {
            DispatchQueue.main.async {
                minutes = roundedMinutes
            }
        }

        let date = Date.routineTime(minutes: roundedMinutes)
        if abs(picker.date.timeIntervalSince(date)) > 1 {
            picker.setDate(date, animated: false)
        }
    }

    final class Coordinator: NSObject {
        var parent: TimePillPicker

        init(parent: TimePillPicker) {
            self.parent = parent
        }

        @objc
        func valueChanged(_ sender: UIDatePicker) {
            let components = Calendar.current.dateComponents([.hour, .minute], from: sender.date)
            parent.minutes = ((components.hour ?? 0) * 60 + (components.minute ?? 0)).roundedToFiveMinutes
        }
    }
}

private extension Date {
    static func routineTime(minutes: Int) -> Date {
        Calendar.current.date(
            bySettingHour: minutes.normalizedDayMinute / 60,
            minute: minutes.normalizedDayMinute % 60,
            second: 0,
            of: Date()
        ) ?? Date()
    }
}

private func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

#Preview {
    SettingsView(
        store: RoutineStore(),
        themeMode: .constant(.system),
        liveActivityEnabled: .constant(false)
    )
}
