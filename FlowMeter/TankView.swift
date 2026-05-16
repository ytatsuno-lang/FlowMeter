import SwiftUI
import CoreLocation

struct TankView: View {
    @EnvironmentObject var store: MeasurementStore
    @EnvironmentObject var locationContext: LocationContext

    @State private var shape: TankShape = .rectangular
    @State private var width: Double = 1.0
    @State private var depth: Double = 1.0
    @State private var diameter: Double = 1.0
    @State private var levelDelta: Double = 0.10

    @State private var startDate: Date? = nil
    @State private var elapsedFinal: TimeInterval? = nil

    @State private var showSaveSheet = false

    @FocusState private var focusedField: Field?
    enum Field: Hashable { case width, depth, diameter, levelDelta }

    private var isRunning: Bool { startDate != nil }
    private var hasResult: Bool { elapsedFinal != nil }
    private var canEditDimensions: Bool { !isRunning && !hasResult }

    private var crossSectionM2: Double {
        switch shape {
        case .rectangular: return width * depth
        case .circular:    let r = diameter / 2; return .pi * r * r
        }
    }
    private var volumeDeltaM3: Double { abs(crossSectionM2 * levelDelta) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                LocationBadge()
                shapePicker
                dimensionInputs
                levelDeltaInput
                predictionBox
                liveDisplay
                mainButton
                bottomButtons
                Spacer(minLength: 80)
            }
            .padding()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    HStack(spacing: 16) {
                        Button {
                            moveFocus(forward: false)
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(!canMoveFocus(forward: false))
                        Button {
                            moveFocus(forward: true)
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(!canMoveFocus(forward: true))
                        Spacer()
                        Button("完了") { focusedField = nil }
                    }
                }
            }
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
        .ignoresSafeArea(.keyboard)
    }

    private var orderedFields: [Field] {
        switch shape {
        case .rectangular: return [.width, .depth, .levelDelta]
        case .circular:    return [.diameter, .levelDelta]
        }
    }

    private func canMoveFocus(forward: Bool) -> Bool {
        guard let current = focusedField,
              let idx = orderedFields.firstIndex(of: current) else { return false }
        return forward ? idx + 1 < orderedFields.count : idx > 0
    }

    private func moveFocus(forward: Bool) {
        guard let current = focusedField,
              let idx = orderedFields.firstIndex(of: current) else { return }
        let nextIdx = forward ? idx + 1 : idx - 1
        guard orderedFields.indices.contains(nextIdx) else { return }
        focusedField = orderedFields[nextIdx]
    }

    private var shapePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("形状")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("", selection: $shape) {
                ForEach(TankShape.allCases) { s in
                    Text(s.label).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!canEditDimensions)
        }
    }

    @ViewBuilder
    private var dimensionInputs: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("寸法 [m]")
                .font(.caption)
                .foregroundStyle(.secondary)
            switch shape {
            case .rectangular:
                HStack(spacing: 10) {
                    labeledField(label: "幅 W", value: $width, field: .width)
                    Text("×").foregroundStyle(.secondary)
                    labeledField(label: "奥行 D", value: $depth, field: .depth)
                }
            case .circular:
                labeledField(label: "直径 Φ", value: $diameter, field: .diameter)
            }
        }
    }

    private var levelDeltaInput: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("水位差 Δh [m]")
                .font(.caption)
                .foregroundStyle(.secondary)
            labeledField(label: "Δh", value: $levelDelta, field: .levelDelta)
        }
    }

    private func labeledField(label: String, value: Binding<Double>, field: Field) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            TextField(label, value: value, format: .number.precision(.fractionLength(0...3)))
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: field)
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(canEditDimensions ? Color.gray.opacity(0.12) : Color.gray.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(!canEditDimensions)
        }
    }

    private var predictionBox: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("断面積")
                    .font(.caption2).foregroundStyle(.secondary)
                Text(String(format: "%.3f m²", crossSectionM2))
                    .font(.subheadline.monospaced())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("体積変化（Δh分）")
                    .font(.caption2).foregroundStyle(.secondary)
                Text(String(format: "%.3f m³ = %.1f L", volumeDeltaM3, volumeDeltaM3 * 1000))
                    .font(.subheadline.monospaced())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var liveDisplay: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { ctx in
            let elapsed: Double = {
                if let e = elapsedFinal { return e }
                if let s = startDate { return ctx.date.timeIntervalSince(s) }
                return 0
            }()
            VStack(spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: "%.2f", elapsed))
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .foregroundStyle(isRunning || hasResult ? .primary : .secondary)
                    Text("秒")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if elapsed > 0.1 {
                    let flow = volumeDeltaM3 * 3600 / elapsed
                    Text(String(format: "%.2f m³/h", flow))
                        .font(.title3.monospaced())
                        .foregroundStyle((isRunning || hasResult) ? .blue : .secondary)
                } else {
                    Text("—").font(.title3).foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.gray.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
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
        .disabled(!canStart && !isRunning && !hasResult)
    }

    private var mainButtonLabel: String {
        if hasResult { return "完了" }
        if isRunning { return "STOP" }
        return "START"
    }

    private var mainButtonSublabel: String? {
        if hasResult { return "計測済み" }
        if isRunning { return "水位がΔh変化したらタップ" }
        return "水位の基準を読んだらタップ"
    }

    private var mainButtonColor: Color {
        if hasResult { return .gray }
        if isRunning { return .orange }
        return canStart ? .blue : .gray
    }

    private var canStart: Bool {
        guard levelDelta > 0 else { return false }
        switch shape {
        case .rectangular: return width > 0 && depth > 0
        case .circular:    return diameter > 0
        }
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
            .disabled(!isRunning && !hasResult)

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

    private var canSave: Bool { hasResult && !isRunning }

    private func mainAction() {
        if hasResult { return }
        let now = Date()
        if let s = startDate {
            elapsedFinal = now.timeIntervalSince(s)
            startDate = nil
        } else {
            guard canStart else { return }
            focusedField = nil
            locationContext.refresh()
            startDate = now
        }
    }

    private func reset() {
        startDate = nil
        elapsedFinal = nil
    }

    private func saveCurrent() { showSaveSheet = true }

    private func buildMeasurement() -> FlowMeasurement {
        let tank = TankInfo(
            shape: shape,
            width: shape == .rectangular ? width : 0,
            depth: shape == .rectangular ? depth : 0,
            diameter: shape == .circular ? diameter : 0,
            levelDelta: levelDelta,
            elapsedSeconds: elapsedFinal ?? 0
        )
        return FlowMeasurement(
            date: Date(),
            capacityL: 0,
            lapTimes: [],
            method: .tank,
            tank: tank
        )
    }
}
