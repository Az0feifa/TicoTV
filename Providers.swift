// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Copyright (C) 2026 Az0feifa <https://github.com/Az0feifa>
// TicoTV — interfaz común para fuentes gratuitas y legales adicionales (Plex, Samsung TV Plus, etc.)
import Foundation

/// Lo que cada fuente aporta al catálogo general.
struct ProviderCatalog {
    var live: [Channel] = []          // canales en vivo (kind = .live)
    var liveCats: [LiveCat] = []      // categorías de esos canales (LiveCat.ids contiene Channel.pid)
    var shelves: [Shelf] = []         // filas a la carta (películas .movie y series .series)
}

/// Cada fuente vive en su propio archivo Prov_<Nombre>.swift y se registra en `allProviders`.
/// Reglas de seguridad obligatorias:
///  - Toda descarga con fetchCapped(...) (HTTPS, tope de tamaño, sin cookies).
///  - Todo host remoto validado con pinnedURL(_:allowed:) contra una lista fija de dominios oficiales.
///  - IDs remotos validados con isSafeID(_:) antes de meterlos en una URL.
///  - El stream final debe pasar isSafeRemoteURL(...) (lo vuelve a comprobar PlayerModel).
///  - Solo contenido en español (latino o España) o subtitulado al español.
protocol StreamProvider {
    static var id: String { get }              // prefijo de URL interna, p. ej. "plex" -> "plex:<payload>"
    static var name: String { get }            // nombre visible, p. ej. "Plex"
    static func load() async throws -> ProviderCatalog
    static func streamURL(_ payload: String) async throws -> URL?   // payload = lo que va después de "<id>:"
    static func search(_ q: String) async -> [Channel]
    static func episodes(_ series: Channel) async throws -> [Channel]
}

extension StreamProvider {
    static func search(_ q: String) async -> [Channel] { [] }
    static func episodes(_ series: Channel) async throws -> [Channel] { [] }
}

/// Milisegundos remotos -> minutos sin trap (Int(Double) revienta con NaN, ±inf o > Int.max).
func safeMinutes(_ ms: Double?) -> Int {
    guard let ms, ms.isFinite, ms > 0, ms < 1e12 else { return 0 }
    return Int(ms / 60000)
}

func isSafeID(_ s: String, max: Int = 128) -> Bool {
    !s.isEmpty && s.count <= max && s.range(of: "^[A-Za-z0-9._~-]+$", options: .regularExpression) != nil
}

/// Devuelve la URL solo si es https y su host termina en alguno de los dominios permitidos.
func pinnedURL(_ s: String, allowed: [String]) -> URL? {
    guard let u = URL(string: s), u.scheme?.lowercased() == "https", u.user == nil, u.port == nil || u.port == 443,
          let h = u.host?.lowercased() else { return nil }
    let ok = allowed.contains { d in h == d || h.hasSuffix("." + d) }
    return ok && isSafeRemoteURL(s) ? u : nil
}
