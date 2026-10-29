import Foundation
import RealityKit
import simd
import SwiftUI
import TourCore
import UIKit

/// Shared three-dimensional chevron artwork: opaque white faces, hunter-green frame/sides.
@MainActor
private enum ARChevronArt {
    static let bodyMesh = makeMesh(ARChevronGeometry.body(depth: ARChevronGeometry.bodyDepth), name: "hunter-chevron-body")
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
            body.position.x = Float(index - 1) * ARChevronGeometry.groupSpacing
            let face = ModelEntity(mesh: faceMesh, materials: [white])
            face.scale = SIMD3<Float>(0.95, 0.97, 1)
            face.position.z = 0.006 // Clear the green front face without z-fighting.
            body.addChild(face)
            // Reveal the deep green sides even when the sign is directly ahead.
            body.orientation = simd_quatf(angle: 16 * .pi / 180, axis: [0, 1, 0])
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
                instruction: ARStreetGuidance.Instruction, timestamp: TimeInterval, arView: ARView? = nil) {
        guard isShowing else { return }
        let candidate = SIMD3<Double>(Double(ground.x), Double(ground.y), Double(ground.z))
        let cameraPoint = SIMD3<Double>(Double(camera.x), Double(camera.y), Double(camera.z))
        guard let pinned = anchorState.update(candidate: candidate, camera: cameraPoint,
                                              instruction: instruction, timestamp: timestamp) else {
            holder.isEnabled = false
            return
        }
        let range = hypot(pinned.position.x - cameraPoint.x, pinned.position.z - cameraPoint.z)
        guard range >= 2, range <= 20 else { holder.isEnabled = false; return }
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
        if let arView {
            // Fit at placement time only: never resize or restart animations on camera frames.
            let bounds = heading.visualBounds(relativeTo: nil)
            var projected: [CGPoint] = []
            for x in [bounds.min.x, bounds.max.x] {
                for y in [bounds.min.y, bounds.max.y] {
                    for z in [bounds.min.z, bounds.max.z] {
                        if let point = arView.project([x, y, z]), point.x.isFinite, point.y.isFinite {
                            projected.append(point)
                        }
                    }
                }
            }
            if projected.count == 8 {
                let width = (projected.map(\.x).max() ?? 0) - (projected.map(\.x).min() ?? 0)
                let height = (projected.map(\.y).max() ?? 0) - (projected.map(\.y).min() ?? 0)
                let fit = Float(ARChevronGeometry.displayFitScale(projectedWidth: Double(width),
                    projectedHeight: Double(height), viewportWidth: Double(arView.bounds.width),
                    viewportHeight: Double(arView.bounds.height)))
                heading.scale = SIMD3<Float>(repeating: fit)
                let fitted = heading.visualBounds(relativeTo: holder)
                holder.position.y = Float(pinned.position.y) + Float(ARStreetGuidance.minimumClearanceMeters) - fitted.min.y
            }
        }
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
