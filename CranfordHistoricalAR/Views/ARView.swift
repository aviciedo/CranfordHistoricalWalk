import SwiftUI
import CoreMotion
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
    @State private var showScanInstruction = true
    @State private var motionManager = CMMotionManager()
    @State private var phoneWasRaised = false
    @State private var horizontalSince: Date?
    @State private var isLeavingAR = false

    var body: some View {
        ZStack {
            if awaitingGeospatialConsent {
                VStack(spacing: 0) {
                    ScreenReturnBar(onBack: returnToMap).padding(16)
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
                }
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
        .onChange(of: navigation.homeReturnID) { _, _ in
            model?.isShowingSignDetails = false
            model?.isShowingBonusPreview = false
            returnToMap()
        }
    }

    private func returnToMap() {
        guard !isLeavingAR else { return }
        isLeavingAR = true
        motionManager.stopDeviceMotionUpdates()
        dismiss()
    }

    /// Requires an upright/tilted phone first to avoid exiting as AR opens.
    private func beginPhoneOrientationMonitoring() {
        guard motionManager.isDeviceMotionAvailable, !motionManager.isDeviceMotionActive else { return }
        motionManager.deviceMotionUpdateInterval = 0.2
        motionManager.startDeviceMotionUpdates(to: .main) { motion, error in
            guard error == nil, let gravity = motion?.gravity, !isLeavingAR else { return }
            let screenUpHorizontal = gravity.z < -0.92
                && abs(gravity.x) < 0.35 && abs(gravity.y) < 0.35
            if abs(gravity.z) < 0.70 {
                phoneWasRaised = true
                horizontalSince = nil
            } else if phoneWasRaised && screenUpHorizontal {
                if let since = horizontalSince {
                    if Date().timeIntervalSince(since) >= 2.0 { returnToMap() }
                } else { horizontalSince = Date() }
            } else { horizontalSince = nil }
        }
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

            if model.isPlaqueScanner {
                PlaqueScannerHUD(model: model, onClose: returnToMap)
            } else {
                ARHUDView(model: model, onClose: returnToMap)
            }

            if !model.isPlaqueScanner, model.availability == .ready && showScanInstruction {
                // Live camera stays active behind this subtle scrim.
                Color.gray.opacity(0.28).ignoresSafeArea().allowsHitTesting(false)
                VStack(spacing: 17) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 46, weight: .ultraLight))
                    Text("Scan your surroundings")
                        .font(.system(.title2, design: .serif).weight(.semibold))
                    Text("Slowly move your iPhone from side to side and scan the area around you to help AR recognize your surroundings.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        withAnimation(.easeOut(duration: 0.25)) { showScanInstruction = false }
                    } label: {
                        Text("Start exploring")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(AppTheme.forest, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(AppTheme.ivory)
                    }
                    .buttonStyle(.plain)
                    Text("Hold the phone flat, screen facing up, for 2 seconds to return to the map.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppTheme.secondaryInk)
                }
                .foregroundStyle(AppTheme.forest)
                .padding(24)
                .frame(maxWidth: 340)
                .background(AppTheme.ivory.opacity(0.96), in: RoundedRectangle(cornerRadius: 22))
                .padding(.horizontal, 20)
            }
        }
        .onAppear { beginPhoneOrientationMonitoring() }
        .onDisappear {
            motionManager.stopDeviceMotionUpdates()
            tour.endARDiscoverySession()
        }
        .sheet(isPresented: Binding(get: { model.isShowingSignDetails }, set: { model.isShowingSignDetails = $0 })) {
            if let stop = tour.arStop {
                HistoricalSignSheet(stop: stop,
                                    onStartDiscovery: model.startPlaqueDiscovery)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: Binding(get: { model.isShowingBonusPreview }, set: { model.isShowingBonusPreview = $0 })) {
            if let stop = tour.arStop { OnSiteBonusPreview(stop: stop).presentationDetents([.large]) }
        }
    }
}

/// A quiet camera frame with one direction surface and one on-site action.
struct ARHUDView: View {
    @Environment(AppNavigation.self) private var navigation
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
                if let hint = model.plaqueHint, !model.tour.isARStopVisited {
                    notice(hint, symbol: "viewfinder.circle")
                }
                Spacer(minLength: 8)
                if model.availability == .ready, model.isShowingWalkingOrientation,
                   !model.isMarkerAvailable, !model.tour.isARStopVisited, model.tour.phase == .inProgress,
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
        .onChange(of: navigation.homeReturnID) { _, _ in isShowingCalibration = false }
        #endif
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScreenReturnBar(onBack: onClose)
            if let name = model.destinationName {
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.tour.discovery.hasVerifiedPlaque ? "Bonus found" :
                         (model.tour.isPlaqueDiscoveryStop && model.tour.discovery.hasArrived ? "At this stop" : "Next stop"))
                        .font(.caption.weight(.medium))
                    Text(name).font(.system(.headline, design: .serif))
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    if !model.tour.isARStopVisited && !(model.tour.isPlaqueDiscoveryStop && model.tour.discovery.hasArrived) {
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
        if model.tour.phase == .complete && model.tour.arStop == nil {
            VStack(alignment: .leading, spacing: 14) {
                Text("Walk complete").font(.system(.title2, design: .serif).weight(.semibold))
                Text("You’ve reached the end of your itinerary. Your stories and bonuses remain available.").font(.subheadline)
                primaryButton("See your summary", symbol: "checkmark.circle", action: onClose)
            }
            .foregroundStyle(AppTheme.forest).padding(18)
            .background(AppTheme.ivory, in: RoundedRectangle(cornerRadius: 20))
        } else if model.tour.isPlaqueDiscoveryStop && (model.tour.discovery.hasArrived || model.tour.discovery.stage == .searching || model.tour.discovery.hasVerifiedPlaque) {
            discoveryControls
        } else if model.tour.isARStopVisited {
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
            } else {
                primaryButton("Find the plaque in AR", symbol: "viewfinder", action: model.startPlaqueDiscovery)
            }
            if model.tour.canContinueARStop {
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
    var isPlaqueScanner = false

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
                Text(isPlaqueScanner ? "Stories, photographs and audio remain available without the camera." : "The map, walking directions and stop information keep working without the camera.")
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
        case .requesting: return isPlaqueScanner ? "Camera access for plaque discovery" : "Camera access for AR"
        case .denied: return "Camera access is off"
        case .restricted: return "Camera is restricted"
        case .unsupported: return "AR isn't available on this device"
        }
    }

    private var message: String {
        switch state {
        case .requesting:
            return isPlaqueScanner ? "Allow camera access to recognize the plaque and unlock its optional bonus." : "Cranford Historical AR shows walking arrows and historical signs over the live camera. Allow camera access to enter the AR view."
        case .denied:
            return "Enable the camera for Cranford Historical AR in Settings to use the AR view."
        case .restricted:
            return "Camera use is restricted by a device policy, so the AR view cannot open."
        case .unsupported:
            return "ARKit world tracking needs an iPhone with an A12 chip or newer. The Simulator cannot run AR."
        }
    }
}

/// Direct, camera-only plaque entry. No walking start, location request or geospatial consent.
struct PlaqueScannerView: View {
    @Environment(AppNavigation.self) private var navigation
    @Environment(TourViewModel.self) private var tour
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    let stopID: String
    @State private var model: ARViewModel?
    @State private var unavailable = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let model {
                switch model.availability {
                case .ready: ARViewContainer(viewModel: model).ignoresSafeArea()
                case .awaitingCameraPermission: CameraExplanationView(state: .requesting, isPlaqueScanner: true)
                case .cameraDenied: CameraExplanationView(state: .denied, isPlaqueScanner: true)
                case .cameraRestricted: CameraExplanationView(state: .restricted, isPlaqueScanner: true)
                case .unsupportedDevice: CameraExplanationView(state: .unsupported, isPlaqueScanner: true)
                }
                PlaqueScannerHUD(model: model, onClose: { dismiss() })
            } else {
                VStack {
                    VStack(alignment: .leading, spacing: 8) {
                        ScreenReturnBar(onBack: { dismiss() })
                        Text(tour.stop(withID: stopID)?.name ?? "Plaque discovery")
                            .font(.system(.headline, design: .serif))
                    }
                    .padding(16).foregroundStyle(AppTheme.forest).background(AppTheme.ivory)
                    Spacer()
                    if unavailable {
                        Text("Plaque discovery is unavailable for this stop.")
                            .padding(20).foregroundStyle(.white)
                    }
                    Spacer()
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            guard model == nil else { return }
            guard tour.preparePlaqueScanner(stopID: stopID) else { unavailable = true; return }
            let scanner = ARViewModel(tour: tour,
                provider: CoreLocationGeoSpatialProvider(hasCompass: false),
                imageLoader: dependencies.imageLoader, narrationPlayer: dependencies.narrationPlayer,
                isPlaqueScanner: true)
            model = scanner
            await scanner.requestCameraAccessIfNeeded()
        }
        .onDisappear { tour.endARDiscoverySession() }
        .onChange(of: navigation.homeReturnID) { _, _ in
            model?.isShowingBonusPreview = false
            dismiss()
        }
        .sheet(isPresented: Binding(get: { model?.isShowingBonusPreview ?? false },
                                   set: { model?.isShowingBonusPreview = $0 })) {
            if let stop = tour.arStop { OnSiteBonusPreview(stop: stop) }
        }
    }
}

/// The scanner has one instruction and no route distance, Continue action or surroundings tutorial.
private struct PlaqueScannerHUD: View {
    let model: ARViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ScreenReturnBar(onBack: onClose)
            Text(model.destinationName ?? "Plaque discovery")
                .font(.system(.headline, design: .serif))
                .fixedSize(horizontal: false, vertical: true)
                .padding(14).background(AppTheme.ivory, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityIdentifier("scanner.stopName")
            Spacer(minLength: 12)
            if model.availability == .ready {
                VStack(alignment: .leading, spacing: 12) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(model.scannerInstruction(at: context.date))
                            .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    }
                    if model.tour.discovery.hasVerifiedPlaque {
                        Label(model.tour.discovery.isPracticeUnlock ? "Practice bonus · Not saved" : "Bonus found",
                              systemImage: "seal.fill")
                            .font(.subheadline.weight(.medium))
                        Button(action: model.openScannerBonus) {
                            Text("View the bonus").font(.headline).frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                    }
                    Button(action: model.retryPlaqueScanner) {
                        Label("Retry", systemImage: "arrow.clockwise").frame(minHeight: 44)
                    }
                    .buttonStyle(.plain).font(.subheadline.weight(.medium))
                    .accessibilityHint("Restarts plaque scanning without changing your walk or saved activities")
                    .accessibilityIdentifier("scanner.retry")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16).background(AppTheme.ivory, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .foregroundStyle(AppTheme.forest)
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}
