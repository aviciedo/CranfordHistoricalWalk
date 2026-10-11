import ARKit
import RealityKit
import SwiftUI

/// Hosts RealityKit's `ARView` (a UIKit view, required by the framework) and forwards session
/// events to `ARViewModel`. No tour logic lives here.
struct ARViewContainer: UIViewRepresentable {
    let viewModel: ARViewModel

    func makeCoordinator() -> Coordinator { Coordinator(viewModel: viewModel) }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        arView.session.delegate = context.coordinator
        arView.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disablePersonOcclusion, .disableHDR, .disableFaceMesh]
        arView.environment.sceneUnderstanding.options = []
        arView.automaticallyConfigureSession = false
        arView.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:))))
        context.coordinator.arView = arView
        viewModel.arViewDidLoad(arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        uiView.session.pause()
        coordinator.viewModel.arViewWillUnload()
    }

    @MainActor
    final class Coordinator: NSObject, ARSessionDelegate {
        let viewModel: ARViewModel
        weak var arView: ARView?

        init(viewModel: ARViewModel) {
            self.viewModel = viewModel
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView else { return }
            let point = recognizer.location(in: arView)
            let entity = arView.entity(at: point)
            viewModel.didTap(entity: entity, at: point)
        }

        // ARSession delivers on the main queue by default (`delegateQueue == nil`), so it is safe
        // to assume main-actor isolation instead of hopping asynchronously for every frame.

        nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
            let transform = frame.camera.transform
            let tracking = frame.camera.trackingState
            let timestamp = frame.timestamp
            MainActor.assumeIsolated {
                viewModel.frameDidUpdate(cameraTransform: transform, trackingState: tracking, timestamp: timestamp)
            }
        }

        nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            let state = camera.trackingState
            MainActor.assumeIsolated { viewModel.trackingStateDidChange(state) }
        }

        nonisolated func sessionWasInterrupted(_ session: ARSession) {
            MainActor.assumeIsolated { viewModel.sessionWasInterrupted() }
        }

        nonisolated func sessionInterruptionEnded(_ session: ARSession) {
            MainActor.assumeIsolated { viewModel.sessionInterruptionEnded() }
        }

        nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
            let message = error.localizedDescription
            let code = (error as? ARError)?.code
            MainActor.assumeIsolated { viewModel.sessionDidFail(message: message, code: code) }
        }

        nonisolated func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
            true
        }
    }
}
