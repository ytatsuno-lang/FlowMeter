import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: MeasurementStore

    var body: some View {
        Group {
            if store.measurements.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("履歴はまだありません")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.measurements) { m in
                        NavigationLink {
                            MeasurementDetailView(store: store, measurementID: m.id)
                        } label: {
                            FlowMeasurementRow(measurement: m)
                        }
                    }
                    .onDelete(perform: store.delete)
                }
            }
        }
        .navigationTitle("計測履歴")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !store.measurements.isEmpty {
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
        }
    }
}

private struct FlowMeasurementRow: View {
    let measurement: FlowMeasurement

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm"
        f.locale = Locale(identifier: "ja_JP")
        return f
    }()

    var methodIcon: String {
        switch measurement.effectiveMethod {
        case .meter: return "gauge.with.dots.needle.50percent"
        case .tank:  return "drop.fill"
        }
    }

    var methodLabel: String {
        switch measurement.effectiveMethod {
        case .meter: return "メーター"
        case .tank:  return "水槽"
        }
    }

    var detailLine: String {
        switch measurement.effectiveMethod {
        case .meter:
            return "\(measurement.lapTimes.count)回 ・ 1周\(Int(measurement.capacityL)) L"
        case .tank:
            guard let t = measurement.tank else { return "" }
            return "\(t.shape.label) \(t.dimensionsLabel) ・ Δ\(String(format: "%.2f", t.levelDelta))m"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(methodLabel, systemImage: methodIcon)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(Capsule())
                Spacer()
                Text(Self.dateFormatter.string(from: measurement.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let avg = measurement.averageFlowRate {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.2f", avg))
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(.blue)
                    Text("m³/h")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text(detailLine)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let loc = measurement.location {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        if let line1 = loc.displayLine1 {
                            Text(line1).font(.caption).lineLimit(1)
                        }
                        if let line2 = loc.displayLine2 {
                            Text(line2)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }

            if !measurement.note.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(measurement.note)
                        .font(.caption)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct MeasurementDetailView: View {
    @ObservedObject var store: MeasurementStore
    let measurementID: UUID

    @State private var note: String = ""
    @State private var loaded = false

    private var measurement: FlowMeasurement? {
        store.measurements.first(where: { $0.id == measurementID })
    }

    static let detailDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy年MM月dd日 (E) HH:mm"
        f.locale = Locale(identifier: "ja_JP")
        return f
    }()

    var body: some View {
        Form {
            if let m = measurement {
                Section("計測結果") {
                    LabeledContent("日時", value: Self.detailDateFormatter.string(from: m.date))
                    LabeledContent("方式") {
                        switch m.effectiveMethod {
                        case .meter: Label("メーター式", systemImage: "gauge.with.dots.needle.50percent")
                        case .tank:  Label("水槽式", systemImage: "drop.fill")
                        }
                    }
                    if let avg = m.averageFlowRate {
                        LabeledContent("流量") {
                            Text(String(format: "%.2f m³/h", avg))
                                .font(.body.monospaced().bold())
                                .foregroundStyle(.blue)
                        }
                    }
                }

                switch m.effectiveMethod {
                case .meter:
                    Section("メーター詳細") {
                        LabeledContent("1周容量", value: "\(Int(m.capacityL)) L")
                    }
                    Section("各回") {
                        ForEach(Array(m.lapTimes.enumerated()), id: \.offset) { i, t in
                            HStack {
                                Text("\(i + 1) 回目")
                                Spacer()
                                Text(String(format: "%.2f s", t))
                                    .font(.body.monospaced())
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.2f m³/h",
                                            FlowMeasurement.flowRate(capacityL: m.capacityL, seconds: t)))
                                    .font(.body.monospaced())
                            }
                        }
                    }
                case .tank:
                    if let t = m.tank {
                        Section("水槽詳細") {
                            LabeledContent("形状", value: t.shape.label)
                            LabeledContent("寸法", value: t.dimensionsLabel)
                            LabeledContent("断面積") {
                                Text(String(format: "%.3f m²", t.crossSectionM2))
                                    .font(.body.monospaced())
                            }
                            LabeledContent("水位差 Δh") {
                                Text(String(format: "%.3f m", t.levelDelta))
                                    .font(.body.monospaced())
                            }
                            LabeledContent("体積変化") {
                                Text(String(format: "%.3f m³ (%.1f L)", t.volumeDeltaM3, t.volumeDeltaL))
                                    .font(.body.monospaced())
                            }
                            LabeledContent("経過時間") {
                                Text(String(format: "%.2f s", t.elapsedSeconds))
                                    .font(.body.monospaced())
                            }
                        }
                    }
                }

                if let loc = m.location {
                    Section("位置情報") {
                        if let name = loc.placeName {
                            LabeledContent("施設/POI", value: name)
                        }
                        if let addr = loc.address {
                            LabeledContent("住所", value: addr)
                        }
                        if !loc.areasOfInterest.isEmpty {
                            LabeledContent("周辺", value: loc.areasOfInterest.joined(separator: " / "))
                        }
                        LabeledContent("座標") {
                            Text(String(format: "%.5f, %.5f", loc.latitude, loc.longitude))
                                .font(.caption.monospaced())
                        }
                        LabeledContent("精度") {
                            Text(String(format: "±%.0f m", loc.horizontalAccuracy))
                                .font(.caption.monospaced())
                        }
                    }
                }

                Section {
                    TextField("メモ（任意）", text: $note, axis: .vertical)
                        .lineLimit(3...10)
                } header: {
                    Text("メモ")
                } footer: {
                    Text("画面を戻ると自動保存されます")
                        .font(.caption2)
                }
            } else {
                Text("データが見つかりません").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("詳細")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !loaded, let m = measurement {
                note = m.note
                loaded = true
            }
        }
        .onDisappear {
            saveIfChanged()
        }
    }

    private func saveIfChanged() {
        guard var m = measurement else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != m.note {
            m.note = trimmed
            store.update(m)
        }
    }
}
