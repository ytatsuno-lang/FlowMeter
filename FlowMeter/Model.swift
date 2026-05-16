import Foundation
import SwiftUI
import Combine

enum RotationCapacity: Int, CaseIterable, Codable, Identifiable {
    case ten = 10
    case hundred = 100
    case thousand = 1000

    var id: Int { rawValue }
    var liters: Double { Double(rawValue) }
    var shortLabel: String { "\(rawValue) L" }
    var detailLabel: String {
        switch self {
        case .ten:      return "×0.001針 (1周 10 L)"
        case .hundred:  return "×0.01針 (1周 100 L)"
        case .thousand: return "×0.1針 (1周 1000 L)"
        }
    }
}

enum MeasurementMethod: String, Codable {
    case meter
    case tank
}

enum TankShape: String, Codable, CaseIterable, Identifiable {
    case rectangular
    case circular

    var id: String { rawValue }
    var label: String {
        switch self {
        case .rectangular: return "矩形"
        case .circular:    return "円形"
        }
    }
}

struct TankInfo: Codable, Equatable {
    var shape: TankShape
    var width: Double = 0      // 矩形: 幅 [m]
    var depth: Double = 0      // 矩形: 奥行 [m]
    var diameter: Double = 0   // 円形: 直径 [m]
    var levelDelta: Double     // 水位差 [m]
    var elapsedSeconds: TimeInterval

    var crossSectionM2: Double {
        switch shape {
        case .rectangular: return width * depth
        case .circular:
            let r = diameter / 2
            return .pi * r * r
        }
    }

    var volumeDeltaM3: Double { abs(crossSectionM2 * levelDelta) }
    var volumeDeltaL: Double { volumeDeltaM3 * 1000 }

    var flowRateM3H: Double {
        guard elapsedSeconds > 0 else { return 0 }
        return volumeDeltaM3 * 3600 / elapsedSeconds
    }

    var dimensionsLabel: String {
        switch shape {
        case .rectangular:
            return String(format: "%.2f × %.2f m", width, depth)
        case .circular:
            return String(format: "Φ%.2f m", diameter)
        }
    }
}

struct LocationSnapshot: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    var horizontalAccuracy: Double
    var placeName: String? = nil
    var address: String? = nil
    var areasOfInterest: [String] = []

    var displayLine1: String? {
        placeName ?? address
    }

    var displayLine2: String? {
        if placeName != nil { return address }
        return nil
    }
}

struct FlowMeasurement: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var capacityL: Double
    var lapTimes: [TimeInterval]
    var note: String = ""
    var location: LocationSnapshot? = nil
    var method: MeasurementMethod? = nil   // nil = .meter（後方互換）
    var tank: TankInfo? = nil

    var effectiveMethod: MeasurementMethod { method ?? .meter }

    var averageTime: TimeInterval? {
        guard !lapTimes.isEmpty else { return nil }
        return lapTimes.reduce(0, +) / Double(lapTimes.count)
    }

    var averageFlowRate: Double? {
        switch effectiveMethod {
        case .meter:
            guard let t = averageTime, t > 0 else { return nil }
            return Self.flowRate(capacityL: capacityL, seconds: t)
        case .tank:
            guard let t = tank, t.elapsedSeconds > 0 else { return nil }
            return t.flowRateM3H
        }
    }

    static func flowRate(capacityL: Double, seconds: TimeInterval) -> Double {
        guard seconds > 0 else { return 0 }
        return capacityL * 3.6 / seconds
    }
}

final class MeasurementStore: ObservableObject {
    @Published var measurements: [FlowMeasurement] = []
    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("flow_measurements.json")
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let list = try? decoder.decode([FlowMeasurement].self, from: data) {
            measurements = list
        }
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(measurements) {
            try? data.write(to: fileURL)
        }
    }

    func add(_ m: FlowMeasurement) {
        measurements.insert(m, at: 0)
        save()
    }

    func delete(at offsets: IndexSet) {
        measurements.remove(atOffsets: offsets)
        save()
    }

    func update(_ m: FlowMeasurement) {
        guard let idx = measurements.firstIndex(where: { $0.id == m.id }) else { return }
        measurements[idx] = m
        save()
    }
}
