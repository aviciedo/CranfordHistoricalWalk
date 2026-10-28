import Foundation
import RealityKit
import simd
import SwiftUI
import TourCore
import UIKit

/// The 3D historical sign (spec §8): a textured plane on a slim post. The texture is the SwiftUI
/// `HistoricalSignView` rasterized once per stop, so typography stays crisp and the layout is
/// shared with the 2D sheet. Entities are reused; only the texture and transforms change.
@MainActor
final class ARHistoricalSignEntity: Entity {
    /// Physical width of the sign plane in meters. Large enough to read from several meters away.
    static let signWidth: Float = 1.6
    static let postHeight: Float = 1.1

    enum Appearance: String {
        /// Existing geo-placed sign on a slim post.
        case geoPost
        /// Popup locked to a detected door plate; no post, centered on the offset.
        case plaqueCard
        /// On-site activation target before the visitor starts the story.
        case visitMarker
    }

    private let pivot = Entity()
    private let floatCarrier = Entity()
    private var plane: ModelEntity?
    private var post: ModelEntity?
    private var closeControl: ModelEntity?
    private(set) var stopID: String?
    private(set) var appearance: Appearance = .geoPost
    private struct Configuration: Equatable {
        let stop: HistoricalStop
        let image: LoadedImage?
        let scale: CGFloat
        let appearance: Appearance
    }
    private var configuration: Configuration?
    private(set) var isPresented = false

    required init() {
        super.init()
        name = "historical-sign"
        addChild(pivot)
        pivot.addChild(floatCarrier)
        isEnabled = false
    }

    /// Entities that count as "the sign" for hit testing.
    func contains(_ entity: Entity) -> Bool {
        var current: Entity? = entity
        while let e = current {
            if e === self { return true }
            current = e.parent
        }
        return false
    }

    /// Top-right close control on the card. Tapping it dismisses; the rest of the card opens the sheet.
    func containsCloseControl(_ entity: Entity) -> Bool {
        var current: Entity? = entity
        while let e = current {
            if e === closeControl || e.name == "sign-close" { return true }
            if e === self { return false }
            current = e.parent
        }
        return false
    }

    // MARK: Content

    /// Builds or swaps the texture for `stop`. Returns false if rendering failed.
    @discardableResult
    func configure(stop: HistoricalStop, image: LoadedImage?, scale: CGFloat, appearance: Appearance = .geoPost) -> Bool {
        let configuration = Configuration(stop: stop, image: image, scale: scale, appearance: appearance)
        // Image-anchor updates arrive every frame. Reuse geometry, collision shapes and
        // texture until the actual content or presentation changes.
        if self.configuration == configuration { return true }
        guard let textureAndAspect = Self.renderTexture(for: stop, image: image, scale: scale, appearance: appearance) else { return false }
        stopID = stop.id
        self.appearance = appearance

        let (texture, aspect) = textureAndAspect
        let width: Float = appearance == .visitMarker ? 0.7 : (appearance == .plaqueCard ? 0.45 : Self.signWidth)
        let height = width * Float(aspect)

        var material = UnlitMaterial()
        material.color = .init(tint: .white, texture: .init(texture))
        material.blending = .transparent(opacity: .init(floatLiteral: 1.0))

        let planeY: Float = appearance == .geoPost ? height / 2 : 0
        if let plane {
            plane.model?.mesh = .generatePlane(width: width, height: height)
            plane.model?.materials = [material]
            plane.position = SIMD3<Float>(0, planeY, 0)
            plane.collision = CollisionComponent(shapes: [.generateBox(width: width, height: height, depth: 0.05)])
        } else {
            let plane = ModelEntity(mesh: .generatePlane(width: width, height: height), materials: [material])
            plane.name = "sign-plane"
            plane.position = SIMD3<Float>(0, planeY, 0)
            plane.collision = CollisionComponent(shapes: [.generateBox(width: width, height: height, depth: 0.05)])
            floatCarrier.addChild(plane)
            self.plane = plane
        }

        if post == nil {
            let postMaterial = SimpleMaterial(color: UIColor(red: 0.22, green: 0.20, blue: 0.18, alpha: 1), roughness: 0.6, isMetallic: false)
            let post = ModelEntity(mesh: .generateBox(width: 0.06, height: ARHistoricalSignEntity.postHeight, depth: 0.06, cornerRadius: 0.01), materials: [postMaterial])
            post.name = "sign-post"
            post.position = SIMD3<Float>(0, -ARHistoricalSignEntity.postHeight / 2, -0.03)
            floatCarrier.addChild(post)
            self.post = post
        }
        post?.isEnabled = appearance == .geoPost
        if appearance == .visitMarker {
            closeControl?.isEnabled = false
        } else {
            layoutCloseControl(cardWidth: width, cardHeight: height, planeY: planeY)
        }
        self.configuration = configuration
        return true
    }

    private func layoutCloseControl(cardWidth: Float, cardHeight: Float, planeY: Float) {
        let size: Float = appearance == .plaqueCard ? 0.09 : 0.22
        let inset: Float = appearance == .plaqueCard ? cardWidth * (54 / 720) : 0.16
        if closeControl == nil {
            var material = UnlitMaterial(color: UIColor.clear)
            material.blending = .transparent(opacity: .init(floatLiteral: 0.02))
            let button = ModelEntity(mesh: .generatePlane(width: size, height: size), materials: [material])
            button.name = "sign-close"
            button.collision = CollisionComponent(shapes: [.generateBox(width: size, height: size, depth: 0.06)])
            floatCarrier.addChild(button)
            closeControl = button
        }
        closeControl?.model?.mesh = .generatePlane(width: size, height: size)
        closeControl?.collision = CollisionComponent(shapes: [.generateBox(width: size, height: size, depth: 0.06)])
        closeControl?.position = SIMD3<Float>(cardWidth / 2 - inset, planeY + cardHeight / 2 - inset, 0.03)
        closeControl?.isEnabled = true
    }

    private static func renderTexture(for stop: HistoricalStop, image: LoadedImage?, scale: CGFloat, appearance: Appearance) -> (TextureResource, CGFloat)? {
        let style: HistoricalSignView.Style = (appearance == .visitMarker ? .activationMarker : (appearance == .plaqueCard ? .arPlaqueCard : .arTexture))
        let view = HistoricalSignView(stop: stop, image: image, style: style)
        let renderer = ImageRenderer(content: view)
        renderer.scale = min(scale, 2) // 2x of 720 pt = 1440 px wide: sharp, still cheap on GPU memory
        renderer.isOpaque = false
        guard let cgImage = renderer.cgImage else { return nil }
        let aspect = CGFloat(cgImage.height) / CGFloat(cgImage.width)
        do {
            // RealityKit `TextureResource.MipmapsMode` cases (Apple, Xcode 16 / iOS 17+):
            // `.none`, `.allocateAll`, `.allocateAndGenerateAll`. There is no `.allocateAndGenerate`.
            let options = TextureResource.CreateOptions(semantic: .color, mipmapsMode: .allocateAndGenerateAll)
            let texture: TextureResource
            if #available(iOS 18.0, *) {
                texture = try TextureResource(image: cgImage, options: options)
            } else {
                texture = try TextureResource.generate(from: cgImage, options: options)
            }
            return (texture, aspect)
        } catch {
            return nil
        }
    }

    // MARK: Presentation

    /// Places the sign so its bottom edge sits at `basePosition` (ground-ish) and plays the entrance.
    func present(at basePosition: SIMD3<Float>, facing cameraPosition: SIMD3<Float>) {
        position = basePosition
        face(cameraPosition, animated: false)
        isEnabled = true
        isPresented = true

        pivot.transform = Transform(scale: SIMD3<Float>(repeating: 0.6), rotation: simd_quatf(angle: 0, axis: [0, 1, 0]), translation: SIMD3<Float>(0, -0.1, 0))
        pivot.move(to: Transform(scale: .one, rotation: simd_quatf(angle: 0, axis: [0, 1, 0]), translation: .zero), relativeTo: self, duration: 0.55, timingFunction: .easeOut)

        if #available(iOS 18.0, *) {
            components.set(OpacityComponent(opacity: 0))
            let fade = FromToByAnimation<Float>(name: "fade-in", from: 0, to: 1, duration: 0.45, timing: .easeOut, bindTarget: .opacity)
            if let resource = try? AnimationResource.generate(with: fade) {
                playAnimation(resource)
            }
        }
        if appearance == .geoPost {
            startFloating()
        }
    }

    /// Subtle scale-in while parented to a plaque image anchor. No float — the plate is the lock.
    func presentOnPlaque() {
        isEnabled = true
        isPresented = true
        pivot.transform = Transform(scale: SIMD3<Float>(repeating: 0.88), rotation: simd_quatf(angle: 0, axis: [0, 1, 0]), translation: .zero)
        pivot.move(to: Transform(scale: .one, rotation: simd_quatf(angle: 0, axis: [0, 1, 0]), translation: .zero), relativeTo: self, duration: 0.35, timingFunction: .easeOut)
        if #available(iOS 18.0, *) {
            components.set(OpacityComponent(opacity: 0))
            let fade = FromToByAnimation<Float>(name: "fade-in", from: 0, to: 1, duration: 0.3, timing: .easeOut, bindTarget: .opacity)
            if let resource = try? AnimationResource.generate(with: fade) {
                playAnimation(resource)
            }
        }
        floatCarrier.stopAllAnimations()
    }

    /// Reposition without replaying the entrance (new GPS fix / user walked around it).
    func move(to basePosition: SIMD3<Float>, facing cameraPosition: SIMD3<Float>) {
        guard isPresented else { return }
        let target = Transform(scale: .one, rotation: yawRotation(toward: cameraPosition, from: basePosition), translation: basePosition)
        move(to: target, relativeTo: parent, duration: 0.6, timingFunction: .easeInOut)
    }

    func face(_ cameraPosition: SIMD3<Float>, animated: Bool) {
        let rotation = yawRotation(toward: cameraPosition, from: position)
        if animated {
            move(to: Transform(scale: scale, rotation: rotation, translation: position), relativeTo: parent, duration: 0.3, timingFunction: .easeInOut)
        } else {
            orientation = rotation
        }
    }

    /// Plane normal is +Z; rotate around Y so +Z points at the camera (billboard on the yaw axis only).
    private func yawRotation(toward cameraPosition: SIMD3<Float>, from position: SIMD3<Float>) -> simd_quatf {
        let dx = cameraPosition.x - position.x
        let dz = cameraPosition.z - position.z
        guard abs(dx) + abs(dz) > 0.001 else { return orientation }
        return simd_quatf(angle: atan2(dx, dz), axis: [0, 1, 0])
    }

    private func startFloating() {
        let up = Transform(scale: .one, rotation: simd_quatf(angle: 0, axis: [0, 1, 0]), translation: SIMD3<Float>(0, 0.025, 0))
        let down = Transform(scale: .one, rotation: simd_quatf(angle: 0, axis: [0, 1, 0]), translation: SIMD3<Float>(0, -0.025, 0))
        let float = FromToByAnimation<Transform>(name: "float", from: down, to: up, duration: 2.6, timing: .easeInOut, bindTarget: .transform, repeatMode: .autoReverse)
        if let resource = try? AnimationResource.generate(with: float) {
            floatCarrier.playAnimation(resource.repeat(), transitionDuration: 0.3, startsPaused: false)
        }
    }

    func dismiss() {
        guard isPresented else { return }
        isPresented = false
        pivot.move(to: Transform(scale: SIMD3<Float>(repeating: 0.7), rotation: simd_quatf(angle: 0, axis: [0, 1, 0]), translation: SIMD3<Float>(0, -0.05, 0)), relativeTo: self, duration: 0.25, timingFunction: .easeIn)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(260))
            guard let self, !self.isPresented else { return }
            self.isEnabled = false
            self.floatCarrier.stopAllAnimations()
        }
    }
}
