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
    }

    @ViewBuilder
    private func controls(_ developer: DeveloperModeController) -> some View {
        @Bindable var developer = developer
        let diagnostics = developer.diagnostics
        Form {
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
                row("Bundle", Bundle.main.bundleIdentifier ?? "—")
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
}
#endif
