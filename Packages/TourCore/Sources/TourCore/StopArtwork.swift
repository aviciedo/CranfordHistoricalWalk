import Foundation

/// Catalog-supplied resource names. No tour-specific stop-ID switch is required by a renderer.
public struct StopArtwork: Hashable, Codable, Sendable {
    public var homeInk: String?
    public var listInk: String?
    public var watercolor: String?
    public var mapLandmark: String?
    public var listHeight: Double?
    public init(homeInk: String? = nil, listInk: String? = nil, watercolor: String? = nil,
                mapLandmark: String? = nil, listHeight: Double? = nil) {
        self.homeInk = homeInk; self.listInk = listInk; self.watercolor = watercolor
        self.mapLandmark = mapLandmark; self.listHeight = listHeight
    }
    public var assetNames: [String] { [homeInk, listInk, watercolor, mapLandmark].compactMap { $0 } }
    public var isValid: Bool {
        assetNames.allSatisfy { name in
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 160
                && !name.contains("/") && !name.contains("\\")
                && !name.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
        } && (listHeight.map { $0.isFinite && (44...160).contains($0) } ?? true)
    }
    /// Include resource identity in provider caches so revised media cannot leave stale textures.
    public var cacheKey: String {
        [homeInk ?? "", listInk ?? "", watercolor ?? "", mapLandmark ?? ""].joined(separator: "\u{1f}")
    }
}
