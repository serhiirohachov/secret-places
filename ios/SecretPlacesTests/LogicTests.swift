import XCTest
@testable import SecretPlaces

final class PromotionRulesTests: XCTestCase {
    func testFreeAndPromoTypesAreAlwaysFree() {
        XCTAssertTrue(PromotionRules.isFreeNow(accessType: .free, isFreeNowFlag: nil, promoStart: nil, promoEnd: nil))
        XCTAssertTrue(PromotionRules.isFreeNow(accessType: .promotionalFree, isFreeNowFlag: nil, promoStart: nil, promoEnd: nil))
    }
    func testPaidIsNotFreeByDefault() {
        XCTAssertFalse(PromotionRules.isFreeNow(accessType: .paid, isFreeNowFlag: nil, promoStart: nil, promoEnd: nil))
    }
    func testActivePromoWindowMakesPaidFree() {
        let now = Date()
        XCTAssertTrue(PromotionRules.isFreeNow(accessType: .paid, isFreeNowFlag: nil,
            promoStart: now.addingTimeInterval(-3600), promoEnd: now.addingTimeInterval(3600), now: now))
    }
    func testExpiredPromoWindowKeepsPaidLocked() {
        let now = Date()
        XCTAssertFalse(PromotionRules.isFreeNow(accessType: .paid, isFreeNowFlag: nil,
            promoStart: now.addingTimeInterval(-7200), promoEnd: now.addingTimeInterval(-3600), now: now))
    }
}

final class GeoTests: XCTestCase {
    func testDistanceToSelfIsZero() {
        XCTAssertEqual(Geo.distanceMeters(50.45, 30.52, 50.45, 30.52), 0, accuracy: 0.001)
    }
    func testKyivToLvivIsRoughly470km() {
        let d = Geo.distanceMeters(50.4501, 30.5234, 49.8397, 24.0297)
        XCTAssertGreaterThan(d, 450_000)
        XCTAssertLessThan(d, 500_000)
    }
}

final class QueryFilterTests: XCTestCase {
    func testFreeOnlyFilter() async throws {
        let repo = MockPlaceRepository()
        let free = try await repo.list(PlaceQuery(freeOnly: true))
        XCTAssertTrue(free.allSatisfy { $0.isFreeExperience })
        XCTAssertFalse(free.isEmpty)
    }
    func testAccessTypeFilter() async throws {
        let repo = MockPlaceRepository()
        let paid = try await repo.list(PlaceQuery(accessType: .paid))
        XCTAssertTrue(paid.allSatisfy { $0.accessType == .paid })
    }
    func testFeaturedAndEditorsFilters() async throws {
        let repo = MockPlaceRepository()
        let featured = try await repo.list(PlaceQuery(featuredOnly: true))
        XCTAssertTrue(featured.allSatisfy { $0.featured })
        let editors = try await repo.list(PlaceQuery(editorsOnly: true))
        XCTAssertTrue(editors.allSatisfy { $0.editorsChoice })
    }
    func testNearbyRespectsRadiusAndSorts() async throws {
        let repo = MockPlaceRepository()
        let near = try await repo.nearby(lat: 50.4487, lng: 30.5142, radiusM: 5000, limit: 10)
        XCTAssertFalse(near.isEmpty)
        for i in 1..<near.count { XCTAssertLessThanOrEqual(near[i-1].distanceM, near[i].distanceM) }
    }
}

final class ModelFormattingTests: XCTestCase {
    func testPriceLabels() {
        XCTAssertEqual(MockData.teaser("a", "A", access: .free).priceLabel, "Free")
        XCTAssertEqual(MockData.teaser("b", "B", access: .paid).priceLabel, "$0.99")
        XCTAssertEqual(MockData.teaser("c", "C", access: .promotionalFree).priceLabel, "Free")
    }
    func testDistanceLabel() {
        let p = NearbyPlace(id: "x", slug: "x", teaserTitle: "t", teaserDescription: "d", heroImageUrl: nil,
            approxLat: 0, approxLng: 0, primaryCategoryId: nil, accessType: .free, priceCents: 0, currency: "USD",
            isFreeNow: true, rating: 0, ratingsCount: 0, distanceM: 1500, unlocked: true)
        XCTAssertEqual(p.distanceLabel, "1.5 km")
    }
}
