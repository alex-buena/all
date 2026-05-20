import CoreLocation
import Foundation
import MapKit
import SwiftyH3
import SwiftUI
import UIKit

struct AppleMapH3View: UIViewRepresentable {
    private enum Constants {
        // Paul-Lincke-Ufer 5, 10999 Berlin
        static let startCoordinate = CLLocationCoordinate2D(latitude: 52.4920058, longitude: 13.4351562)
        static let startRegion = MKCoordinateRegion(
            center: startCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.026, longitudeDelta: 0.04)
        )

        // Keep fixed resolution as requested; no adaptive resolution.
        static let h3Resolution: H3Cell.Resolution = .res10

        // Overlay refresh and clipping behavior.
        static let overlayPaddingFactor = 2.1
        static let overlayRefreshMinimumIntervalSeconds = 0.1
        static let overlaySignatureMapPointQuantum = 8.0
        static let maxHoleCells = 1400
        static let visitedCellsStorageKey = "visited_h3_cells_res10"

        static let unsupportedFieldsNote = "Native MapKit currently does not expose opening hours, social profiles, review snippets, or rich descriptions as public MKMapItem fields."
    }

    let foursquareToken: String
    @Binding var selectedPlace: PlaceInfo?

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedPlace: $selectedPlace, foursquareToken: foursquareToken)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsCompass = true

        if #available(iOS 16.0, *) {
            let configuration = MKStandardMapConfiguration(elevationStyle: .realistic)
            configuration.pointOfInterestFilter = .includingAll
            mapView.preferredConfiguration = configuration
            mapView.selectableMapFeatures = [.pointsOfInterest]
        } else {
            mapView.pointOfInterestFilter = .includingAll
        }

        // Perspective interaction enabled.
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        mapView.setRegion(Constants.startRegion, animated: false)

        context.coordinator.configure(mapView: mapView)
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {}

    final class Coordinator: NSObject, MKMapViewDelegate {
        private struct VisitedCellGeometry {
            let centerPoint: MKMapPoint
            let loop: H3Loop
        }

        private struct OverlayBuildRequest {
            let paddedRect: MKMapRect
            let signature: String
            let visitedCellGeometryByID: [String: VisitedCellGeometry]
        }

        private let selectedPlace: Binding<PlaceInfo?>
        private let foursquareService: FoursquarePlaceService?

        private weak var mapView: MKMapView?
        private var activeMaskOverlay: MKPolygon?
        private var lastOverlaySignature: String?
        private var pendingOverlayRefreshWorkItem: DispatchWorkItem?
        private var overlayRefreshPending = false
        private var overlayRefreshForceImmediate = false
        private var lastOverlayRefreshTimestamp: TimeInterval = 0
        private var overlayBuildInFlight = false
        private var pendingOverlayBuildRequest: OverlayBuildRequest?
        private var visitedCellIDs: Set<String>
        private var visitedCellGeometryByID: [String: VisitedCellGeometry]
        private var overlayRevision: Int = 0

        private var activeDetailRequestID: UUID?
        private var mapItemLookupTask: Task<Void, Never>?
        private var foursquareLookupTask: Task<Void, Never>?

        init(selectedPlace: Binding<PlaceInfo?>, foursquareToken: String) {
            self.selectedPlace = selectedPlace

            let persisted = UserDefaults.standard.stringArray(forKey: Constants.visitedCellsStorageKey) ?? []
            self.visitedCellIDs = Set(persisted.filter { H3Cell($0) != nil })
            self.visitedCellGeometryByID = Self.makeVisitedCellGeometryDictionary(for: self.visitedCellIDs)

            let normalizedToken = foursquareToken.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalizedToken.isEmpty || normalizedToken.contains("YOUR_") {
                self.foursquareService = nil
            } else {
                self.foursquareService = FoursquarePlaceService(apiKey: normalizedToken)
            }
        }

        func configure(mapView: MKMapView) {
            self.mapView = mapView
            markVisitedCell(at: mapView.region.center)
            requestOverlayRefresh(on: mapView, forceImmediate: true)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            markVisitedCell(at: mapView.region.center)
            requestOverlayRefresh(on: mapView, forceImmediate: true)
        }

        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            requestOverlayRefresh(on: mapView, forceImmediate: false)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polygon = overlay as? MKPolygon else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.fillColor = Self.maskTextureColor
            renderer.strokeColor = .clear
            renderer.lineWidth = 0
            renderer.shouldRasterize = true
            return renderer
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            guard let mapFeatureAnnotation = annotation as? MKMapFeatureAnnotation else { return }
            mapView.deselectAnnotation(annotation, animated: false)
            selectMapFeature(mapFeatureAnnotation)
        }

        private func selectMapFeature(_ annotation: MKMapFeatureAnnotation) {
            var place = Self.makePlaceholderPlace(from: annotation)
            activeDetailRequestID = place.id
            place.isLoadingDetails = true
            place.detailsError = nil
            place.isLoadingFoursquareDetails = false
            place.foursquareDetailsError = nil
            selectedPlace.wrappedValue = place

            mapItemLookupTask?.cancel()
            foursquareLookupTask?.cancel()
            mapItemLookupTask = Task { [weak self] in
                guard let self else { return }

                do {
                    let mapItem = try await self.loadMapItem(for: annotation)
                    if Task.isCancelled { return }

                    await MainActor.run {
                        self.applyMapItem(mapItem, for: place.id)
                    }
                } catch {
                    if Task.isCancelled { return }

                    await MainActor.run {
                        self.applyMapItemError(error, for: place.id)
                    }
                }
            }
        }

        private func loadMapItem(for annotation: MKMapFeatureAnnotation) async throws -> MKMapItem {
            let request = MKMapItemRequest(mapFeatureAnnotation: annotation)
            return try await request.mapItem
        }

        private func applyMapItem(_ mapItem: MKMapItem, for requestID: UUID) {
            guard
                activeDetailRequestID == requestID,
                var currentPlace = selectedPlace.wrappedValue,
                currentPlace.id == requestID
            else {
                return
            }

            currentPlace.isLoadingDetails = false
            currentPlace.detailsError = nil

            if let resolvedName = mapItem.name?.trimmedNonEmpty {
                currentPlace.name = resolvedName
            }

            currentPlace.coordinate = Self.coordinate(for: mapItem, fallback: currentPlace.coordinate)
            currentPlace.category = Self.categoryText(from: mapItem.pointOfInterestCategory) ?? currentPlace.category
            currentPlace.isBar = Self.isLikelyBar(name: currentPlace.name, category: currentPlace.category)
            currentPlace.phone = mapItem.phoneNumber?.trimmedNonEmpty
            currentPlace.website = mapItem.url
            currentPlace.timeZoneIdentifier = mapItem.timeZone?.identifier
            currentPlace.addressText = Self.addressText(from: mapItem)
            currentPlace.mapItemIdentifier = mapItem.identifier?.description
            currentPlace.unsupportedFieldsNote = Constants.unsupportedFieldsNote
            currentPlace.availableFields = Self.availableFields(from: mapItem)

            selectedPlace.wrappedValue = currentPlace
            startFoursquareEnrichment(for: currentPlace)
        }

        private func applyMapItemError(_ error: Error, for requestID: UUID) {
            guard
                activeDetailRequestID == requestID,
                var currentPlace = selectedPlace.wrappedValue,
                currentPlace.id == requestID
            else {
                return
            }

            currentPlace.isLoadingDetails = false
            currentPlace.detailsError = "Unable to load place details from Apple Maps."
            currentPlace.unsupportedFieldsNote = Constants.unsupportedFieldsNote
            currentPlace.isLoadingFoursquareDetails = false
            selectedPlace.wrappedValue = currentPlace
        }

        private func startFoursquareEnrichment(for place: PlaceInfo) {
            guard
                activeDetailRequestID == place.id,
                var currentPlace = selectedPlace.wrappedValue,
                currentPlace.id == place.id
            else {
                return
            }

            guard let foursquareService else {
                currentPlace.isLoadingFoursquareDetails = false
                currentPlace.foursquareDetailsError = "Set FOURSQUARE_API_KEY (or FSQ_API_KEY) to load Foursquare enrichment."
                selectedPlace.wrappedValue = currentPlace
                return
            }

            currentPlace.isLoadingFoursquareDetails = true
            currentPlace.foursquareDetailsError = nil
            selectedPlace.wrappedValue = currentPlace

            let requestID = currentPlace.id
            let name = currentPlace.name
            let coordinate = currentPlace.coordinate

            foursquareLookupTask?.cancel()
            foursquareLookupTask = Task { [weak self] in
                guard let self else { return }

                do {
                    let enrichment = try await foursquareService.fetchEnrichment(name: name, coordinate: coordinate)
                    if Task.isCancelled { return }

                    await MainActor.run {
                        self.applyFoursquareEnrichment(enrichment, for: requestID)
                    }
                } catch {
                    if Task.isCancelled { return }

                    await MainActor.run {
                        self.applyFoursquareError(error, for: requestID)
                    }
                }
            }
        }

        private func applyFoursquareEnrichment(_ enrichment: FoursquareEnrichment, for requestID: UUID) {
            guard
                activeDetailRequestID == requestID,
                var currentPlace = selectedPlace.wrappedValue,
                currentPlace.id == requestID
            else {
                return
            }

            currentPlace.isLoadingFoursquareDetails = false
            currentPlace.foursquareDetailsError = nil
            currentPlace.foursquarePlaceID = enrichment.placeID
            currentPlace.foursquareCategoryNames = enrichment.categoryNames
            currentPlace.foursquareDescriptionText = enrichment.descriptionText
            currentPlace.foursquareHoursText = enrichment.hoursText
            currentPlace.foursquarePhone = enrichment.phone
            currentPlace.foursquareWebsite = enrichment.website
            currentPlace.foursquareSocialLinks = enrichment.socialLinks
            currentPlace.foursquareRating = enrichment.rating
            currentPlace.foursquareReviewCount = enrichment.reviewCount
            currentPlace.foursquareReviewSnippets = enrichment.reviewSnippets

            if let resolvedName = enrichment.resolvedName?.trimmedNonEmpty {
                currentPlace.name = resolvedName
            }
            if currentPlace.phone?.trimmedNonEmpty == nil {
                currentPlace.phone = enrichment.phone
            }
            if currentPlace.website == nil {
                currentPlace.website = enrichment.website
            }

            selectedPlace.wrappedValue = currentPlace
        }

        private func applyFoursquareError(_ error: Error, for requestID: UUID) {
            guard
                activeDetailRequestID == requestID,
                var currentPlace = selectedPlace.wrappedValue,
                currentPlace.id == requestID
            else {
                return
            }

            currentPlace.isLoadingFoursquareDetails = false
            let reason = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            currentPlace.foursquareDetailsError = "Foursquare enrichment unavailable: \(reason)"
            selectedPlace.wrappedValue = currentPlace
        }

        private func requestOverlayRefresh(on mapView: MKMapView, forceImmediate: Bool) {
            overlayRefreshPending = true
            overlayRefreshForceImmediate = overlayRefreshForceImmediate || forceImmediate
            processOverlayRefreshQueue(on: mapView)
        }

        private func processOverlayRefreshQueue(on mapView: MKMapView) {
            guard overlayRefreshPending || overlayRefreshForceImmediate else { return }
            guard pendingOverlayRefreshWorkItem == nil else { return }

            let minimumInterval = Constants.overlayRefreshMinimumIntervalSeconds
            let now = ProcessInfo.processInfo.systemUptime
            let elapsed = now - lastOverlayRefreshTimestamp
            let shouldRunNow = overlayRefreshForceImmediate || elapsed >= minimumInterval

            if shouldRunNow {
                overlayRefreshPending = false
                overlayRefreshForceImmediate = false
                lastOverlayRefreshTimestamp = now
                refreshOverlay(on: mapView)

                if overlayRefreshPending || overlayRefreshForceImmediate {
                    processOverlayRefreshQueue(on: mapView)
                }
                return
            }

            let delay = max(0, minimumInterval - elapsed)
            let workItem = DispatchWorkItem { [weak self, weak mapView] in
                guard let self, let mapView else { return }
                self.pendingOverlayRefreshWorkItem = nil
                self.processOverlayRefreshQueue(on: mapView)
            }

            pendingOverlayRefreshWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }

        private func refreshOverlay(on mapView: MKMapView) {
            let paddedRect = Self.paddedMapRect(from: mapView.visibleMapRect, factor: Constants.overlayPaddingFactor)
            let signature = Self.overlaySignature(
                for: paddedRect,
                revision: overlayRevision
            )
            guard signature != lastOverlaySignature else { return }

            let request = OverlayBuildRequest(
                paddedRect: paddedRect,
                signature: signature,
                visitedCellGeometryByID: visitedCellGeometryByID
            )

            if overlayBuildInFlight {
                pendingOverlayBuildRequest = request
                return
            }

            startOverlayBuild(request)
        }

        private func startOverlayBuild(_ request: OverlayBuildRequest) {
            overlayBuildInFlight = true
            Task.detached(priority: .userInitiated) {
                let maskOverlay = Self.buildMaskOverlay(
                    for: request.paddedRect,
                    visitedCellGeometryByID: request.visitedCellGeometryByID
                )
                if Task.isCancelled { return }

                await MainActor.run { [weak self] in
                    guard let self else { return }

                    if let mapView = self.mapView {
                        if let previous = self.activeMaskOverlay {
                            mapView.removeOverlay(previous)
                        }

                        if let maskOverlay {
                            self.activeMaskOverlay = maskOverlay
                            mapView.addOverlay(maskOverlay, level: .aboveRoads)
                        } else {
                            self.activeMaskOverlay = nil
                        }
                    }

                    self.lastOverlaySignature = request.signature
                    self.overlayBuildInFlight = false
                    self.processPendingOverlayBuildRequestIfNeeded()
                }
            }
        }

        private func processPendingOverlayBuildRequestIfNeeded() {
            guard !overlayBuildInFlight, let pending = pendingOverlayBuildRequest else { return }
            pendingOverlayBuildRequest = nil
            guard pending.signature != lastOverlaySignature else { return }
            startOverlayBuild(pending)
        }

        private func markVisitedCell(at coordinate: CLLocationCoordinate2D) {
            let normalized = Self.normalizedCoordinate(coordinate)
            guard CLLocationCoordinate2DIsValid(normalized) else { return }

            do {
                let latLng = H3LatLng(latitudeDegs: normalized.latitude, longitudeDegs: normalized.longitude)
                let cell = try latLng.cell(at: Constants.h3Resolution)
                let cellID = String(describing: cell)
                if visitedCellIDs.insert(cellID).inserted {
                    if let geometry = Self.makeVisitedCellGeometry(for: cell) {
                        visitedCellGeometryByID[cellID] = geometry
                    }
                    overlayRevision &+= 1
                    persistVisitedCells()
                }
            } catch {
                // Ignore conversion errors.
            }
        }

        private func persistVisitedCells() {
            UserDefaults.standard.set(Array(visitedCellIDs).sorted(), forKey: Constants.visitedCellsStorageKey)
        }

        private static func coordinate(for mapItem: MKMapItem, fallback: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
            if #available(iOS 26.0, *) {
                return mapItem.location.coordinate
            }

            return fallback
        }

        private static func addressText(from mapItem: MKMapItem) -> String? {
            if #available(iOS 26.0, *) {
                if let fullAddress = mapItem.address?.fullAddress.trimmedNonEmpty {
                    return fullAddress
                }

                if let mapkitFormatted = mapItem.addressRepresentations?.fullAddress(includingRegion: true, singleLine: false)?.trimmedNonEmpty {
                    return mapkitFormatted
                }
            }

            return nil
        }

        private static func makePlaceholderPlace(from annotation: MKMapFeatureAnnotation) -> PlaceInfo {
            let coordinate = annotation.coordinate
            let name = annotation.title?.trimmedNonEmpty ?? "Selected place"
            let category = categoryText(from: annotation.pointOfInterestCategory) ?? "place"

            return PlaceInfo(
                name: name,
                category: category,
                coordinate: coordinate,
                isBar: isLikelyBar(name: name, category: category),
                unsupportedFieldsNote: Constants.unsupportedFieldsNote
            )
        }

        private static func categoryText(from category: MKPointOfInterestCategory?) -> String? {
            guard let rawValue = category?.rawValue.trimmedNonEmpty else { return nil }
            return rawValue
                .replacingOccurrences(of: ".", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }

        private static func availableFields(from mapItem: MKMapItem) -> [PlaceDataField] {
            var fields: [PlaceDataField] = []

            func appendField(_ label: String, _ value: String?) {
                guard let normalized = value?.trimmedNonEmpty else { return }
                fields.append(PlaceDataField(label: label, value: normalized))
            }

            appendField("name", mapItem.name)
            appendField("phoneNumber", mapItem.phoneNumber)
            appendField("url", mapItem.url?.absoluteString)
            appendField("timeZone", mapItem.timeZone?.identifier)
            appendField("pointOfInterestCategory", mapItem.pointOfInterestCategory?.rawValue)
            appendField("isCurrentLocation", mapItem.isCurrentLocation ? "true" : "false")
            appendField("mapItemIdentifier", mapItem.identifier?.description)

            if #available(iOS 18.0, *) {
                if !mapItem.alternateIdentifiers.isEmpty {
                    let joined = mapItem.alternateIdentifiers
                        .map(\.description)
                        .sorted()
                        .joined(separator: "\n")
                    appendField("alternateIdentifiers", joined)
                }
            }

            if #available(iOS 26.0, *) {
                let coordinate = mapItem.location.coordinate
                appendField("location.latitude", String(format: "%.7f", coordinate.latitude))
                appendField("location.longitude", String(format: "%.7f", coordinate.longitude))

                appendField("address.fullAddress", mapItem.address?.fullAddress)
                appendField("address.shortAddress", mapItem.address?.shortAddress)

                if let addressRepresentations = mapItem.addressRepresentations {
                    appendField(
                        "addressRepresentations.fullAddress(region=true,singleLine=false)",
                        addressRepresentations.fullAddress(includingRegion: true, singleLine: false)
                    )
                    appendField(
                        "addressRepresentations.fullAddress(region=true,singleLine=true)",
                        addressRepresentations.fullAddress(includingRegion: true, singleLine: true)
                    )
                    appendField(
                        "addressRepresentations.fullAddress(region=false,singleLine=false)",
                        addressRepresentations.fullAddress(includingRegion: false, singleLine: false)
                    )
                    appendField("addressRepresentations.cityName", addressRepresentations.cityName)
                    appendField("addressRepresentations.cityWithContext", addressRepresentations.cityWithContext)
                    appendField(
                        "addressRepresentations.cityWithContext(automatic)",
                        addressRepresentations.cityWithContext(.automatic)
                    )
                    appendField(
                        "addressRepresentations.cityWithContext(short)",
                        addressRepresentations.cityWithContext(.short)
                    )
                    appendField(
                        "addressRepresentations.cityWithContext(full)",
                        addressRepresentations.cityWithContext(.full)
                    )
                    appendField("addressRepresentations.regionName", addressRepresentations.regionName)
                }
            }

            return fields
        }

        private static func isLikelyBar(name: String, category: String) -> Bool {
            let haystack = "\(name.lowercased()) \(category.lowercased())"
            return haystack.contains("bar")
                || haystack.contains("pub")
                || haystack.contains("cocktail")
                || haystack.contains("night")
        }

        private static let maskTextureColor: UIColor = {
            let size = CGSize(width: 28, height: 28)
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { context in
                let rect = CGRect(origin: .zero, size: size)
                UIColor(white: 0.04, alpha: 0.58).setFill()
                context.fill(rect)

                let cg = context.cgContext
                cg.setStrokeColor(UIColor(white: 1.0, alpha: 0.08).cgColor)
                cg.setLineWidth(1.0)

                var offset: CGFloat = -size.height
                while offset < size.width + size.height {
                    cg.move(to: CGPoint(x: offset, y: 0))
                    cg.addLine(to: CGPoint(x: offset - size.height, y: size.height))
                    offset += 7
                }
                cg.strokePath()
            }

            return UIColor(patternImage: image)
        }()

        nonisolated private static func paddedMapRect(from mapRect: MKMapRect, factor: Double) -> MKMapRect {
            let safeFactor = max(1.0, factor)
            let dx = -mapRect.size.width * (safeFactor - 1.0) * 0.5
            let dy = -mapRect.size.height * (safeFactor - 1.0) * 0.5
            return mapRect.insetBy(dx: dx, dy: dy)
        }

        nonisolated private static func overlaySignature(
            for mapRect: MKMapRect,
            revision: Int
        ) -> String {
            let quantum = Constants.overlaySignatureMapPointQuantum
            func quantized(_ value: Double) -> Int64 {
                Int64((value / quantum).rounded())
            }

            return [
                String(quantized(mapRect.origin.x)),
                String(quantized(mapRect.origin.y)),
                String(quantized(mapRect.size.width)),
                String(quantized(mapRect.size.height)),
                String(revision),
            ].joined(separator: "|")
        }

        nonisolated private static func buildMaskOverlay(
            for mapRect: MKMapRect,
            visitedCellGeometryByID: [String: VisitedCellGeometry]
        ) -> MKPolygon? {
            let outerLoop = mapRectLoop(from: mapRect)
            guard outerLoop.count >= 3 else { return nil }

            let holes = visibleHoleLoops(in: mapRect, visitedCellGeometryByID: visitedCellGeometryByID)
            let polygon = H3Polygon(outerLoop, holes: holes)
            return MKPolygon(polygon)
        }

        nonisolated private static func visibleHoleLoops(
            in mapRect: MKMapRect,
            visitedCellGeometryByID: [String: VisitedCellGeometry]
        ) -> [H3Loop] {
            let centerPoint = MKMapPoint(x: mapRect.midX, y: mapRect.midY)
            var candidates: [(distance: Double, loop: H3Loop)] = []
            candidates.reserveCapacity(min(visitedCellGeometryByID.count, Constants.maxHoleCells))

            for geometry in visitedCellGeometryByID.values {
                guard mapRect.contains(geometry.centerPoint) else { continue }

                let dx = geometry.centerPoint.x - centerPoint.x
                let dy = geometry.centerPoint.y - centerPoint.y
                let distance = (dx * dx + dy * dy).squareRoot()
                candidates.append((distance: distance, loop: geometry.loop))
            }

            if candidates.count > Constants.maxHoleCells {
                candidates.sort { $0.distance < $1.distance }
                candidates = Array(candidates.prefix(Constants.maxHoleCells))
            }

            return candidates.map(\.loop)
        }

        nonisolated private static func makeVisitedCellGeometryDictionary(
            for visitedCellIDs: Set<String>
        ) -> [String: VisitedCellGeometry] {
            var dictionary: [String: VisitedCellGeometry] = [:]
            dictionary.reserveCapacity(visitedCellIDs.count)

            for cellID in visitedCellIDs {
                guard let cell = H3Cell(cellID), let geometry = makeVisitedCellGeometry(for: cell) else { continue }
                dictionary[cellID] = geometry
            }

            return dictionary
        }

        nonisolated private static func makeVisitedCellGeometry(for cell: H3Cell) -> VisitedCellGeometry? {
            guard let cellCenter = try? cell.center else { return nil }
            guard let boundary = try? cell.boundary, boundary.count >= 3 else { return nil }
            let centerPoint = MKMapPoint(cellCenter.coordinates)
            return VisitedCellGeometry(centerPoint: centerPoint, loop: boundary)
        }

        nonisolated private static func mapRectLoop(from mapRect: MKMapRect) -> H3Loop {
            let topLeft = MKMapPoint(x: mapRect.minX, y: mapRect.minY).coordinate
            let topRight = MKMapPoint(x: mapRect.maxX, y: mapRect.minY).coordinate
            let bottomRight = MKMapPoint(x: mapRect.maxX, y: mapRect.maxY).coordinate
            let bottomLeft = MKMapPoint(x: mapRect.minX, y: mapRect.maxY).coordinate

            return [
                topLeft,
                topRight,
                bottomRight,
                bottomLeft,
            ]
                .map(Self.normalizedCoordinate(_:))
                .map { H3LatLng(latitudeDegs: $0.latitude, longitudeDegs: $0.longitude) }
        }

        nonisolated private static func normalizedCoordinate(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
            let latitude = min(max(coordinate.latitude, -85.0), 85.0)
            var longitude = coordinate.longitude
            while longitude > 180.0 { longitude -= 360.0 }
            while longitude < -180.0 { longitude += 360.0 }
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
