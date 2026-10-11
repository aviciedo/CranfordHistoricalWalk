import Foundation
import RealityKit
import simd

/// Owns the RealityKit scene graph for the tour: one world anchor at the origin, the reusable
/// navigation arrow entity and (from Stage 5) the historical sign. Nothing here knows about GPS;
/// `GeoAnchorManager` decides *where* things go, this type only moves entities.
@MainActor
final class ARAnchorManager {
    private(set) weak var arView: ARView?
    private let rootAnchor = AnchorEntity(world: SIMD3<Float>(repeating: 0))
    let arrows = ARNavigationArrowEntity()

    init() {
        rootAnchor.name = "tour-root"
        rootAnchor.addChild(arrows)
    }

    func attach(to arView: ARView) {
        guard self.arView !== arView else { return }
        self.arView = arView
        if rootAnchor.scene == nil {
            arView.scene.addAnchor(rootAnchor)
        }
    }

    func detach() {
        rootAnchor.removeFromParent()
        arView = nil
    }

    func add(_ entity: Entity) {
        if entity.parent !== rootAnchor { rootAnchor.addChild(entity) }
    }

    func remove(_ entity: Entity) {
        if entity.parent === rootAnchor { entity.removeFromParent() }
    }

    /// Hides everything (used when tracking is lost or the user is at the stop).
    func hideNavigation() {
        arrows.setVisible(false)
    }
}
