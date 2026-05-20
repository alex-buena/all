import SwiftUI

public struct ContentView: View {
    @State private var selectedPlace: PlaceInfo?
    private let foursquareToken: String = {
        let environmentToken = ProcessInfo.processInfo.environment["FOURSQUARE_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let shortEnvironmentToken = ProcessInfo.processInfo.environment["FSQ_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let infoPlistToken = (Bundle.main.object(forInfoDictionaryKey: "FOURSQUARE_API_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let infoPlistShortToken = (Bundle.main.object(forInfoDictionaryKey: "FSQ_API_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return [environmentToken, shortEnvironmentToken, infoPlistToken, infoPlistShortToken]
            .compactMap { $0 }
            .first(where: { !$0.isEmpty }) ?? ""
    }()

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            AppleMapH3View(
                foursquareToken: foursquareToken,
                selectedPlace: $selectedPlace
            )
                .ignoresSafeArea()

            if let selectedPlace {
                PlaceInfoCard(place: selectedPlace) {
                    self.selectedPlace = nil
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedPlace?.id)
    }
}

private struct PlaceInfoCard: View {
    let place: PlaceInfo
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name)
                            .font(.headline)
                        Text(place.category)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Close", action: onClose)
                        .font(.caption)
                }

                Text(place.isBar ? "Bar: Yes" : "Bar: No")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(place.isBar ? Color.green.opacity(0.22) : Color.gray.opacity(0.18))
                    .clipShape(Capsule())

                Text(String(format: "Lat %.5f, Lon %.5f", place.coordinate.latitude, place.coordinate.longitude))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let addressText = place.addressText, !addressText.isEmpty {
                    Text(addressText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let mapsURL = place.mapsURL {
                    Link("Open in Apple Maps", destination: mapsURL)
                        .font(.subheadline.weight(.semibold))
                }

                if let website = place.website {
                    Link("Website", destination: website)
                        .font(.subheadline.weight(.semibold))
                }

                if let phone = place.phone, !phone.isEmpty {
                    Text("Phone: \(phone)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let timeZoneIdentifier = place.timeZoneIdentifier, !timeZoneIdentifier.isEmpty {
                    Text("Time zone: \(timeZoneIdentifier)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let mapItemIdentifier = place.mapItemIdentifier, !mapItemIdentifier.isEmpty {
                    Text("Apple map item id: \(mapItemIdentifier)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let unsupportedFieldsNote = place.unsupportedFieldsNote, !unsupportedFieldsNote.isEmpty {
                    Text(unsupportedFieldsNote)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !place.availableFields.isEmpty {
                    Divider()
                        .padding(.vertical, 4)

                    Text("Available Native MapKit Fields")
                        .font(.caption.weight(.semibold))

                    ForEach(place.availableFields) { field in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(field.label)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(field.value)
                                .font(.system(.caption2, design: .monospaced))
                                .textSelection(.enabled)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Divider()
                    .padding(.vertical, 4)

                Text("Foursquare Enrichment")
                    .font(.caption.weight(.semibold))

                if place.isLoadingFoursquareDetails {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading Foursquare details…")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if let foursquareDetailsError = place.foursquareDetailsError, !foursquareDetailsError.isEmpty {
                    Text(foursquareDetailsError)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                if let foursquarePlaceID = place.foursquarePlaceID, !foursquarePlaceID.isEmpty {
                    Text("FSQ ID: \(foursquarePlaceID)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !place.foursquareCategoryNames.isEmpty {
                    Text("FSQ Categories: \(place.foursquareCategoryNames.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let foursquareHoursText = place.foursquareHoursText, !foursquareHoursText.isEmpty {
                    Text("FSQ Hours: \(foursquareHoursText)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let foursquareDescriptionText = place.foursquareDescriptionText, !foursquareDescriptionText.isEmpty {
                    Text("FSQ Description: \(foursquareDescriptionText)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let foursquarePhone = place.foursquarePhone, !foursquarePhone.isEmpty {
                    Text("FSQ Phone: \(foursquarePhone)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let foursquareWebsite = place.foursquareWebsite {
                    Link("FSQ Website", destination: foursquareWebsite)
                        .font(.caption2.weight(.semibold))
                }

                if let foursquareRating = place.foursquareRating {
                    if let foursquareReviewCount = place.foursquareReviewCount {
                        Text(String(format: "FSQ Rating: %.1f (%d ratings)", foursquareRating, foursquareReviewCount))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(String(format: "FSQ Rating: %.1f", foursquareRating))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else if let foursquareReviewCount = place.foursquareReviewCount {
                    Text("FSQ Ratings count: \(foursquareReviewCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                ForEach(place.foursquareSocialLinks.keys.sorted(), id: \.self) { key in
                    if let value = place.foursquareSocialLinks[key] {
                        if let linkURL = Self.socialLinkURL(from: value) {
                            Link("FSQ \(key.capitalized)", destination: linkURL)
                                .font(.caption2.weight(.semibold))
                        } else {
                            Text("FSQ \(key.capitalized): \(value)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if !place.foursquareReviewSnippets.isEmpty {
                    Text("FSQ Review snippets")
                        .font(.caption2.weight(.semibold))

                    ForEach(Array(place.foursquareReviewSnippets.prefix(3).enumerated()), id: \.offset) { index, snippet in
                        Text("\(index + 1). \(snippet)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if place.isLoadingDetails {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading Apple Maps details…")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if let detailsError = place.detailsError, !detailsError.isEmpty {
                    Text(detailsError)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxHeight: 440)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private static func socialLinkURL(from value: String) -> URL? {
        if value.hasPrefix("http://") || value.hasPrefix("https://") {
            return URL(string: value)
        }
        return URL(string: "https://\(value)")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
