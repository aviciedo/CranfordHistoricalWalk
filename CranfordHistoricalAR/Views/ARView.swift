import SwiftUI
import TourCore

/// The AR experience (spec §6): camera, 3D arrows, distance/time, status messaging.
/// Presented full-screen from the tour; shares `TourViewModel` with the map.
struct ARTourView: View {
    @Environment(TourViewModel.self) private var tour
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var model: ARViewModel?

    var body: some View {
        ZStack {
            if let model {
                content(model)
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .task {
            if model == nil {
                model = ARViewModel(tour: tour, provider: dependencies.makeGeoSpatialProvider(), imageLoader: dependencies.imageLoader)
            }
            await model?.requestCameraAccessIfNeeded()
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(false)
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

            ARHUDView(model: model, onClose: { dismiss() })
        }
        .sheet(isPresented: Binding(get: { model.isShowingSignDetails }, set: { model.isShowingSignDetails = $0 })) {
            if let stop = tour.presentedSignStop ?? tour.currentStop {
                HistoricalSignSheet(stop: stop)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

/// Everything drawn over the camera. Kept as plain SwiftUI so it stays legible in sunlight.
struct ARHUDView: View {
    let model: ARViewModel
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            topBar
            if let message = model.statusMessage {
                statusBanner(message)
            }
            Spacer()
            if model.availability == .ready {
                bottomPanel
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .animation(.easeInOut(duration: 0.25), value: model.statusMessage)
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial, in: Circle())
            }
            .accessibilityLabel("Close AR view")

            Spacer()

            if let name = model.destinationName {
                VStack(alignment: .trailing, spacing: 4) {
                    EyebrowText("Next stop", color: .secondary)
                    Text(name)
                        .font(.system(.headline, design: .serif))
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                    HStack(spacing: 12) {
                        Label(model.distanceText, systemImage: "figure.walk")
                        Label(model.timeText, systemImage: "clock")
                    }
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .frame(maxWidth: 260, alignment: .trailing)
            }
        }
    }

    private func statusBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "viewfinder")
                .foregroundStyle(AppTheme.brass)
            Text(message)
                .font(.footnote.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            if case .failed = model.localizationState {
                Button("Retry") { model.retrySession() }
                    .font(.footnote.weight(.semibold))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    @ViewBuilder
    private var bottomPanel: some View {
        if model.tour.phase == .complete {
            tourCompletePanel
        } else if model.tour.isSignPresented {
            signControls
        } else {
            HStack(alignment: .bottom) {
                ARNavigationArrowView(
                    relativeBearing: model.relativeBearingToWaypoint,
                    distanceText: model.distanceText,
                    isProminent: model.shouldShowFallbackIndicator
                )
                Spacer()
                if model.canShowSignManually {
                    Button {
                        model.showSign()
                    } label: {
                        Label("Show sign", systemImage: "signpost.right")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.regularMaterial, in: Capsule())
                    }
                } else if let instruction = model.tour.currentInstruction, !model.tour.isRouteAnEstimate {
                    Text(instruction)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                        .padding(10)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .frame(maxWidth: 200, alignment: .trailing)
                }
            }
        }
    }

    /// The last sign was put away while in AR: hand off to the summary screen (spec §12).
    private var tourCompletePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowText("Tour complete", color: AppTheme.brass)
            Text("You've visited every stop on the walk.")
                .font(.system(.headline, design: .serif))
            Button(action: onClose) {
                Label("See your summary", systemImage: "list.bullet.rectangle")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.heritageGreen, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    /// Shown while the historical sign is up: read the full text, or close it (spec §9 manual close).
    private var signControls: some View {
        VStack(spacing: 10) {
            if let stop = model.tour.presentedSignStop ?? model.tour.currentStop {
                NarrationControls(stop: stop)
            }
            HStack(spacing: 12) {
                Button {
                    model.isShowingSignDetails = true
                } label: {
                    Label("Read", systemImage: "text.book.closed")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.regularMaterial, in: Capsule())
                }
                Button {
                    model.closeSign()
                } label: {
                    Label(model.closeSignTitle, systemImage: model.tour.isCurrentStopVisited ? "arrow.right" : "xmark")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.regularMaterial, in: Capsule())
                }
            }
            .font(.subheadline.weight(.semibold))
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
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
