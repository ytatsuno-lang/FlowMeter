import SwiftUI
import CoreLocation

struct MeterView: View {
    @EnvironmentObject var store: MeasurementStore
    @EnvironmentObject var locationContext: LocationContext
    @State private var capacity: RotationCapacity = .hundred
    @State private var startDate: Date? = nil
    @State private var laps: [TimeInterval] = []
    @State private var showSaveSheet = false

    private var isRunning: Bool { startDate != nil }
    private var isFinished: Bool { laps.count >= 3 }
    private var canChangeCapacity: Bool { !isRunning && laps.isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                LocationBadge()
                capacityPicker
                liveDisplay
                lapsList
                mainButton
                bottomButtons
                Spacer(minLength: 80)
            }
            .padding()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showSaveSheet) {
                SaveSheet(
                    measurement: buildMeasurement(),
                    onConfirm: { m in
                        store.add(m)
                        reset()
                    }
                )
                .environmentObject(locationContext)
            }
        }
    }

    private func buildMeasurement() -> FlowMeasurement {
        FlowMeasurement(
            date: Date(),
            capacityL: capacity.liters,
            lapTimes: laps,
            method: .meter
        )
    }

    private var capacityPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("1周あたりの容量")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("", selection: $capacity) {
                ForEach(RotationCapacity.allCases) { c in
                    Text(c.shortLabel).tag(c)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!canChangeCapacity)
            Text(capacity.detailLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var liveDisplay: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { ctx in
            let elapsed = startDate.map { ctx.date.timeIntervalSince($0) } ?? 0
            VStack(spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: "%.2f", elapsed))
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                        .foregroundStyle(isRunning ? .primary : .secondary)
                    Text("秒")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if elapsed > 0.1 {
                    let flow = FlowMeasurement.flowRate(capacityL: capacity.liters, seconds: elapsed)
                    Text(String(format: "%.2f m³/h", flow))
                        .font(.title3.monospaced())
                        .foregroundStyle(isRunning ? .blue : .secondary)
                } else {
                    Text("—")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var lapsList: some View {
        VStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                LapRow(
                    title: "\(i + 1) 回目",
                    time: i < laps.count ? laps[i] : nil,
                    capacity: capacity,
                    style: .lap,
                    onDelete: i < laps.count ? { deleteLap(at: i) } : nil
                )
            }
            if laps.count >= 2 {
                Divider().padding(.vertical, 2)
                let avg = laps.reduce(0, +) / Double(laps.count)
                LapRow(title: "平均 (\(laps.count)回)", time: avg, capacity: capacity, style: .average, onDelete: nil)
            }
        }
    }

    private func deleteLap(at index: Int) {
        guard index < laps.count else { return }
        laps.remove(at: index)
    }

    private var mainButton: some View {
        Button(action: mainAction) {
            VStack(spacing: 2) {
                Text(mainButtonLabel)
                    .font(.title2.bold())
                if let sub = mainButtonSublabel {
                    Text(sub)
                        .font(.caption2)
                        .opacity(0.85)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(mainButtonColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isFinished)
    }

    private var mainButtonLabel: String {
        if isFinished { return "完了" }
        if isRunning { return "LAP  \(laps.count + 1) / 3" }
        return "START"
    }

    private var mainButtonSublabel: String? {
        if isFinished { return "3回計測済み" }
        if isRunning { return "針が0を通過したらタップ" }
        if laps.isEmpty { return "針が0を通過したらタップ" }
        return "次の計測"
    }

    private var mainButtonColor: Color {
        if isFinished { return .gray }
        if isRunning { return .orange }
        return .blue
    }

    private var bottomButtons: some View {
        HStack(spacing: 10) {
            Button(action: reset) {
                Text("リセット")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.2))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(laps.isEmpty && !isRunning)

            Button(action: saveCurrent) {
                Text("保存")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(canSave ? Color.green : Color.gray.opacity(0.2))
                    .foregroundStyle(canSave ? .white : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(!canSave)
        }
    }

    private var canSave: Bool { !laps.isEmpty && !isRunning }

    private func mainAction() {
        if isFinished { return }
        let now = Date()
        if let s = startDate {
            let elapsed = now.timeIntervalSince(s)
            laps.append(elapsed)
            if laps.count < 3 {
                startDate = now
            } else {
                startDate = nil
            }
        } else {
            if laps.isEmpty {
                // START時に裏で位置情報を更新試行（失敗しても既存は保持される）
                locationContext.refresh()
            }
            startDate = now
        }
    }

    private func reset() {
        startDate = nil
        laps = []
    }

    private func saveCurrent() {
        showSaveSheet = true
    }
}

private struct LapRow: View {
    enum Style { case lap, average }
    let title: String
    let time: TimeInterval?
    let capacity: RotationCapacity
    let style: Style
    let onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(style == .average ? .subheadline.bold() : .subheadline)
                .foregroundStyle(style == .average ? .blue : .primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            if let t = time {
                Spacer(minLength: 4)
                Text(String(format: "%.2f s", t))
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                let flow = FlowMeasurement.flowRate(capacityL: capacity.liters, seconds: t)
                Text(String(format: "%.2f m³/h", flow))
                    .font((style == .average ? Font.headline : Font.body).monospaced())
                    .foregroundStyle(style == .average ? .blue : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(minWidth: 110, alignment: .trailing)
                if let onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title)を削除")
                } else {
                    Color.clear.frame(width: 22, height: 22)
                }
            } else {
                Text("—")
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(style == .average ? Color.blue.opacity(0.10) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
