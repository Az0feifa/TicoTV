// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Az0feifa <https://github.com/Az0feifa>
// TicoTV — señales en vivo publicadas por las propias emisoras (verificadas 01/10/2026 desde Costa Rica).
// Cada URL proviene del reproductor oficial de la emisora (ver `fuente`). Si una emisora cambia su URL,
// el canal se marca como caído automáticamente y deja de mostrarse.
import Foundation

enum OficialesProvider: StreamProvider {
    static let id = "ofic"
    static let name = "Canales oficiales"

    private struct Ch { let name, url, logo, group, fuente: String }
    private static let list: [Ch] = [
        Ch(name: "Repretel Canal 6", url: "https://d3xpfoln9sj56.cloudfront.net/ts:abr.m3u8", logo: "https://i.imgur.com/nfKJftW.png", group: "Costa Rica", fuente: "repretel.com/envivo-canal6"),
        Ch(name: "Repretel Canal 4", url: "https://ddycmnicl95kp.cloudfront.net/live/1a04m9qnerwa/master.m3u8", logo: "https://i.imgur.com/5arZEgO.png", group: "Costa Rica", fuente: "repretel.com/envivo-canal4"),
        Ch(name: "DW Español", url: "https://dwamdstream104.akamaized.net/hls/live/2015530/dwstream104/master.m3u8", logo: "https://i.imgur.com/8MRNFb9.png", group: "Noticias", fuente: "dw.com/es/live-tv"),
        Ch(name: "France 24 Español", url: "https://live.france24.com/hls/live/2037220-b/F24_ES_HI_HLS/master_5000.m3u8", logo: "", group: "Noticias", fuente: "france24.com/es/en-vivo"),
        Ch(name: "RTVE Canal 24 Horas", url: "https://ztnr.rtve.es/ztnr/1694255.m3u8", logo: "https://i.ibb.co/21sXZ3GT/24h.png", group: "Noticias", fuente: "rtve.es/play"),
        Ch(name: "TVE Internacional América", url: "https://rtvelivestream-rtveplayplus.rtve.es/rtvesec/int/tvei_ame_main_1080.m3u8", logo: "https://i.ibb.co/RpKLCMvp/tve.png", group: "España", fuente: "rtve.es/play"),
        Ch(name: "Star TVE", url: "https://rtvelivestream-rtveplayplus.rtve.es/rtvesec/int/star_main_1080.m3u8", logo: "https://i.ibb.co/j98NY8Mr/starcolor.png", group: "España", fuente: "rtve.es/play"),
        Ch(name: "La 1 (TVE)", url: "https://rtvelivestream.rtve.es/rtvesec/la1/la1_main_dvr.m3u8", logo: "https://i.ibb.co/MxJNPHsn/La-1.png", group: "España", fuente: "rtve.es/play"),
        Ch(name: "Canal Sur 2", url: "https://rtva-channel22.flumotion.cloud/playlist.m3u8", logo: "", group: "España", fuente: "canalsurmas.es"),
        Ch(name: "Canal Sur Más Noticias", url: "https://rtva-channel42.flumotion.cloud/playlist.m3u8", logo: "https://i.imgur.com/A3JscwS.png", group: "España", fuente: "canalsurmas.es"),
        Ch(name: "Televisión Canaria", url: "https://rtvclive.flumotion.cloud/rtvc1live/smil:channel1PRG.smil/playlist.m3u8", logo: "", group: "España", fuente: "canariasplay.es"),
        Ch(name: "Canal Extremadura Infantil", url: "https://cdn-canalextremadura.watchity.net/fast2/master.m3u8", logo: "", group: "Infantil", fuente: "canalextremadura.app"),
        Ch(name: "Canal Parlamento (España)", url: "https://congresodirecto.akamaized.net/hls/live/2037973/canalparlamento/master.m3u8", logo: "https://i.imgur.com/BUO0wH6.png", group: "Noticias", fuente: "congreso.es"),
        Ch(name: "Canal 22 (México)", url: "https://5fc584f3f19c9.streamlock.net/canal22/videocanal22/playlist.m3u8", logo: "https://i.imgur.com/6qiYvhe.png", group: "México", fuente: "canal22.org.mx"),
        Ch(name: "TV UNAM", url: "https://5fc584f3f19c9.streamlock.net/tvunam/videotvunam/playlist.m3u8", logo: "", group: "México", fuente: "tv.unam.mx"),
        Ch(name: "Capital 21 (CDMX)", url: "https://video.cdmx.gob.mx/redes/stream.m3u8", logo: "https://i.imgur.com/8ign49i.png", group: "México", fuente: "capital21.cdmx.gob.mx"),
    ]

    static func load() async throws -> ProviderCatalog {
        var cat = ProviderCatalog()
        cat.live = list.compactMap { c in
            guard c.url.hasPrefix("https://"), isSafeRemoteURL(c.url) else { return nil }
            var ch = Channel(name: c.name, url: c.url, logo: c.logo, group: "Oficial · " + c.group)
            ch.pid = "ofic-" + c.name; ch.summary = "Señal oficial publicada en " + c.fuente
            return ch
        }
        let groups = Dictionary(grouping: cat.live, by: { String($0.group.dropFirst("Oficial · ".count)) })
        cat.liveCats = groups.keys.sorted().map { k in LiveCat(name: k, ids: Set((groups[k] ?? []).map(\.pid))) }
        return cat
    }
    // Las URLs son directas (https y validadas): PlayerModel las reproduce sin pasar por aquí.
    static func streamURL(_ payload: String) async throws -> URL? { nil }
    static func search(_ q: String) async -> [Channel] {
        let n = norm(q); guard n.count >= 2, let c = try? await load() else { return [] }
        return c.live.filter { norm($0.name).contains(n) }
    }
}
