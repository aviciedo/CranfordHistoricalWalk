import Foundation

/// A concave, right-pointing chevron with a closed extrusion. Pure geometry lets us verify
/// winding, depth and direction without depending on RealityKit or a camera.
public enum ARChevronGeometry {
    public struct Mesh: Sendable {
        public var positions: [SIMD3<Float>]
        public var normals: [SIMD3<Float>]
        public var indices: [UInt32]
    }

    public static let bodyDepth: Float = 0.72
    public static let groupSpacing: Float = 1.75

    /// Sampled corner curves soften both convex tips and the concave notch.
    public static let outline: [SIMD2<Float>] = {
        let corners: [SIMD2<Float>] = [
            [-0.58, 0.82], [-0.16, 1.02], [0.70, 0],
            [-0.16, -1.02], [-0.58, -0.82], [-0.06, 0]
        ]
        return corners.indices.flatMap { i -> [SIMD2<Float>] in
            let p = corners[i], before = corners[(i + corners.count - 1) % corners.count], after = corners[(i + 1) % corners.count]
            func clipped(_ other: SIMD2<Float>) -> SIMD2<Float> {
                let d = other - p, length = sqrt(d.x * d.x + d.y * d.y)
                return p + d * min(0.15, 0.08 / length)
            }
            let start = clipped(before), end = clipped(after)
            return (0...4).map { step in
                let t = Float(step) / 4, u = 1 - t
                return start * (u * u) + p * (2 * u * t) + end * (t * t)
            }
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
        let depth = depth.isFinite ? max(0.01, min(1.2, depth)) : 0.18
        var mesh = front()
        mesh.positions += outline.map { [$0.x, $0.y, -depth] }
        mesh.normals += Array(repeating: [0, 0, -1], count: outline.count)
        for i in stride(from: 0, to: frontIndices.count, by: 3) {
            mesh.indices += [frontIndices[i] + UInt32(outline.count), frontIndices[i + 2] + UInt32(outline.count), frontIndices[i + 1] + UInt32(outline.count)]
        }
        let radius = min(0.045, depth / 4)
        let outward: [SIMD2<Float>] = outline.indices.map { i in
            func normal(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> SIMD2<Float> {
                let d = b - a, length = sqrt(d.x * d.x + d.y * d.y)
                return [-d.y / length, d.x / length]
            }
            let sum = normal(outline[(i + outline.count - 1) % outline.count], outline[i])
                + normal(outline[i], outline[(i + 1) % outline.count])
            return sum / sqrt(sum.x * sum.x + sum.y * sum.y)
        }
        let firstRing = UInt32(mesh.positions.count)
        // Quarter-circle bevels meet the flat caps and straight extruded sidewalls.
        for ring in 0..<8 {
            let upper = ring < 4
            let step = upper ? ring : 7 - ring
            let angle = Float(step) * .pi / 6
            let z: Float = step == 0 ? (upper ? 0 : -depth)
                : (upper ? -radius * (1 - cos(angle)) : -depth + radius * (1 - cos(angle)))
            for i in outline.indices {
                let point = outline[i] + outward[i] * radius * sin(angle)
                mesh.positions.append([point.x, point.y, z])
                mesh.normals.append([outward[i].x * sin(angle), outward[i].y * sin(angle),
                                     (upper ? 1 : -1) * cos(angle)])
            }
        }
        for ring in 0..<7 {
            for i in outline.indices {
                let a = firstRing + UInt32(ring * outline.count + i)
                let b = firstRing + UInt32(ring * outline.count + (i + 1) % outline.count)
                let c = b + UInt32(outline.count), d = a + UInt32(outline.count)
                mesh.indices += [a, b, c, a, c, d]
            }
        }
        return mesh
    }

    /// A separately rendered white reverse cap with outward-facing winding.
    public static func back(depth: Float = bodyDepth) -> Mesh {
        var mesh = front()
        let depth = depth.isFinite ? max(0.01, min(1.2, depth)) : bodyDepth
        mesh.positions = mesh.positions.map { [$0.x, $0.y, -depth] }
        mesh.normals = Array(repeating: [0, 0, -1], count: outline.count)
        for i in stride(from: 0, to: mesh.indices.count, by: 3) {
            mesh.indices.swapAt(i + 1, i + 2)
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
