import XCTest
@testable import SecretPlaces

/// Client-side mirror of the CRITICAL security criterion:
/// sensitive fields must never appear on a locked place.
final class PrivacyAndEntitlementTests: XCTestCase {

    func testLockedPaidPlaceHidesSensitiveData() async throws {
        let repo = MockPlaceRepository(unlockedIds: [])
        let details = try await repo.details(id: "paid1")   // paid, not entitled
        XCTAssertTrue(details.locked)
        XCTAssertFalse(details.isUnlocked)
        XCTAssertNil(details.exactLat)
        XCTAssertNil(details.exactLng)
        XCTAssertNil(details.exactCoordinate)
        XCTAssertNil(details.businessName)
        XCTAssertNil(details.fullDescription)
        XCTAssertNil(details.walkingInstructions)
    }

    func testEntitlementUnlocksExactData() async throws {
        let repo = MockPlaceRepository(unlockedIds: ["paid1"])
        let details = try await repo.details(id: "paid1")
        XCTAssertFalse(details.locked)
        XCTAssertEqual(try XCTUnwrap(details.exactLat), 50.4490, accuracy: 0.0001)
        XCTAssertEqual(details.businessName, "The Val")
        XCTAssertEqual(details.displayTitle, "The Val Speakeasy")   // uses fullTitle when unlocked
        XCTAssertNotNil(details.exactCoordinate)
    }

    func testFreePlaceAlwaysRevealsExactData() async throws {
        let repo = MockPlaceRepository(unlockedIds: [])
        let details = try await repo.details(id: "free1")
        XCTAssertFalse(details.locked)
        XCTAssertNotNil(details.exactLat)
        XCTAssertEqual(details.businessName, "Courtyard Roasters")
    }

    func testPromotionalFreePlaceIsUnlockedWithoutPurchase() async throws {
        let repo = MockPlaceRepository(unlockedIds: [])
        let details = try await repo.details(id: "promo1")
        XCTAssertFalse(details.locked)
        XCTAssertNotNil(details.exactCoordinate)
    }
}
