// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Copyright (C) 2026 Az0feifa <https://github.com/Az0feifa>
// TicoTV — Samsung TV Plus (FAST: TV en vivo gratuita y legal con anuncios), solo canales en español.
//
// Fuentes:
//  - Lista de canales: https://i.mjh.nz/SamsungTVPlus/.channels.json (índice comunitario de Matt Huisman;
//    solo metadatos: nombre, logo, categoría, si el canal usa DRM). No aloja contenido.
//  - Stream: https://jmp2.uk/stvp-<id> responde 302 hacia el CDN oficial que usa la app de Samsung TV Plus
//    (sis-global.prod.samsungtv.plus, CloudFront/Akamai/MediaTailor de los canales, Amagi, Rakuten TV FAST,
//    Wurl, Pluto TV stitcher, NewID). Resolvemos la redirección aquí y fijamos el host FINAL contra una lista.
//
// Selección: región España (es) completa + categoría "Latino" de EE. UU. Se omiten canales con DRM
// (license_url) y los que el CDN rechaza desde fuera de su país (403/401) se detectan al reproducir.
import Foundation

private struct STVPRoot: Decodable { let regions: [String: STVPRegion] }
private struct STVPRegion: Decodable { let channels: [String: STVPChannel]? }
private struct STVPChannel: Decodable {
    let name: String
    let chno: Int?
    let logo: String?
    let description: String?
    let group: String?
    let license_url: String?
}

enum SamsungTVPlusProvider: StreamProvider {
    static let id = "stvp"
    static let name = "Samsung TV Plus"

    private static let listURL = "https://i.mjh.nz/SamsungTVPlus/.channels.json"
    private static let listHosts = ["i.mjh.nz"]
    private static let jumpHosts = ["jmp2.uk"]
    /// Hosts finales observados tras la redirección (CDN oficiales de los canales de Samsung TV Plus).
    private static let streamHosts = [
        "samsungtv.plus",            // sis-global.prod.samsungtv.plus (SSAI de Samsung)
        "cloudfront.net",            // AWS CloudFront (MediaTailor de Samsung y de los canales)
        "akamaized.net",             // pb-*.akamaized.net (playout de Samsung)
        "amazonaws.com",             // *.mediatailor.*.amazonaws.com
        "amagi.tv",                  // Amagi (playout FAST)
        "rakuten.tv",                // *.fast.rakuten.tv (Rakuten TV FAST, España)
        "pluto.tv",                  // stitcher de Pluto TV (canales MTV, etc.)
        "wurl.com",                  // Wurl (FAST)
        "its-newid.net",             // NewID (FAST)
    ]
    private static let maxChannels = 600
    /// Exclusión defensiva de contenido para adultos.
    private static let blocked = ["adult", "adulto", "xxx", "+18", "18+", "playboy", "erotic", "erótic", "sexy", "chicas guapas"]

    static func load() async throws -> ProviderCatalog {
        guard let u = pinnedURL(listURL, allowed: listHosts) else { throw URLError(.badURL) }
        let data = try await fetchCapped(URLRequest(url: u), max: 8_000_000)
        let root = try JSONDecoder().decode(STVPRoot.self, from: data)

        // (región, filtro de categoría, sufijo visible)
        let picks: [(String, (String) -> Bool, String)] = [
            ("es", { _ in true }, ""),
            ("us", { $0.lowercased() == "latino" }, " (EE. UU.)"),
        ]
        var live: [Channel] = []
        var cats: [String: Set<String>] = [:]
        var order: [String] = []
        var seenNames = Set<String>()
        for (region, keep, suffix) in picks {
            guard let chans = root.regions[region]?.channels else { continue }
            let sorted = chans.sorted { ($0.value.chno ?? Int.max, $0.key) < ($1.value.chno ?? Int.max, $1.key) }
            for (cid, c) in sorted {
                guard live.count < maxChannels, isSafeID(cid, max: 32) else { continue }
                if let l = c.license_url, !l.isEmpty { continue }              // DRM: no se reproduce en AVPlayer sin licencia
                let grp = (c.group ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard keep(grp) else { continue }
                let nm = String(c.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
                let low = (nm + " " + grp).lowercased()
                guard !nm.isEmpty, !blocked.contains(where: { low.contains($0) }) else { continue }
                guard seenNames.insert(nm.lowercased()).inserted else { continue }   // mismo canal en 2 regiones
                let logo = c.logo.flatMap { isSafeImageURL($0)?.absoluteString } ?? ""
                let catName = "\(name) · " + (grp.isEmpty ? "Varios" : String(grp.prefix(60))) + suffix
                var ch = Channel(name: nm, url: "\(id):\(cid)", logo: logo, group: catName)
                ch.kind = .live; ch.pid = cid
                ch.summary = String((c.description ?? "").prefix(600))
                live.append(ch)
                if cats[catName] == nil { order.append(catName) }
                cats[catName, default: []].insert(cid)
            }
        }
        return ProviderCatalog(live: live, liveCats: order.map { LiveCat(name: $0, ids: cats[$0] ?? []) })
    }

    /// Sigue la redirección de jmp2.uk, exige que el destino final sea un CDN conocido (https) y que
    /// responda una lista HLS (#EXTM3U). Devuelve nil si el canal está bloqueado por región (403/401).
    static func streamURL(_ payload: String) async throws -> URL? {
        guard isSafeID(payload, max: 32),
              let jump = pinnedURL("https://jmp2.uk/stvp-\(payload)", allowed: jumpHosts) else { return nil }
        var req = URLRequest(url: jump)
        req.setValue("okhttp/4.12.0", forHTTPHeaderField: "User-Agent")
        // Igual que fetchCapped (https, sesión efímera sin cookies, tope de tamaño) pero conservando la URL final.
        let (bytes, resp) = try await netSession.bytes(for: req, delegate: RedirectGuard(allowed: streamHosts))
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let final = http.url?.absoluteString,
              let url = pinnedURL(final, allowed: streamHosts) else { return nil }
        if let h = url.host?.lowercased(), h.hasSuffix(".amazonaws.com"), !h.contains(".mediatailor.") { return nil }
        var head = Data()
        for try await b in bytes { head.append(b); if head.count >= 7 { break } }
        guard String(decoding: head, as: UTF8.self).hasPrefix("#EXTM3U") else { return nil }
        return url
    }
}
