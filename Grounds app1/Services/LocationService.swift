import Foundation
import CoreLocation
import Combine

class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()

    @Published var location: CLLocation?
    @Published var authStatus: CLAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    // CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }

    func locationManager(_ manager: CLLocationManager,
                         didChangeAuthorization status: CLAuthorizationStatus) {
        authStatus = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            start()
        }
    }

    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }

    // Distance from user to a shop
    func distance(to shop: CoffeeShop) -> String? {
        guard let loc = location else { return nil }
        let shopLoc = CLLocation(latitude: shop.latitude, longitude: shop.longitude)
        let meters = loc.distance(from: shopLoc)
        let miles  = meters / 1609.34
        return miles < 0.1 ? "Here now" :
               miles < 1   ? String(format: "%.0f ft", meters * 3.281) :
                              String(format: "%.1f mi", miles)
    }
}
