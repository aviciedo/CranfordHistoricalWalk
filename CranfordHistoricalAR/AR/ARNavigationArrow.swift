import Foundation
import RealityKit
import simd
import SwiftUI
import TourCore
import UIKit

/// Shared three-dimensional chevron artwork: opaque white faces, hunter-green frame/sides.
@MainActor
private enum ARChevronArt {
    static let bodyMesh = makeMesh(ARChevronGeometry.body(depth: 0.32), name: "hunter-chevron-body")
    static let faceMesh = makeMesh(ARChevronGeometry.front(), name: "white-chevron-face")

    static func makeMesh(_ data: ARChevronGeometry.Mesh, name: String) -> MeshResource? {
        var descriptor = MeshDescriptor(name: name)
        descriptor.positions = MeshBuffers.Positions(data.positions)
        descriptor.normals = MeshBuffers.Normals(data.normals)
        descriptor.primitives = .triangles(data.indices)
        return try? MeshResource.generate(from: [descriptor])
    }

    static func makeGroup() -> Entity {
        let group = Entity()
        guard let bodyMesh, let faceMesh else { return group }
        let green = SimpleMaterial(color: UIColor(AppTheme.forest),
                                   roughness: 0.7, isMetallic: false)
        let white = UnlitMaterial(color: .white)
        for index in 0..<3 {
            let body = ModelEntity(mesh: bodyMesh, materials: [green])
            body.position.x = Float(index - 1) * 1.08
            let face = ModelEntity(mesh: faceMesh, materials: [white])
            face.scale = SIMD3<Float>(0.91, 0.94, 1)
            face.position.z = 0.006 // Clear the green front face without z-fighting.
            body.addChild(face)
            group.addChild(body)
        }
        group.scale = SIMD3<Float>(repeating: Float(ARStreetGuidance.chevronScale))
        return group
    }
}

/// A fixed, upright 3D road sign. The whole pose is applied only on a new placement;
/// camera-facing billboards and continuously restarted rotation animations are deliberately absent.
@MainActor
final class ARNavigationArrowEntity: Entity {
    static let firstArrowDistance: Float = Float(ARStreetGuidance.lookAheadMeters)
    static let heightBelowCamera: Float = 1.15
    private let holder = Entity()
    private let heading = Entity()
    private var anchorState = ARStreetGuidance.AnchorState()
    private var renderedPlacement: ARStreetGuidance.Placement?
    private(set) var isShowing = false
    var canRender: Bool { ARChevronArt.bodyMesh != nil && ARChevronArt.faceMesh != nil }
    var guidancePosition: SIMD3<Float>? {
        holder.isEnabled && renderedPlacement != nil ? holder.position(relativeTo: nil) : nil
    }

    required init() {
        super.init()
        heading.addChild(ARChevronArt.makeGroup())
        holder.addChild(heading)
        holder.isEnabled = false
        addChild(holder)
    }

    func update(ground: SIMD3<Float>, camera: SIMD3<Float>,
                instruction: ARStreetGuidance.Instruction, timestamp: TimeInterval) {
        guard isShowing else { return }
        let candidate = SIMD3<Double>(Double(ground.x), Double(ground.y), Double(ground.z))
        let cameraPoint = SIMD3<Double>(Double(camera.x), Double(camera.y), Double(camera.z))
        guard let pinned = anchorState.update(candidate: candidate, camera: cameraPoint,
                                              instruction: instruction, timestamp: timestamp) else {
            holder.isEnabled = false
            return
        }
        guard ARArrowCoach.keepsPinnedSignVisible(position: pinned.position, camera: cameraPoint) else {
            holder.isEnabled = false
            return
        }
        holder.isEnabled = true
        guard renderedPlacement != pinned else { return }
        holder.stopAllAnimations(recursive: true)
        let facing = simd_quatf(angle: Float(pinned.facingYawRadians), axis: [0, 1, 0])
        let degrees = ARChevronGeometry.rotationDegrees(direction: pinned.instruction.direction)
        let rotation = simd_quatf(angle: Float(degrees * Double.pi / 180), axis: [0, 0, 1])
        heading.transform = Transform(scale: .one, rotation: rotation, translation: .zero)
        let arrowBounds = heading.visualBounds(relativeTo: holder)
        // Up/diagonal signs are taller than left/right signs: keep every orientation above ground.
        let lift = Float(ARStreetGuidance.minimumClearanceMeters) - arrowBounds.min.y
        let position = SIMD3<Float>(Float(pinned.position.x), Float(pinned.position.y) + lift, Float(pinned.position.z))
        holder.transform = Transform(scale: .one, rotation: facing, translation: position)
        renderedPlacement = pinned
    }

    /// Transient lost ground/tracking hides the sign without throwing away its world pose.
    func setVisible(_ visible: Bool) {
        isShowing = visible
        holder.isEnabled = visible && renderedPlacement != nil
    }

    /// Session resets, provider changes and a genuinely new destination need a new world pose.
    func resetAnchor() {
        anchorState.reset()
        renderedPlacement = nil
        holder.stopAllAnimations(recursive: true)
        holder.isEnabled = false
    }
}
