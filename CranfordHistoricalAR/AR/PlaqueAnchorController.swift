import ARKit
import Foundation
import RealityKit
import simd
import TourCore

/// Loads the `PlaqueAnchors` reference-image group and parents the tour card to a detected
/// `ARImageAnchor`. Failures (missing group, Simulator, lost track) never throw — callers fall
/// back to the geo-anchored sign.
@MainActor
final class PlaqueAnchorController {
    private(set) weak var arView: ARView?
    private var imageAnchorEntity: AnchorEntity?
    private(set) var trackedAnchor: ARImageAnchor?
    private(set) var trackedImageName: String?

    static var resourceGroupName: String { SignPlacementPolicy.resourceGroupName }

    static func loadReferenceImages(in bundle: Bundle = .main) -> Set<ARReferenceImage> {
        ARReferenceImage.referenceImages(inGroupNamed: resourceGroupName, bundle: bundle) ?? []
    }

    static func isAvailable(in bundle: Bundle = .main) -> Bool {
        ARWorldTrackingConfiguration.isSupported && !loadReferenceImages(in: bundle).isEmpty
    }

    /// World-tracking configuration that also looks for the bundled plates. Returns false when
    /// the group is empty so the caller can skip `detectionImages` entirely.
    @discardableResult
    static func applyDetectionImages(to configuration: ARWorldTrackingConfiguration, bundle: Bundle = .main) -> Bool {
        let images = loadReferenceImages(in: bundle)
        guard !images.isEmpty else { return false }
        configuration.detectionImages = images
        configuration.maximumNumberOfTrackedImages = 1
        configuration.automaticImageScaleEstimationEnabled = true
        return true
    }

    func attach(to arView: ARView) {
        self.arView = arView
    }

    func observe(_ imageAnchor: ARImageAnchor) {
        trackedAnchor = imageAnchor
        trackedImageName = imageAnchor.referenceImage.name
    }

    func detach() {
        unbind()
        arView = nil
    }

    /// Parents `sign` to the image so the card rides with the physical plate.
    func bind(imageAnchor: ARImageAnchor, sign: ARHistoricalSignEntity, offset: PlaqueCardOffset) {
        guard let arView else { return }
        if trackedAnchor?.identifier != imageAnchor.identifier || imageAnchorEntity == nil {
            imageAnchorEntity?.removeFromParent()
            let entity = AnchorEntity(anchor: imageAnchor)
            entity.name = "plaque-image-anchor"
            arView.scene.addAnchor(entity)
            imageAnchorEntity = entity
        }
        trackedAnchor = imageAnchor
        trackedImageName = imageAnchor.referenceImage.name
        if sign.parent !== imageAnchorEntity {
            sign.removeFromParent()
            imageAnchorEntity?.addChild(sign)
        }
        let local = offset.imageLocalTranslation
        sign.position = SIMD3<Float>(Float(local.x), Float(local.y), Float(local.z))
        // Plane faces +Z; rotate so +Z maps to image +Y (out of the plate toward the camera).
        // After that rotation, card-up (+Y) maps to image −Z (up the wall).
        sign.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
    }

    func matches(_ imageAnchor: ARImageAnchor, expectedName: String?) -> Bool {
        guard let expectedName, !expectedName.isEmpty else { return false }
        return imageAnchor.referenceImage.name == expectedName
    }

    func unbind(sign: ARHistoricalSignEntity? = nil, returningTo worldParent: Entity? = nil) {
        if let sign, let worldParent, sign.parent !== worldParent {
            sign.removeFromParent()
            worldParent.addChild(sign)
            sign.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
        }
        imageAnchorEntity?.removeFromParent()
        imageAnchorEntity = nil
        trackedAnchor = nil
        trackedImageName = nil
    }
}
