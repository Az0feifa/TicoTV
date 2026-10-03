// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Copyright (C) 2026 Az0feifa <https://github.com/Az0feifa>
// Plex (servicio oficial, gratuito y legal con anuncios) — canales en vivo + películas y series a la carta.
// Solo API pública de Plex con usuario anónimo (sin cuenta). Se excluye todo lo marcado con DRM.
// Filtro de idioma: canales con language == "es" y los hubs oficiales "En Español" y "Popular Telenovelas".
import Foundation

// MARK: - Modelos JSON (todo opcional: datos remotos)

struct PlexAnon: Decodable { let authToken: String? }

struct PlexPart: Decodable { let id: String?; let key: String? }
struct PlexMedia: Decodable { let drm: Bool?; let `protocol`: String?; let Part: [PlexPart]? }
struct PlexImage: Decodable { let type: String?; let url: String? }

struct PlexLiveChannel: Decodable {
    let id: String?
    let title: String?
    let summary: String?
    let thumb: String?
    let art: String?
    let language: String?
    let hidden: Bool?
    let genreRatingKeys: [String]?
    let Media: [PlexMedia]?
}
struct PlexLineup: Decodable {
    struct MC: Decodable { let Channel: [PlexLiveChannel]? }
    let MediaContainer: MC
}
struct PlexGridFilter: Decodable { let genreRatingKey: String?; let title: String? }
struct PlexFeature: Decodable { let GridChannelFilter: [PlexGridFilter]? }
struct PlexEPGRoot: Decodable {
    struct MP: Decodable { let Feature: [PlexFeature]? }
    let MediaProvider: MP
}

struct PlexMeta: Decodable {
    let ratingKey: String?
    let type: String?
    let title: String?
    let summary: String?
    let year: Int?
    let index: Int?
    let parentIndex: Int?
    let duration: Double?
    let contentRating: String?
    let thumb: String?
    let art: String?
    let Media: [PlexMedia]?
    let Image: [PlexImage]?
}
struct PlexMetaList: Decodable {
    struct MC: Decodable { let Metadata: [PlexMeta]? }
    let MediaContainer: MC
}

enum PlexError: LocalizedError {
    case noToken, unavailable
    var errorDescription: String? {
        switch self {
        case .noToken: return "Plex no entregó un token anónimo (servicio no disponible en esta región)."
        case .unavailable: return "Plex no devolvió contenido en español disponible en esta región."
        }
    }
}

// MARK: - Cliente (token anónimo en caché)

actor PlexClient {
    static let shared = PlexClient()
    static let epg = "https://epg.provider.plex.tv"
    static let vod = "https://vod.provider.plex.tv"
    /// Únicos hosts a los que se envía el token.
    static let apiHosts = ["epg.provider.plex.tv", "vod.provider.plex.tv", "clients.plex.tv"]

    private var token: String?
    private var tokenDate = Date.distantPast
    private var cache: ProviderCatalog?
    private let clientID: String = {
        let k = "plex.clientID"
        if let v = UserDefaults.standard.string(forKey: k), isSafeID(v) { return v }
        let v = UUID().uuidString.lowercased(); UserDefaults.standard.set(v, forKey: k); return v
    }()

    private func headers(_ r: inout URLRequest) {
        r.setValue("Plex Web", forHTTPHeaderField: "X-Plex-Product")
        r.setValue("4.145.0", forHTTPHeaderField: "X-Plex-Version")
        r.setValue("Chrome", forHTTPHeaderField: "X-Plex-Platform")
        r.setValue(clientID, forHTTPHeaderField: "X-Plex-Client-Identifier")
        r.setValue("es", forHTTPHeaderField: "X-Plex-Language")
        r.setValue("application/json", forHTTPHeaderField: "Accept")
    }

    func authToken() async throws -> String {
        if let t = token, Date().timeIntervalSince(tokenDate) < 6 * 3600 { return t }
        guard let u = pinnedURL("https://clients.plex.tv/api/v2/users/anonymous", allowed: Self.apiHosts) else { throw URLError(.badURL) }
        var r = URLRequest(url: u); r.httpMethod = "POST"; headers(&r)
        let d = try await fetchCapped(r, max: 200_000)
        guard let t = try JSONDecoder().decode(PlexAnon.self, from: d).authToken, isSafeID(t, max: 64) else { throw PlexError.noToken }
        token = t; tokenDate = Date(); return t
    }

    private func get<T: Decodable>(_ s: String, _ t: T.Type) async throws -> T {
        guard let u = pinnedURL(s, allowed: Self.apiHosts) else { throw URLError(.badURL) }
        var r = URLRequest(url: u); headers(&r)
        r.setValue(try await authToken(), forHTTPHeaderField: "X-Plex-Token")
        return try JSONDecoder().decode(T.self, from: try await fetchCapped(r))
    }

    func live() async throws -> ([PlexLiveChannel], [String: String]) {
        let ch = try await get(Self.epg + "/lineups/plex/channels", PlexLineup.self).MediaContainer.Channel ?? []
        let root = try? await get(Self.epg + "/", PlexEPGRoot.self)
        var genres: [String: String] = [:]
        for f in root?.MediaProvider.Feature ?? [] {
            for g in f.GridChannelFilter ?? [] { if let k = g.genreRatingKey, let n = g.title { genres[k] = n } }
        }
        return (ch, genres)
    }

    func hub(_ key: String) async throws -> [PlexMeta] {
        guard isSafeID(key) else { return [] }
        return try await get(Self.vod + "/hubs/sections/movies/\(key)?count=200", PlexMetaList.self).MediaContainer.Metadata ?? []
    }

    func children(_ ratingKey: String) async throws -> [PlexMeta] {
        guard isSafeID(ratingKey, max: 64) else { return [] }
        return try await get(Self.vod + "/library/metadata/\(ratingKey)/children", PlexMetaList.self).MediaContainer.Metadata ?? []
    }

    func cached() -> ProviderCatalog? { cache }
    func store(_ c: ProviderCatalog) { cache = c }
    func clear() { cache = nil }

    /// payload = "live:<id>" o "vod:<partID>". URL fresca con el token anónimo.
    func streamURL(_ payload: String) async throws -> URL? {
        let parts = payload.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, isSafeID(parts[1]) else { return nil }
        let base: String
        switch parts[0] {
        case "live": base = Self.epg + "/library/parts/\(parts[1]).m3u8"
        case "vod": base = Self.vod + "/library/parts/\(parts[1])-hls.m3u8"
        default: return nil
        }
        let t = try await authToken()
        guard var c = URLComponents(string: base) else { return nil }
        c.queryItems = [URLQueryItem(name: "X-Plex-Token", value: t),
                        URLQueryItem(name: "X-Plex-Client-Identifier", value: clientID),
                        URLQueryItem(name: "X-Plex-Product", value: "Plex Web"),
                        URLQueryItem(name: "X-Plex-Platform", value: "Chrome")]
        guard let s = c.url?.absoluteString else { return nil }
        return pinnedURL(s, allowed: ["epg.provider.plex.tv", "vod.provider.plex.tv"])
    }
}

// MARK: - Proveedor

enum PlexProvider: StreamProvider {
    static let id = "plex"
    static let name = "Plex"

    /// Hubs oficiales con contenido en español visibles desde Costa Rica.
    private static let hubs: [(key: String, name: String)] = [("en-espanol-us", "En Español"),
                                                             ("popular-telenovelas", "Telenovelas")]

    private static let esGenre: [String: String] = [
        "Bingeworthy": "Series", "Movies": "Cine", "True Crime": "Crimen", "News": "Noticias", "Sports": "Deportes",
        "Reality": "Reality", "Classics": "Clásicos", "Adrenaline & Sci-Fi": "Acción y ciencia ficción",
        "Comedy": "Comedia", "Daytime TV & Games": "Concursos", "Explore": "Documentales",
        "Food, Home & Culture": "Cocina y hogar", "Kids & Family": "Infantil y familia",
        "Global": "Internacional", "Music": "Música"]

    private static func img(_ s: String?) -> String {
        guard let s, isSafeImageURL(s) != nil else { return "" }
        return s
    }
    private static func hlsPartID(_ media: [PlexMedia]?) -> String? {
        let m = media ?? []
        if m.contains(where: { $0.drm == true }) { return nil }            // nunca contenido con DRM
        guard let key = m.first(where: { ($0.protocol ?? "") == "hls" })?.Part?.first?.key,
              key.hasPrefix("/library/parts/"), key.hasSuffix("-hls.m3u8") else { return nil }
        let id = String(key.dropFirst("/library/parts/".count).dropLast("-hls.m3u8".count))
        return isSafeID(id) ? id : nil
    }

    private static func liveChannel(_ c: PlexLiveChannel, genres: [String: String]) -> Channel? {
        guard c.hidden != true, (c.language ?? "").lowercased().hasPrefix("es"),
              let id = c.id, isSafeID(id), let title = c.title, !title.isEmpty,
              !(c.Media ?? []).contains(where: { $0.drm == true }),
              (c.Media ?? []).contains(where: { ($0.protocol ?? "hls") == "hls" }) else { return nil }
        let raw = c.genreRatingKeys?.compactMap { genres[$0] }.first ?? "En Español"
        let cat = esGenre[raw] ?? raw
        var ch = Channel(name: title, url: "plex:live:" + id, logo: img(c.thumb), group: "Plex · " + cat)
        ch.pid = "plex-" + id; ch.summary = c.summary ?? ""; ch.backdrop = img(c.art)
        return ch
    }

    private static func vodItem(_ m: PlexMeta) -> Channel? {
        guard let rk = m.ratingKey, isSafeID(rk, max: 64), let title = m.title, !title.isEmpty,
              !["X", "XXX", "NC-17"].contains((m.contentRating ?? "").uppercased()) else { return nil }
        let poster = img(m.Image?.first { $0.type == "coverPoster" }?.url ?? m.thumb)
        let wide = img(m.Image?.first { $0.type == "background" }?.url ?? m.art)
        let url: String, kind: Kind
        switch m.type {
        case "movie":
            guard let p = hlsPartID(m.Media) else { return nil }
            url = "plex:vod:" + p; kind = .movie
        case "show":
            url = "plex:series:" + rk; kind = .series
        default: return nil
        }
        var c = Channel(name: title, url: url, logo: poster, group: kind == .series ? "Serie" : "Película")
        c.kind = kind; c.pid = rk; c.backdrop = wide; c.summary = m.summary ?? ""
        c.year = m.year.map(String.init) ?? ""; c.rating = m.contentRating ?? ""
        c.minutes = safeMinutes(m.duration)
        return c
    }

    static func load() async throws -> ProviderCatalog {
        if let c = await PlexClient.shared.cached() { return c }
        var cat = ProviderCatalog()
        if let (chs, genres) = try? await PlexClient.shared.live() {
            var seen = Set<String>()
            cat.live = chs.compactMap { liveChannel($0, genres: genres) }.filter { seen.insert($0.pid).inserted }
            let groups = Dictionary(grouping: cat.live, by: { String($0.group.dropFirst("Plex · ".count)) })
            cat.liveCats = groups.keys.sorted().compactMap { k in
                guard let items = groups[k] else { return nil }
                return LiveCat(name: "Plex · " + k, ids: Set(items.map(\.pid)))
            }
        }
        for h in hubs {
            guard let items = try? await PlexClient.shared.hub(h.key).compactMap(vodItem) else { continue }
            let movies = items.filter { $0.kind == .movie }, series = items.filter { $0.kind == .series }
            if !movies.isEmpty { cat.shelves.append(Shelf(id: "plex-\(h.key)-m", name: "Plex · Películas · \(h.name)", items: movies)) }
            if !series.isEmpty { cat.shelves.append(Shelf(id: "plex-\(h.key)-s", name: "Plex · Series · \(h.name)", items: series)) }
        }
        guard !cat.live.isEmpty || !cat.shelves.isEmpty else { throw PlexError.unavailable }
        await PlexClient.shared.store(cat)
        return cat
    }

    static func streamURL(_ payload: String) async throws -> URL? {
        try await PlexClient.shared.streamURL(payload)
    }

    static func episodes(_ series: Channel) async throws -> [Channel] {
        let rk = series.pid
        guard isSafeID(rk, max: 64) else { return [] }
        var out: [Channel] = []
        for season in try await PlexClient.shared.children(rk).prefix(30) {
            guard let sk = season.ratingKey, isSafeID(sk, max: 64) else { continue }
            for e in try await PlexClient.shared.children(sk) {
                guard let p = hlsPartID(e.Media) else { continue }
                var c = Channel(name: e.title ?? "Episodio \(e.index ?? 0)", url: "plex:vod:" + p,
                                logo: img(e.thumb).isEmpty ? series.logo : img(e.thumb), group: series.name)
                c.kind = .episode; c.season = e.parentIndex ?? season.index ?? 1; c.episode = e.index ?? 0
                c.minutes = safeMinutes(e.duration); c.summary = e.summary ?? ""
                c.backdrop = series.backdrop; c.pid = e.ratingKey ?? ""
                out.append(c)
            }
        }
        return out
    }

    /// Plex no ofrece búsqueda pública solo del catálogo gratuito (discover devuelve sobre todo títulos
    /// de otros servicios); se busca localmente en el catálogo en español ya cargado.
    static func search(_ q: String) async -> [Channel] {
        let needle = q.trimmingCharacters(in: .whitespaces).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        guard needle.count >= 2, let cat = try? await load() else { return [] }
        let all = cat.shelves.flatMap(\.items) + cat.live
        var seen = Set<String>()
        return all.filter {
            $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).contains(needle) && seen.insert($0.url).inserted
        }
    }
}
