import Foundation

/// A concave, right-pointing chevron with a closed extrusion. Pure geometry lets us verify
/// winding, depth and direction without depending on RealityKit or a camera.
public enum ARChevronGeometry {
    public struct Mesh: Sendable {
        public var positions: [SIMD3<Float>]
        public var normals: [SIMD3<Float>]
        public var indices: [UInt32]
    }

    public static let outline: [SIMD2<Float>] = [
        [-0.45, 0.75], [-0.12, 0.95], [0.55, 0],
        [-0.12, -0.95], [-0.45, -0.75], [0.10, 0]
    ]
    // Positive-Z front winding, including the concave inner corner.
    public static let frontIndices: [UInt32] = [5, 1, 0, 5, 2, 1, 5, 3, 2, 5, 4, 3]

    public static func front() -> Mesh {
        Mesh(positions: outline.map { [$0.x, $0.y, 0] },
             normals: Array(repeating: [0, 0, 1], count: outline.count), indices: frontIndices)
    }

    public static func body(depth: Float = 0.18) -> Mesh {
        let depth = depth.isFinite ? max(0.01, min(0.5, depth)) : 0.18
        var mesh = front()
        mesh.positions += outline.map { [$0.x, $0.y, -depth] }
        mesh.normals += Array(repeating: [0, 0, -1], count: outline.count)
        for i in stride(from: 0, to: frontIndices.count, by: 3) {
            mesh.indices += [frontIndices[i] + 6, frontIndices[i + 2] + 6, frontIndices[i + 1] + 6]
        }
        for i in outline.indices {
            let a = outline[i], b = outline[(i + 1) % outline.count]
            let dx = b.x - a.x, dy = b.y - a.y
            let length = sqrt(dx * dx + dy * dy)
            let normal: SIMD3<Float> = [-dy / length, dx / length, 0]
            let start = UInt32(mesh.positions.count)
            mesh.positions += [[a.x, a.y, 0], [b.x, b.y, 0], [b.x, b.y, -depth], [a.x, a.y, -depth]]
            mesh.normals += Array(repeating: normal, count: 4)
            mesh.indices += [start, start + 1, start + 2, start, start + 2, start + 3]
        }
        return mesh
    }

    /// Screen bearing: ahead points up, right points right, behind points down.
    public static func rotationDegrees(relativeBearing: Double) -> Double {
        90 - (relativeBearing.isFinite ? relativeBearing : 0)
    }

    public static func rotationDegrees(direction: ARWalkingGuidance.Direction) -> Double {
        switch direction {
        case .right: return 0
        case .bearRight: return 45
        case .ahead: return 90
        case .bearLeft: return 135
        case .left: return 180
        case .turnAround: return 270
        }
    }
}
