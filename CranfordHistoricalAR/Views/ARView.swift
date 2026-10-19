import SwiftUI
import TourCore

/// The AR experience (spec §6): camera, 3D arrows, distance/time, status messaging.
/// Presented full-screen from the tour; shares `TourViewModel` with the map.
struct ARTourView: View {
    @Environment(TourViewModel.self) private var tour
    @Environment(AppDependencies.self) private var dependencies
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.dismiss) private var dismiss
    @State private var model: ARViewModel?
    @State private var awaitingGeospatialConsent = false

    var body: some View {
        ZStack {
            if awaitingGeospatialConsent {
                ARCorePrivacyConsentView(
                    onAccept: {
                        ARCoreConsentStore.accept()
                        awaitingGeospatialConsent = false
                        startAR()
                    },
                    onDecline: {
                        awaitingGeospatialConsent = false
                        startAR()
                    }
                )
            } else if let model {
                content(model)
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .task {
            if model != nil || awaitingGeospatialConsent { return }
            if dependencies.configuration.arCoreGeospatialEnabled, !ARCoreConsentStore.hasAccepted {
                awaitingGeospatialConsent = true
                return
            }
            startAR()
        }
        .preferredColorScheme(awaitingGeospatialConsent ? .light : .dark)
        .statusBarHidden(false)
    }

    private func startAR() {
        if model == nil {
            model = ARViewModel(tour: tour, provider: dependencies.makeGeoSpatialProvider(), imageLoader: dependencies.imageLoader, narrationPlayer: dependencies.narrationPlayer)
        }
        Task { await model?.requestCameraAccessIfNeeded() }
    }

    @ViewBuilder
    private func content(_ model: ARViewModel) -> some View {
        ZStack {
            switch model.availability {
            case .ready:
                ARViewContainer(viewModel: model)
                    .ignoresSafeArea()
            case .awaitingCameraPermission:
                CameraExplanationView(state: .requesting)
            case .cameraDenied:
                CameraExplanationView(state: .denied)
            case .cameraRestricted:
                CameraExplanationView(state: .restricted)
            case .unsupportedDevice:
                CameraExplanationView(state: .unsupported)
            }

            ARHUDView(model: model, onClose: {
                if let stop = tour.currentStop { navigation.showOnMap(stopID: stop.id) }
                else { navigation.selectedTab = .map }
                dismiss()
            })
        }
        .sheet(isPresented: Binding(get: { model.isShowingSignDetails }, set: { model.isShowingSignDetails = $0 })) {
            if let stop = tour.presentedSignStop ?? tour.currentStop {
                HistoricalSignSheet(stop: stop, onContinue: { model.isShowingSignDetails = false },
                                    onStartDiscovery: model.startPlaqueDiscovery,
                                    onEnterAR: { model.isShowingSignDetails = false })
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: Binding(get: { model.isShowingBonusPreview }, set: { model.isShowingBonusPreview = $0 })) {
            if let stop = tour.currentStop { OnSiteBonusPreview(stop: stop).presentationDetents([.large]) }
        }
    }
}

/// A quiet camera frame with one direction surface and one on-site action.
struct ARHUDView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let model: ARViewModel
    var onClose: () -> Void
    #if DEVELOPER_MENU
    @State private var isShowingCalibration = false
    #endif

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 10) {
                topBar
                if let message = model.statusMessage { notice(message, symbol: "viewfinder") }
                if let hint = model.plaqueHint, !model.tour.isCurrentStopVisited {
                    notice(hint, symbol: "viewfinder.circle")
                }
                Spacer(minLength: 8)
                if model.availability == .ready, model.isShowingWalkingOrientation,
                   !model.isMarkerAvailable, !model.tour.isCurrentStopVisited, model.tour.phase == .inProgress,
                   !(model.tour.isPlaqueDiscoveryStop && model.tour.discovery.hasArrived) {
                    ARWalkingOrientationView(relativeBearing: model.relativeBearingToWaypoint,
                                             street: model.orientationStreet,
                                             distance: model.walkingCue?.distanceText,
                                             isUpcomingTurn: model.walkingCue?.isUpcomingTurn == true)
                        .transition(.opacity)
                    Spacer(minLength: 8)
                }
                if model.availability == .ready {
                    ViewThatFits(in: .vertical) {
                        bottomPanel.fixedSize(horizontal: false, vertical: true)
                        ScrollView { bottomPanel }
                            .scrollBounceBehavior(.basedOnSize)
                    }
                    .frame(maxHeight: geometry.size.height * 0.58, alignment: .bottom)
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 12)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: model.isShowingWalkingOrientation)
            .overlay {
                if model.isShowingDiscoveryConfirmation {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 54, weight: .light))
                        Text(model.visitConfirmation).font(.headline)
                        Text("On-site extra unlocked").font(.subheadline)
                    }
                    .foregroundStyle(AppTheme.forest).padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                    .padding(24)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .combine)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: model.isShowingDiscoveryConfirmation)
        }
        #if DEVELOPER_MENU
        .sheet(isPresented: $isShowingCalibration) { DeveloperControlsView() }
        #endif
    }

    private var topBar: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onClose) {
                Label("Map", systemImage: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14).frame(minHeight: 48)
                    .background(AppTheme.ivory, in: Capsule())
            }
            .buttonStyle(.plain).foregroundStyle(AppTheme.forest)
            .accessibilityLabel("Return to walking map")
            Spacer(minLength: 0)
            if let name = model.destinationName {
                VStack(alignment: .trailing, spacing: 5) {
                    Text(model.tour.isCurrentStopVisited ? "Discovered" :
                         (model.tour.isPlaqueDiscoveryStop && model.tour.discovery.hasArrived ? "At this stop" : "Next stop"))
                        .font(.caption.weight(.medium))
                    Text(name).font(.system(.headline, design: .serif))
                        .multilineTextAlignment(.trailing).fixedSize(horizontal: false, vertical: true)
                    if !model.tour.isCurrentStopVisited && !(model.tour.isPlaqueDiscoveryStop && model.tour.discovery.hasArrived) {
                        HStack(spacing: 10) {
                            Label(model.distanceText, systemImage: "figure.walk")
                            Label(model.timeText, systemImage: "clock")
                        }
                        .font(.subheadline.weight(.medium)).monospacedDigit()
                        .contentTransition(.numericText())
                    }
                }
                .foregroundStyle(AppTheme.forest).padding(14)
                .background(AppTheme.ivory, in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private func notice(_ message: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(AppTheme.ivory)
            Text(message).font(.footnote.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            if case .failed = model.localizationState {
                Button("Retry") { model.retrySession() }.font(.footnote.weight(.semibold))
            }
        }
        .foregroundStyle(AppTheme.ivory).padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.forest.opacity(0.94), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var bottomPanel: some View {
        if model.tour.phase == .complete {
            VStack(alignment: .leading, spacing: 14) {
                Text("Walk complete").font(.system(.title2, design: .serif).weight(.semibold))
                Text("You've discovered every stop on this walk.").font(.subheadline)
                primaryButton("See your summary", symbol: "checkmark.circle", action: onClose)
            }
            .foregroundStyle(AppTheme.forest).padding(18)
            .background(AppTheme.ivory, in: RoundedRectangle(cornerRadius: 20))
        } else if model.tour.isPlaqueDiscoveryStop && (model.tour.discovery.hasArrived || model.tour.discovery.hasVerifiedPlaque) {
            discoveryControls
        } else if model.tour.isCurrentStopVisited {
            storyControls
        } else {
            VStack(spacing: 10) {
                ARNavigationArrowView(relativeBearing: model.relativeBearingToWaypoint, detail: model.guidanceDetail,
                                      cue: model.isMarkerAvailable ? nil : model.walkingCue,
                                      isApproximate: model.isGuidanceApproximate)
                if let message = model.activationMessage { notice(message, symbol: "location.circle") }
                if model.isMarkerAvailable {
                    primaryButton("Activate stop marker", symbol: "viewfinder.circle", action: model.activateMarker)
                        .accessibilityHint("Opens the historical sign, starts narration and records an on-site visit when your position is accurate enough.")
                } else if model.canShowSignManually {
                    primaryButton("Show stop marker", symbol: "viewfinder", action: model.showSign)
                }
            }
        }
    }

    private var discoveryControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.tour.discovery.hasVerifiedPlaque {
                if model.geoAnchors.isWindowBonusAccessible {
                    Button(action: model.openBonus) {
                        Label("Open on-site extra", systemImage: "photo.on.rectangle.angled")
                            .font(.headline).frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Point at the plaque to view your on-site extra.").font(.subheadline)
                }
            } else if model.tour.discovery.stage == .searching {
                Text(model.discoverySearchHint).font(.headline)
                Text(model.discoveryPlacementInstruction)
                    .font(.subheadline).foregroundStyle(AppTheme.secondaryInk)
            } else if model.tour.discovery.hasFinishedStory {
                primaryButton("Find the plaque in AR", symbol: "viewfinder", action: model.startPlaqueDiscovery)
            } else {
                primaryButton("Read or listen to the story", symbol: "book", action: { model.isShowingSignDetails = true })
            }
            if model.tour.canContinueCurrentStop {
                Button(action: model.continueToNextStop) {
                    Label(model.tour.nextStop.map { "Continue to \($0.name)" } ?? "Finish walk", systemImage: "arrow.right")
                        .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            HStack {
                Button("Story") { model.isShowingSignDetails = true }.frame(minHeight: 44)
                #if DEVELOPER_MENU
                Spacer()
                Button("Align bonus") { isShowingCalibration = true }.frame(minHeight: 44)
                #endif
            }
            .font(.footnote.weight(.medium)).buttonStyle(.plain)
        }
        .foregroundStyle(AppTheme.forest).padding(16)
        .background(AppTheme.ivory.opacity(0.93), in: RoundedRectangle(cornerRadius: 18))
    }

    private var storyControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(model.visitConfirmation, systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.forest)
            if let stop = model.tour.currentStop { NarrationControls(stop: stop) }
            HStack(spacing: 12) {
                Button { model.isShowingSignDetails = true } label: {
                    Label("Stop details", systemImage: "doc.text").frame(maxWidth: .infinity, minHeight: 44)
                }
                Button {
                    model.tour.isSignPresented ? model.closeSign() : model.showSign()
                } label: {
                    Text(model.tour.isSignPresented ? "Hide AR card" : "Show AR card")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .buttonStyle(.plain).font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.forest)
            if let next = model.tour.nextStop {
                Text("Next: \(next.name)").font(.subheadline).foregroundStyle(AppTheme.forest.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            primaryButton(model.tour.nextStop == nil ? "Finish walk" : "Continue to next stop",
                          symbol: "arrow.right", action: model.continueToNextStop)
        }
        .padding(16).background(AppTheme.ivory, in: RoundedRectangle(cornerRadius: 20))
        .environment(\.colorScheme, .light)
    }

    private func primaryButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.headline)
                .frame(maxWidth: .infinity, minHeight: 54).padding(.horizontal, 12)
        }
        .buttonStyle(.plain).foregroundStyle(AppTheme.ivory)
        .background(AppTheme.forest, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Pre-permission explanation and denial handling for the camera (spec §14).
struct CameraExplanationView: View {
    enum State { case requesting, denied, restricted, unsupported }
    let state: State

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: icon)
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(AppTheme.brass)
                Text(title)
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if state == .denied, let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open Settings", destination: url)
                        .font(.headline)
                        .padding(.top, 6)
                }
                Text("The map, walking directions and stop information keep working without the camera.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
            }
            .padding(32)
            .foregroundStyle(.white)
        }
    }

    private var icon: String {
        switch state {
        case .requesting: return "camera.viewfinder"
        case .denied, .restricted: return "camera.slash"
        case .unsupported: return "iphone.slash"
        }
    }

    private var title: String {
        switch state {
        case .requesting: return "Camera access for AR"
        case .denied: return "Camera access is off"
        case .restricted: return "Camera is restricted"
        case .unsupported: return "AR isn't available on this device"
        }
    }

    private var message: String {
        switch state {
        case .requesting:
            return "Cranford Historical AR shows walking arrows and historical signs over the live camera. Allow camera access to enter the AR view."
        case .denied:
            return "Enable the camera for Cranford Historical AR in Settings to use the AR view."
        case .restricted:
            return "Camera use is restricted by a device policy, so the AR view cannot open."
        case .unsupported:
            return "ARKit world tracking needs an iPhone with an A12 chip or newer. The Simulator cannot run AR."
        }
    }
}
