// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Az0feifa <https://github.com/Az0feifa>
// Pluto TV (servicio oficial, gratuito y legal con anuncios) — canales en vivo + películas y series a la carta
import Foundation

struct PlutoBoot: Decodable {
    struct Servers: Decodable { let channels: String; let vod: String; let stitcher: String; let search: String? }
    let servers: Servers
    let stitcherParams: String
    let sessionToken: String
    let refreshInSec: Double?
}

struct PlutoImage: Decodable { let type: String?; let url: String? }
struct PlutoPath: Decodable { let path: String? }
struct PlutoCover: Decodable { let aspectRatio: String?; let url: String? }

struct PlutoLiveChannel: Decodable {
    let id: String
    let name: String
    let number: Int?
    let summary: String?
    let images: [PlutoImage]?
    let stitched: PlutoPath?
}
struct PlutoLiveCategory: Decodable { let name: String; let channelIDs: [String] }
struct PlutoList<T: Decodable>: Decodable { let data: [T] }

struct PlutoVodItem: Decodable {
    let _id: String
    let name: String
    let summary: String?
    let type: String?
    let rating: String?
    let genre: String?
    let stitched: PlutoPath?
    let covers: [PlutoCover]?
    let featuredImage: PlutoPath?
    let clip: Clip?
    let duration: Double?
    let originalContentDuration: Double?
    struct Clip: Decodable { let originalReleaseDate: String? }
}
struct PlutoVodCategory: Decodable { let _id: String; let name: String; let items: [PlutoVodItem]? }
struct PlutoVodCategories: Decodable { let categories: [PlutoVodCategory] }
struct PlutoEpisode: Decodable {
    let _id: String
    let name: String
    let number: Int?
    let season: Int?
    let stitched: PlutoPath?
    let duration: Double?
    let originalContentDuration: Double?
    let description: String?
}
struct PlutoTimeline: Decodable { let start: String; let stop: String; let title: String }
struct PlutoChannelTL: Decodable { let channelId: String; let timelines: [PlutoTimeline] }
struct PlutoSearchHit: Decodable { let id: String; let type: String? }
struct PlutoSearchResp: Decodable { let data: [PlutoSearchHit] }
struct PlutoSeason: Decodable { let number: Int?; let episodes: [PlutoEpisode] }
struct PlutoSeries: Decodable { let seasons: [PlutoSeason] }

actor PlutoClient {
    static let shared = PlutoClient()
    private var boot: PlutoBoot?
    private var bootDate = Date.distantPast
    private let clientID: String = {
        let k = "pluto.clientID"
        if let v = UserDefaults.standard.string(forKey: k) { return v }
        let v = UUID().uuidString.lowercased(); UserDefaults.standard.set(v, forKey: k); return v
    }()
    private var vodCache: [PlutoVodCategory] = []
    private var liveCache: ([PlutoLiveChannel], [PlutoLiveCategory])?

    /// Solo se aceptan servidores https://*.pluto.tv (el token nunca sale de Pluto).
    private func pinned(_ s: String) throws -> String {
        guard let u = URL(string: s), u.scheme?.lowercased() == "https", u.user == nil, u.port == nil,
              let h = u.host?.lowercased(), h == "pluto.tv" || h.hasSuffix(".pluto.tv") else {
            throw URLError(.badURL)
        }
        return s.hasSuffix("/") ? String(s.dropLast()) : s
    }
    private func safeID(_ s: String) -> Bool { s.range(of: "^[A-Za-z0-9_-]{1,64}$", options: .regularExpression) != nil }

    func session() async throws -> PlutoBoot {
        if let b = boot, Date().timeIntervalSince(bootDate) < (b.refreshInSec ?? 3600) - 60 { return b }
        var c = URLComponents(string: "https://boot.pluto.tv/v4/start")!
        c.queryItems = [("appName","web"),("appVersion","9.0.0"),("deviceVersion","120.0.0"),("deviceModel","web"),
                        ("deviceMake","chrome"),("deviceType","web"),("clientID",clientID),("clientModelNumber","1.0.0"),
                        ("serverSideAds","false"),("drmCapabilities","")].map { URLQueryItem(name: $0.0, value: $0.1) }
        guard let bootURL = c.url else { throw URLError(.badURL) }
        let d = try await fetchCapped(bootURL)
        let b = try JSONDecoder().decode(PlutoBoot.self, from: d)
        _ = try pinned(b.servers.channels); _ = try pinned(b.servers.vod); _ = try pinned(b.servers.stitcher)
        if let s = b.servers.search { _ = try pinned(s) }
        guard b.stitcherParams.rangeOfCharacter(from: CharacterSet(charactersIn: "#\n\r ")) == nil else { throw URLError(.badURL) }
        boot = b; bootDate = Date(); return b
    }

    private func get<T: Decodable>(_ url: String, _ t: T.Type) async throws -> T {
        let b = try await session()
        guard let u = URL(string: try pinned(url)) else { throw URLError(.badURL) }
        var r = URLRequest(url: u)
        r.setValue("Bearer \(b.sessionToken)", forHTTPHeaderField: "Authorization")
        let d = try await fetchCapped(r)
        return try JSONDecoder().decode(T.self, from: d)
    }

    func live() async throws -> ([PlutoLiveChannel], [PlutoLiveCategory]) {
        if let l = liveCache { return l }
        let b = try await session()
        let ch = try await get(b.servers.channels + "/v2/guide/channels?channelIds=&offset=0&limit=1000&sort=number:asc", PlutoList<PlutoLiveChannel>.self).data
        let cats = try await get(b.servers.channels + "/v2/guide/categories", PlutoList<PlutoLiveCategory>.self).data
        liveCache = (ch, cats); return (ch, cats)
    }

    func vod() async throws -> [PlutoVodCategory] {
        if !vodCache.isEmpty { return vodCache }
        let b = try await session()
        vodCache = try await get(b.servers.vod + "/v4/vod/categories?includeItems=true&offset=1000&page=1&sort=number:asc", PlutoVodCategories.self).categories
        return vodCache
    }

    func episodes(_ seriesID: String) async throws -> [PlutoEpisode] {
        guard safeID(seriesID) else { return [] }
        let b = try await session()
        let s = try await get(b.servers.vod + "/v4/vod/series/\(seriesID)/seasons?offset=1000&page=1", PlutoSeries.self)
        return s.seasons.flatMap { se in se.episodes.map { $0 } }
    }

    /// Borra cachés para traer el catálogo actualizado.
    func invalidate() { vodCache = []; liveCache = nil }

    /// Guía de programación (ahora y después) para los canales dados.
    func guide(_ ids: [String]) async throws -> [String: [PlutoTimeline]] {
        let b = try await session()
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:00:00.000'Z'"
        let start = f.string(from: Date())
        var out: [String: [PlutoTimeline]] = [:]
        let clean = ids.filter(safeID)
        for i in stride(from: 0, to: clean.count, by: 60) {
            let chunk = clean[i..<min(i + 60, clean.count)].joined(separator: ",")
            let url = b.servers.channels + "/v2/guide/timelines?start=\(start)&channelIds=\(chunk)&duration=360"
            let r = try await get(url, PlutoList<PlutoChannelTL>.self).data
            for c in r { out[c.channelId] = c.timelines }
        }
        return out
    }

    /// Búsqueda oficial de Pluto TV (todo el catálogo). Devuelve títulos completos + ids de canales.
    func search(_ q: String) async throws -> ([PlutoVodItem], [String]) {
        let b = try await session()
        guard let s = b.servers.search, var c = URLComponents(string: try pinned(s) + "/v1/search") else { return ([], []) }
        c.queryItems = [URLQueryItem(name: "q", value: String(q.prefix(80))), URLQueryItem(name: "limit", value: "40")]
        guard let u = c.url?.absoluteString else { throw URLError(.badURL) }
        let r = try await get(u, PlutoSearchResp.self)
        let vodIDs = r.data.filter { $0.type == "movie" || $0.type == "series" }.map(\.id).filter(safeID).prefix(30)
        let chIDs = r.data.filter { $0.type == "channel" }.map(\.id).filter(safeID)
        guard !vodIDs.isEmpty else { return ([], chIDs) }
        let items = try await get(b.servers.vod + "/v4/vod/items?ids=" + vodIDs.joined(separator: ","), [PlutoVodItem].self)
        let order = Dictionary(vodIDs.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        return (items.sorted { (order[$0._id] ?? 99) < (order[$1._id] ?? 99) }, chIDs)
    }

    /// URL fresca del stream (el token caduca, por eso se arma al momento de reproducir)
    func streamURL(_ path: String) async throws -> URL? {
        guard path.hasPrefix("/stitch/"), !path.contains(".."), !path.contains("?"), !path.contains("#"),
              !path.contains("@"), !path.contains("//"), path.count < 300 else { return nil }
        let b = try await session()
        return URL(string: "\(try pinned(b.servers.stitcher))/v2\(path)?\(b.stitcherParams)&jwt=\(b.sessionToken)&masterJWTPassthrough=true&includeExtendedEvents=true")
    }
}

// MARK: - Conversión a filas de la app

func plutoChannel(_ c: PlutoLiveChannel) -> Channel? {
    guard let p = c.stitched?.path else { return nil }
    let logo = c.images?.first { $0.type == "colorLogoPNG" }?.url ?? c.images?.first?.url ?? ""
    var ch = Channel(name: c.name, url: "pluto:" + p, logo: logo, group: c.number.map { "Pluto TV · Canal \($0)" } ?? "Pluto TV")
    ch.pid = c.id; ch.summary = c.summary ?? ""
    return ch
}

func plutoItem(_ i: PlutoVodItem) -> Channel? {
    let isSeries = i.type == "series"
    guard isSeries || !(i.stitched?.path ?? "").isEmpty else { return nil }
    let poster = i.covers?.first { $0.aspectRatio == "347:500" }?.url ?? i.featuredImage?.path ?? ""
    let wide = i.featuredImage?.path ?? i.covers?.first { $0.aspectRatio == "16:9" }?.url ?? ""
    var c = Channel(name: i.name, url: isSeries ? "plutoseries:" + i._id : "pluto:" + (i.stitched?.path ?? ""),
                    logo: poster, group: isSeries ? "Serie" : "Película")
    c.kind = isSeries ? .series : .movie
    c.pid = i._id; c.backdrop = wide; c.summary = i.summary ?? ""; c.rating = i.rating ?? ""
    c.year = String((i.clip?.originalReleaseDate ?? "").prefix(4))
    c.minutes = safeMinutes(i.originalContentDuration ?? i.duration)
    return c
}

func plutoLiveAll() async throws -> ([Channel], [LiveCat]) {
    let (ch, cats) = try await PlutoClient.shared.live()
    return (ch.compactMap(plutoChannel), cats.map { LiveCat(name: $0.name, ids: Set($0.channelIDs)) })
}

func plutoVodShelves() async throws -> [Shelf] {
    try await PlutoClient.shared.vod().compactMap { cat in
        let items = (cat.items ?? []).compactMap(plutoItem)
        return items.isEmpty ? nil : Shelf(id: cat._id, name: cat.name, items: items)
    }
}

func plutoEpisodes(series: Channel) async throws -> [Channel] {
    try await PlutoClient.shared.episodes(series.pid).compactMap { e in
        guard let p = e.stitched?.path else { return nil }
        var c = Channel(name: e.name, url: "pluto:" + p, logo: series.logo, group: series.name)
        c.kind = .episode; c.season = e.season ?? 1; c.episode = e.number ?? 0
        c.minutes = safeMinutes(e.originalContentDuration ?? e.duration)
        c.summary = e.description ?? ""; c.backdrop = series.backdrop; c.pid = e._id
        return c
    }
}

func plutoSearch(_ q: String) async throws -> ([Channel], [String]) {
    let (items, ch) = try await PlutoClient.shared.search(q)
    return (items.compactMap(plutoItem), ch)
}
