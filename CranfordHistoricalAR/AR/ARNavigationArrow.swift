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
        let green = SimpleMaterial(color: UIColor(AppTheme.forest),
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
        group.scale = SIMD3<Float>(repeating: Float(ARStreetGuidance.chevronScale))
        return group
    }
}

/// Three upright world-positioned chevrons above the route, facing the visitor. Their visual
/// direction follows the smoothed camera-relative route bearing, rather than a fixed icon.
@MainActor
final class ARNavigationArrowEntity: Entity {
    static let firstArrowDistance: Float = Float(ARStreetGuidance.lookAheadMeters)
    static let heightBelowCamera: Float = 1.15
    private let holder = Entity()
    private let heading = Entity()
    private var anchorState = ARStreetGuidance.AnchorState()
    private(set) var isShowing = false

    required init() {
        super.init()
        heading.addChild(ARChevronArt.makeGroup())
        holder.addChild(heading)
        holder.isEnabled = false
        addChild(holder)
    }

    func update(ground: SIMD3<Float>, direction: SIMD3<Float>, camera: SIMD3<Float>,
                relativeBearing: Double?, segment: Int, maneuver: ARWalkingGuidance.Direction?, force: Bool = false) {
        guard isShowing, let bearing = relativeBearing, bearing.isFinite else {
            holder.isEnabled = false
            return
        }
        let candidate = SIMD3<Double>(Double(ground.x), Double(ground.y), Double(ground.z))
        let cameraPoint = SIMD3<Double>(Double(camera.x), Double(camera.y), Double(camera.z))
        let routeDirection = SIMD2<Double>(Double(direction.x), Double(direction.z))
        guard let pinned = anchorState.update(candidate: candidate, camera: cameraPoint,
                                             direction: routeDirection, segment: segment, force: force) else {
            holder.isEnabled = false
            return
        }
        let position = SIMD3<Float>(Float(pinned.x), Float(pinned.y + ARStreetGuidance.centerAboveGroundMeters), Float(pinned.z))
        let offset = camera - position
        let facing = simd_quatf(angle: atan2(offset.x, offset.z), axis: [0, 1, 0])
        let degrees: Double
        if let maneuver, abs(bearing) < 50 {
            degrees = ARChevronGeometry.rotationDegrees(direction: maneuver)
        } else {
            degrees = ARChevronGeometry.rotationDegrees(relativeBearing: bearing)
        }
        let rotation = simd_quatf(angle: Float(degrees * Double.pi / 180.0), axis: [0, 0, 1])
        holder.isEnabled = true
        // The position is anchored. Only billboard rotation follows the camera for legibility.
        holder.transform = Transform(scale: .one, rotation: facing, translation: position)
        let target = Transform(scale: .one, rotation: rotation, translation: .zero)
        if UIAccessibility.isReduceMotionEnabled { heading.transform = target }
        else { heading.move(to: target, relativeTo: holder, duration: 0.25, timingFunction: .easeInOut) }
    }

    func setVisible(_ visible: Bool) {
        guard visible != isShowing else { return }
        isShowing = visible
        holder.isEnabled = visible
        if !visible {
            holder.stopAllAnimations(recursive: true)
            anchorState.reset()
        }
    }
}
