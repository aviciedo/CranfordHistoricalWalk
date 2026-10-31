import CoreLocation
import Foundation
import TourCore

// TourCore owns the Codable model. These extensions bridge it to Apple frameworks.

/// Compatibility lookup for legacy stop-ID-only view/test entry points. Actual tour views
/// pass selected-stop metadata, so another catalog requires no new Swift mappings.
enum BundledStopArtwork {
    static let document: HistoricalTourDocument? = {
        guard let url = Bundle.main.url(forResource: "historical_stops", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? HistoricalStopDecoder.decode(data)
    }()
    static func resolve(stopID: String, override: StopArtwork? = nil) -> StopArtwork? {
        override ?? document?.stops.first(where: { $0.id == stopID })?.artwork
    }
}

extension GeoCoordinate {
    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

extension CLLocationCoordinate2D {
    var geoCoordinate: GeoCoordinate { GeoCoordinate(self) }
}

extension HistoricalStop {
    var clLocationCoordinate: CLLocationCoordinate2D { coordinate.clLocationCoordinate }

    var googleWalkingDirectionsURL: URL? {
        guard coordinate.isValid else { return nil }
        var url = URLComponents(string: "https://www.google.com/maps/dir/")
        url?.queryItems = [URLQueryItem(name: "api", value: "1"),
                           URLQueryItem(name: "destination", value: "\(latitude),\(longitude)"),
                           URLQueryItem(name: "travelmode", value: "walking")]
        return url?.url
    }

    var hasRecordedNarration: Bool {
        guard let source = narrationSource else { return false }
        switch source {
        case .remoteAudio, .bundledAudio: return true
        case .synthesizedSpeech: return false
        }
    }

    /// Date line for the sign; sample stops never show a fabricated date.
    var displayDate: String? {
        guard let historicalDate, !historicalDate.isEmpty else { return nil }
        return historicalDate
    }

    /// Same five stops as the bundled walking tour (previews and host-app tests).
    static let previewStops: [HistoricalStop] = [
        HistoricalStop(
            id: "hpab-001", name: "Droescher’s Mill", latitude: 40.650249, longitude: -74.301047,
            address: "347 Lincoln Avenue East, Cranford, NJ",
            shortDescription: """
                The mill site dates to at least 1779.
                Last surviving historic mill on the Rahway River.
                """,
            longDescription: """
                Standing along the Rahway River, Droescher’s Mill is the last surviving historic mill of the eleven that once operated along the river.

                The site dates to at least 1779, although the existing wooden structure was built after an earlier mill burned in 1821. Over generations, the mill adapted to changing industries, producing lumber, woolen goods, sharpening stones, and even pipe organs.

                Named for businessman Severin Droescher, who operated a sharpening-stone business here in the early 1900s, the mill is a rare surviving connection to Cranford’s industrial beginnings and the river that helped shape the community.
                """,
            historicalDate: "Construction: After 1821", imageName: "droeschers-mill",
            photos: [
                HistoricalStopPhoto(imageName: "droeschers-mill", caption: "Droescher’s Mill"),
                HistoricalStopPhoto(imageName: "droeschers-mill-foundation", caption: "Stone foundation beside the Rahway River dam"),
                HistoricalStopPhoto(imageName: "droeschers-mill-upper-doors", caption: "Upper doors and pulley at Droescher’s Mill"),
                HistoricalStopPhoto(imageName: "droeschers-mill-stonework", caption: "Close-up of the mill’s stone foundation"),
                HistoricalStopPhoto(imageName: "droeschers-mill-front", caption: "Front of Droescher’s Mill"),
                HistoricalStopPhoto(imageName: "droeschers-mill-river-view", caption: "Droescher’s Mill and the Rahway River dam"),
                HistoricalStopPhoto(imageName: "droeschers-mill-through-railing", caption: "Droescher’s Mill and the Rahway River, viewed through the railing"),
            ],
            audioURL: URL(string: "stop_01_droeschers_mill.mp3"),
            narrationText: """
                Droescher’s Mill: A River That Built a Town

                Imagine Cranford more than two hundred years ago. Before the railroad, before the busy downtown and modern neighborhoods we know today, the Rahway River was the heart of our community.

                The river’s flowing waters provided the power that helped early settlers build homes, produce goods, and establish businesses.

                In fact, early Cranford was once known as “Crane’s Mills”, a reflection of how important milling was to our town’s development.

                Here at Droescher’s Mill, that history survives.

                Historical records confirm a mill on this site as early as 1779. The original building was destroyed by fire in 1821, and the wooden structure you see today was built afterward. Its substantial fieldstone foundation, approximately two feet thick in places, and heavy oak timbers reflect the durable construction of early industrial buildings.

                Over the next century, the mill changed with the needs of the community.

                Water-powered machinery helped transform raw materials into useful products. The site operated as a sawmill, later became associated with wool manufacturing, and eventually supported woodworking, and other industries.

                By the early 1900s, businessman Severin Droescher was using the mill to manufacture sharpening stones for razors and other cutting tools. He also improved the surrounding riverfront, rebuilding the dam and adding stone walls, a footbridge, and landscaped features connected to his nearby Lincoln Park residential development.

                In the twentieth century, its workshops were adapted for pipe-organ manufacturing, before eventually being converted into offices and commercial spaces we know today. The mill is now home to commercial offices with many of the tenants in the healthcare sector. The site also houses a popular local yoga studio, Alleum Yoga which serves the Cranford community as a welcoming and inclusive wellness space.\u{20}

                Today, the building no longer operates as a water-powered mill. Yet the Rahway River still flows beside it, and the dam remains part of Cranford's river-management infrastructure.

                Recognized on the National Register of Historic Places in 1974 and designated a Cranford historic landmark in 2014, Droescher’s Mill stands as a tangible reminder of the community's industrial origins.

                Of the eleven historic mills that once lined the Rahway River, this is the last survivor.
                """,
            narrationVoicePreference: .warmMaleEnglish,
            order: 1, estimatedVisitDuration: 151.301224, isSample: false, coordinatesUnverified: true,
            plaque: StopPlaque(
                transcription: "c. 1737",
                quoteLabel: "Door plaque",
                referenceImageName: SignPlacementPolicy.millReferenceImageName,
                physicalWidthMeters: SignPlacementPolicy.assumedPlaqueWidthMeters
            )
        ),
        HistoricalStop(
            id: "hpab-002", name: "Greystone", latitude: 40.6524, longitude: -74.2990,
            address: "600 Lincoln Park East, Cranford, NJ",
            shortDescription: "A grand 25-room mansion overlooking the Rahway River, later transformed into Cranford Hall.",
            longDescription: """
                Built beginning in 1920, Greystone was an extraordinary 25-room, English castle-inspired mansion overlooking the Rahway River. Its 14-acre estate, with 600 feet of riverfront, belonged to wealthy silk manufacturer Charles E. Kaltenbach.

                Constructed on land once owned by Severin Droescher, the mansion replaced most of his planned Lincoln Park residential development. Hollywood stars like Gloria Swanson and newspaper magnate William Randolph Hearst were among Greystone’s distinguished guests.

                Following Kaltenbach's death and the decline of his silk business, the property was acquired by Cranford Township. In 1939, it reopened as Cranford Hall, beginning its long history as a healthcare facility.
                """,
            historicalDate: "Built: Beginning in 1920", imageName: "greystone",
            photos: [
                HistoricalStopPhoto(imageName: "greystone", caption: "Greystone"),
                HistoricalStopPhoto(imageName: "greystone-additional-view", caption: "Greystone — additional view"),
                HistoricalStopPhoto(imageName: "greystone-tower", caption: "Greystone’s stone tower"),
                HistoricalStopPhoto(imageName: "greystone-stonework", caption: "Close-up of Greystone’s stonework"),
                HistoricalStopPhoto(imageName: "greystone-footbridge-1912", caption: "Lincoln Park stone footbridge, 1912. The bridge remains today.", credit: "Cranford Historical Society, The Birth and Growth of Cranford, Part IV, PDF page 6."),
                HistoricalStopPhoto(imageName: "greystone-gloria-swanson", caption: "Gloria Swanson"),
                HistoricalStopPhoto(imageName: "greystone-william-randolph-hearst", caption: "William Randolph Hearst"),
            ],
            audioURL: URL(string: "stop_02_greystone.mp3"),
            narrationText: """
                Greystone: The Castle on the River

                At our previous stop, Droescher’s Mill, we discovered how the Rahway River powered the industries that helped build early Cranford.

                By the early 1900s as the town continued to grow, its scenic banks of the Rahway River had become desirable places for grand homes and landscaped estates. And few were more impressive than the mansion that once stood here, known as Greystone.

                Construction began in 1920 for Charles E. Kaltenbach, a wealthy silk-ribbon manufacturer whose family business had prospered in New Jersey's textile industry.

                Inspired by an English castle, the magnificent 25-room mansion featured castle-like towers and an elegant ballroom. Its sprawling 14-acre grounds included landscaped gardens and an extraordinary 600 feet of frontage along the Rahway River.

                Interestingly, this estate was built on land formerly owned by Severin Droescher, the businessman behind the nearby mill. Droescher had originally envisioned an exclusive neighborhood called Lincoln Park, but Kaltenbach acquired a large portion of the property for his private estate.

                Greystone soon became a setting for lavish and glamorous Hollywood entertainment. Hollywood stars like Gloria Swanson and newspaper magnate William Randolph Hearst were among its famous guests.

                But the mansion's glamorous chapter was very short.

                In 1930, Kaltenbach died suddenly of a heart attack at just 44 years old. Meanwhile, his family's silk business struggled as new synthetic fabrics, including rayon, transformed the textile industry.

                By the late 1930s, the estate faced substantial unpaid taxes, and Cranford Township acquired the property.

                Then came an unexpected new beginning.

                In October 1939, the former mansion reopened as Cranford Hall, a nursing and convalescent home. Over the following decades, much of the original estate was divided and developed, but the building continued serving the community.

                Today, the property remains a healthcare facility, known as Cranford Park Care.

                From a magnificent private residence to a place dedicated to caring for others, Greystone reflects Cranford's changing and dynamic history.

                And just as at Droescher’s Mill, the Rahway River remains a quiet witness to the continuous transformation of our town.
                """,
            narrationVoicePreference: .warmMaleEnglish,
            order: 2, estimatedVisitDuration: 142.733061, isSample: false, coordinatesUnverified: true,
            plaque: StopPlaque(transcription: "Cranford Park", quoteLabel: "On-site discovery plaque",
                              referenceImageName: SignPlacementPolicy.parkReferenceImageName,
                              physicalWidthMeters: SignPlacementPolicy.assumedParkReferenceWidthMeters)
        ),
        HistoricalStop(
            id: "hpab-003", name: "Rahway River", latitude: 40.6659731, longitude: -74.3108614,
            address: "Rahway River, Cranford, NJ",
            shortDescription: "New narration is coming soon.",
            longDescription: "",
            order: 3, isSample: false, coordinatesUnverified: true, narrationPending: true
        ),
        HistoricalStop(
            id: "hpab-004", name: "First Baptist Church", latitude: 40.653165, longitude: -74.302768,
            address: "100 High St, Cranford, NJ",
            shortDescription: "New narration is coming soon.",
            longDescription: "",
            imageName: "first-baptist-church-belfry",
            photos: [
                HistoricalStopPhoto(imageName: "first-baptist-church-belfry", caption: "Belfry and rose window at First Baptist Church"),
                HistoricalStopPhoto(imageName: "first-baptist-church-front", caption: "First Baptist Church, viewed from the front"),
                HistoricalStopPhoto(imageName: "first-baptist-church-stained-glass", caption: "Rose window and stained-glass lettering above the entrance"),
                HistoricalStopPhoto(imageName: "first-baptist-church-entrance-window", caption: "Close-up of the stained-glass window above the entrance"),
                HistoricalStopPhoto(imageName: "first-baptist-church-side", caption: "First Baptist Church’s side windows and belfry"),
            ],
            order: 4, isSample: false, coordinatesUnverified: true, narrationPending: true
        ),
        HistoricalStop(
            id: "hpab-005", name: "Cranford Hotel", latitude: 40.65513, longitude: -74.304765,
            address: "1 S Union Ave, Cranford, NJ",
            shortDescription: "New narration is coming soon.",
            longDescription: "",
            order: 5, isSample: false, coordinatesUnverified: true, narrationPending: true
        )
    ]
}

extension WalkingRoute {
    var clCoordinates: [CLLocationCoordinate2D] { routeCoordinates.map(\.clLocationCoordinate) }
}
