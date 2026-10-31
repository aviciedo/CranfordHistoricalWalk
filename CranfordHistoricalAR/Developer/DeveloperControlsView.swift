#if DEVELOPER_MENU
import SwiftUI
import UIKit
import TourCore

/// "Developer Controls" (spec §19). Reachable only from the debug menu in Debug builds.
struct DeveloperControlsView: View {
    @Environment(TourViewModel.self) private var tour
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(AppNavigation.self) private var navigation
    @State private var captureStopID = ""
    @State private var captureLabel = ""
    @State private var csvExport: GPSCaptureExport?

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
                ToolbarItem(placement: .cancellationAction) { ScreenBackButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { ScreenHomeButton() }
            }
        }
        .task { tour.startLocationIfPossible() }
        .onChange(of: tour.stops.map(\.id), initial: true) { _, ids in
            if !ids.contains(captureStopID) { captureStopID = tour.currentStop?.id ?? ids.first ?? "" }
        }
        .onChange(of: navigation.homeReturnID) { _, _ in csvExport = nil }
        .sheet(item: $csvExport) { GPSCaptureShareSheet(fileURL: $0.url).dismissOnReturnHome() }
        .dismissOnReturnHome()
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
                Toggle("Save visit history", isOn: $developer.isVisitRecordingEnabled)
                row("Saved stops", "\(tour.visitRecords.count)")
                Button(role: .destructive) {
                    dependencies.narrationPlayer.stop()
                    developer.clearVisitsAndResetTour()
                } label: {
                    Label("Clear visits & restart at stop 1", systemImage: "arrow.counterclockwise")
                }
                .disabled(tour.loadState != .loaded)
                Button(role: .destructive) {
                    dependencies.narrationPlayer.stop()
                    developer.clearAllActivitiesAndResetTour()
                } label: {
                    Label("Clear visits, stories & sketches", systemImage: "arrow.counterclockwise")
                }
                .disabled(tour.loadState != .loaded)
                .accessibilityHint("Clears all three activity records and restarts the walk at stop 1")
            } header: {
                Text("Visit testing")
            } footer: {
                Text("Turn saving off for test walks. AR cards, narration and Continue still work. Existing saved visits stay until you clear them. Saving turns on again when you reopen the app. Clear visits restarts at stop 1 and keeps story and sketchbook progress. Use Clear visits, stories & sketches for a fresh activity test. GPS can record a new visit while you remain on site.")
            }

            Section {
                Button { developer.refreshGPSNow() } label: {
                    HStack {
                        Label("Refresh GPS now", systemImage: "arrow.clockwise")
                        Spacer()
                        if developer.isRefreshingGPS { ProgressView() }
                    }
                    .frame(minHeight: 44)
                }
                .disabled(developer.isRefreshingGPS)
                if let message = developer.gpsRefreshMessage {
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: 12) {
                        if let sample = tour.userLocation {
                            row("Source", sample.isSimulated || tour.locationService is SimulatedLocationService ? "Simulated location" : "Device GPS")
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
                Text("Uses the same location as the map and AR. Six decimal places show the reported coordinates; they do not increase GPS accuracy. Only fresh device readings can be saved; simulated readings are rejected.")
            }

            gpsCaptureSections(developer)

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

            Section("Walking progression") {
                row("Destination", tour.currentStop?.name ?? "None")
                row("Near-stop seconds", String(Int(tour.walkingProgression.accumulatedVisitSeconds)))
                row("Blocked by", tour.progressionDecision.advanceBlockers.map(\.rawValue).joined(separator: ", "))
                ShareLink("Share local progression diagnostics", item: tour.progressionDiagnostics.exportJSON)
                Text("In-memory diagnostic snapshots only. No coordinates, automatic uploads or saved GPS history.")
                    .font(.footnote)
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

    @ViewBuilder
    private func gpsCaptureSections(_ developer: DeveloperModeController) -> some View {
        Section {
            Picker("Tour stop", selection: $captureStopID) {
                if captureStopID.isEmpty { Text("Select a stop").tag("") }
                ForEach(tour.stops) { stop in Text(stop.name).tag(stop.id) }
            }
            TextField("Capture label (optional)", text: $captureLabel,
                      prompt: Text("e.g. public viewing area"))
                .textInputAutocapitalization(.sentences)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        if developer.saveGPSCapture(stopID: captureStopID, label: captureLabel) { captureLabel = "" }
                    } label: {
                        Label("Save GPS reading", systemImage: "location.circle")
                            .frame(minHeight: 44)
                    }
                    .disabled(developer.captureIssue(stopID: captureStopID, now: context.date) != nil)
                    .accessibilityIdentifier("developer.gps.capture")
                    if let issue = developer.captureIssue(stopID: captureStopID, now: context.date) {
                        Text(issue).font(.footnote).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let sample = tour.userLocation, sample.horizontalAccuracy > 25 {
                        Text("Low accuracy. The reported uncertainty will be saved with this reading.")
                            .font(.footnote).foregroundStyle(AppTheme.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if let message = developer.captureMessage {
                Text(message).font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            Text("Capture GPS location")
        } footer: {
            Text("Save multiple labeled readings per stop. Captures stay on this device and never change map markers, routing or arrival detection.")
        }

        Section {
            let captures = developer.captures(for: captureStopID)
            if captures.isEmpty {
                Text("No saved readings for this stop.").foregroundStyle(.secondary)
            }
            ForEach(captures) { capture in
                VStack(alignment: .leading, spacing: 8) {
                    Text(capture.label).font(.headline)
                    Text(capture.savedAt.formatted(date: .abbreviated, time: .standard)).font(.caption)
                    Text(String(format: "%.6f, %.6f", locale: Locale(identifier: "en_US_POSIX"),
                                capture.coordinate.latitude, capture.coordinate.longitude))
                        .font(.subheadline).monospacedDigit().textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    row("Reported accuracy", String(format: "± %.1f m", capture.horizontalAccuracy))
                    if let fix = capture.fixTimestamp {
                        Text("GPS fix: \(fix.formatted(date: .abbreviated, time: .standard))")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Imported viewing point · Original fix time unknown")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let precise = capture.preciseLocation {
                        row("Precise Location at capture", precise ? "On" : "Off")
                    }
                    Button {
                        UIPasteboard.general.string = capture.copyText
                    } label: {
                        Label("Copy reading", systemImage: "doc.on.doc").frame(minHeight: 44)
                    }
                }
                .padding(.vertical, 4)
                .swipeActions(allowsFullSwipe: false) {
                    Button("Delete", role: .destructive) { developer.deleteGPSCapture(id: capture.id) }
                }
            }
            if !developer.currentTourCaptures.isEmpty {
                Button {
                    UIPasteboard.general.string = developer.currentTourCaptures.map(\.copyText).joined(separator: "\n\n")
                } label: {
                    Label("Copy all saved readings", systemImage: "doc.on.doc").frame(minHeight: 44)
                }
                Button {
                    if let url = developer.makeCSVExport() { csvExport = GPSCaptureExport(url: url) }
                } label: {
                    Label("Share all readings as CSV", systemImage: "square.and.arrow.up").frame(minHeight: 44)
                }
                .accessibilityIdentifier("developer.gps.shareCSV")
            }
        } header: {
            Text("Stored GPS captures")
        } footer: {
            Text("Copy or share readings for this tour when requesting coordinate updates. Swipe a saved reading to delete it. Clearing tour visits does not delete GPS captures.")
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

}

private struct GPSCaptureExport: Identifiable {
    let id = UUID()
    let url: URL
}

private struct GPSCaptureShareSheet: UIViewControllerRepresentable {
    let fileURL: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
