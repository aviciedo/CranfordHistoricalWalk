import XCTest
@testable import TourCore

final class GeospatialLaunchPolicyTests: XCTestCase {
    private func defaults() -> UserDefaults {
        let name = "geospatial-consent-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func ready(
        mode: TourProviderMode = .automatic,
        requested: Bool = true,
        sdk: Bool = true,
        key: Bool = true,
        consent: Bool = true,
        device: Bool = true,
        location: Bool = true,
        precise: Bool = true,
        network: Bool = true
    ) -> GeospatialSessionChoice {
        GeospatialSessionResolver.resolve(
            mode: mode,
            geospatialRequested: requested,
            sdkLinked: sdk,
            hasAPIKey: key,
            userConsented: consent,
            deviceSupportsGeospatial: device,
            locationAuthorized: location,
            preciseLocation: precise,
            networkAvailable: network
        )
    }

    func testOnlyTheLiteralOneRequestsGeospatial() {
        XCTAssertTrue(GeospatialLaunchPolicy.plistRequestsGeospatial("1"))
        XCTAssertTrue(GeospatialLaunchPolicy.plistRequestsGeospatial(" 1\n"))
        for raw in ["", "0", "true", "TRUE", "yes", "01", "1.0", "$(ENABLE_ARCORE_GEOSPATIAL)"] {
            XCTAssertFalse(GeospatialLaunchPolicy.plistRequestsGeospatial(raw), raw)
        }
    }

    func testProviderModeOverridesTheDefaultOnFlag() {
        XCTAssertTrue(GeospatialLaunchPolicy.requestsGeospatial(plistEnabled: true, mode: .automatic))
        XCTAssertFalse(GeospatialLaunchPolicy.requestsGeospatial(plistEnabled: false, mode: .automatic))
        XCTAssertFalse(GeospatialLaunchPolicy.requestsGeospatial(plistEnabled: true, mode: .appleOnly))
        XCTAssertTrue(GeospatialLaunchPolicy.requestsGeospatial(plistEnabled: false, mode: .googleOnly))
    }

    func testConsentIsPresentedOnlyWhenGeospatialIsRequestedAndNotYetAccepted() {
        XCTAssertTrue(GeospatialLaunchPolicy.shouldPresentConsent(requestsGeospatial: true, alreadyAccepted: false))
        XCTAssertFalse(GeospatialLaunchPolicy.shouldPresentConsent(requestsGeospatial: true, alreadyAccepted: true))
        XCTAssertFalse(GeospatialLaunchPolicy.shouldPresentConsent(requestsGeospatial: false, alreadyAccepted: false))
        XCTAssertFalse(GeospatialLaunchPolicy.shouldPresentConsent(requestsGeospatial: false, alreadyAccepted: true))
    }

    func testAcceptPersistsAndDeclineDoesNot() {
        XCTAssertEqual(GeospatialLaunchPolicy.consentDefaultsKey, "arcoreGeospatialConsentAccepted")
        let store = defaults()
        XCTAssertFalse(GeospatialLaunchPolicy.hasAccepted(defaults: store))
        GeospatialLaunchPolicy.decline(defaults: store)
        XCTAssertFalse(GeospatialLaunchPolicy.hasAccepted(defaults: store))
        XCTAssertNil(store.object(forKey: GeospatialLaunchPolicy.consentDefaultsKey))
        GeospatialLaunchPolicy.accept(defaults: store)
        XCTAssertTrue(GeospatialLaunchPolicy.hasAccepted(defaults: store))
        GeospatialLaunchPolicy.decline(defaults: store)
        XCTAssertTrue(GeospatialLaunchPolicy.hasAccepted(defaults: store), "A later decline must not revoke stored acceptance")
        GeospatialLaunchPolicy.reset(defaults: store)
        XCTAssertFalse(GeospatialLaunchPolicy.hasAccepted(defaults: store))
        XCTAssertTrue(GeospatialLaunchPolicy.shouldPresentConsent(
            requestsGeospatial: GeospatialLaunchPolicy.requestsGeospatial(plistEnabled: true, mode: .automatic),
            alreadyAccepted: GeospatialLaunchPolicy.hasAccepted(defaults: store)
        ))
    }

    func testDefaultOnWithoutConsentUsesAppleAndDoesNotStartARCore() {
        let choice = ready(consent: false)
        XCTAssertEqual(choice, .coreLocation(.missingUserConsent))
        let selection = GeospatialSessionResolver.selection(for: choice)
        XCTAssertEqual(selection.backend, .coreLocation)
        XCTAssertFalse(selection.usesARCore)
        XCTAssertEqual(selection.fallbackReason, .missingUserConsent)
    }

    func testDeclinedDefaultStillFallsBackWhenTheSDKIsMissing() {
        XCTAssertEqual(ready(sdk: false, consent: false), .coreLocation(.sdkNotLinked))
    }

    func testAppleOnlyIgnoresTheDefaultOnFlag() {
        XCTAssertEqual(ready(mode: .appleOnly, consent: true), .coreLocation(nil))
        XCTAssertEqual(ready(mode: .appleOnly, consent: false, network: false), .coreLocation(nil))
    }

    func testGoogleOnlyWithoutConsentStaysUnavailable() {
        XCTAssertEqual(ready(mode: .googleOnly, requested: false, consent: false), .googleUnavailable(.missingUserConsent))
        XCTAssertEqual(ready(mode: .googleOnly, requested: false, sdk: false, consent: false), .googleUnavailable(.sdkNotLinked))
        XCTAssertEqual(ready(mode: .googleOnly, key: false), .googleUnavailable(.missingAPIKey))
        XCTAssertEqual(ready(mode: .googleOnly, precise: false), .googleUnavailable(.preciseLocationRequired))
        XCTAssertEqual(ready(mode: .googleOnly, network: false), .googleUnavailable(.networkUnavailable))
        XCTAssertEqual(ready(mode: .googleOnly, requested: false), .arCore)
    }

    func testAutomaticFallbackOrderStillBlocksARCore() {
        XCTAssertEqual(ready(requested: false), .coreLocation(.flagDisabled))
        XCTAssertEqual(ready(requested: false, sdk: false), .coreLocation(.sdkNotLinked))
        XCTAssertEqual(ready(key: false), .coreLocation(.missingAPIKey))
        XCTAssertEqual(ready(device: false), .coreLocation(.deviceUnsupported))
        XCTAssertEqual(ready(location: false), .coreLocation(.locationPermissionDenied))
        XCTAssertEqual(ready(precise: false), .coreLocation(.preciseLocationRequired))
        XCTAssertEqual(ready(network: false), .coreLocation(.networkUnavailable))
        XCTAssertEqual(ready(), .arCore)
    }

    func testShippedConfigRequestsGeospatialAndStillLetsSecretsOverrideIt() throws {
        let root = try repositoryRoot()
        let base = try String(contentsOf: root.appendingPathComponent("Config/Base.xcconfig"), encoding: .utf8)
        let baseValues = xcconfigAssignments(base)
        XCTAssertEqual(baseValues["ENABLE_ARCORE_GEOSPATIAL"], "1")
        XCTAssertTrue(GeospatialLaunchPolicy.plistRequestsGeospatial(baseValues["ENABLE_ARCORE_GEOSPATIAL"] ?? ""))

        let example = try String(contentsOf: root.appendingPathComponent("Config/Secrets.example.xcconfig"), encoding: .utf8)
        XCTAssertEqual(xcconfigAssignments(example)["ENABLE_ARCORE_GEOSPATIAL"], "0")
        XCTAssertFalse(GeospatialLaunchPolicy.plistRequestsGeospatial("0"))

        let info = try String(contentsOf: root.appendingPathComponent("CranfordHistoricalAR/Info.plist"), encoding: .utf8)
        let flag = try plistString(info, key: "EnableARCoreGeospatial")
        XCTAssertEqual(flag, "$(ENABLE_ARCORE_GEOSPATIAL)")
        XCTAssertFalse(GeospatialLaunchPolicy.plistRequestsGeospatial(flag), "An unexpanded build setting must not count as enabled")

        for name in ["Debug.xcconfig", "Release.xcconfig"] {
            let text = try String(contentsOf: root.appendingPathComponent("Config/\(name)"), encoding: .utf8)
            let baseInclude = try XCTUnwrap(text.range(of: "#include \"Base.xcconfig\""))
            let secretsInclude = try XCTUnwrap(text.range(of: "#include? \"Secrets.xcconfig\""))
            XCTAssertLessThan(baseInclude.lowerBound, secretsInclude.lowerBound, name)
            XCTAssertTrue(text.contains("APP_COMPILATION_CONDITIONS_1 = ARCORE_GEOSPATIAL"), name)
            XCTAssertTrue(text.contains("APP_COMPILATION_CONDITIONS_0 ="), name)
        }
    }

    private func repositoryRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("Config/Base.xcconfig").path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        throw NSError(domain: "GeospatialLaunchPolicyTests", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Could not find Config/Base.xcconfig from \(#filePath)"
        ])
    }

    private func xcconfigAssignments(_ text: String) -> [String: String] {
        var values: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("//") || trimmed.hasPrefix("#") { continue }
            guard let eq = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[..<eq].trimmingCharacters(in: .whitespaces)
            let value = trimmed[trimmed.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            values[String(key)] = String(value)
        }
        return values
    }

    private func plistString(_ xml: String, key: String) throws -> String {
        let pattern = "<key>\(key)</key>\\s*<string>([^<]*)</string>"
        let expression = try NSRegularExpression(pattern: pattern)
        let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        let match = try XCTUnwrap(expression.firstMatch(in: xml, range: range))
        let value = try XCTUnwrap(Range(match.range(at: 1), in: xml))
        return String(xml[value])
    }
}
