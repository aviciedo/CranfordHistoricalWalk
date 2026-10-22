import XCTest
@testable import TourCore

final class ARChevronGeometryTests: XCTestCase {
    func testFrontTriangulationCoversConcaveOutlineWithForwardWinding() {
        let mesh = ARChevronGeometry.front()
        var area: Float = 0
        for i in stride(from: 0, to: mesh.indices.count, by: 3) {
            let a = mesh.positions[Int(mesh.indices[i])]
            let b = mesh.positions[Int(mesh.indices[i + 1])]
            let c = mesh.positions[Int(mesh.indices[i + 2])]
            let cross = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
            XCTAssertGreaterThan(cross, 0, "Every white face must point toward the viewer")
            area += cross / 2
        }
        let outline = ARChevronGeometry.outline
        let polygonArea = abs(outline.indices.reduce(Float(0)) { result, i in
            let a = outline[i], b = outline[(i + 1) % outline.count]
            return result + a.x * b.y - b.x * a.y
        }) / 2
        XCTAssertEqual(area, polygonArea, accuracy: 0.00001)
    }

    func testExtrusionIsClosedAndHasValidNormalsAndDepth() {
        let mesh = ARChevronGeometry.body()
        XCTAssertEqual(mesh.positions.count, mesh.normals.count)
        XCTAssertEqual(mesh.positions.map(\.z).min()!, -0.18, accuracy: 0.00001)
        XCTAssertEqual(mesh.positions.map(\.z).max()!, 0)
        var edges: [String: Int] = [:]
        func key(_ index: UInt32) -> String {
            let p = mesh.positions[Int(index)]
            return "\(p.x),\(p.y),\(p.z)"
        }
        for i in stride(from: 0, to: mesh.indices.count, by: 3) {
            let triangle = Array(mesh.indices[i..<(i + 3)])
            for index in triangle { XCTAssertLessThan(Int(index), mesh.positions.count) }
            for j in 0..<3 {
                let pair = [key(triangle[j]), key(triangle[(j + 1) % 3])].sorted().joined(separator: "|")
                edges[pair, default: 0] += 1
            }
        }
        XCTAssertTrue(edges.values.allSatisfy { $0 == 2 }, "Every geometric edge must meet two faces")
        for n in mesh.normals { XCTAssertEqual(n.x * n.x + n.y * n.y + n.z * n.z, 1, accuracy: 0.00001) }
    }

    func testDirectionMappingMatchesCameraRelativeRoute() {
        XCTAssertEqual(ARChevronGeometry.rotationDegrees(relativeBearing: 0), 90)
        XCTAssertEqual(ARChevronGeometry.rotationDegrees(relativeBearing: 90), 0)
        XCTAssertEqual(ARChevronGeometry.rotationDegrees(relativeBearing: -90), 180)
        XCTAssertEqual(ARChevronGeometry.rotationDegrees(relativeBearing: 180), -90)
        XCTAssertEqual(ARChevronGeometry.rotationDegrees(direction: .right), 0)
        XCTAssertEqual(ARChevronGeometry.rotationDegrees(direction: .left), 180)
        XCTAssertEqual(ARChevronGeometry.rotationDegrees(direction: .bearRight), 45)
        XCTAssertEqual(ARChevronGeometry.rotationDegrees(direction: .bearLeft), 135)
        XCTAssertEqual(ARChevronGeometry.rotationDegrees(direction: .ahead), 90)
        XCTAssertEqual(ARChevronGeometry.rotationDegrees(direction: .turnAround), 270)
    }

    func testInvalidDepthAndBearingCannotCreateNonfiniteGeometry() {
        for depth: Float in [.nan, -.infinity, -1, 0, 5] {
            let mesh = ARChevronGeometry.body(depth: depth)
            XCTAssertTrue(mesh.positions.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
            XCTAssertLessThan(mesh.positions.map(\.z).min()!, 0)
        }
        XCTAssertEqual(ARChevronGeometry.rotationDegrees(relativeBearing: .nan), 90)
    }
}
