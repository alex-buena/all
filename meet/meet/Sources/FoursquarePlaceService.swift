import CoreLocation
import Foundation

struct FoursquareEnrichment {
    let placeID: String
    let resolvedName: String?
    let categoryNames: [String]
    let descriptionText: String?
    let hoursText: String?
    let phone: String?
    let website: URL?
    let socialLinks: [String: String]
    let rating: Double?
    let reviewCount: Int?
    let reviewSnippets: [String]
}

enum FoursquarePlaceServiceError: LocalizedError {
    case noSearchResults
    case invalidResponse
    case malformedPayload
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .noSearchResults:
            return "No Foursquare place match found for this location."
        case .invalidResponse:
            return "Invalid response from Foursquare."
        case .malformedPayload:
            return "Malformed payload from Foursquare."
        case .apiError(let statusCode, let message):
            return "Foursquare API error (\(statusCode)): \(message)"
        }
    }
}

final class FoursquarePlaceService {
    private enum Constants {
        static let scheme = "https"
        static let host = "places-api.foursquare.com"
        static let apiVersion = "2025-06-17"
        static let searchLimit = 1
        static let premiumFields = [
            "fsq_place_id",
            "name",
            "categories",
            "description",
            "hours",
            "social_media",
            "tel",
            "website",
            "rating",
            "stats",
            "tips",
            "location",
        ]
    }

    private let urlSession: URLSession
    private let authorizationHeaderValue: String

    init(apiKey: String, urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("bearer ") {
            self.authorizationHeaderValue = trimmed
        } else {
            self.authorizationHeaderValue = "Bearer \(trimmed)"
        }
    }

    func fetchEnrichment(name: String, coordinate: CLLocationCoordinate2D) async throws -> FoursquareEnrichment {
        let searchJSON = try await searchPlace(name: name, coordinate: coordinate)

        guard
            let results = searchJSON["results"] as? [[String: Any]],
            let first = results.first,
            let placeID = Self.stringValue(first["fsq_place_id"])
        else {
            throw FoursquarePlaceServiceError.noSearchResults
        }

        let detailsJSON = try await fetchPlaceDetails(placeID: placeID)

        let resolvedName = Self.stringValue(detailsJSON["name"]) ?? Self.stringValue(first["name"])
        let categories = Self.categoryNames(from: detailsJSON["categories"])
            .ifEmpty(Self.categoryNames(from: first["categories"]))
        let descriptionText = Self.stringValue(detailsJSON["description"])
        let hoursText = Self.stringValue((detailsJSON["hours"] as? [String: Any])?["display"])
        let phone = Self.stringValue(detailsJSON["tel"])
        let website = Self.urlValue(detailsJSON["website"])
        let socialLinks = Self.socialLinks(from: detailsJSON["social_media"])
        let rating = Self.doubleValue(detailsJSON["rating"])
        let reviewCount = Self.intValue((detailsJSON["stats"] as? [String: Any])?["total_ratings"])
        let reviewSnippets = Self.reviewSnippets(from: detailsJSON["tips"])

        return FoursquareEnrichment(
            placeID: placeID,
            resolvedName: resolvedName,
            categoryNames: categories,
            descriptionText: descriptionText,
            hoursText: hoursText,
            phone: phone,
            website: website,
            socialLinks: socialLinks,
            rating: rating,
            reviewCount: reviewCount,
            reviewSnippets: reviewSnippets
        )
    }

    private func searchPlace(name: String, coordinate: CLLocationCoordinate2D) async throws -> [String: Any] {
        let queryItems = [
            URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "query", value: name),
            URLQueryItem(name: "limit", value: String(Constants.searchLimit)),
            URLQueryItem(name: "locale", value: "en"),
        ]

        return try await requestJSON(path: "/places/search", queryItems: queryItems)
    }

    private func fetchPlaceDetails(placeID: String) async throws -> [String: Any] {
        let premiumQueryItems = [
            URLQueryItem(name: "fields", value: Constants.premiumFields.joined(separator: ",")),
            URLQueryItem(name: "locale", value: "en"),
        ]

        do {
            return try await requestJSON(path: "/places/\(placeID)", queryItems: premiumQueryItems)
        } catch {
            // Some accounts/credits reject premium field sets; fall back to default details.
            return try await requestJSON(path: "/places/\(placeID)", queryItems: [URLQueryItem(name: "locale", value: "en")])
        }
    }

    private func requestJSON(path: String, queryItems: [URLQueryItem]) async throws -> [String: Any] {
        var components = URLComponents()
        components.scheme = Constants.scheme
        components.host = Constants.host
        components.path = path
        components.queryItems = queryItems

        guard let url = components.url else {
            throw FoursquarePlaceServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue(authorizationHeaderValue, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Constants.apiVersion, forHTTPHeaderField: "X-Places-Api-Version")
        request.setValue("en", forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FoursquarePlaceServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = Self.errorMessage(from: data) ?? "Request failed"
            throw FoursquarePlaceServiceError.apiError(statusCode: httpResponse.statusCode, message: message)
        }

        let payload = try JSONSerialization.jsonObject(with: data)
        guard let json = payload as? [String: Any] else {
            throw FoursquarePlaceServiceError.malformedPayload
        }
        return json
    }

    private static func errorMessage(from data: Data) -> String? {
        guard
            let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return String(data: data, encoding: .utf8)
        }

        if let message = stringValue(payload["message"]) {
            return message
        }

        if let error = payload["error"] as? [String: Any],
           let message = stringValue(error["message"]) {
            return message
        }

        return String(data: data, encoding: .utf8)
    }

    private static func categoryNames(from value: Any?) -> [String] {
        guard let categories = value as? [[String: Any]] else { return [] }
        return categories.compactMap { stringValue($0["name"]) }
    }

    private static func socialLinks(from value: Any?) -> [String: String] {
        guard let raw = value as? [String: Any] else { return [:] }
        var links: [String: String] = [:]
        for (key, value) in raw {
            if let normalized = stringValue(value) {
                links[key] = normalized
            }
        }
        return links
    }

    private static func reviewSnippets(from value: Any?) -> [String] {
        guard let tips = value as? [[String: Any]] else { return [] }
        return tips.compactMap { stringValue($0["text"]) }
    }

    private static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let double as Double:
            return double
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string)
        default:
            return nil
        }
    }

    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let int as Int:
            return int
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string)
        default:
            return nil
        }
    }

    private static func urlValue(_ value: Any?) -> URL? {
        guard let string = stringValue(value) else { return nil }
        return URL(string: string)
    }
}

private extension [String] {
    func ifEmpty(_ fallback: [String]) -> [String] {
        isEmpty ? fallback : self
    }
}
