import XCTest
@testable import SecretPlaces

/// Decodes the real shapes returned by Supabase (snake_case) to guard the contract.
final class DecodingTests: XCTestCase {
    private func decoder() -> JSONDecoder {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d
    }

    func testDecodeLockedPlaceDetailsHasNoSensitiveFields() throws {
        // Mirrors get_place_details() output for a locked paid place — NO exact_* keys.
        let json = """
        {"id":"1","slug":"x","locked":true,"teaser_title":"Cocktail bar","teaser_description":"Hidden.",
        "hero_image_url":null,"approx_lat":50.45,"approx_lng":30.52,"city_id":"c","neighborhood_id":"n",
        "primary_category_id":"cat","access_type":"paid","price_cents":99,"currency":"USD",
        "product_id":"com.secretplaces.place.x","is_free_now":false,"travel_time_min":12,
        "recommended_transport":"walk","best_time":"evening","best_season":"all year","expected_duration_min":60,
        "crowd_level":"medium","price_level":2,"accessibility_info":null,"safety_info":null,"mobile_signal":"good",
        "what_to_bring":null,"rating":0,"ratings_count":0,"featured":true,"editors_choice":true,"images":[],"tags":[]}
        """.data(using: .utf8)!
        let d = try decoder().decode(PlaceDetails.self, from: json)
        XCTAssertTrue(d.locked)
        XCTAssertNil(d.exactLat)
        XCTAssertNil(d.businessName)
        XCTAssertNil(d.fullDescription)
    }

    func testDecodeUnlockedPlaceDetailsHasSensitiveFields() throws {
        let json = """
        {"id":"1","slug":"x","locked":false,"teaser_title":"Cocktail bar","teaser_description":"Hidden.",
        "hero_image_url":null,"approx_lat":50.45,"approx_lng":30.52,"city_id":"c","neighborhood_id":"n",
        "primary_category_id":"cat","access_type":"paid","price_cents":99,"currency":"USD",
        "product_id":"com.secretplaces.place.x","is_free_now":false,"travel_time_min":12,
        "recommended_transport":"walk","best_time":"evening","best_season":"all year","expected_duration_min":60,
        "crowd_level":"medium","price_level":2,"accessibility_info":null,"safety_info":null,"mobile_signal":"good",
        "what_to_bring":null,"rating":4.5,"ratings_count":3,"featured":true,"editors_choice":true,
        "images":[{"url":"https://x/i.jpg","sort":0,"is_hero":true}],"tags":["hidden"],
        "full_title":"The Val Speakeasy","full_description":"Knock to enter.","exact_lat":50.449,"exact_lng":30.515,
        "exact_address":"Kyiv","business_name":"The Val","walking_instructions":"Steel door.","parking_info":null,
        "insider_tips":"Off-menu sour.","photo_spot":null,"website":null,"booking_url":null,
        "apple_maps_url":"https://maps.apple.com","google_maps_url":"https://maps.google.com","opening_hours":null}
        """.data(using: .utf8)!
        let d = try decoder().decode(PlaceDetails.self, from: json)
        XCTAssertFalse(d.locked)
        XCTAssertEqual(try XCTUnwrap(d.exactLat), 50.449, accuracy: 0.0001)
        XCTAssertEqual(d.businessName, "The Val")
        XCTAssertEqual(d.images.count, 1)
        XCTAssertEqual(d.displayTitle, "The Val Speakeasy")
    }

    func testDecodePlaceTeaserFromPublicView() throws {
        let json = """
        [{"id":"1","slug":"x","teaser_title":"T","teaser_description":"D","hero_image_url":null,
        "approx_lat":50.45,"approx_lng":30.52,"country_id":"ua","region_id":null,"city_id":"c","neighborhood_id":"n",
        "primary_category_id":"cat","access_type":"promotionalFree","price_cents":99,"currency":"USD","product_id":null,
        "is_free_now":true,"travel_time_min":10,"recommended_transport":"walk","best_time":"evening","best_season":"all",
        "expected_duration_min":45,"crowd_level":"low","price_level":1,"accessibility_info":null,"safety_info":null,
        "mobile_signal":"good","what_to_bring":null,"rating":5,"ratings_count":1,"featured":false,"editors_choice":false}]
        """.data(using: .utf8)!
        let arr = try decoder().decode([PlaceTeaser].self, from: json)
        XCTAssertEqual(arr.count, 1)
        XCTAssertEqual(arr[0].accessType, .promotionalFree)
        XCTAssertTrue(arr[0].isFreeExperience)
    }
}
