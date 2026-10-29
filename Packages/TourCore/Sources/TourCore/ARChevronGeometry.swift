import Foundation

/// A concave, right-pointing chevron with a closed extrusion. Pure geometry lets us verify
/// winding, depth and direction without depending on RealityKit or a camera.
public enum ARChevronGeometry {
    public struct Mesh: Sendable {
        public var positions: [SIMD3<Float>]
        public var normals: [SIMD3<Float>]
        public var indices: [UInt32]
    }

    public static let bodyDepth: Float = 0.25
    public static let groupSpacing: Float = 1.36

    /// Small corner chamfers give original geometry a substantial, softened silhouette.
    public static let outline: [SIMD2<Float>] = {
        let corners: [SIMD2<Float>] = [
            [-0.58, 0.82], [-0.16, 1.02], [0.70, 0],
            [-0.16, -1.02], [-0.58, -0.82], [-0.06, 0]
        ]
        return corners.indices.flatMap { i -> [SIMD2<Float>] in
            let p = corners[i], before = corners[(i + corners.count - 1) % corners.count], after = corners[(i + 1) % corners.count]
            func clipped(_ other: SIMD2<Float>) -> SIMD2<Float> {
                let d = other - p, length = sqrt(d.x * d.x + d.y * d.y)
                return p + d * min(0.09, 0.045 / length)
            }
            return [clipped(before), clipped(after)]
        }
    }()
    public static let frontIndices: [UInt32] = {
        var polygon = Array(outline.indices.reversed()), triangles: [UInt32] = []
        func cross(_ a: SIMD2<Float>, _ b: SIMD2<Float>, _ c: SIMD2<Float>) -> Float {
            (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
        }
        while polygon.count > 3 {
            var found = false
            for i in polygon.indices {
                let a = polygon[(i + polygon.count - 1) % polygon.count], b = polygon[i], c = polygon[(i + 1) % polygon.count]
                guard cross(outline[a], outline[b], outline[c]) > 0.000001 else { continue }
                let contains = polygon.contains { p in
                    p != a && p != b && p != c
                        && cross(outline[a], outline[b], outline[p]) >= -0.000001
                        && cross(outline[b], outline[c], outline[p]) >= -0.000001
                        && cross(outline[c], outline[a], outline[p]) >= -0.000001
                }
                if contains { continue }
                triangles += [UInt32(a), UInt32(b), UInt32(c)]
                polygon.remove(at: i); found = true; break
            }
            guard found else { return [] }
        }
        return triangles + polygon.map(UInt32.init)
    }()

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
            mesh.indices += [frontIndices[i] + UInt32(outline.count), frontIndices[i + 2] + UInt32(outline.count), frontIndices[i + 1] + UInt32(outline.count)]
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

    /// Uniformly fit the projected group without distorting chevrons or filling the camera view.
    /// The conservative fallback keeps invalid projections from creating nonfinite transforms.
    public static func displayFitScale(projectedWidth: Double, projectedHeight: Double,
                                       viewportWidth: Double, viewportHeight: Double) -> Double {
        guard [projectedWidth, projectedHeight, viewportWidth, viewportHeight].allSatisfy({ $0.isFinite && $0 > 0 }) else { return 1 }
        return min(1, min(viewportWidth * 0.76 / projectedWidth,
                          viewportHeight * 0.29 / projectedHeight))
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
