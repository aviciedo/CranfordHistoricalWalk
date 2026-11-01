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
    static let faceMesh = makeMesh(ARChevronGeometry.front(), name: "white-chevron-face")

    static func makeMesh(_ data: ARChevronGeometry.Mesh, name: String) -> MeshResource? {
        var descriptor = MeshDescriptor(name: name)
        descriptor.positions = MeshBuffers.Positions(data.positions)
        descriptor.normals = MeshBuffers.Normals(data.normals)
        // One cached vertical color ramp across the extruded hunter-green material.
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(data.positions.map {
            SIMD2<Float>(($0.z + ARChevronGeometry.bodyDepth) / ARChevronGeometry.bodyDepth,
                         ($0.y + 1.1) / 2.2)
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
        guard let bodyMesh, let faceMesh else { return group }
        // Authored shading stays hunter green in outdoor shade instead of turning
        // almost black when environment lighting is weak. White faces remain unlit too.
        var green = UnlitMaterial(color: UIColor(AppTheme.forest))
        if let sideTexture { green.color = .init(tint: .white, texture: .init(sideTexture)) }
        let white = UnlitMaterial(color: .white)
        for index in 0..<3 {
            let body = ModelEntity(mesh: bodyMesh, materials: [green])
            body.position.x = Float(index - 1) * ARChevronGeometry.groupSpacing
            let face = ModelEntity(mesh: faceMesh, materials: [white])
            face.scale = SIMD3<Float>(0.985, 0.985, 1)
            face.position.z = 0.006 // Clear the green front face without z-fighting.
            body.addChild(face)
            group.addChild(body)
        }
        // Rotate only the artwork, not the anchor or navigation direction. Perspective
        // exposes the substantial green extrusion even from the initial viewing position.
        group.orientation = simd_quatf(angle: ARChevronGeometry.presentationYawRadians, axis: [0, 1, 0])
        group.scale = SIMD3<Float>(repeating: 1.0)
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
    private var spatialState = ARWorldPlacementState()
    private var renderedSpatialPose: ARWorldPlacementState.Pose?
    private var renderedPlacement: ARStreetGuidance.Placement?
    private(set) var isShowing = false
    var canRender: Bool { ARChevronArt.bodyMesh != nil && ARChevronArt.faceMesh != nil }
    var guidancePosition: SIMD3<Float>? {
        holder.isEnabled && (renderedSpatialPose != nil || renderedPlacement != nil) ? holder.position(relativeTo: nil) : nil
    }

    required init() {
        super.init()
        heading.addChild(ARChevronArt.makeGroup())
        holder.addChild(heading)
        holder.isEnabled = false
        addChild(holder)
    }

    func updateManeuver(ground: SIMD3<Float>, camera: SIMD3<Float>,
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

    /// Route orientation is supplied in world space; camera heading never rotates this object.
    func updateSpatial(ground: SIMD3<Float>, camera: SIMD3<Float>, routeDirection: SIMD3<Float>,
                       instruction: ARStreetGuidance.Instruction, segment: Int, timestamp: TimeInterval) {
        guard isShowing else { return }
        // Local +Z is the sign normal. Face back along the walking segment, not toward the camera.
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
        let bounds = heading.visualBounds(relativeTo: holder)
        let lift = Float(ARStreetGuidance.minimumClearanceMeters) - bounds.min.y
        let transform = Transform(scale: .one, rotation: simd_quatf(angle: Float(pose.yaw), axis: [0, 1, 0]),
            translation: SIMD3(Float(pose.position.x), Float(pose.position.y) + lift, Float(pose.position.z)))
        if let previous = renderedSpatialPose,
           simd_length(transform.translation - holder.position) < 2,
           abs(GeoMath.relativeBearing(heading: previous.yaw * 180 / .pi, bearing: pose.yaw * 180 / .pi)) < 20 {
            holder.move(to: transform, relativeTo: holder.parent, duration: 0.25, timingFunction: .easeInOut)
        } else { holder.stopAllAnimations(recursive: true); holder.transform = transform }
        renderedSpatialPose = pose
    }

    /// Transient lost ground/tracking hides the sign without throwing away its world pose.
    func setVisible(_ visible: Bool) {
        isShowing = visible
        holder.isEnabled = visible && (renderedSpatialPose != nil || renderedPlacement != nil)
    }

    /// Session resets, provider changes and a genuinely new destination need a new world pose.
    func resetAnchor() {
        anchorState.reset()
        spatialState.reset()
        renderedSpatialPose = nil
        renderedPlacement = nil
        holder.stopAllAnimations(recursive: true)
        holder.isEnabled = false
    }
}
