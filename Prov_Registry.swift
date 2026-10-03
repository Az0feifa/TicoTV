// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Az0feifa <https://github.com/Az0feifa>
// TicoTV — registro de fuentes adicionales gratuitas y legales (en español o subtituladas).
// Cada Prov_<Nombre>.swift define su enum y se agrega aquí.
let allProviders: [any StreamProvider.Type] = [
    PlexProvider.self,            // Plex: canales en vivo y películas/series en español (oficial, sin cuenta)
    SamsungTVPlusProvider.self,   // Samsung TV Plus: España + Latino EE. UU.
    OficialesProvider.self,       // Señales oficiales de emisoras (Repretel, RTVE, DW, France 24, Canal 22…)
]
