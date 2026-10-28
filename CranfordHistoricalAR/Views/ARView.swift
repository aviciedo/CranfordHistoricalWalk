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
    @State private var motionManager = CMMotionManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var phoneDown = PhoneDownReturnPolicy()
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
        .holdsWalkingContext()
        .onChange(of: scenePhase) { _, phase in
            phoneDown.reset()
            if phase != .active { motionManager.stopDeviceMotionUpdates() }
            else if model != nil && !isLeavingAR { beginPhoneOrientationMonitoring() }
        }
        .onChange(of: tour.pendingPassportStampStopID) { _, id in
            if id != nil {
                model?.isShowingSignDetails = false
                returnToMap()
            }
        }
        .onChange(of: navigation.homeReturnID) { _, _ in
            model?.isShowingSignDetails = false
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
        guard scenePhase == .active, !isLeavingAR, motionManager.isDeviceMotionAvailable, !motionManager.isDeviceMotionActive else { return }
        motionManager.deviceMotionUpdateInterval = 0.2
        motionManager.startDeviceMotionUpdates(to: .main) { motion, error in
            guard error == nil, let gravity = motion?.gravity, !isLeavingAR else { return }
            if phoneDown.update(x: gravity.x, y: gravity.y, z: gravity.z,
                timestamp: motion?.timestamp ?? 0,
                suspended: scenePhase != .active || model?.isShowingSignDetails == true) {
                returnToMap()
            }
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
        let isShowingIntroduction = !model.isPlaqueScanner && model.availability == .ready
            && !model.geoAnchors.hasDetectedGround && !model.geoAnchors.hasPlacedNavigation
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

            if isShowingIntroduction {
                Color.gray.opacity(0.28).ignoresSafeArea().allowsHitTesting(false)
            }
            ARHUDView(model: model, onClose: returnToMap)
        }
        .onAppear { beginPhoneOrientationMonitoring() }
        .onDisappear {
            motionManager.stopDeviceMotionUpdates()
            tour.endARDiscoverySession()
        }

    }
}

/// Context-specific, automatically dismissed once real ground is detected.
private struct ARScanIntroduction: View {
    var body: some View {
        ViewThatFits(in: .vertical) {
            VStack(spacing: 10) {
                ScanPhoneMotion().scaleEffect(0.65).frame(height: 72)
                instruction
            }
            instruction
        }
        .foregroundStyle(AppTheme.forest)
        .padding(16)
        .background(AppTheme.ivory, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 24)
        .accessibilityIdentifier("ar.scanIntroduction")
    }

    private var instruction: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Find the ground for directions")
                .font(.headline).accessibilityAddTraits(.isHeader)
            Text("Pause somewhere safe. Tilt your phone slightly down and move it slowly side to side.")
                .font(.subheadline).fixedSize(horizontal: false, vertical: true)
            Text("Lower it flat for 2 seconds to return to the map.")
                .font(.footnote).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Native symbols keep the movement cue simple and readable. Reduce Motion leaves it still.
private struct ScanPhoneMotion: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || scenePhase != .active)) { context in
            let phase = reduceMotion ? 0 : sin(context.date.timeIntervalSinceReferenceDate * Double.pi / 2)
            VStack(spacing: 8) {
                Image(systemName: "iphone.gen3")
                    .font(.system(size: 62, weight: .light))
                    .rotationEffect(.degrees(phase * 8))
                    .offset(x: CGFloat(phase) * 20)
                    .frame(width: 120, height: 78)
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 20, weight: .medium))
            }
        }
        .frame(height: 112)
        .accessibilityHidden(true) // The instruction directly beneath explains the same movement.
    }
}

/// A quiet camera frame with one direction surface and one on-site action.
struct ARHUDView: View {
    let model: ARViewModel
    var onClose: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ViewThatFits(in: .vertical) {
                hudContent(height: geometry.size.height)
                ScrollView { hudContent(height: geometry.size.height) }
                    .scrollBounceBehavior(.basedOnSize)
            }
        }
    }

    private func hudContent(height: CGFloat) -> some View {
        VStack(spacing: 10) {
                topBar
                if let message = model.statusMessage { notice(message, symbol: "viewfinder") }
                if model.availability == .ready && !model.geoAnchors.hasDetectedGround && !model.geoAnchors.hasPlacedNavigation {
                    ARScanIntroduction()
                }
                Spacer(minLength: 8)
                if model.availability == .ready {
                    ViewThatFits(in: .vertical) {
                        bottomPanel.fixedSize(horizontal: false, vertical: true)
                        ScrollView { bottomPanel }
                            .scrollBounceBehavior(.basedOnSize)
                    }
                    .frame(maxHeight: height * 0.58, alignment: .bottom)
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 12)
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScreenReturnBar(onBack: onClose)
            if let name = model.destinationName {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(name).font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Text(model.timeText).font(.caption.weight(.medium)).monospacedDigit()
                        .fixedSize()
                }
                .foregroundStyle(.white).padding(.horizontal, 14).padding(.vertical, 10)
                .background(AppTheme.forest.opacity(0.90), in: RoundedRectangle(cornerRadius: 14))
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
                Text("You’ve reached the end of your itinerary. Your stories and passport stamps remain available.").font(.subheadline)
                primaryButton("See your summary", symbol: "checkmark.circle", action: onClose)
            }
            .foregroundStyle(AppTheme.forest).padding(18)
            .background(AppTheme.ivory, in: RoundedRectangle(cornerRadius: 20))
        } else {
            ARNavigationArrowView(detail: model.guidanceDetail,
                                  cue: model.walkingCue,
                                  isApproximate: model.isGuidanceApproximate,
                                  needsGroundScan: model.geoAnchors.isTrackingReady && !model.geoAnchors.hasDetectedGround && !model.geoAnchors.hasPlacedNavigation,
                                  needsOrientation: model.isShowingWalkingOrientation && abs(model.relativeBearingToWaypoint ?? 0) > 50,
                                  nextStopName: model.tour.nextStop?.name,
                                  onContinue: model.tour.isCurrentVisitConfirmed ? model.continueToNextStop : nil)
        }
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
            return isPlaqueScanner ? "Allow camera access to recognize the plaque and collect its passport stamp." : "Cranford Historical AR shows walking arrows and historical signs over the live camera. Allow camera access to enter the AR view."
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
        .holdsWalkingContext()
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
        .onChange(of: tour.pendingPassportStampStopID) { _, id in
            if id != nil { dismiss() }
        }
        .onChange(of: navigation.homeReturnID) { _, _ in
            dismiss()
        }

    }
}

/// The scanner has one instruction and no route distance, Continue action or surroundings tutorial.
private struct PlaqueScannerHUD: View {
    let model: ARViewModel
    let onClose: () -> Void

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }.scrollBounceBehavior(.basedOnSize)
        }
    }

    private var content: some View {
        VStack(spacing: 12) {
            ScreenReturnBar(onBack: onClose)
            HStack(alignment: .center, spacing: 12) {
                if let reference = model.tour.arStop?.plaque?.referenceImageName {
                    Image(reference + "-target").resizable().scaledToFit()
                        .frame(width: 72, height: 72)
                        .accessibilityLabel("Reference photograph of the plaque to find")
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Frame this plaque").font(.headline)
                    Text(model.destinationName ?? "Plaque discovery").font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14).background(AppTheme.ivory, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityIdentifier("scanner.stopName")
            Spacer(minLength: 12)
            if model.availability == .ready {
                VStack(alignment: .leading, spacing: 12) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(model.scannerPhaseTitle).font(.headline)
                            Text(model.scannerInstruction(at: context.date))
                                .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if model.tour.discovery.hasVerifiedPlaque {
                        Label(model.scannerStampResult,
                              systemImage: "seal.fill")
                            .font(.subheadline.weight(.medium))
                    }
                    Button(action: model.retryPlaqueScanner) {
                        Label("Retry", systemImage: "arrow.clockwise").frame(minHeight: 44)
                    }
                    .buttonStyle(.plain).font(.subheadline.weight(.medium))
                    .accessibilityHint("Restarts plaque scanning without changing your walk or saved activities")
                    .accessibilityIdentifier("scanner.retry")
                    Button("Return to story", action: onClose)
                        .buttonStyle(.plain).font(.subheadline.weight(.medium)).frame(minHeight: 44)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16).background(AppTheme.ivory, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .foregroundStyle(AppTheme.forest)
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}
