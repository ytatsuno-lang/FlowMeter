import SwiftUI
import CoreLocation

struct SaveSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locationContext: LocationContext

    let measurement: FlowMeasurement
    let onConfirm: (FlowMeasurement) -> Void

    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            Form {
                summarySection
                locationSection
                noteSection
            }
            .navigationTitle("保存")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .bold()
                }
            }
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        Section("計測結果") {
            HStack {
                Text("流量")
                Spacer()
                if let flow = measurement.averageFlowRate {
                    Text(String(format: "%.2f m³/h", flow))
                        .font(.body.monospaced().bold())
                        .foregroundStyle(.blue)
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            switch measurement.effectiveMethod {
            case .meter:
                HStack {
                    Text("方式")
                    Spacer()
                    Text("メーター式 ・ \(measurement.lapTimes.count)回 ・ 1周\(Int(measurement.capacityL)) L")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            case .tank:
                if let t = measurement.tank {
                    HStack {
                        Text("方式")
                        Spacer()
                        Text("水槽式 ・ \(t.shape.label)")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    HStack {
                        Text("寸法")
                        Spacer()
                        Text(t.dimensionsLabel)
                            .font(.subheadline.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("水位差・経過")
                        Spacer()
                        Text(String(format: "Δ%.2f m ・ %.1f s", t.levelDelta, t.elapsedSeconds))
                            .font(.subheadline.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("体積変化")
                        Spacer()
                        Text(String(format: "%.3f m³ (%.1f L)", t.volumeDeltaM3, t.volumeDeltaL))
                            .font(.subheadline.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var locationSection: some View {
        Section {
            switch locationContext.state {
            case .idle where locationContext.location == nil:
                HStack {
                    Text("（未取得）").foregroundStyle(.secondary)
                    Spacer()
                    Button("取得") { locationContext.refresh() }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            case .loading where locationContext.location == nil:
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("現在地を取得中…").foregroundStyle(.secondary)
                    Spacer()
                    Button("スキップ") { locationContext.cancel() }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            case .denied:
                VStack(alignment: .leading, spacing: 6) {
                    Text("位置情報が許可されていません").foregroundStyle(.orange)
                    Text("「設定 → FlowMeter → 位置情報」から許可してください")
                        .font(.caption).foregroundStyle(.secondary)
                    if let url = URL(string: "app-settings:") {
                        Link("設定アプリを開く", destination: url)
                            .font(.caption)
                    }
                }
            default:
                locationDetail
            }
        } header: {
            HStack {
                Text("位置情報")
                Spacer()
                if let age = locationContext.ageDescription() {
                    Text(locationContext.isStale ? "\(age) ・ 古い可能性" : age)
                        .font(.caption2)
                        .textCase(nil)
                        .foregroundStyle(locationContext.isStale ? .orange : .secondary)
                } else {
                    Text("許可: \(AuthStatusFormatter.describe(locationContext.authorizationStatus))")
                        .font(.caption2)
                        .textCase(nil)
                }
            }
        } footer: {
            if locationContext.location != nil {
                HStack {
                    if case .failed(let msg) = locationContext.state {
                        Text(msg)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                    if case .loading = locationContext.state {
                        ProgressView().controlSize(.mini)
                        Text("再取得中…")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Button("再取得") { locationContext.refresh() }
                            .font(.caption)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var locationDetail: some View {
        if let loc = locationContext.location {
            VStack(alignment: .leading, spacing: 4) {
                if let line1 = loc.displayLine1 {
                    Text(line1).font(.subheadline.bold())
                } else {
                    Text("座標のみ取得")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let line2 = loc.displayLine2 {
                    Text(line2).font(.caption).foregroundStyle(.secondary)
                }
                if !loc.areasOfInterest.isEmpty {
                    Text("周辺: " + loc.areasOfInterest.joined(separator: " / "))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Text(String(format: "%.5f, %.5f (±%.0fm)",
                            loc.latitude, loc.longitude, loc.horizontalAccuracy))
                    .font(.caption2.monospaced()).foregroundStyle(.tertiary)
            }
        } else if case .failed(let msg) = locationContext.state {
            VStack(alignment: .leading, spacing: 6) {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.orange)
                Button("再試行") { locationContext.refresh() }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
    }

    private var noteSection: some View {
        Section("メモ") {
            TextField("任意（点検内容、気付き等）", text: $note, axis: .vertical)
                .lineLimit(3...8)
        }
    }

    private func save() {
        var m = measurement
        m.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        m.location = locationContext.location
        onConfirm(m)
        dismiss()
    }
}
