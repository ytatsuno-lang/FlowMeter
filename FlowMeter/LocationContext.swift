import SwiftUI
import CoreLocation
import Combine

@MainActor
final class LocationContext: ObservableObject {
    @Published var location: LocationSnapshot? = nil
    @Published var capturedAt: Date? = nil
    @Published var state: LocationFetchState = .idle

    private let service = LocationService()

    var authorizationStatus: CLAuthorizationStatus { service.authorizationStatus }

    var ageSeconds: TimeInterval? {
        capturedAt.map { -$0.timeIntervalSinceNow }
    }

    func ageDescription(asOf now: Date = Date()) -> String? {
        guard let t = capturedAt else { return nil }
        let secs = now.timeIntervalSince(t)
        if secs < 60 { return "たった今" }
        if secs < 3600 { return "\(Int(secs/60))分前" }
        let h = Int(secs/3600)
        if h < 24 { return "\(h)時間前" }
        return "\(h/24)日前"
    }

    var isStale: Bool {
        guard let s = ageSeconds else { return false }
        return s > 3600
    }

    func refresh() {
        state = .loading
        service.requestLocation(timeoutSeconds: 30) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let loc):
                    var snap = LocationSnapshot(
                        latitude: loc.coordinate.latitude,
                        longitude: loc.coordinate.longitude,
                        horizontalAccuracy: loc.horizontalAccuracy
                    )
                    self.location = snap
                    self.capturedAt = Date()
                    self.state = .success
                    if let placemark = await Geocoder.reverseGeocodeWithTimeout(loc, timeoutSeconds: 5) {
                        snap.address = Geocoder.formatAddress(placemark)
                        snap.placeName = Geocoder.extractPlaceName(placemark, address: snap.address)
                        snap.areasOfInterest = placemark.areasOfInterest ?? []
                        self.location = snap
                    }
                case .failure(let err):
                    if let le = err as? LocationService.LocationError, case .denied = le {
                        self.state = .denied
                    } else if self.location != nil {
                        self.state = .failed("更新失敗、前回の位置を保持")
                    } else {
                        self.state = .failed(err.localizedDescription)
                    }
                }
            }
        }
    }

    func cancel() {
        service.cancel()
        if case .loading = state {
            state = location != nil ? .success : .idle
        }
    }

    func clear() {
        service.cancel()
        location = nil
        capturedAt = nil
        state = .idle
    }
}

struct LocationBadge: View {
    @EnvironmentObject var context: LocationContext

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .font(.body)
            VStack(alignment: .leading, spacing: 1) {
                Text(line1)
                    .font(.caption)
                    .lineLimit(1)
                if let l2 = line2 {
                    Text(l2)
                        .font(.caption2)
                        .foregroundStyle(staleColor)
                        .lineLimit(1)
                }
            }
            Spacer()
            actionButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var actionButton: some View {
        if case .loading = context.state {
            ProgressView().controlSize(.small)
        } else {
            Button {
                context.refresh()
            } label: {
                Text(context.location == nil ? "取得" : "更新")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var iconName: String {
        if case .denied = context.state { return "location.slash" }
        if case .loading = context.state { return "location.circle" }
        return "mappin.and.ellipse"
    }

    private var iconColor: Color {
        if case .denied = context.state { return .orange }
        if context.location != nil {
            return context.isStale ? .orange : .blue
        }
        return .secondary
    }

    private var staleColor: Color {
        context.isStale ? .orange : .secondary
    }

    private var line1: String {
        if case .denied = context.state { return "位置情報拒否中" }
        if case .loading = context.state { return "現在地を取得中…" }
        if let loc = context.location {
            return loc.displayLine1 ?? "座標のみ取得"
        }
        if case .failed(let msg) = context.state { return msg }
        return "位置情報なし"
    }

    private var line2: String? {
        guard let age = context.ageDescription() else { return nil }
        if context.isStale {
            return "\(age) ・ 古い可能性"
        }
        return age
    }

    private var backgroundColor: Color {
        if context.isStale { return Color.orange.opacity(0.10) }
        return Color.gray.opacity(0.10)
    }
}
