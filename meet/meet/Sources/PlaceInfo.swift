import CoreLocation
import Foundation

struct PlaceDataField: Identifiable {
    let label: String
    let value: String

    var id: String { "\(label)|\(value)" }
}

struct PlaceInfo: Identifiable {
    let id = UUID()
    var name: String
    var category: String
    var coordinate: CLLocationCoordinate2D
    var isBar: Bool
    var addressText: String?
    var phone: String?
    var website: URL?
    var timeZoneIdentifier: String?
    var mapItemIdentifier: String?
    var isLoadingDetails: Bool = false
    var detailsError: String?
    var unsupportedFieldsNote: String?
    var availableFields: [PlaceDataField] = []
    var foursquarePlaceID: String?
    var foursquareCategoryNames: [String] = []
    var foursquareDescriptionText: String?
    var foursquareHoursText: String?
    var foursquarePhone: String?
    var foursquareWebsite: URL?
    var foursquareSocialLinks: [String: String] = [:]
    var foursquareRating: Double?
    var foursquareReviewCount: Int?
    var foursquareReviewSnippets: [String] = []
    var isLoadingFoursquareDetails: Bool = false
    var foursquareDetailsError: String?

    var mapsURL: URL? {
        var components = URLComponents(string: "https://maps.apple.com")
        components?.queryItems = [
            URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "q", value: name),
        ]
        return components?.url
    }
}
