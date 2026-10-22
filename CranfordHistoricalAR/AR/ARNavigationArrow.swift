import Foundation
import RealityKit
import simd
import SwiftUI
import TourCore
import UIKit

/// Shared three-dimensional chevron artwork: opaque white faces, hunter-green frame/sides.
@MainActor
private enum ARChevronArt {
    static let bodyMesh = makeMesh(ARChevronGeometry.body(), name: "hunter-chevron-body")
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
        let green = SimpleMaterial(color: UIColor(red: 0.10, green: 0.25, blue: 0.17, alpha: 1),
                                   roughness: 0.55, isMetallic: false)
        let white = UnlitMaterial(color: .white)
        for index in 0..<3 {
            let body = ModelEntity(mesh: bodyMesh, materials: [green])
            body.position.x = Float(index - 1) * 0.78
            let face = ModelEntity(mesh: faceMesh, materials: [white])
            face.scale = SIMD3<Float>(0.84, 0.88, 1)
            face.position.z = 0.006 // Clear the green front face without z-fighting.
            body.addChild(face)
            group.addChild(body)
        }
        group.scale = SIMD3<Float>(repeating: 0.65)
        return group
    }
}

/// Three upright world-positioned chevrons above the route, facing the visitor. Their visual
/// direction follows the smoothed camera-relative route bearing, rather than a fixed icon.
@MainActor
final class ARNavigationArrowEntity: Entity {
    static let heightBelowCamera: Float = 1.15
    private let holder = Entity()
    private let heading = Entity()
    private var lastPosition: SIMD3<Float>?
    private var lastRotation: simd_quatf?
    private var lastBearing: Double?
    private(set) var isShowing = false

    required init() {
        super.init()
        heading.addChild(ARChevronArt.makeGroup())
        holder.addChild(heading)
        holder.isEnabled = false
        addChild(holder)
    }

    func update(base: SIMD3<Float>, direction: SIMD3<Float>, camera: SIMD3<Float>,
                relativeBearing: Double?, force: Bool = false, maximumDistance: Float? = nil) {
        let flat = SIMD3<Float>(direction.x, 0, direction.z)
        guard ARChevronPlacement.canAim(flatLength: simd_length(flat), relativeBearing: relativeBearing),
              let bearing = relativeBearing else {
            holder.isEnabled = false
            return
        }
        let dir = simd_normalize(flat)
        let distance = ARChevronPlacement.travelDistance(maximumDistance: maximumDistance)
        holder.isEnabled = ARChevronPlacement.isVisible(isShowing: isShowing, travelDistance: distance)
        guard holder.isEnabled else { return }
        var position = base + dir * distance
        position.y += 0.95
        let offset = camera - position
        let facing = simd_quatf(angle: atan2(offset.x, offset.z), axis: [0, 1, 0])
        let degrees = ARChevronGeometry.rotationDegrees(relativeBearing: bearing)
        let rotation = simd_quatf(angle: Float(degrees * .pi / 180), axis: [0, 0, 1])
        let appearing = lastPosition == nil
        let bearingChange = lastBearing.map { ARChevronPlacement.bearingChangeDegrees(from: $0, to: bearing) } ?? 360
        if let lastPosition, let lastRotation,
           ARChevronPlacement.shouldKeepPreviousPose(
               positionDelta: simd_distance(position, lastPosition),
               facingDot: simd_dot(facing.vector, lastRotation.vector),
               bearingChange: bearingChange, force: force) { return }
        lastPosition = position
        lastRotation = facing
        lastBearing = bearing
        let target = Transform(scale: .one, rotation: facing, translation: position)
        let headingTarget = Transform(scale: .one, rotation: rotation, translation: .zero)
        if UIAccessibility.isReduceMotionEnabled {
            holder.transform = target
            heading.transform = headingTarget
        } else if appearing {
            holder.transform = Transform(scale: SIMD3<Float>(repeating: 0.94), rotation: facing, translation: position)
            heading.transform = headingTarget
            holder.move(to: target, relativeTo: self, duration: 0.3, timingFunction: .easeInOut)
        } else {
            holder.move(to: target, relativeTo: self, duration: 0.4, timingFunction: .easeInOut)
            heading.move(to: headingTarget, relativeTo: holder, duration: 0.35, timingFunction: .easeInOut)
        }
    }

    func setVisible(_ visible: Bool) {
        guard visible != isShowing else { return }
        isShowing = visible
        holder.isEnabled = visible
        if !visible {
            holder.stopAllAnimations(recursive: true)
            lastPosition = nil; lastRotation = nil; lastBearing = nil
        }
    }
}

/// A reusable, upright arrow and street label in the AR world, facing the visitor.
/// Texture work occurs only when the maneuver, street or rounded distance changes.
@MainActor
final class ARTurnSignEntity: Entity {
    private let plane = ModelEntity(mesh: .generatePlane(width: 3.2, height: 1.2))
    private let chevrons = ARChevronArt.makeGroup()
    private var signature: String?
    private var lastPosition: SIMD3<Float>?
    private var lastRotation: simd_quatf?
    private var lastScale: Float?
    private var hideTask: Task<Void, Never>?
    private(set) var isShowing = false

    required init() {
        super.init()
        plane.position.y = -1.2
        addChild(plane)
        chevrons.position.y = 0.4
        addChild(chevrons)
        isEnabled = false
    }

    func update(cue: ARWalkingGuidance.RouteCue, position: SIMD3<Float>, camera: SIMD3<Float>) {
        let key = "\(cue.direction.rawValue)|\(cue.streetLabel)|\(cue.distanceText)"
        if signature != key || !isShowing {
            let angle = Float(ARChevronGeometry.rotationDegrees(direction: cue.direction) * .pi / 180)
            let target = Transform(scale: chevrons.scale, rotation: simd_quatf(angle: angle, axis: [0, 0, 1]),
                                   translation: SIMD3<Float>(0, 0.4, 0))
            if UIAccessibility.isReduceMotionEnabled || !isShowing { chevrons.transform = target }
            else { chevrons.move(to: target, relativeTo: self, duration: 0.35, timingFunction: .easeInOut) }
        }
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
        // Scaling the label below the chevrons must not bury it beneath the street.
        var targetPosition = position
        targetPosition.y += max(0, 1.8 * size - 1.8)
        let target = Transform(scale: SIMD3<Float>(repeating: size), rotation: rotation, translation: targetPosition)
        let appearing = !isShowing
        hideTask?.cancel()
        hideTask = nil
        if appearing {
            stopAllAnimations()
            if #available(iOS 18.0, *) { components.set(OpacityComponent(opacity: 1)) }
        }
        isShowing = true
        isEnabled = true
        if !appearing, let lastPosition, let lastRotation, let lastScale,
           simd_distance(targetPosition, lastPosition) < 0.25,
           abs(size - lastScale) < 0.03,
           abs(simd_dot(rotation.vector, lastRotation.vector)) > 0.999 { return }
        lastPosition = targetPosition
        lastRotation = rotation
        lastScale = size
        if UIAccessibility.isReduceMotionEnabled {
            transform = target
        } else {
            if appearing {
                transform = Transform(scale: target.scale * 0.94, rotation: rotation, translation: targetPosition)
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
        if !animated {
            hideTask?.cancel()
            hideTask = nil
        }
        guard isShowing else {
            if !animated { isEnabled = false; stopAllAnimations() }
            return
        }
        isShowing = false
        lastPosition = nil
        lastRotation = nil
        lastScale = nil
        stopAllAnimations()
        guard animated, !UIAccessibility.isReduceMotionEnabled else { isEnabled = false; return }
        move(to: Transform(scale: scale * 0.96, rotation: orientation, translation: position),
             relativeTo: parent, duration: 0.2, timingFunction: .easeInOut)
        if #available(iOS 18.0, *) {
            let fade = FromToByAnimation<Float>(name: "turn-exit", from: 1, to: 0, duration: 0.2,
                                               timing: .easeInOut, bindTarget: .opacity)
            if let animation = try? AnimationResource.generate(with: fade) { playAnimation(animation) }
        }
        hideTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(220)) } catch { return }
            guard let self, !self.isShowing else { return }
            self.isEnabled = false
        }
    }
}
