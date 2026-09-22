import Foundation
import CoreLocation

enum AccessType: String, Codable, Equatable, Sendable {
    case free, paid
    case includedInCollection
    case promotionalFree

    var isPayable: Bool { self == .paid }
}

struct Category: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let slug: String
    let title: String
    let icon: String?
    let sort: Int
}

struct Country: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let slug: String
    let name: String
    let emojiFlag: String?
    let coverUrl: String?
}

struct City: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let slug: String
    let title: String
    let description: String?
    let lat: Double?
    let lng: Double?
    let coverUrl: String?
    let countryId: String?
    let isOutsideCity: Bool?
}

struct Neighborhood: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let cityId: String
    let slug: String
    let title: String
    let description: String?
    let lat: Double?
    let lng: Double?
    let coverUrl: String?
}

struct PlaceCollection: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let slug: String
    let title: String
    let description: String?
    let coverUrl: String?
    let isFree: Bool
    let priceCents: Int
    let featured: Bool
    let cityId: String?
}

struct PlaceImage: Codable, Equatable, Sendable {
    let url: String
    let sort: Int?
    let isHero: Bool?
}

/// The public teaser card — what everyone can see (from `places_public`).
struct PlaceTeaser: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let slug: String
    let teaserTitle: String
    let teaserDescription: String
    let heroImageUrl: String?
    let approxLat: Double?
    let approxLng: Double?
    let countryId: String?
    let regionId: String?
    let cityId: String?
    let neighborhoodId: String?
    let primaryCategoryId: String?
    let accessType: AccessType
    let priceCents: Int
    let currency: String
    let productId: String?
    let isFreeNow: Bool?
    let travelTimeMin: Int?
    let recommendedTransport: String?
    let bestTime: String?
    let bestSeason: String?
    let expectedDurationMin: Int?
    let crowdLevel: String?
    let priceLevel: Int?
    let accessibilityInfo: String?
    let safetyInfo: String?
    let mobileSignal: String?
    let whatToBring: String?
    let rating: Double
    let ratingsCount: Int
    let featured: Bool
    let editorsChoice: Bool

    var isFreeExperience: Bool { accessType == .free || accessType == .promotionalFree || (isFreeNow ?? false) }
    var approxCoordinate: CLLocationCoordinate2D? {
        guard let la = approxLat, let ln = approxLng else { return nil }
        return CLLocationCoordinate2D(latitude: la, longitude: ln)
    }
    var priceLabel: String {
        if isFreeExperience { return "Free" }
        return String(format: "$%.2f", Double(priceCents) / 100.0)
    }
}

/// Full details from `get_place_details` RPC. Sensitive fields are present ONLY when unlocked.
struct PlaceDetails: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let slug: String
    let locked: Bool
    let teaserTitle: String
    let teaserDescription: String
    let heroImageUrl: String?
    let approxLat: Double?
    let approxLng: Double?
    let cityId: String?
    let neighborhoodId: String?
    let primaryCategoryId: String?
    let accessType: AccessType
    let priceCents: Int
    let currency: String
    let productId: String?
    let isFreeNow: Bool?
    let travelTimeMin: Int?
    let recommendedTransport: String?
    let bestTime: String?
    let bestSeason: String?
    let expectedDurationMin: Int?
    let crowdLevel: String?
    let priceLevel: Int?
    let accessibilityInfo: String?
    let safetyInfo: String?
    let mobileSignal: String?
    let whatToBring: String?
    let rating: Double
    let ratingsCount: Int
    let featured: Bool
    let editorsChoice: Bool
    let images: [PlaceImage]
    let tags: [String]

    // SENSITIVE — only when unlocked
    let fullTitle: String?
    let fullDescription: String?
    let exactLat: Double?
    let exactLng: Double?
    let exactAddress: String?
    let businessName: String?
    let walkingInstructions: String?
    let parkingInfo: String?
    let insiderTips: String?
    let photoSpot: String?
    let website: String?
    let bookingUrl: String?
    let appleMapsUrl: String?
    let googleMapsUrl: String?

    var isUnlocked: Bool { !locked }
    var exactCoordinate: CLLocationCoordinate2D? {
        guard let la = exactLat, let ln = exactLng else { return nil }
        return CLLocationCoordinate2D(latitude: la, longitude: ln)
    }
    var priceLabel: String {
        if accessType == .free || (isFreeNow ?? false) { return "Free" }
        return String(format: "$%.2f", Double(priceCents) / 100.0)
    }
    var displayTitle: String { isUnlocked ? (fullTitle ?? teaserTitle) : teaserTitle }
}

/// A nearby result (from nearby_places RPC).
struct NearbyPlace: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let slug: String
    let teaserTitle: String
    let teaserDescription: String
    let heroImageUrl: String?
    let approxLat: Double?
    let approxLng: Double?
    let primaryCategoryId: String?
    let accessType: AccessType
    let priceCents: Int
    let currency: String
    let isFreeNow: Bool
    let rating: Double
    let ratingsCount: Int
    let distanceM: Double
    let unlocked: Bool

    var distanceLabel: String {
        if distanceM < 1000 { return "\(Int(distanceM)) m" }
        return String(format: "%.1f km", distanceM / 1000)
    }
}

enum PlaceUserStatus: String, Codable, Sendable { case wantToVisit = "want_to_visit", visited }
