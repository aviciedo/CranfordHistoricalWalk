import Foundation
import RealityKit
import simd

/// Owns the RealityKit scene graph for the tour: one world anchor at the origin, the reusable
/// navigation entities, historical sign and on-site window bonus. Nothing here knows about GPS;
/// `GeoAnchorManager` decides *where* things go, this type only moves entities.
@MainActor
final class ARAnchorManager {
    private(set) weak var arView: ARView?
    private let rootAnchor = AnchorEntity(world: SIMD3<Float>(repeating: 0))
    let arrows = ARNavigationArrowEntity()
    let sign = ARHistoricalSignEntity()
    let windowBonus = ARHistoricalSignEntity()
    /// World-space parent for the geo sign. The plaque controller re-parents `sign` onto an image anchor.
    var worldRoot: Entity { rootAnchor }

    init() {
        rootAnchor.name = "tour-root"
        rootAnchor.addChild(arrows)
        rootAnchor.addChild(sign)
        rootAnchor.addChild(windowBonus)
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

    func hideAll() {
        hideNavigation()
        sign.dismiss()
        windowBonus.dismiss()
    }
}
