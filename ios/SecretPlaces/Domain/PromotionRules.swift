import Foundation

/// Pure client-side mirror of the server's is_free_now logic. The server is
/// authoritative; this is used for display and is fully unit-testable.
enum PromotionRules {
    static func isFreeNow(accessType: AccessType, isFreeNowFlag: Bool?, promoStart: Date?, promoEnd: Date?, now: Date = Date()) -> Bool {
        if accessType == .free || accessType == .promotionalFree { return true }
        if isFreeNowFlag == true { return true }
        if let s = promoStart, let e = promoEnd, now >= s, now <= e { return true }
        return false
    }
}

/// Pure geo helper (haversine).
enum Geo {
    static func distanceMeters(_ aLat: Double, _ aLng: Double, _ bLat: Double, _ bLng: Double) -> Double {
        let r = 6_371_000.0
        let dLat = (bLat - aLat) * .pi / 180
        let dLng = (bLng - aLng) * .pi / 180
        let lat1 = aLat * .pi / 180, lat2 = bLat * .pi / 180
        let h = sin(dLat/2) * sin(dLat/2) + cos(lat1) * cos(lat2) * sin(dLng/2) * sin(dLng/2)
        return 2 * r * asin(min(1, sqrt(h)))
    }
}
