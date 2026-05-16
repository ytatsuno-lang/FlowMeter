import Foundation
import CoreLocation
import Combine

enum LocationFetchState: Equatable {
    case idle
    case loading
    case success
    case denied
    case failed(String)
}

final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum LocationError: LocalizedError {
        case denied
        case unavailable
        case timeout
        var errorDescription: String? {
            switch self {
            case .denied:      return "位置情報の使用が許可されていません。設定アプリから許可してください。"
            case .unavailable: return "現在地を取得できませんでした"
            case .timeout:     return "位置情報の取得がタイムアウトしました"
            }
        }
    }

    private let manager = CLLocationManager()
    private var completion: ((Result<CLLocation, Error>) -> Void)?
    private var timeoutTask: Task<Void, Never>?
    private let cacheMaxAge: TimeInterval = 300        // 5分
    private let cacheMaxAccuracy: Double = 1000        // 1km以内

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }
    var lastKnownLocation: CLLocation? { manager.location }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation(timeoutSeconds: TimeInterval = 20,
                         completion: @escaping (Result<CLLocation, Error>) -> Void) {
        self.completion = completion

        // 直近キャッシュがあれば即返す
        if let cached = manager.location,
           -cached.timestamp.timeIntervalSinceNow < cacheMaxAge,
           cached.horizontalAccuracy >= 0,
           cached.horizontalAccuracy < cacheMaxAccuracy {
            finish(.success(cached))
            return
        }

        startTimeout(timeoutSeconds)
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            finish(.failure(LocationError.denied))
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        @unknown default:
            finish(.failure(LocationError.unavailable))
        }
    }

    func cancel() {
        finish(.failure(LocationError.unavailable))
    }

    private func startTimeout(_ seconds: TimeInterval) {
        timeoutTask?.cancel()
        timeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if Task.isCancelled { return }
            guard let self, self.completion != nil else { return }
            // タイムアウト時、過去に取得した位置があればそれを使う
            if let last = self.manager.location, last.horizontalAccuracy >= 0 {
                self.finish(.success(last))
            } else {
                self.finish(.failure(LocationError.timeout))
            }
        }
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        timeoutTask?.cancel()
        timeoutTask = nil
        let c = completion
        completion = nil
        c?(result)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if completion != nil { manager.requestLocation() }
        case .denied, .restricted:
            finish(.failure(LocationError.denied))
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last, loc.horizontalAccuracy >= 0 else { return }
        finish(.success(loc))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 失敗してもキャッシュがあればそれで完了
        if let last = manager.location, last.horizontalAccuracy >= 0 {
            finish(.success(last))
        } else {
            finish(.failure(error))
        }
    }
}

enum Geocoder {
    static func reverseGeocode(_ location: CLLocation) async -> CLPlacemark? {
        let geocoder = CLGeocoder()
        let locale = Locale(identifier: "ja_JP")
        let placemarks = try? await geocoder.reverseGeocodeLocation(location, preferredLocale: locale)
        return placemarks?.first
    }

    static func reverseGeocodeWithTimeout(_ location: CLLocation, timeoutSeconds: Double) async -> CLPlacemark? {
        await withTaskGroup(of: CLPlacemark?.self) { group in
            group.addTask { await reverseGeocode(location) }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    static func formatAddress(_ pm: CLPlacemark) -> String? {
        var parts: [String] = []
        if let v = pm.administrativeArea { parts.append(v) }
        if let v = pm.locality { parts.append(v) }
        if let v = pm.subLocality { parts.append(v) }
        if let v = pm.thoroughfare { parts.append(v) }
        if let v = pm.subThoroughfare { parts.append(v) }
        return parts.isEmpty ? nil : parts.joined()
    }

    static func extractPlaceName(_ pm: CLPlacemark, address: String?) -> String? {
        guard let name = pm.name, !name.isEmpty else { return nil }
        if let address, name == address { return nil }
        if let thoroughfare = pm.thoroughfare, name.contains(thoroughfare) { return nil }
        return name
    }
}

enum AuthStatusFormatter {
    static func describe(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:       return "未確認"
        case .restricted:          return "制限中（保護者制限など）"
        case .denied:              return "拒否中"
        case .authorizedAlways:    return "常に許可"
        case .authorizedWhenInUse: return "使用中のみ許可"
        @unknown default:          return "不明"
        }
    }
}
