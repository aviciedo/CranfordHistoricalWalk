#!/usr/bin/env python3
"""Build a portable harness from the ACTUAL app models/stores/routing and flow tests.
Only Apple-coordinate bridges and external service protocols are replaced; ARKit,
SwiftUI and AVFoundation still require the native host-app tests on a Mac.
Run swift test --package-path .build/activity-model-harness after this script.
"""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
out = root / '.build/activity-model-harness'
src = out / 'Sources/ActivityModelHarness'
tests = out / 'Tests/ActivityModelHarnessTests'
src.mkdir(parents=True, exist_ok=True)
tests.mkdir(parents=True, exist_ok=True)
(out / 'Package.swift').write_text('''// swift-tools-version:5.9
import PackageDescription
let package = Package(name: "ActivityModelHarness", platforms: [.macOS(.v14)],
 dependencies: [.package(path: "../../Packages/TourCore")],
 targets: [.target(name: "ActivityModelHarness", dependencies: [.product(name: "TourCore", package: "TourCore")],
 swiftSettings: [.define("DEVELOPER_MENU")]),
 .testTarget(name: "ActivityModelHarnessTests", dependencies: ["ActivityModelHarness", .product(name: "TourCore", package: "TourCore")])])
''')
for relative in ['ViewModels/TourViewModel.swift', 'ViewModels/TourViewModel+Proximity.swift',
                 'ViewModels/TourViewModel+Routing.swift', 'Services/StopVisitStore.swift',
                 'Services/SimulatedLocationService.swift', 'App/AppNavigation.swift']:
    text = (root / 'CranfordHistoricalAR' / relative).read_text().replace('import CoreLocation\n', '')
    (src / Path(relative).name).write_text(text)
location = (root / 'CranfordHistoricalAR/Services/LocationService.swift').read_text()
location = location[:location.index('// MARK: - Core Location implementation')].replace('import CoreLocation\n', '')
# Remove only Apple framework convenience initializers; keep real value types, protocol,
# broadcaster, simulation, location pipeline and routing unchanged.
for signature in ['    init(location: CLLocation)', '    init(heading: CLHeading)',
                  '    init(_ status: CLAuthorizationStatus)', '    init(_ error: Error)']:
    a = location.index(signature)
    brace = location.index('{', a)
    depth, b = 1, brace + 1
    while depth:
        depth += (location[b] == '{') - (location[b] == '}')
        b += 1
    location = location[:a] + location[b:]
(src / 'LocationService.swift').write_text(location)
preview = (root / 'CranfordHistoricalAR/Models/HistoricalStop+App.swift').read_text()
preview = preview[preview.index('    static let previewStops:'):]
(src / 'PreviewStops.swift').write_text('import Foundation\nimport TourCore\nextension HistoricalStop {\n' + preview)
(src / 'ServiceBridges.swift').write_text('''import Foundation
import TourCore
typealias CLLocationCoordinate2D = GeoCoordinate
enum DirectionsError: LocalizedError {
 case unavailable
 var errorDescription: String? { "Directions unavailable in portable tests" }
}
extension GeoCoordinate { var clLocationCoordinate: GeoCoordinate { self } }
protocol HistoricalStopService: Sendable { func loadTour() async throws -> HistoricalTourDocument }
struct InMemoryHistoricalStopService: HistoricalStopService {
 let stops: [HistoricalStop]
 func loadTour() async throws -> HistoricalTourDocument { HistoricalTourDocument(tourName: "Test", stops: stops) }
}
protocol DirectionsService: Sendable {
 func walkingRoute(from: GeoCoordinate, to: GeoCoordinate) async throws -> WalkingRoute
}
struct PreviewDirectionsService: DirectionsService {
 func walkingRoute(from: GeoCoordinate, to: GeoCoordinate) async throws -> WalkingRoute {
  var route = WalkingRoute.straightLineEstimate(from: from, to: to)
  route.source = .simulated
  return route
 }
}
''')
(tests / 'TourCompletionFlowTests.swift').write_text((root / 'CranfordHistoricalARTests/TourCompletionFlowTests.swift').read_text())
print(out)
