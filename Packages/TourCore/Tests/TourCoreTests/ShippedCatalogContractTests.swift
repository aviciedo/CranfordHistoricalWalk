import XCTest
@testable import TourCore

/// The portable fixture omits shipped artwork, recordings and AR asset bytes.
/// These checks read the repository files the app actually bundles.
final class ShippedCatalogContractTests: XCTestCase {
    func testPlaqueAssetsWidthsAndHotelReferenceBytesStayAligned() throws {
        let root = repositoryRoot()
        let shipped = try loadShippedCatalog(from: root)
        let fixture = try HistoricalStopDecoder.decode(Fixtures.data("historical_stops"))
        XCTAssertEqual(shipped.identity, .legacy, "A new tour id would split saved visits and walk resume")
        XCTAssertEqual(shipped.catalogVersion, 1)

        let expected = [
            (id: "hpab-001", name: SignPlacementPolicy.millReferenceImageName,
             width: SignPlacementPolicy.assumedPlaqueWidthMeters),
            (id: "hpab-002", name: SignPlacementPolicy.parkReferenceImageName,
             width: SignPlacementPolicy.assumedParkReferenceWidthMeters),
            (id: "hpab-005", name: SignPlacementPolicy.hotelReferenceImageName,
             width: SignPlacementPolicy.assumedHotelReferenceWidthMeters)
        ]
        let groupURL = root.appendingPathComponent(
            "CranfordHistoricalAR/Assets.xcassets/PlaqueAnchors.arresourcegroup/Contents.json")
        let group = try jsonObject(at: groupURL)
        let resources = try XCTUnwrap(group["resources"] as? [[String: Any]])
        XCTAssertEqual(resources.compactMap { $0["filename"] as? String }.sorted(),
                       expected.map { $0.name + ".arreferenceimage" }.sorted())

        for item in expected {
            for document in [shipped, fixture] {
                let stop = try XCTUnwrap(document.stops.first { $0.id == item.id })
                XCTAssertEqual(stop.plaque?.referenceImageName, item.name)
                XCTAssertEqual(stop.plaque?.physicalWidthMeters ?? -1, item.width, accuracy: 0.000_001)
                XCTAssertTrue(stop.hasPlaqueReference)
                XCTAssertEqual(SignPlacementPolicy.recognizedStop(
                    imageName: item.name, isTracked: true, trackingReady: true, stops: document.stops)?.id, item.id)
                let photographs = Set(stop.galleryPhotos.map(\.imageName))
                XCTAssertFalse(photographs.contains(item.name), item.id)
            }
            let referenceDirectory = groupURL.deletingLastPathComponent()
                .appendingPathComponent(item.name + ".arreferenceimage")
            let contents = try jsonObject(at: referenceDirectory.appendingPathComponent("Contents.json"))
            let properties = try XCTUnwrap(contents["properties"] as? [String: Any])
            XCTAssertEqual(jsonDouble(properties["width"]), item.width, accuracy: 0.000_001)
            XCTAssertEqual(properties["unit"] as? String, "meters")
            XCTAssertNoThrow(try Data(contentsOf: referenceDirectory.appendingPathComponent(item.name + ".jpg")))
        }
        for id in ["hpab-003", "hpab-004"] {
            for document in [shipped, fixture] {
                let stop = try XCTUnwrap(document.stops.first { $0.id == id })
                XCTAssertNil(stop.plaque, id)
                XCTAssertFalse(stop.hasPlaqueReference, id)
            }
        }
        XCTAssertEqual(SignPlacementPolicy.discoveryHint(referenceImageName: SignPlacementPolicy.hotelReferenceImageName),
                       "Find the oval Cranford Hotel plaque marked Established 1882")
        XCTAssertEqual(SignPlacementPolicy.discoveryHint(referenceImageName: SignPlacementPolicy.millReferenceImageName),
                       "Find the plaque beside the red double doors")
        XCTAssertEqual(SignPlacementPolicy.discoveryHint(referenceImageName: SignPlacementPolicy.parkReferenceImageName),
                       "Find the black Cranford Park plaque on the stone wall")
        XCTAssertEqual(SignPlacementPolicy.discoveryHint(referenceImageName: "unregistered"), "Find this stop’s plaque")

        let field = try jsonObject(at: root.appendingPathComponent("docs/field-references/cranford-hotel-plaque.json"))
        XCTAssertEqual(field["stopID"] as? String, "hpab-005")
        XCTAssertEqual(field["referenceImageName"] as? String, SignPlacementPolicy.hotelReferenceImageName)
        XCTAssertEqual(jsonDouble(field["reference_frame_width_meters"]),
                       SignPlacementPolicy.assumedHotelReferenceWidthMeters, accuracy: 0.000_001)
        XCTAssertEqual(field["resampled"] as? Bool, false)
        XCTAssertEqual(field["generative_processing"] as? Bool, false)
        XCTAssertEqual(integers(field["source_canvas"]), [960, 1280])
        XCTAssertEqual(integers(field["crop_box_left_top_right_bottom"]), [24, 359, 951, 990])
        XCTAssertEqual(integers(field["reference_canvas"]), [927, 631])
        let original = root.appendingPathComponent("docs/field-references/cranford-hotel-plaque-original.jpg")
        let reference = groupURL.deletingLastPathComponent()
            .appendingPathComponent("cranford-hotel-plaque.arreferenceimage/cranford-hotel-plaque.jpg")
        XCTAssertEqual(sha256Hex(try Data(contentsOf: original)), field["original_sha256"] as? String)
        XCTAssertEqual(sha256Hex(try Data(contentsOf: reference)), field["reference_sha256"] as? String)
    }

    func testShippedArtworkAndNarrationBytesMatchTheCatalog() throws {
        let root = repositoryRoot()
        let document = try loadShippedCatalog(from: root)
        let artwork: [String: StopArtwork] = [
            "hpab-001": StopArtwork(homeInk: "home-sketch-mill", listInk: "stop-ink-mill",
                                    watercolor: "sketchbook-mill", mapLandmark: "mill-map-landmark"),
            "hpab-002": StopArtwork(homeInk: "home-sketch-greystone", listInk: "stop-ink-greystone",
                                    watercolor: "sketchbook-greystone", mapLandmark: "greystone-map-landmark"),
            "hpab-003": StopArtwork(homeInk: "home-sketch-river", listInk: "stop-ink-river",
                                    mapLandmark: "rahway-river-illustration"),
            "hpab-004": StopArtwork(homeInk: "home-sketch-church", listInk: "stop-ink-church",
                                    mapLandmark: "first-baptist-church-illustration", listHeight: 104),
            "hpab-005": StopArtwork(homeInk: "home-sketch-hotel", listInk: "stop-ink-hotel",
                                    watercolor: "sketchbook-hotel", mapLandmark: "hotel-map-landmark")
        ]
        XCTAssertEqual(document.stops.map(\.id), Array(artwork.keys).sorted())
        for stop in document.stops {
            let media = try XCTUnwrap(stop.artwork, stop.id)
            XCTAssertEqual(media, artwork[stop.id], stop.id)
            XCTAssertTrue(media.isValid, stop.id)
            XCTAssertEqual(media.watercolor != nil, stop.hasPlaqueReference, stop.id)
        }

        let recordings = try XCTUnwrap(document.recordings)
        XCTAssertEqual(recordings.map(\.stopID), ["hpab-001", "hpab-002"])
        for recording in recordings {
            XCTAssertTrue(recording.isValid, recording.stopID)
            let stop = try XCTUnwrap(document.stops.first { $0.id == recording.stopID })
            XCTAssertFalse(stop.narrationPending)
            XCTAssertEqual(stop.audioURL?.lastPathComponent, recording.fileName)
            XCTAssertEqual(stop.estimatedVisitDuration, recording.duration, accuracy: 0.000_000_1)
            XCTAssertEqual(stop.narrationSource, .bundledAudio(fileName: recording.fileName))
            let transcript = try XCTUnwrap(stop.narrationText)
            XCTAssertEqual(sha256Hex(Data(transcript.utf8)), recording.transcriptSHA256)
            let audioURL = root.appendingPathComponent("assets/audio/stops").appendingPathComponent(recording.fileName)
            XCTAssertEqual(sha256Hex(try Data(contentsOf: audioURL)), recording.audioSHA256)
            let production = try jsonObject(at: audioURL.deletingPathExtension().appendingPathExtension("production.json"))
            XCTAssertEqual(production["audio_sha256"] as? String, recording.audioSHA256)
            XCTAssertEqual(jsonDouble(production["duration_seconds"]), recording.duration, accuracy: 0.000_000_1)
        }
        for id in ["hpab-003", "hpab-004", "hpab-005"] {
            let stop = try XCTUnwrap(document.stops.first { $0.id == id })
            XCTAssertTrue(stop.narrationPending, id)
            XCTAssertNil(stop.audioURL, id)
            XCTAssertNil(stop.narrationText, id)
            XCTAssertNil(stop.narrationSource, id)
            XCTAssertFalse(recordings.contains { $0.stopID == id }, id)
        }
    }
}

private func repositoryRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func loadShippedCatalog(from root: URL) throws -> HistoricalTourDocument {
    let url = root.appendingPathComponent("CranfordHistoricalAR/Resources/historical_stops.json")
    return try HistoricalStopDecoder.decode(Data(contentsOf: url))
}

private func jsonObject(at url: URL) throws -> [String: Any] {
    let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
    return try XCTUnwrap(object as? [String: Any], url.lastPathComponent)
}

private func integers(_ value: Any?) -> [Int] {
    (value as? [NSNumber])?.map(\.intValue) ?? []
}

private func jsonDouble(_ value: Any?) -> Double {
    (value as? NSNumber)?.doubleValue ?? -1
}

/// SHA-256 without CryptoKit so the same check runs on Linux and Apple toolchains.
private func sha256Hex(_ data: Data) -> String {
    var hash = SHA256Hasher()
    hash.update(data)
    return hash.finalize().map { String(format: "%02x", $0) }.joined()
}

private struct SHA256Hasher {
    private static let k: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    ]
    private var state: [UInt32] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    ]
    private var buffer = [UInt8]()
    private var messageBits: UInt64 = 0

    mutating func update(_ data: Data) {
        messageBits += UInt64(data.count) * 8
        buffer.append(contentsOf: data)
        var offset = 0
        while buffer.count - offset >= 64 {
            compress(Array(buffer[offset..<(offset + 64)]))
            offset += 64
        }
        if offset > 0 { buffer.removeFirst(offset) }
    }

    mutating func finalize() -> [UInt8] {
        var tail = buffer
        tail.append(0x80)
        while tail.count % 64 != 56 { tail.append(0) }
        var length = messageBits.bigEndian
        withUnsafeBytes(of: &length) { tail.append(contentsOf: $0) }
        var offset = 0
        while offset < tail.count {
            compress(Array(tail[offset..<(offset + 64)]))
            offset += 64
        }
        return state.flatMap { value in
            let big = value.bigEndian
            return withUnsafeBytes(of: big) { Array($0) }
        }
    }

    private mutating func compress(_ block: [UInt8]) {
        var words = [UInt32](repeating: 0, count: 64)
        for index in 0..<16 {
            let start = index * 4
            words[index] = UInt32(block[start]) << 24 | UInt32(block[start + 1]) << 16
                | UInt32(block[start + 2]) << 8 | UInt32(block[start + 3])
        }
        for index in 16..<64 {
            let s0 = rotate(words[index - 15], by: 7) ^ rotate(words[index - 15], by: 18) ^ (words[index - 15] >> 3)
            let s1 = rotate(words[index - 2], by: 17) ^ rotate(words[index - 2], by: 19) ^ (words[index - 2] >> 10)
            words[index] = words[index - 16] &+ s0 &+ words[index - 7] &+ s1
        }
        var a = state[0], b = state[1], c = state[2], d = state[3]
        var e = state[4], f = state[5], g = state[6], h = state[7]
        for index in 0..<64 {
            let s1 = rotate(e, by: 6) ^ rotate(e, by: 11) ^ rotate(e, by: 25)
            let choice = (e & f) ^ (~e & g)
            let temp1 = h &+ s1 &+ choice &+ Self.k[index] &+ words[index]
            let s0 = rotate(a, by: 2) ^ rotate(a, by: 13) ^ rotate(a, by: 22)
            let majority = (a & b) ^ (a & c) ^ (b & c)
            let temp2 = s0 &+ majority
            h = g; g = f; f = e; e = d &+ temp1
            d = c; c = b; b = a; a = temp1 &+ temp2
        }
        state[0] = state[0] &+ a; state[1] = state[1] &+ b
        state[2] = state[2] &+ c; state[3] = state[3] &+ d
        state[4] = state[4] &+ e; state[5] = state[5] &+ f
        state[6] = state[6] &+ g; state[7] = state[7] &+ h
    }

    private func rotate(_ value: UInt32, by shift: UInt32) -> UInt32 {
        (value >> shift) | (value << (32 - shift))
    }
}
