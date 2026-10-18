import Foundation
import RealityKit
import simd
import SwiftUI
import TourCore
import UIKit

/// One broad, translucent ground arrow. Reuses its mesh; no pulsing or repeated breadcrumb trail.
@MainActor
final class ARNavigationArrowEntity: Entity {
    static let firstArrowDistance: Float = 2.5
    static let heightBelowCamera: Float = 1.15
    private let holder = Entity()
    private var lastBase: SIMD3<Float>?
    private var lastDirection: SIMD3<Float>?
    private var lastDistance: Float?
    private(set) var isShowing = false

    required init() {
        super.init()
        guard let mesh = Self.makeArrowMesh() else { return }
        var material = UnlitMaterial(color: UIColor(red: 248 / 255, green: 246 / 255, blue: 238 / 255, alpha: 1))
        material.blending = .transparent(opacity: .init(floatLiteral: 0.58))
        let arrow = ModelEntity(mesh: mesh, materials: [material])
        // A fine, translucent forest edge preserves contrast without the previous heavy border.
        var edgeMaterial = UnlitMaterial(color: UIColor(red: 46 / 255, green: 58 / 255, blue: 47 / 255, alpha: 1))
        edgeMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.26))
        let edge = ModelEntity(mesh: mesh, materials: [edgeMaterial])
        edge.scale = SIMD3<Float>(1.035, 1, 1.035)
        edge.position.y = -0.004
        arrow.addChild(edge)
        holder.addChild(arrow)
        holder.isEnabled = false
        addChild(holder)
    }

    func update(base: SIMD3<Float>, direction: SIMD3<Float>, force: Bool = false, maximumDistance: Float? = nil) {
        let flat = SIMD3<Float>(direction.x, 0, direction.z)
        guard simd_length(flat) > 0.001 else { return }
        let dir = simd_normalize(flat)
        // Keep the whole arrow in front of the marker, rather than pointing through its door.
        let distance = min(Self.firstArrowDistance, maximumDistance.map { max(0, $0 - 1.2) } ?? Self.firstArrowDistance)
        holder.isEnabled = isShowing && distance >= 0.9
        guard holder.isEnabled else { return }
        let appearing = lastBase == nil
        if !force, let lastBase, let lastDirection, let lastDistance,
           simd_length(SIMD2(base.x - lastBase.x, base.z - lastBase.z)) < 0.6,
           abs(base.y - lastBase.y) < 0.04, abs(distance - lastDistance) < 0.15,
           simd_dot(dir, lastDirection) > cos(Float(3 * Double.pi / 180)) { return }
        lastBase = base
        lastDirection = dir
        lastDistance = distance
        let yaw = atan2(dir.x, -dir.z)
        let target = Transform(scale: .one, rotation: simd_quatf(angle: -yaw, axis: [0, 1, 0]), translation: base + dir * distance)
        if UIAccessibility.isReduceMotionEnabled {
            holder.transform = target
        } else {
            if appearing {
                holder.transform = Transform(scale: SIMD3<Float>(repeating: 0.94), rotation: target.rotation, translation: target.translation)
            }
            holder.move(to: target, relativeTo: self, duration: 0.4, timingFunction: .easeInOut)
        }
    }

    func setVisible(_ visible: Bool) {
        guard visible != isShowing else { return }
        isShowing = visible
        holder.isEnabled = visible
        if !visible { lastBase = nil; lastDirection = nil; lastDistance = nil }
    }

    // MARK: Mesh

    /// Flat chevron arrow in the XZ plane pointing toward −Z, ~1.8 m long, double-sided.
    static func makeArrowMesh() -> MeshResource? {
        let L: Float = 1.8, W: Float = 1.35, shaftW: Float = 0.44, headL: Float = 0.85
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
        // Head triangle and shaft quad; no overlapping transparent faces.
        var indices: [UInt32] = [
            0, 6, 1,          // head
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

/// A reusable, upright arrow and street label in the AR world, facing the visitor.
/// Texture work occurs only when the maneuver, street or rounded distance changes.
@MainActor
final class ARTurnSignEntity: Entity {
    private let plane = ModelEntity(mesh: .generatePlane(width: 3.2, height: 2.4))
    private var signature: String?
    private var lastPosition: SIMD3<Float>?
    private var lastRotation: simd_quatf?
    private(set) var isShowing = false

    required init() {
        super.init()
        addChild(plane)
        isEnabled = false
    }

    func update(cue: ARWalkingGuidance.RouteCue, position: SIMD3<Float>, camera: SIMD3<Float>) {
        let key = "\(cue.direction.rawValue)|\(cue.streetLabel)|\(cue.distanceText)"
        if signature != key {
            let renderer = ImageRenderer(content: ARFloatingTurnContent(cue: cue))
            renderer.scale = 1.5
            renderer.isOpaque = false
            guard let cgImage = renderer.cgImage else { hide(); return }
            let options = TextureResource.CreateOptions(semantic: .color, mipmapsMode: .allocateAndGenerateAll)
            let texture: TextureResource
            do {
                if #available(iOS 18.0, *) {
                    texture = try TextureResource(image: cgImage, options: options)
                } else {
                    texture = try TextureResource.generate(from: cgImage, options: options)
                }
            } catch { hide(); return }
            var material = UnlitMaterial()
            material.color = .init(tint: .white, texture: .init(texture))
            material.blending = .transparent(opacity: .init(floatLiteral: 0.96))
            plane.model?.materials = [material]
            signature = key
        }
        let offset = camera - position
        let rotation = simd_quatf(angle: atan2(offset.x, offset.z), axis: [0, 1, 0])
        // Keep the street legible as the intersection comes into view.
        let size = max(0.85, min(2.3, simd_length(SIMD2(offset.x, offset.z)) / 9))
        let target = Transform(scale: SIMD3<Float>(repeating: size), rotation: rotation, translation: position)
        let appearing = !isShowing
        isShowing = true
        isEnabled = true
        if !appearing, let lastPosition, let lastRotation,
           simd_distance(position, lastPosition) < 0.25,
           abs(simd_dot(rotation.vector, lastRotation.vector)) > 0.999 { return }
        lastPosition = position
        lastRotation = rotation
        if UIAccessibility.isReduceMotionEnabled {
            transform = target
        } else {
            if appearing {
                transform = Transform(scale: target.scale * 0.94, rotation: rotation, translation: position)
                if #available(iOS 18.0, *) {
                    components.set(OpacityComponent(opacity: 0))
                    let fade = FromToByAnimation<Float>(name: "turn-entrance", from: 0, to: 1, duration: 0.3,
                                                       timing: .easeInOut, bindTarget: .opacity)
                    if let animation = try? AnimationResource.generate(with: fade) { playAnimation(animation) }
                }
            }
            move(to: target, relativeTo: parent, duration: 0.4, timingFunction: .easeInOut)
        }
    }

    func hide(animated: Bool = false) {
        guard isShowing else {
            if !animated { isEnabled = false; stopAllAnimations() }
            return
        }
        isShowing = false
        lastPosition = nil
        lastRotation = nil
        stopAllAnimations()
        guard animated, !UIAccessibility.isReduceMotionEnabled else { isEnabled = false; return }
        move(to: Transform(scale: scale * 0.96, rotation: orientation, translation: position),
             relativeTo: parent, duration: 0.2, timingFunction: .easeInOut)
        if #available(iOS 18.0, *) {
            let fade = FromToByAnimation<Float>(name: "turn-exit", from: 1, to: 0, duration: 0.2,
                                               timing: .easeInOut, bindTarget: .opacity)
            if let animation = try? AnimationResource.generate(with: fade) { playAnimation(animation) }
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            guard let self, !self.isShowing else { return }
            self.isEnabled = false
        }
    }
}
