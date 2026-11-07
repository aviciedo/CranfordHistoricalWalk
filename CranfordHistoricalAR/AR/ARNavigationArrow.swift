import Foundation
import RealityKit
import simd
import SwiftUI
import TourCore
import UIKit

/// Shared three-dimensional chevron artwork: opaque white faces, hunter-green extruded sides.
@MainActor
private enum ARChevronArt {
    static let sideTexture = makeSideTexture()
    static let bodyMesh = makeMesh(ARChevronGeometry.body(depth: ARChevronGeometry.bodyDepth), name: "hunter-green-chevron-body")
    static let backMesh = makeMesh(ARChevronGeometry.back(), name: "white-chevron-back")
    static let faceMesh = makeMesh(ARChevronGeometry.front(), name: "white-chevron-face")

    static func makeMesh(_ data: ARChevronGeometry.Mesh, name: String) -> MeshResource? {
        var descriptor = MeshDescriptor(name: name)
        descriptor.positions = MeshBuffers.Positions(data.positions)
        descriptor.normals = MeshBuffers.Normals(data.normals)
        // One cached vertical color ramp across the extruded hunter-green material.
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(data.positions.map {
            SIMD2<Float>(0.5, min(1, max(0, -$0.z / ARChevronGeometry.bodyDepth)))
        })
        descriptor.primitives = .triangles(data.indices)
        return try? MeshResource.generate(from: [descriptor])
    }

    static func makeSideTexture() -> TextureResource? {
        let base = UIColor(AppTheme.forest)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 1
        guard base.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        let light = UIColor(red: red + (1 - red) * 0.13, green: green + (1 - green) * 0.13,
                            blue: blue + (1 - blue) * 0.13, alpha: 1)
        let dark = UIColor(red: red * 0.62, green: green * 0.62, blue: blue * 0.62, alpha: 1)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1; format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 256), format: format).image { context in
            base.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 16, height: 256))
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [light.cgColor, base.cgColor, dark.cgColor] as CFArray, locations: [0, 0.48, 1]) else { return }
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: 256), options: [])
        }
        guard let cgImage = image.cgImage else { return nil }
        return try? TextureResource.generate(from: cgImage, options: .init(semantic: .color))
    }

    static func makeGroup() -> Entity {
        let group = Entity()
        guard let bodyMesh, let faceMesh, let backMesh else { return group }
        // Authored shading stays hunter green in outdoor shade instead of turning
        // almost black when environment lighting is weak. White faces remain unlit too.
        var green = UnlitMaterial(color: UIColor(AppTheme.forest))
        if let sideTexture { green.color = .init(tint: .white, texture: .init(sideTexture)) }
        let white = UnlitMaterial(color: .white)
        for index in 0..<3 {
            let body = ModelEntity(mesh: bodyMesh, materials: [green])
            body.position.x = Float(index - 1) * ARChevronGeometry.groupSpacing
            let face = ModelEntity(mesh: faceMesh, materials: [white])
            face.name = "navigation-white-front"
            face.position.z = 0.006 // Clear the green front face without z-fighting.
            body.addChild(face)
            let back = ModelEntity(mesh: backMesh, materials: [white])
            back.name = "navigation-white-back"
            back.position.z = -0.006
            body.addChild(back)
            group.addChild(body)
        }
        // No presentation tilt: the route renderer lays the actual mesh on the ground.
        return group
    }
}

/// A fixed, horizontal 3D route marker. The whole pose is applied only on a new placement;
/// camera-facing billboards and continuously restarted rotation animations are deliberately absent.
@MainActor
final class ARNavigationArrowEntity: Entity {
    static let firstArrowDistance: Float = Float(ARStreetGuidance.lookAheadMeters)
    static let heightBelowCamera: Float = 1.15
    private let holder = Entity()
    private let heading = Entity()
    private var spatialState = ARWorldPlacementState()
    private var renderedSpatialPose: ARWorldPlacementState.Pose?
    private(set) var isShowing = false
    var canRender: Bool { ARChevronArt.bodyMesh != nil && ARChevronArt.faceMesh != nil && ARChevronArt.backMesh != nil }
    var pinnedGroundPosition: SIMD3<Float>? {
        renderedSpatialPose.map { SIMD3(Float($0.position.x), Float($0.position.y), Float($0.position.z)) }
    }
    var guidancePosition: SIMD3<Float>? {
        holder.isEnabled && renderedSpatialPose != nil ? holder.position(relativeTo: nil) : nil
    }

    required init() {
        super.init()
        heading.addChild(ARChevronArt.makeGroup())
        holder.addChild(heading)
        holder.isEnabled = false
        addChild(holder)
    }

    /// Route orientation is supplied in world space; camera heading never rotates this object.
    func updateSpatial(ground: SIMD3<Float>, camera: SIMD3<Float>, routeDirection: SIMD3<Float>,
                       instruction: ARStreetGuidance.Instruction, segment: Int, timestamp: TimeInterval) {
        guard isShowing else { return }
        guard routeDirection.x.isFinite, routeDirection.z.isFinite,
              hypot(routeDirection.x, routeDirection.z) > 0.05 else {
            holder.isEnabled = false
            return
        }
        // After the ground rotation, ahead maps to local -Z and white-face normal to +Y.
        let yaw = atan2(-Double(routeDirection.x), -Double(routeDirection.z))
        guard let pose = spatialState.update(position: SIMD3(Double(ground.x), Double(ground.y), Double(ground.z)),
            routeYaw: yaw, direction: instruction.direction, segment: segment,
            camera: SIMD3(Double(camera.x), Double(camera.y), Double(camera.z)), timestamp: timestamp) else {
            holder.isEnabled = false
            return
        }
        holder.isEnabled = true
        guard pose != renderedSpatialPose else { return }
        let degrees = ARChevronGeometry.rotationDegrees(direction: pose.direction)
        heading.transform = Transform(scale: .one,
            rotation: simd_quatf(angle: Float(degrees * .pi / 180), axis: [0, 0, 1]), translation: .zero)
        holder.orientation = simd_quatf(angle: Float(pose.yaw), axis: [0, 1, 0])
            * simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        let bounds = heading.visualBounds(relativeTo: holder.parent)
        let lift = Float(ARStreetGuidance.minimumClearanceMeters) - (bounds.min.y - holder.position.y)
        let transform = Transform(scale: .one, rotation: simd_quatf(angle: Float(pose.yaw), axis: [0, 1, 0])
                * simd_quatf(angle: -.pi / 2, axis: [1, 0, 0]),
            translation: SIMD3(Float(pose.position.x), Float(pose.position.y) + lift, Float(pose.position.z)))
        holder.stopAllAnimations(recursive: true)
        holder.transform = transform
        renderedSpatialPose = pose
    }

    /// Transient lost ground/tracking hides the sign without throwing away its world pose.
    func setVisible(_ visible: Bool) {
        isShowing = visible
        holder.isEnabled = visible && renderedSpatialPose != nil
    }

    /// Session resets, provider changes and a genuinely new destination need a new world pose.
    func resetAnchor() {
        spatialState.reset()
        renderedSpatialPose = nil
        holder.stopAllAnimations(recursive: true)
        holder.isEnabled = false
    }
}
