import Foundation
import XCTest
@testable import TourCore

final class GPSCaptureTests: XCTestCase {
    private func capture(label: String = "Front door") -> GPSCapture {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        return GPSCapture(tour: .legacy, stopID: "hpab-001", stopName: "Droescher’s Mill", label: label,
            coordinate: GeoCoordinate(latitude: 40.650249, longitude: -74.301047), horizontalAccuracy: 3.1,
            fixTimestamp: date.addingTimeInterval(-2), savedAt: date, preciseLocation: true)
    }

    func testArchiveRoundTripKeepsFullReadingMetadata() throws {
        let original = GPSCaptureArchive(records: [capture()])
        XCTAssertTrue(original.isValid)
        XCTAssertEqual(try JSONDecoder().decode(GPSCaptureArchive.self, from: JSONEncoder().encode(original)), original)
    }

    func testWeakOrReducedAccuracyRemainsHonestFieldEvidence() {
        var reading = capture(); reading.horizontalAccuracy = 70; reading.preciseLocation = false
        XCTAssertTrue(reading.isValid)
        XCTAssertTrue(GPSCapture.csv([reading]).contains(",70.0,"))
        XCTAssertTrue(GPSCapture.csv([reading]).contains(",false,device_gps"))
    }

    func testInvalidStaleOrInventedDeviceReadingsAreRejected() {
        var reading = capture(); reading.coordinate.latitude = 100
        XCTAssertFalse(reading.isValid)
        reading = capture(); reading.horizontalAccuracy = .nan; XCTAssertFalse(reading.isValid)
        reading = capture(); reading.horizontalAccuracy = -1; XCTAssertFalse(reading.isValid)
        reading = capture(); reading.fixTimestamp = nil; XCTAssertFalse(reading.isValid)
        reading = capture(); reading.preciseLocation = nil; XCTAssertFalse(reading.isValid)
        reading = capture(); reading.fixTimestamp = reading.savedAt.addingTimeInterval(-30); XCTAssertFalse(reading.isValid)
        reading = capture(); reading.fixTimestamp = reading.savedAt.addingTimeInterval(6); XCTAssertFalse(reading.isValid)
        reading = capture(label: "  "); XCTAssertFalse(reading.isValid)
    }

    func testLegacyCaptureDoesNotInventFixTimeOrPermission() {
        var reading = capture(); reading.source = .legacyViewingPoint
        reading.fixTimestamp = nil; reading.preciseLocation = nil
        XCTAssertTrue(reading.isValid)
        XCTAssertTrue(reading.copyText.contains("Unknown — imported legacy viewing point"))
        XCTAssertTrue(GPSCapture.csv([reading]).contains(",,legacy_viewing_point"))
    }

    func testArchiveRejectsDuplicateIdentifiersAndUnknownVersions() {
        let reading = capture()
        XCTAssertFalse(GPSCaptureArchive(records: [reading, reading]).isValid)
        var archive = GPSCaptureArchive(records: [reading]); archive.version = 2
        XCTAssertFalse(archive.isValid)
    }

    func testCSVPreservesCoordinatesUTCTimestampsAndEscapesLabels() {
        let reading = capture(label: "Door, \"north\"\nPublic path")
        let csv = GPSCapture.csv([reading])
        XCTAssertTrue(csv.contains("\"Door, \"\"north\"\"\nPublic path\""))
        XCTAssertTrue(csv.contains(",40.650249,-74.301047,3.1,"))
        XCTAssertTrue(csv.contains("Z,"))
        XCTAssertTrue(csv.hasSuffix("\r\n"))
        XCTAssertTrue(csv.contains("fix_timestamp_utc"))
    }

    func testCSVNeutralizesUserLabelFormulasWithoutBreakingNegativeCoordinates() {
        for label in ["=1+1", "+1+1", "-1+1", "@SUM(A1)", "  =cmd", "\n+cmd", "=1\"2"] {
            let csv = GPSCapture.csv([capture(label: label)])
            let escaped = label.replacingOccurrences(of: "\"", with: "\"\"")
            XCTAssertTrue(csv.contains("\"'\(escaped)\""), label)
        }
        let ordinary = GPSCapture.csv([capture(label: "North-gate")])
        XCTAssertTrue(ordinary.contains("\"North-gate\""))
        XCTAssertFalse(ordinary.contains("'North-gate"))
        XCTAssertTrue(GPSCapture.csv([capture(label: "=1+1")]).contains(",-74.301047,"))
    }

    func testFreshnessBoundaryAndMissingIdentityRejectDeviceEvidence() {
        var reading = capture()
        reading.fixTimestamp = reading.savedAt.addingTimeInterval(-29.999)
        XCTAssertTrue(reading.isValid)
        reading.fixTimestamp = reading.savedAt.addingTimeInterval(-30)
        XCTAssertFalse(reading.isValid)
        reading = capture()
        reading.fixTimestamp = reading.savedAt.addingTimeInterval(5)
        XCTAssertTrue(reading.isValid)
        reading.fixTimestamp = reading.savedAt.addingTimeInterval(5.001)
        XCTAssertFalse(reading.isValid)
        reading = capture(); reading.stopID = ""; XCTAssertFalse(reading.isValid)
        reading = capture(); reading.stopName = ""; XCTAssertFalse(reading.isValid)
        reading = capture(); reading.tour = TourCatalogIdentity(tourID: " ", version: 1); XCTAssertFalse(reading.isValid)
        reading = capture(); reading.tour.version = 0; XCTAssertFalse(reading.isValid)
        reading = capture(); reading.horizontalAccuracy = .infinity; XCTAssertFalse(reading.isValid)
    }

    func testLegacyFiniteFixIsKeptAndPreciseLocationCopyStaysExplicit() {
        var legacy = capture()
        legacy.source = .legacyViewingPoint
        legacy.preciseLocation = nil
        legacy.fixTimestamp = legacy.savedAt
        XCTAssertTrue(legacy.isValid)
        XCTAssertTrue(legacy.copyText.contains("Precise Location: Unknown"))
        var off = capture(); off.preciseLocation = false
        XCTAssertTrue(off.copyText.contains("Precise Location: Off"))
        XCTAssertTrue(GPSCaptureArchive(records: []).isValid)
        XCTAssertTrue(GPSCapture.csv([]).hasPrefix("capture_id,"))
        XCTAssertTrue(GPSCapture.csv([]).hasSuffix("\r\n"))
        XCTAssertEqual(GPSCapture.csv([]).components(separatedBy: "\r\n").count, 2)
    }

    func testCopyIncludesAccuracyFixTimeAndSourceRatherThanCoordinatesAlone() {
        let text = capture().copyText
        XCTAssertTrue(text.contains("Latitude: 40.650249"))
        XCTAssertTrue(text.contains("Longitude: -74.301047"))
        XCTAssertTrue(text.contains("Reported accuracy: ± 3.1 m"))
        XCTAssertTrue(text.contains("GPS fix (UTC):"))
        XCTAssertTrue(text.contains("Precise Location: On"))
        XCTAssertTrue(text.contains("Source: device_gps"))
    }
}
