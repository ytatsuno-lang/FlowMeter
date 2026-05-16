import SwiftUI

struct VolumeCalculatorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var shape: TankShape = .rectangular
    @State private var width: Double = 1.0
    @State private var depth: Double = 1.0
    @State private var height: Double = 1.0
    @State private var diameter: Double = 1.0

    @FocusState private var focused: Bool

    private var volumeM3: Double {
        switch shape {
        case .rectangular: return width * depth * height
        case .circular:
            let r = diameter / 2
            return .pi * r * r * height
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("形状") {
                    Picker("", selection: $shape) {
                        ForEach(TankShape.allCases) { s in
                            Text(s.label).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("寸法 [m]") {
                    switch shape {
                    case .rectangular:
                        numberRow(label: "幅 W", value: $width)
                        numberRow(label: "奥行 D", value: $depth)
                        numberRow(label: "高さ H", value: $height)
                    case .circular:
                        numberRow(label: "直径 Φ", value: $diameter)
                        numberRow(label: "高さ H", value: $height)
                    }
                }

                Section("容量") {
                    HStack {
                        Text("m³")
                        Spacer()
                        Text(String(format: "%.4f", volumeM3))
                            .font(.body.monospaced().bold())
                            .foregroundStyle(.blue)
                    }
                    HStack {
                        Text("L (= リットル)")
                        Spacer()
                        Text(String(format: "%.2f", volumeM3 * 1000))
                            .font(.body.monospaced().bold())
                            .foregroundStyle(.blue)
                    }
                    HStack {
                        Text("t (≒ トン, 水)")
                        Spacer()
                        Text(String(format: "%.3f", volumeM3))
                            .font(.body.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("容量計算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("完了") { focused = false }
                    }
                }
            }
        }
    }

    private func numberRow(label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(label, value: value, format: .number.precision(.fractionLength(0...3)))
                .keyboardType(.decimalPad)
                .focused($focused)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
        }
    }
}
