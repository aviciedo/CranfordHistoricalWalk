import Foundation
import TourCore
import UIKit

/// An image resolved for a stop, with enough metadata for honest labeling (spec §10, §20).
struct LoadedImage: Equatable {
    enum Kind: Equatable { case photograph, illustration }

    let image: UIImage
    let kind: Kind
    /// True when the artwork is a stand-in and must be labeled "PLACEHOLDER IMAGE".
    let isPlaceholder: Bool

    static func == (lhs: LoadedImage, rhs: LoadedImage) -> Bool {
        lhs.image === rhs.image && lhs.kind == rhs.kind && lhs.isPlaceholder == rhs.isPlaceholder
    }
}

/// Resolves artwork for historical stops. The production app can swap in a backend-backed
/// implementation without touching the AR or sheet code (spec §10).
///
/// Two entry points because the AR texture is rasterized synchronously on the main actor:
/// `cachedImage` answers immediately from memory, `image` may hit the asset catalog or network.
@MainActor
protocol ImageLoader: AnyObject {
    /// Immediate answer, or `nil` when nothing is cached yet.
    func cachedImage(for stop: HistoricalStop) -> LoadedImage?
    /// Resolves the best available image, caching it. Never throws: a missing image is normal.
    func image(for stop: HistoricalStop) async -> LoadedImage?
    /// Resolve one gallery page without replacing the stop's cover/AR artwork.
    func image(for photo: HistoricalStopPhoto, at stop: HistoricalStop) async -> LoadedImage?
    /// Warm the cache for stops the user is about to reach.
    func prefetch(_ stops: [HistoricalStop])
}

/// Precedence: local asset (`imageName`) → remote photograph (`imageURL`) → remote illustration
/// (`illustrationURL`). Assets whose name starts with `placeholder` and every image of a sample
/// stop are flagged as placeholders.
@MainActor
final class CompositeImageLoader: ImageLoader {
    private let cache = NSCache<NSString, CacheEntry>()
    private let session: URLSession
    private var inFlight: [String: Task<LoadedImage?, Never>] = [:]
    /// Stops for which every source failed; retried only after `retryInterval`.
    private var failures: [String: Date] = [:]
    private let retryInterval: TimeInterval = 120

    private final class CacheEntry {
        let value: LoadedImage
        init(_ value: LoadedImage) { self.value = value }
    }

    init(session: URLSession? = nil) {
        self.session = session ?? CompositeImageLoader.makeSession()
        cache.countLimit = 8
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = 15
        configuration.urlCache = URLCache(memoryCapacity: 8 * 1024 * 1024, diskCapacity: 64 * 1024 * 1024)
        return URLSession(configuration: configuration)
    }

    func cachedImage(for stop: HistoricalStop) -> LoadedImage? {
        cache.object(forKey: stop.id as NSString)?.value
    }

    func image(for stop: HistoricalStop) async -> LoadedImage? {
        if let cached = cachedImage(for: stop) { return cached }
        guard stop.hasAnyImage else { return nil }
        return await load(key: stop.id) { [weak self] in await self?.resolve(stop) }
    }

    func image(for photo: HistoricalStopPhoto, at stop: HistoricalStop) async -> LoadedImage? {
        let key = "\(stop.id)|photo|\(photo.imageName)"
        return await load(key: key) { [weak self] in
            await self?.localImage(named: photo.imageName, isSample: stop.isSample)
        }
    }

    private func load(key: String, resolve: @escaping @MainActor () async -> LoadedImage?) async -> LoadedImage? {
        if let cached = cache.object(forKey: key as NSString)?.value { return cached }
        if let failedAt = failures[key], Date().timeIntervalSince(failedAt) < retryInterval { return nil }
        if let task = inFlight[key] { return await task.value }

        let task = Task<LoadedImage?, Never> { await resolve() }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        if let result {
            cache.setObject(CacheEntry(result), forKey: key as NSString,
                            cost: result.image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0)
            failures[key] = nil
        } else {
            failures[key] = Date()
        }
        return result
    }

    func prefetch(_ stops: [HistoricalStop]) {
        for stop in stops where cachedImage(for: stop) == nil && stop.hasAnyImage {
            Task { [weak self] in _ = await self?.image(for: stop) }
        }
    }

    private func resolve(_ stop: HistoricalStop) async -> LoadedImage? {
        if let photo = stop.galleryPhotos.first,
           let image = await image(for: photo, at: stop) {
            return image
        }
        if let url = stop.imageURL, let image = await download(url) {
            return LoadedImage(image: image, kind: .photograph, isPlaceholder: stop.isSample)
        }
        if let url = stop.illustrationURL, let image = await download(url) {
            return LoadedImage(image: image, kind: .illustration, isPlaceholder: stop.isSample)
        }
        return nil
    }

    private func localImage(named name: String, isSample: Bool) async -> LoadedImage? {
        await Task.detached(priority: .utility) { () -> LoadedImage? in
            guard let image = UIImage(named: name) else { return nil }
            return LoadedImage(image: image.preparingForDisplay() ?? image,
                               kind: name.lowercased().contains("illustration") ? .illustration : .photograph,
                               isPlaceholder: isSample || name.lowercased().hasPrefix("placeholder"))
        }.value
    }

    /// Downloads and decodes off the main actor. Any failure yields `nil` — never an error (spec §21).
    private func download(_ url: URL) async -> UIImage? {
        guard url.scheme == "https" || url.scheme == "http" || url.isFileURL else { return nil }
        let session = self.session
        return await Task.detached(priority: .utility) { () -> UIImage? in
            guard let (data, response) = try? await session.data(from: url) else { return nil }
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return nil }
            guard let image = UIImage(data: data) else { return nil }
            // Decode now so the first draw on the main thread does not stall.
            return image.preparingForDisplay() ?? image
        }.value
    }
}
