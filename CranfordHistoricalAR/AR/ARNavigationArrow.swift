import Foundation
import RealityKit
import simd
import UIKit

/// A short trail of flat 3D arrows laid on the ground ahead of the user (spec §7).
/// Entities are created once and reused; only transforms and materials change.
@MainActor
final class ARNavigationArrowEntity: Entity {
    static let arrowCount = 4
    static let firstArrowDistance: Float = 1.6
    static let arrowSpacing: Float = 1.25
    /// Meters below the camera (phone held at chest/eye height ≈ 1.3–1.5 m above ground).
    static let heightBelowCamera: Float = 1.15

    /// Positioned holders; each has a single mesh child that carries the pulse animation.
    private var holders: [Entity] = []
    private var lastBase: SIMD3<Float>?
    private var lastDirection: SIMD3<Float>?
    private var lastLayoutTime: TimeInterval = 0
    private(set) var isShowing = false

    required init() {
        super.init()
        buildArrows()
    }

    private func buildArrows() {
        guard let mesh = ARNavigationArrowEntity.makeArrowMesh() else { return }
        for index in 0..<ARNavigationArrowEntity.arrowCount {
            // Ivory with a forest rim stays legible on both dark asphalt and pale paths.
            var material = UnlitMaterial(color: UIColor(red: 248 / 255, green: 246 / 255, blue: 238 / 255, alpha: 1))
            material.blending = .transparent(opacity: .init(floatLiteral: 0.98 - Float(index) * 0.08))
            let arrow = ModelEntity(mesh: mesh, materials: [material])
            arrow.name = "arrow-mesh-\(index)"
            let rim = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: UIColor(red: 46 / 255, green: 58 / 255, blue: 47 / 255, alpha: 1))])
            rim.scale = SIMD3<Float>(1.16, 1, 1.16)
            rim.position.y = -0.006
            arrow.addChild(rim)
            let holder = Entity()
            holder.name = "arrow-\(index)"
            holder.addChild(arrow)
            holder.isEnabled = false
            addChild(holder)
            holders.append(holder)
            startPulse(on: arrow, phase: index)
        }
    }

    /// Gentle breathing so arrows read as live guidance without being distracting (spec §8 restraint).
    /// The animation binds the child's full transform, which is why position/rotation live on the holder.
    private func startPulse(on mesh: ModelEntity, phase: Int) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let from = Transform(scale: SIMD3<Float>(repeating: 0.96), rotation: simd_quatf(angle: 0, axis: [0, 1, 0]), translation: .zero)
        let to = Transform(scale: SIMD3<Float>(repeating: 1.04), rotation: simd_quatf(angle: 0, axis: [0, 1, 0]), translation: .zero)
        let pulse = FromToByAnimation<Transform>(
            name: "pulse",
            from: from,
            to: to,
            duration: 1.1,
            timing: .easeInOut,
            isAdditive: false,
            bindTarget: .transform,
            repeatMode: .autoReverse,
            delay: Double(phase) * 0.15
        )
        if let resource = try? AnimationResource.generate(with: pulse) {
            mesh.playAnimation(resource.repeat(), transitionDuration: 0.2, startsPaused: false)
        }
    }

    /// Lays the arrows from `base` (the user's current ground position) along `direction` (unit, XZ).
    /// Arrows stay fixed in the world until the user walks past the first one or the direction
    /// changes meaningfully, so they feel anchored rather than glued to the screen.
    func update(base: SIMD3<Float>, direction: SIMD3<Float>, now: TimeInterval, force: Bool = false, maximumDistance: Float? = nil) {
        let dir = normalizedXZ(direction)
        guard dir != .zero else { return }

        // The trail ends at a visible marker instead of pointing through its wall/door.
        for (index, holder) in holders.enumerated() {
            let distance = Self.firstArrowDistance + Float(index) * Self.arrowSpacing
            holder.isEnabled = isShowing && (maximumDistance.map { distance < $0 - 0.25 } ?? true)
        }

        var needsLayout = force || lastBase == nil || lastDirection == nil
        if !needsLayout, let lastBase, let lastDirection {
            let along = simd_dot(base - lastBase, lastDirection)
            let angle = acos(max(-1, min(1, simd_dot(dir, lastDirection)))) * 180 / .pi
            let lateral = simd_length((base - lastBase) - along * lastDirection)
            needsLayout = along > ARNavigationArrowEntity.arrowSpacing
                || angle > 14
                || lateral > 1.5
                || now - lastLayoutTime > 4
        }
        guard needsLayout else { return }
        lastBase = base
        lastDirection = dir
        lastLayoutTime = now

        // Mesh points toward −Z; rotating by −yaw about +Y maps −Z onto `dir`.
        let yaw = atan2(dir.x, -dir.z)
        let rotation = simd_quatf(angle: -yaw, axis: [0, 1, 0])
        for (index, holder) in holders.enumerated() {
            let distance = ARNavigationArrowEntity.firstArrowDistance + Float(index) * ARNavigationArrowEntity.arrowSpacing
            let target = Transform(scale: .one, rotation: rotation, translation: base + dir * distance)
            if holder.isEnabled && isShowing && !force {
                holder.move(to: target, relativeTo: self, duration: 0.35, timingFunction: .easeInOut)
            } else {
                holder.transform = target
            }
        }
    }

    func setVisible(_ visible: Bool) {
        guard visible != isShowing else { return }
        isShowing = visible
        for holder in holders { holder.isEnabled = visible }
        if !visible { lastBase = nil; lastDirection = nil }
    }

    private func normalizedXZ(_ v: SIMD3<Float>) -> SIMD3<Float> {
        let flat = SIMD3<Float>(v.x, 0, v.z)
        let length = simd_length(flat)
        return length > 0.0001 ? flat / length : .zero
    }

    // MARK: Mesh

    /// Flat chevron arrow in the XZ plane pointing toward −Z, ~0.55 m long, double-sided.
    static func makeArrowMesh() -> MeshResource? {
        let L: Float = 0.55, W: Float = 0.42, shaftW: Float = 0.16, headL: Float = 0.26
        // Outline (counter-clockwise seen from above, +Y up). Tip at −Z.
        let outline: [SIMD2<Float>] = [
            SIMD2(0, -L / 2),                      // tip
            SIMD2(W / 2, -L / 2 + headL),           // right head corner
            SIMD2(shaftW / 2, -L / 2 + headL),      // right shaft top
            SIMD2(shaftW / 2, L / 2),               // right shaft bottom
            SIMD2(-shaftW / 2, L / 2),              // left shaft bottom
            SIMD2(-shaftW / 2, -L / 2 + headL),     // left shaft top
            SIMD2(-W / 2, -L / 2 + headL)           // left head corner
        ]
        var positions: [SIMD3<Float>] = outline.map { SIMD3($0.x, 0, $0.y) }
        // Triangulation of the concave outline: head triangle + shaft quad + two side wedges.
        var indices: [UInt32] = [
            0, 6, 1,          // head
            1, 6, 2, 2, 6, 5, // between head corners and shaft top
            2, 5, 3, 3, 5, 4  // shaft
        ]
        // Make it double-sided by duplicating with reversed winding.
        let count = UInt32(positions.count)
        positions += positions
        let back = indices.chunked(3).flatMap { [$0[0] + count, $0[2] + count, $0[1] + count] }
        indices += back
        let normals = Array(repeating: SIMD3<Float>(0, 1, 0), count: Int(count)) + Array(repeating: SIMD3<Float>(0, -1, 0), count: Int(count))

        var descriptor = MeshDescriptor(name: "navigation-arrow")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        return try? MeshResource.generate(from: [descriptor])
    }
}

private extension Array {
    func chunked(_ size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
