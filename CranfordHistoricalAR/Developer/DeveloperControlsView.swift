#if DEVELOPER_MENU
import SwiftUI
import TourCore

/// "Developer Controls" (spec §19). Reachable only from the debug menu in Debug builds.
struct DeveloperControlsView: View {
    @Environment(TourViewModel.self) private var tour
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let developer = dependencies.developer {
                    controls(developer)
                } else {
                    ContentUnavailableView("Developer Mode unavailable", systemImage: "hammer", description: Text("The developer controller was not created."))
                }
            }
            .navigationTitle("Developer Controls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { tour.startLocationIfPossible() }
    }

    @ViewBuilder
    private func controls(_ developer: DeveloperModeController) -> some View {
        @Bindable var developer = developer
        let diagnostics = developer.diagnostics
        Form {
            Section("Installed build and narration") {
                row("Version", "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"))")
                row("Audio release", ProducedNarrationRelease.identifier)
                ForEach(ProducedNarrationRelease.recordings, id: \.stopID) { recording in
                    row(recording.stopID, recording.fileName)
                }
                if let source = dependencies.narrationPlayer.preparedSource {
                    row("Prepared audio", String(describing: source))
                }
            }
            .textSelection(.enabled)

            Section {
                Button("Save this location as the viewing point") { developer.saveViewingPoint() }
                    .frame(minHeight: 44)
                if let point = developer.savedViewingPoint {
                    row("Viewing latitude", String(format: "%.6f", point.latitude))
                    row("Viewing longitude", String(format: "%.6f", point.longitude))
                    if let accuracy = developer.savedViewingAccuracy { row("Recorded accuracy", String(format: "± %.1f m", accuracy)) }
                    Button("Clear saved viewing point", role: .destructive) { developer.clearViewingPoint() }
                }
                if let message = developer.viewingPointMessage {
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                }
            } header: {
                Text("Mill viewing point")
            } footer: {
                Text("Capture from the permitted public viewing area. This local test setting survives relaunch. Copy these coordinates and accuracy for the next app update; it does not certify public access.")
            }
            .textSelection(.enabled)

            Section {
                calibrationSlider("Move right", value: $developer.bonusRight, range: -2...9)
                calibrationSlider("Move up", value: $developer.bonusUp, range: -3...6)
                calibrationSlider("Width", value: $developer.bonusWidth, range: 1...10)
                calibrationSlider("Height", value: $developer.bonusHeight, range: 1...8)
                Button("Reset approximate placement") { developer.resetWindowLayout() }
            } header: {
                Text("Mill window bonus alignment")
            } footer: {
                Text("Keep the plaque in the camera view while adjusting. Fit the overlay to BOTH glass panes in the red doors, then close this page to inspect it. Values are multiples of plaque width and are saved only on this device. The initial layout and plaque width are unmeasured estimates.")
            }

            Section {
                calibrationSlider("Move right", value: $developer.parkRight, range: -1...1, unit: "reference width", step: 0.01)
                calibrationSlider("Move up", value: $developer.parkUp, range: -0.5...2, unit: "reference width", step: 0.01)
                calibrationSlider("Width", value: $developer.parkWidth, range: 0.25...2, unit: "reference width", step: 0.01)
                calibrationSlider("Height", value: $developer.parkHeight, range: 0.2...2, unit: "reference width", step: 0.01)
                Button("Reset Greystone placement") { developer.resetParkLayout() }
            } header: {
                Text("Greystone plaque bonus alignment")
            } footer: {
                Text("Keep the Cranford Park plaque and stone surround in view while adjusting. Fit the bonus inside the stone pillar above the black sign. Values use the original close-up image frame width, including stone. Physical scale is still estimated. Settings stay on this device and do not change the mill.")
            }

            Section {
                Toggle("Save visit history", isOn: $developer.isVisitRecordingEnabled)
                row("Saved stops", "\(tour.visitRecords.count)")
                Button(role: .destructive) {
                    dependencies.narrationPlayer.stop()
                    developer.clearVisitsAndResetTour()
                } label: {
                    Label("Clear visits & restart at stop 1", systemImage: "arrow.counterclockwise")
                }
                .disabled(tour.loadState != .loaded)
            } header: {
                Text("Visit testing")
            } footer: {
                Text("Turn saving off for test walks. AR cards, narration and Continue still work. Existing saved visits stay until you clear them. Saving turns on again when you reopen the app. Clearing also resets this walk to no stops visited.")
            }

            Section {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: 12) {
                        if let sample = tour.userLocation {
                            row("Source", sample.isSimulated || developer.isSimulating ? "Simulated location" : "Device GPS")
                            row("Latitude", String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), sample.coordinate.latitude))
                            row("Longitude", String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), sample.coordinate.longitude))
                            row("Reported accuracy", sample.horizontalAccuracy >= 0 && sample.horizontalAccuracy.isFinite
                                ? String(format: "± %.1f m", sample.horizontalAccuracy) : "Unavailable")
                            row("Fix age", String(format: "%.0f seconds", max(0, context.date.timeIntervalSince(sample.timestamp))))
                            if !StopActivationPolicy.isFresh(sample.timestamp, now: context.date) {
                                Text("This location is out of date. Wait for a fresh GPS fix.")
                                    .font(.footnote).foregroundStyle(AppTheme.warning)
                            }
                        } else {
                            Text("Waiting for a location fix…")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        row("Precise Location permission", tour.locationAuthorization == .authorized
                            ? (tour.isPreciseLocation ? "On" : "Off") : "Not granted")
                    }
                    .monospacedDigit()
                    .textSelection(.enabled)
                }
                if let issue = diagnostics.locationIssue {
                    Text(issue).font(.footnote).foregroundStyle(AppTheme.warning)
                }
            } header: {
                Text("Live coordinates")
            } footer: {
                Text("Uses the same location as the map and AR. Six decimal places show the reported coordinates; they do not increase GPS accuracy. For on-site testing, leave Simulated location off.")
            }

            Section {
                Toggle("Simulated location", isOn: Binding(
                    get: { developer.isSimulating },
                    set: { $0 ? developer.enableSimulation() : developer.disableSimulation() }
                ))
                if developer.isSimulating {
                    Picker("Walking speed", selection: $developer.speedMultiplier) {
                        Text("1×").tag(1.0)
                        Text("3×").tag(3.0)
                        Text("10×").tag(10.0)
                    }
                    .pickerStyle(.segmented)
                    Picker("GPS accuracy", selection: $developer.simulatedAccuracy) {
                        Text("5 m").tag(5.0)
                        Text("25 m").tag(25.0)
                        Text("60 m (weak)").tag(60.0)
                    }
                }
            } header: {
                Text("Location")
            } footer: {
                Text("Replaces Core Location with a simulated walker. The map, routing, proximity and AR all consume it through the same single location source.")
            }

            Section("Movement") {
                if developer.isWalking {
                    Button {
                        developer.pauseWalking()
                    } label: {
                        Label("Pause walking", systemImage: "pause.circle")
                    }
                } else {
                    Button {
                        developer.walkTowardNextStop()
                    } label: {
                        Label("Walk toward next stop", systemImage: "figure.walk.motion")
                    }
                    .disabled(tour.currentStop == nil)
                }
                Button {
                    developer.nudgeTowardNextStop()
                } label: {
                    Label("Move 25 m toward next stop", systemImage: "arrow.forward.to.line")
                }
                .disabled(tour.currentStop == nil)
                Button {
                    developer.jumpToNextStop()
                } label: {
                    Label("Jump to next stop", systemImage: "mappin.and.ellipse")
                }
                .disabled(tour.currentStop == nil)
            }

            Section("Tour") {
                if tour.isPlaqueDiscoveryStop {
                    Button("Mark story read for testing") { developer.markStoryRead() }
                }
                if tour.phase == .notStarted {
                    Button {
                        tour.startTour()
                    } label: {
                        Label("Start tour", systemImage: "play.circle")
                    }
                    .disabled(tour.loadState != .loaded)
                }
                Button {
                    developer.triggerHistoricalSign()
                } label: {
                    Label("Trigger historical sign", systemImage: "signpost.right")
                }
                .disabled(tour.currentStop == nil || tour.isSignPresented)
                Button {
                    developer.skipToNextStop()
                } label: {
                    Label("Mark visited & skip to next stop", systemImage: "forward.end")
                }
                .disabled(tour.currentStop == nil)
                Button(role: .destructive) {
                    dependencies.narrationPlayer.stop()
                    developer.resetTour()
                } label: {
                    Label("Reset tour", systemImage: "arrow.counterclockwise")
                }
            }

            Section("Diagnostics") {
                row("Current stop", diagnostics.currentStop)
                row("Proximity state", diagnostics.proximityState)
                row("Distance", diagnostics.distanceToStop)
                row("Route", diagnostics.routeSource)
                row("Completed", diagnostics.completed)
                row("Walked", DistanceFormatter.distance(meters: diagnostics.walkedMeters))
                if let issue = diagnostics.locationIssue { row("Location", issue) }
                if let error = diagnostics.routingError {
                    Text(error).font(.footnote).foregroundStyle(AppTheme.warning)
                }
            }

            Section("Configuration") {
                row("Maps SDK key", dependencies.configuration.hasGoogleMapsKey ? "present" : "missing")
                row("Maps SDK initialized", GoogleMapsBootstrap.isConfigured ? "yes" : "no")
                row("Routes API key", dependencies.configuration.hasRoutesKey ? "present" : "missing")
                row("ARCore API key", dependencies.configuration.hasARCoreKey ? "present" : "missing")
                row("Directions provider", dependencies.configuration.directionsProvider.rawValue)
                row("ARCore Geospatial flag", dependencies.configuration.arCoreGeospatialEnabled ? "requested" : "off")
                row("ARCore SDK linked", GeoSpatialProviderFactory.isSDKLinked ? "yes" : "no")
                row("Geospatial consent", ARCoreConsentStore.hasAccepted ? "accepted" : "not accepted")
                row("Precise location", tour.isPreciseLocation ? "yes" : "no")
                row("Network", NetworkPathMonitor.shared.isSatisfied ? "satisfied" : "unsatisfied")
                let selection = GeoSpatialProviderFactory.selection(
                    configuration: dependencies.configuration,
                    locationAuthorized: tour.locationAuthorization == .authorized,
                    preciseLocation: tour.isPreciseLocation
                )
                row("Would use", selection.backend == .arCoreGeospatial ? "ARCore Geospatial" : "Core Location")
                if let reason = selection.fallbackReason {
                    Text(reason.userMessage).font(.footnote).foregroundStyle(AppTheme.warning)
                }
                row("Bundle", AppConfiguration.iosBundleIdentifier())
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func calibrationSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String = "plaque width", step: Double = 0.1) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            row(title, String(format: "%.2f × %@", value.wrappedValue, unit))
            Slider(value: value, in: range, step: step)
                .accessibilityLabel(title)
        }
    }
}
#endif
