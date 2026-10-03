// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Az0feifa <https://github.com/Az0feifa>
// TicoTV — núcleo: modelo, fuentes legales (iptv-org, archive.org), seguridad y parser M3U
import SwiftUI
import AVKit

enum Kind: String, Codable, Hashable { case live, movie, series, episode, classic }

struct Channel: Identifiable, Hashable, Codable {
    var id: String { archiveID.isEmpty ? url : archiveID }
    let name: String
    var url: String
    let logo: String
    let group: String
    var userAgent: String = ""
    var referer: String = ""
    var archiveID: String = ""
    var year: String = ""
    var kind: Kind = .live
    var pid: String = ""          // id de Pluto TV
    var backdrop: String = ""     // imagen 16:9
    var summary: String = ""
    var rating: String = ""
    var minutes: Int = 0
    var season: Int = 0
    var episode: Int = 0
    var isArchive: Bool { !archiveID.isEmpty }
}

struct Source: Identifiable, Hashable {
    var id: String { url }
    let name: String
    let url: String
    var isMovies: Bool { url.hasPrefix("ia:") || url.hasPrefix("plutovod:") }
    var isPluto: Bool { url.hasPrefix("plutolive:") || url.hasPrefix("plutovod:") }
    var iaQuery: String { String(url.dropFirst(3)) }
}

// Películas de dominio público / libre distribución en Internet Archive (archive.org)
let movieSources: [Source] = [
    Source(name: "Más vistas", url: "ia:collection:feature_films AND (licenseurl:*publicdomain* OR licenseurl:*creativecommons*)"),
    Source(name: "En español", url: "ia:collection:feature_films AND language:(spa OR Spanish OR español) AND (licenseurl:*publicdomain* OR licenseurl:*creativecommons*)"),
    Source(name: "Cine negro", url: "ia:collection:Film_Noir"),
    Source(name: "Ciencia ficción y terror", url: "ia:collection:SciFi_Horror"),
    Source(name: "Cine mudo y Chaplin", url: "ia:collection:silent_films"),
    Source(name: "Caricaturas clásicas", url: "ia:collection:classic_cartoons"),
]
let adultFilter = " AND mediatype:movies AND NOT subject:(sex* OR erot* OR porn* OR sex OR erotic OR erotica OR nudity OR adult OR exploitation OR sexploitation OR burlesque OR stag) AND NOT title:(sex* OR sexu* OR erot* OR nud* OR porn* OR madness OR xxx OR pleasure OR naked)"

struct IASearch: Decodable { struct R: Decodable { let docs: [Doc] }; let response: R }
struct Doc: Decodable {
    let identifier: String
    let title: FlexString?
    let year: FlexString?
}
struct FlexString: Decodable {
    let value: String
    init(from d: Decoder) throws {
        let c = try d.singleValueContainer()
        if let s = try? c.decode(String.self) { value = s }
        else if let i = try? c.decode(Int.self) { value = String(i) }
        else if let a = try? c.decode([String].self) { value = a.first ?? "" }
        else { value = "" }
    }
}
struct IAMeta: Decodable { struct F: Decodable { let name: String; let format: String?; let size: String? }; let files: [F]? }

func archiveSearch(_ q: String, rows: Int = 120) async throws -> [Channel] {
    var c = URLComponents(string: "https://archive.org/advancedsearch.php")!
    c.queryItems = [URLQueryItem(name: "q", value: q + adultFilter),
                    URLQueryItem(name: "fl[]", value: "identifier"),
                    URLQueryItem(name: "fl[]", value: "title"),
                    URLQueryItem(name: "fl[]", value: "year"),
                    URLQueryItem(name: "sort[]", value: "downloads desc"),
                    URLQueryItem(name: "rows", value: String(rows)),
                    URLQueryItem(name: "output", value: "json")]
    guard let searchURL = c.url else { throw URLError(.badURL) }
    let data = try await fetchCapped(searchURL)
    let r = try JSONDecoder().decode(IASearch.self, from: data)
    return r.response.docs.map {
        Channel(name: $0.title?.value ?? $0.identifier, url: "",
                logo: "https://archive.org/services/img/\($0.identifier)",
                group: $0.year?.value ?? "", archiveID: $0.identifier, year: $0.year?.value ?? "", kind: .classic)
    }
}

/// Busca el mejor MP4 reproducible de una película
func archiveStreamURL(_ id: String) async throws -> URL? {
    guard id.range(of: "^[A-Za-z0-9._-]{1,120}$", options: .regularExpression) != nil,
          let metaURL = URL(string: "https://archive.org/metadata/\(id)") else { return nil }
    let data = try await fetchCapped(metaURL)
    let files = (try JSONDecoder().decode(IAMeta.self, from: data)).files ?? []
    let mp4 = files.filter { $0.name.lowercased().hasSuffix(".mp4") || $0.name.lowercased().hasSuffix(".m4v") }
    let pick = mp4.first { ($0.format ?? "").lowercased().contains("h.264") && !($0.format ?? "").contains("IA") }
        ?? mp4.first { ($0.format ?? "").contains("512Kb") }
        ?? mp4.max { (Int($0.size ?? "0") ?? 0) < (Int($1.size ?? "0") ?? 0) }
    guard let f = pick,
          let enc = f.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
    return URL(string: "https://archive.org/download/\(id)/\(enc)")
}

let base = "https://iptv-org.github.io/iptv"
let sources: [Source] = [
    Source(name: "Costa Rica", url: "\(base)/countries/cr.m3u"),
    Source(name: "México", url: "\(base)/countries/mx.m3u"),
    Source(name: "España", url: "\(base)/countries/es.m3u"),
    Source(name: "Argentina", url: "\(base)/countries/ar.m3u"),
    Source(name: "Colombia", url: "\(base)/countries/co.m3u"),
    Source(name: "Panamá", url: "\(base)/countries/pa.m3u"),
    Source(name: "Estados Unidos", url: "\(base)/countries/us.m3u"),
    Source(name: "Todo en español", url: "\(base)/languages/spa.m3u"),
    Source(name: "Noticias", url: "\(base)/categories/news.m3u"),
    Source(name: "Películas", url: "\(base)/categories/movies.m3u"),
    Source(name: "Deportes", url: "\(base)/categories/sports.m3u"),
    Source(name: "Infantil", url: "\(base)/categories/kids.m3u"),
    Source(name: "Música", url: "\(base)/categories/music.m3u"),
    Source(name: "Documentales", url: "\(base)/categories/documentary.m3u"),
]

// MARK: - Seguridad: validación de datos remotos

/// Solo http(s) hacia hosts públicos: bloquea file://, localhost, .local e IPs privadas/LAN.
func isSafeRemoteURL(_ s: String) -> Bool {
    guard let u = URL(string: s), let scheme = u.scheme?.lowercased(),
          scheme == "http" || scheme == "https",
          let host = u.host?.lowercased(), !host.isEmpty, u.user == nil else { return false }
    if host == "localhost" || host.hasSuffix(".local") || host.hasSuffix(".localhost")
        || host.hasSuffix(".lan") || host.hasSuffix(".internal") || host == "0.0.0.0"
        || host.contains(":") || host.hasPrefix("[") { return false }   // IPv6 literales fuera
    let p = host.split(separator: ".").compactMap { Int($0) }
    if p.count == 4 && host.split(separator: ".").count == 4 {
        if p[0] == 10 || p[0] == 127 || p[0] == 0 || p[0] >= 224
            || (p[0] == 169 && p[1] == 254) || (p[0] == 172 && (16...31).contains(p[1]))
            || (p[0] == 192 && p[1] == 168) || (p[0] == 100 && (64...127).contains(p[1])) { return false }
    }
    return true
}
func isSafeImageURL(_ s: String) -> URL? {
    guard s.lowercased().hasPrefix("https://"), isSafeRemoteURL(s) else { return nil }
    return URL(string: s)
}
/// Cabeceras HTTP: solo ASCII imprimible y máximo 256 caracteres.
func cleanHeader(_ s: String) -> String {
    String(String(s.unicodeScalars.filter { $0.value >= 0x20 && $0.value < 0x7F }.map(Character.init)).prefix(256))
}
/// Descargas con tiempo límite y tamaño máximo (evita que un archivo gigante cuelgue la app).
let netSession: URLSession = {
    let c = URLSessionConfiguration.ephemeral          // sin caché ni cookies persistentes
    c.timeoutIntervalForRequest = 20; c.timeoutIntervalForResource = 90
    c.httpCookieAcceptPolicy = .never; c.httpShouldSetCookies = false
    return URLSession(configuration: c)
}()
/// Redirecciones: solo https a hosts públicos; si `allowed` existe, el destino debe estar en esa lista.
/// Si cambia el host se quitan las cabeceras con credenciales (Authorization, X-Plex-Token).
final class RedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let allowed: [String]?
    init(allowed: [String]? = nil) { self.allowed = allowed }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let s = request.url?.absoluteString, s.lowercased().hasPrefix("https://"), isSafeRemoteURL(s) else { return completionHandler(nil) }
        if let allowed, pinnedURL(s, allowed: allowed) == nil { return completionHandler(nil) }
        var r = request
        if request.url?.host?.lowercased() != task.originalRequest?.url?.host?.lowercased() {
            r.setValue(nil, forHTTPHeaderField: "Authorization"); r.setValue(nil, forHTTPHeaderField: "X-Plex-Token")
        }
        completionHandler(r)
    }
}
func fetchCapped(_ request: URLRequest, max: Int = 20_000_000) async throws -> Data {
    guard request.url?.scheme?.lowercased() == "https" else { throw URLError(.secureConnectionFailed) }
    let (bytes, resp) = try await netSession.bytes(for: request, delegate: RedirectGuard())
    if resp.expectedContentLength > Int64(max) { throw URLError(.dataLengthExceedsMaximum) }
    var d = Data()
    for try await b in bytes { d.append(b); if d.count > max { throw URLError(.dataLengthExceedsMaximum) } }
    return d
}
func fetchCapped(_ url: URL) async throws -> Data { try await fetchCapped(URLRequest(url: url)) }

func parseM3U(_ text: String) -> [Channel] {
    var out: [Channel] = []
    var info: String? = nil
    var ua = "", ref = ""
    func attr(_ line: String, _ key: String) -> String {
        guard let r = line.range(of: "\(key)=\"") else { return "" }
        return String(line[r.upperBound...].prefix { $0 != "\"" })
    }
    func displayName(_ line: String) -> String {
        var inQ = false; var idx: String.Index? = nil
        for i in line.indices {
            if line[i] == "\"" { inQ.toggle() }
            else if line[i] == "," && !inQ { idx = i; break }
        }
        guard let i = idx else { return "Canal" }
        var n = String(line[line.index(after: i)...])
        n = n.replacingOccurrences(of: #"\s*\((\d{3,4}p)\)"#, with: "", options: .regularExpression)
        n = n.replacingOccurrences(of: "[Not 24/7]", with: "· a ratos")
        n = n.replacingOccurrences(of: "[Geo-blocked]", with: "· bloqueo geográfico")
        return n.trimmingCharacters(in: .whitespaces)
    }
    for raw in text.components(separatedBy: .newlines) {
        let line = raw.trimmingCharacters(in: .whitespaces)
        if line.hasPrefix("#EXTINF") {
            info = line; ua = cleanHeader(attr(line, "http-user-agent")); ref = cleanHeader(attr(line, "http-referrer"))
        } else if line.hasPrefix("#EXTVLCOPT:http-user-agent=") {
            ua = cleanHeader(String(line.dropFirst("#EXTVLCOPT:http-user-agent=".count)))
        } else if line.hasPrefix("#EXTVLCOPT:http-referrer=") {
            ref = cleanHeader(String(line.dropFirst("#EXTVLCOPT:http-referrer=".count)))
        } else if !line.isEmpty, !line.hasPrefix("#"), let l = info, isSafeRemoteURL(line), out.count < 20_000 {
            out.append(Channel(name: displayName(l), url: line, logo: attr(l, "tvg-logo"),
                               group: attr(l, "group-title"), userAgent: ua, referer: ref))
            info = nil; ua = ""; ref = ""
        }
    }
    return out
}

let crURL = "\(base)/countries/cr.m3u"
