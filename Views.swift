// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Copyright (C) 2026 Az0feifa <https://github.com/Az0feifa>
// TicoTV — pantallas
import SwiftUI

// MARK: - App y estructura
@main
struct TicoTVApp: App {
    var body: some Scene {
        WindowGroup("TicoTV") {
            RootView().preferredColorScheme(.dark).frame(minWidth: 1000, minHeight: 640)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .textEditing) {
                Button("Buscar") { Nav.shared.focusSearch() }.keyboardShortcut("f", modifiers: .command)
            }
            CommandGroup(replacing: .appInfo) {
                Button("Acerca de TicoTV") {
                    let credits = NSMutableAttributedString(string: "Creado por Az0feifa\n", attributes: [.font: NSFont.systemFont(ofSize: 11)])
                    credits.append(NSAttributedString(string: "github.com/Az0feifa", attributes: [.link: URL(string: "https://github.com/Az0feifa") as Any, .font: NSFont.systemFont(ofSize: 11)]))
                    credits.append(NSAttributedString(string: "\n\nTV, películas y series gratis y legales en español.", attributes: [.font: NSFont.systemFont(ofSize: 11)]))
                    NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            CommandGroup(replacing: .help) {
                Link("TicoTV en GitHub", destination: URL(string: "https://github.com/Az0feifa/TicoTV")!)
                Link("Creado por Az0feifa", destination: URL(string: "https://github.com/Az0feifa")!)
            }
            CommandMenu("Catálogo") {
                Button("Actualizar ahora") { Task { await AutoRefresh.refreshAll() } }.keyboardShortcut("r", modifiers: .command)
            }
            CommandMenu("Ir") {
                ForEach(Array(Dest.allCases.enumerated()), id: \.element) { i, d in
                    Button(d.rawValue) { Nav.shared.go(d) }.keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: .command)
                }
            }
        }
    }
}

struct RootView: View {
    @ObservedObject var nav = Nav.shared
    @ObservedObject var pm = PlayerModel.shared
    @ObservedObject var cat = Catalog.shared
    var body: some View {
        NavigationSplitView(columnVisibility: $nav.columns) {
            List(selection: $nav.dest) {
                Section {
                    ForEach(Dest.allCases) { d in Label(d.rawValue, systemImage: d.icon).tag(d) }
                }
                Section("Perfil") { ProfileMenu() }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 250)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Link("Creado por Az0feifa", destination: URL(string: "https://github.com/Az0feifa")!)
                        .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                    Text(creditsLine())
                        .font(.caption2).foregroundStyle(.tertiary)
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            }
        } detail: {
            ZStack {
                NavigationStack(path: $nav.path) {
                    DestView(dest: nav.dest ?? .inicio)
                        .navigationDestination(for: Route.self) { r in
                            switch r {
                            case .detail(let c): DetailView(item: c)
                            case .grid(let t, let items): GridPage(title: t, items: items)
                            }
                        }
                }
                .safeAreaInset(edge: .top, spacing: 0) { NowPlayingBar() }
            }
            .background(pageBG)
        }
        .overlay { PlayerHost() }
        .onChange(of: nav.dest) { _, _ in nav.path = [] ; if pm.expanded { pm.minimize() } }
        .task {
            async let p: Void = cat.loadPluto()
            async let i: Void = cat.loadIPTV(crURL)
            async let x: Void = ExtraSources.shared.load()
            _ = await (p, i, x)
            await GuideStore.shared.load()
            AutoRefresh.start()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in pm.saveProgressNow() }
    }
}

struct DestView: View {
    let dest: Dest
    var body: some View {
        switch dest {
        case .inicio: HomeView()
        case .buscar: SearchView()
        case .vivo: LiveView()
        case .peliculas: VODView(series: false)
        case .series: VODView(series: true)
        case .favoritos: FavoritesView()
        case .milista: MyListView()
        }
    }
}

struct MyListView: View {
    @ObservedObject var cat = Catalog.shared
    var body: some View {
        GridOrEmpty(title: "Mi lista", items: cat.watchlist, empty: "Use «Agregar a Mi lista» en la página de una película o serie para guardar lo que quiere ver después.")
    }
}

struct PlayerHost: View {
    @ObservedObject var pm = PlayerModel.shared
    var body: some View {
        ZStack {
            if pm.expanded && pm.current != nil { PlayerOverlay().transition(.opacity) }
        }.animation(.easeInOut(duration: 0.2), value: pm.expanded)
    }
}

// MARK: - Inicio (superficie de exploración; único hero de la app)
struct HomeView: View {
    @ObservedObject var cat = Catalog.shared
    @ObservedObject var extra = ExtraSources.shared
    @ObservedObject var ps = ProgressStore.shared
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 30) {
                if let h = cat.heroItem { Hero(item: h) } else if cat.plutoState == .loading { HeroPlaceholder() }
                if !cat.continueWatching.isEmpty {
                    ShelfRow(title: "Seguir viendo", items: cat.continueWatching) { WideCard(item: $0) }
                }
                if !cat.watchlist.isEmpty { ShelfRow(title: "Mi lista", items: cat.watchlist) { PosterCard(item: $0) } }
                if let (seed, rec) = cat.recommendations() { ShelfRow(title: "Porque vio «\(seed)»", items: rec) { PosterCard(item: $0) } }
                if let cr = cat.iptv[crURL], !cr.isEmpty {
                    ShelfRow(title: "Canales de Costa Rica", items: cat.alive(cr)) { WideCard(item: $0, width: 220) }
                }
                let movies = cat.liveChannels("Películas")
                if !movies.isEmpty { ShelfRow(title: "Cine en vivo", items: movies, subtitle: "Pluto TV") { WideCard(item: $0, width: 220) } }
                ForEach(cat.homeShelves) { s in ShelfRow(title: s.name, items: s.items) { PosterCard(item: $0) } }
                ForEach(extra.allShelves.prefix(6)) { s in ShelfRow(title: s.name, items: s.items) { PosterCard(item: $0) } }
                if cat.plutoState == .failed {
                    EmptyState(icon: "wifi.exclamationmark", title: "Pluto TV no respondió",
                               message: "Revise su conexión a internet.", action: ("Reintentar", { Task { await cat.loadPluto(force: true) } }))
                }
            }.padding(.bottom, 40)
        }
        .navigationTitle("Inicio")
    }
}

struct Hero: View {
    let item: Channel
    @ObservedObject var cat = Catalog.shared
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(url: item.backdrop).frame(height: 400).frame(maxWidth: .infinity).clipped()
            LinearGradient(stops: [.init(color: .clear, location: 0.35), .init(color: pageBG, location: 1)], startPoint: .top, endPoint: .bottom)
            LinearGradient(colors: [pageBG.opacity(0.85), .clear], startPoint: .leading, endPoint: .center)
            VStack(alignment: .leading, spacing: 10) {
                Text("DESTACADO DE HOY").font(.caption.weight(.heavy)).tracking(1.2).foregroundStyle(accent)
                Text(item.name).font(.system(size: 34, weight: .heavy)).lineLimit(2)
                Text(meta(item)).font(.callout).foregroundStyle(.secondary)
                if !item.summary.isEmpty { Text(item.summary).lineLimit(3).foregroundStyle(.secondary).frame(maxWidth: 520, alignment: .leading) }
                HStack(spacing: 10) {
                    Button { PlayerModel.shared.play(item) } label: { Label("Reproducir", systemImage: "play.fill").padding(.horizontal, 6) }
                        .buttonStyle(.borderedProminent).tint(accent).foregroundStyle(.black).controlSize(.large)
                    Button { Nav.shared.open(item) } label: { Label("Detalles", systemImage: "info.circle") }
                        .buttonStyle(.bordered).controlSize(.large)
                    Button { cat.toggleList(item) } label: { Image(systemName: cat.inList(item) ? "checkmark" : "plus") }
                        .buttonStyle(.bordered).controlSize(.large).help(cat.inList(item) ? "En Mi lista" : "Agregar a Mi lista")
                    Button { cat.toggleFav(item) } label: { Image(systemName: cat.isFav(item) ? "star.fill" : "star") }
                        .buttonStyle(.bordered).controlSize(.large).help("Favoritos")
                }.padding(.top, 4)
            }.padding(.horizontal, pagePad).padding(.bottom, 26)
        }
    }
}

struct HeroPlaceholder: View {
    var body: some View { cardBG.frame(height: 400).overlay(ProgressView()) }
}

// MARK: - Buscar (superficie de comando: el teclado manda, sin hero)
final class FocusBox: ObservableObject { @Published var tick = 0 }

struct SearchField: NSViewRepresentable {
    @Binding var text: String
    let focusTick: Int
    let onSubmit: () -> Void
    func makeNSView(context: Context) -> NSSearchField {
        let f = NSSearchField()
        f.placeholderString = "Busque canales, películas, series o cine clásico"
        f.font = .systemFont(ofSize: 17); f.controlSize = .large
        f.delegate = context.coordinator; f.sendsSearchStringImmediately = true
        f.focusRingType = .default
        DispatchQueue.main.async { f.window?.makeFirstResponder(f) }
        return f
    }
    func updateNSView(_ f: NSSearchField, context: Context) {
        if f.stringValue != text { f.stringValue = text }
        if context.coordinator.lastTick != focusTick {
            context.coordinator.lastTick = focusTick
            DispatchQueue.main.async { f.window?.makeFirstResponder(f) }
        }
    }
    func makeCoordinator() -> Coord { Coord(self) }
    final class Coord: NSObject, NSSearchFieldDelegate {
        var p: SearchField; var lastTick = -1
        init(_ p: SearchField) { self.p = p }
        func controlTextDidChange(_ n: Notification) { if let f = n.object as? NSSearchField { p.text = f.stringValue } }
        func control(_ c: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
            if sel == #selector(NSResponder.insertNewline(_:)) { p.onSubmit(); return true }
            return false
        }
    }
}

struct SearchView: View {
    @StateObject var m = SearchModel()
    @ObservedObject var cat = Catalog.shared
    @ObservedObject var nav = Nav.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                SearchField(text: $m.q, focusTick: nav.searchFocusTick) { cat.addRecent(m.q); m.run(m.q) }
                    .frame(height: 34).padding(.horizontal, pagePad)
                ChipBar(options: ["Todo"] + SKind.allCases.map(\.rawValue), selected: m.scope?.rawValue ?? "Todo") { o in
                    m.scope = SKind(rawValue: o)
                }
            }
            .padding(.top, 22).padding(.bottom, 12)
            Divider().opacity(0.4)
            ScrollView {
                if m.tooShort { SearchHome(m: m) } else { SearchResults(m: m) }
            }
        }
        .navigationTitle("Buscar")
        .onDisappear { if !m.q.isEmpty { cat.addRecent(m.q) } }
    }
}

struct SearchHome: View {
    @ObservedObject var m: SearchModel
    @ObservedObject var cat = Catalog.shared
    let ideas = ["Acción", "Comedia", "Terror", "Naruto", "Novelas", "Noticias", "Chaplin", "Costa Rica"]
    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            if !cat.recents.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Búsquedas recientes").font(.title3.weight(.semibold))
                        Spacer()
                        Button("Borrar historial") { cat.clearRecents() }.buttonStyle(.link).foregroundStyle(.secondary)
                    }
                    FlowChips(items: cat.recents, icon: "clock.arrow.circlepath") { m.q = $0 }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Ideas para buscar").font(.title3.weight(.semibold))
                FlowChips(items: ideas, icon: "sparkle.magnifyingglass") { m.q = $0 }
            }
            Text("Busca en todo Pluto TV, en los canales abiertos cargados y en el cine clásico de archive.org.")
                .font(.callout).foregroundStyle(.secondary)
        }
        .padding(.horizontal, pagePad).padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FlowChips: View {
    let items: [String]
    var icon = ""
    let pick: (String) -> Void
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130, maximum: 220), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { t in
                Button { pick(t) } label: {
                    Label(t, systemImage: icon).lineLimit(1).font(.callout)
                        .padding(.horizontal, 12).frame(height: 30).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain)
            }
        }
    }
}

struct SearchResults: View {
    @ObservedObject var m: SearchModel
    var kinds: [SKind] { SKind.allCases.filter { m.scope == nil || m.scope == $0 } }
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 28) {
            ForEach(kinds) { k in
                let items = m.res[k] ?? []
                if !items.isEmpty || m.loading.contains(k) || m.failed.contains(k) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Text(k.rawValue).font(.title3.weight(.semibold))
                            if !items.isEmpty { Text("\(items.count)").foregroundStyle(.secondary) }
                            if m.loading.contains(k) {
                                ProgressView().controlSize(.small)
                                Text(k == .clasico ? "Buscando en archive.org…" : "Buscando en Pluto TV…").font(.caption).foregroundStyle(.secondary)
                            }
                            if m.failed.contains(k) && items.isEmpty {
                                Text("No respondió.").font(.caption).foregroundStyle(.secondary)
                                Button("Reintentar") { m.run(m.q, force: true) }.buttonStyle(.link).foregroundStyle(accent)
                            }
                            Spacer()
                            if m.scope == nil && items.count > 8 {
                                Button("Ver los \(items.count)") { m.scope = k }.buttonStyle(.link).foregroundStyle(accent)
                            }
                        }.padding(.horizontal, pagePad)
                        if m.scope == nil {
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(alignment: .top, spacing: 16) {
                                    ForEach(items.prefix(12)) { c in
                                        if k == .vivo { WideCard(item: c, width: 220) } else { PosterCard(item: c) }
                                    }
                                }.padding(.horizontal, pagePad).padding(.vertical, 8)
                            }
                        } else if !items.isEmpty {
                            ItemGrid(items: items)
                        }
                    }
                }
            }
            if m.loading.isEmpty && kinds.allSatisfy({ (m.res[$0] ?? []).isEmpty }) && !m.searched.isEmpty {
                EmptyState(icon: "magnifyingglass", title: "No encontramos «\(m.searched)»",
                           message: "Revise la ortografía o pruebe con otra palabra, por ejemplo el nombre de un actor o un género.")
            }
        }.padding(.vertical, 20)
    }
}

// MARK: - En vivo
final class LiveUI: ObservableObject {
    @Published var source = "Pluto TV"
    @Published var extraCat = "Todos"
    @Published var plutoCat = "Todos"
    @Published var country = "Costa Rica"
}

struct LiveView: View {
    @StateObject var ui = LiveUI()
    @ObservedObject var cat = Catalog.shared
    var iptvSource: Source? { sources.first { $0.name == ui.country } }
    var liveSubtitle: String {
        switch ui.source {
        case "Pluto TV": return "Canales de Pluto TV, gratis con anuncios"
        case "Abiertos": return "Canales abiertos de televisión (listas públicas)"
        case "Canales oficiales": return "Señales publicadas por las propias televisoras"
        default: return "Canales de \(ui.source) en español, gratis con anuncios"
        }
    }
    @ObservedObject var extra = ExtraSources.shared
    @ObservedObject var guide = GuideStore.shared
    var extraCatalog: ProviderCatalog? { allProviders.first { $0.name == ui.source }.flatMap { extra.catalogs[$0.id] } }
    var items: [Channel] {
        if ui.source == "Pluto TV" { return cat.liveChannels(ui.plutoCat == "Todos" ? nil : ui.plutoCat) }
        if let ec = extraCatalog {
            guard ui.extraCat != "Todos", let c = ec.liveCats.first(where: { $0.name == ui.extraCat }) else { return cat.alive(ec.live) }
            return cat.alive(ec.live.filter { c.ids.contains($0.pid) })
        }
        guard let s = iptvSource else { return [] }
        return cat.alive(cat.iptv[s.url] ?? [])
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .bottom) {
                    PageTitle(title: "En vivo", subtitle: liveSubtitle)
                    Spacer()
                    Picker("", selection: $ui.source) {
                        Text("Pluto TV").tag("Pluto TV")
                        ForEach(extra.liveProviderNames(), id: \.self) { Text($0).tag($0) }
                        Text("Canales abiertos").tag("Abiertos")
                    }.pickerStyle(.segmented).labelsHidden().fixedSize().padding(.trailing, pagePad)
                }
                if ui.source == "Pluto TV" {
                    ChipBar(options: ["Todos"] + cat.liveCats.map(\.name), selected: ui.plutoCat) { ui.plutoCat = $0 }
                } else if let ec = extraCatalog {
                    if !ec.liveCats.isEmpty {
                        ChipBar(options: ["Todos"] + ec.liveCats.map { shortCat($0.name) }, selected: shortCat(ui.extraCat)) { o in
                            ui.extraCat = ec.liveCats.first { shortCat($0.name) == o }?.name ?? "Todos"
                        }
                    }
                } else {
                    ChipBar(options: sources.map(\.name), selected: ui.country) { ui.country = $0 }
                }
                if ui.source == "Pluto TV" && cat.plutoState == .loading { LoadingRow(text: "Cargando canales de Pluto TV…") }
                else if extraCatalog != nil, items.isEmpty { EmptyState(icon: "tv", title: "Sin canales en esta categoría") }
                else if extraCatalog == nil, let s = iptvSource, ui.source != "Pluto TV", cat.failed.contains(s.url) {
                    EmptyState(icon: "wifi.exclamationmark", title: "No se pudo cargar la lista", action: ("Reintentar", { Task { await cat.loadIPTV(s.url) } }))
                } else if extraCatalog == nil, let s = iptvSource, ui.source != "Pluto TV", cat.iptv[s.url] == nil { LoadingRow(text: "Cargando canales…") }
                else if items.isEmpty { EmptyState(icon: "tv", title: "Sin canales en esta categoría") }
                else {
                    Text("\(items.count) canales").font(.caption).foregroundStyle(.secondary).padding(.horizontal, pagePad)
                    ItemGrid(items: items)
                }
            }.padding(.bottom, 40)
        }
        .navigationTitle("En vivo")
        .task(id: ui.country) { if ui.source == "Abiertos", let s = iptvSource { await cat.loadIPTV(s.url) } }
        .onChange(of: ui.source) { _, v in ui.extraCat = "Todos"; if v == "Abiertos", let s = iptvSource { Task { await cat.loadIPTV(s.url) } } }
        .task { await guide.load() }
    }
}

// MARK: - Películas / Series
final class VODUI: ObservableObject { @Published var genre = "Todo"; @Published var classic = movieSources[0].name }

struct VODView: View {
    let series: Bool
    @StateObject var ui = VODUI()
    @ObservedObject var cat = Catalog.shared
    @ObservedObject var extra = ExtraSources.shared
    var genres: [Genre] { series ? seriesGenres : movieGenres }
    var shelves: [Shelf] {
        let g = genres.first { $0.name == ui.genre } ?? genres[0]
        return (cat.vod + extra.allShelves).filter { matches(g, $0.name) }.compactMap { s in
            let items = s.items.filter { $0.kind == (series ? .series : .movie) }
            return items.count >= 3 ? Shelf(id: s.id, name: s.name, items: items) : nil
        }
    }
    var classicSource: Source { movieSources.first { $0.name == ui.classic } ?? movieSources[0] }
    var body: some View {
        let sh = shelves
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                PageTitle(title: series ? "Series" : "Películas",
                          subtitle: ui.genre == classicChip ? "Cine de dominio público · archive.org" : "A la carta en Pluto TV, gratis con anuncios")
                ChipBar(options: genres.map(\.name) + (series ? [] : [classicChip]), selected: ui.genre) { ui.genre = $0 }
                if ui.genre == classicChip {
                    ChipBar(options: movieSources.map(\.name), selected: ui.classic) { ui.classic = $0 }
                    if let items = cat.archive[classicSource.iaQuery] { ItemGrid(items: items).padding(.top, 8) }
                    else if cat.failed.contains(classicSource.iaQuery) {
                        EmptyState(icon: "wifi.exclamationmark", title: "archive.org no respondió", action: ("Reintentar", { Task { await cat.loadArchive(classicSource.iaQuery) } }))
                    } else { LoadingRow(text: "Cargando cine clásico…") }
                } else if cat.plutoState == .loading || cat.plutoState == .idle { LoadingRow(text: "Cargando catálogo de Pluto TV…") }
                else if cat.plutoState == .failed {
                    EmptyState(icon: "wifi.exclamationmark", title: "Pluto TV no respondió", action: ("Reintentar", { Task { await cat.loadPluto(force: true) } }))
                } else if sh.isEmpty { EmptyState(icon: "film", title: "No hay títulos en este género ahora", message: "El catálogo de Pluto cambia cada semana.") }
                else {
                    VStack(alignment: .leading, spacing: 28) {
                        ForEach(sh) { s in ShelfRow(title: s.name, items: s.items) { PosterCard(item: $0) } }
                    }.padding(.top, 8)
                }
            }.padding(.bottom, 40)
        }
        .navigationTitle(series ? "Series" : "Películas")
        .task(id: ui.classic + ui.genre) { if ui.genre == classicChip { await cat.loadArchive(classicSource.iaQuery) } }
    }
}

// MARK: - Favoritos
struct FavoritesView: View {
    @ObservedObject var cat = Catalog.shared
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                PageTitle(title: "Favoritos")
                if cat.favorites.isEmpty {
                    EmptyState(icon: "star", title: "Aún no tiene favoritos",
                               message: "Pulse la estrella sobre cualquier póster o en la página de detalles para guardarlo aquí.")
                }
                if !cat.favorites.isEmpty || !cat.history.isEmpty {
                    let ch = cat.favorites.filter { $0.kind == .live }
                    let vod = cat.favorites.filter { $0.kind != .live }
                    if !ch.isEmpty { ShelfRow(title: "Canales", items: ch) { WideCard(item: $0, width: 220) } }
                    if !vod.isEmpty {
                        Text("Películas y series").font(.title3.weight(.semibold)).padding(.horizontal, pagePad)
                        ItemGrid(items: vod)
                    }
                    if !cat.history.isEmpty { ShelfRow(title: "Vistos recientemente", items: cat.history) { WideCard(item: $0) } }
                }
            }.padding(.bottom, 40)
        }
        .navigationTitle("Favoritos")
    }
}

// MARK: - Rejilla completa ("Ver todo")
struct GridPage: View {
    let title: String
    let items: [Channel]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageTitle(title: title, subtitle: "\(items.count) títulos")
                ItemGrid(items: items)
            }.padding(.bottom, 40)
        }.navigationTitle(title)
    }
}

// MARK: - Detalle de película / serie
final class DetailState: ObservableObject {
    @Published var episodes: [Channel] = []
    @Published var season = 1
    @Published var loading = false
    @Published var failed = false
    @Published var expanded = false
}

struct DetailView: View {
    let item: Channel
    @StateObject var st = DetailState()
    @ObservedObject var cat = Catalog.shared
    var seasons: [Int] { Array(Set(st.episodes.map(\.season))).sorted() }
    /// Último episodio empezado, o el siguiente al último visto, o el primero de la temporada elegida.
    var resumeEpisode: Channel? {
        let hist = Catalog.shared.history.filter { $0.kind == .episode && $0.group == item.name }
        if let last = hist.first, let i = st.episodes.firstIndex(where: { $0.id == last.id }) {
            let done = (ProgressStore.shared.map[last.id].map { $0.dur > 0 && $0.pos >= $0.dur * 0.95 }) ?? false
            if !done || i + 1 >= st.episodes.count { return st.episodes[i] }
            return st.episodes[i + 1]
        }
        return st.episodes.first { $0.season == st.season } ?? st.episodes.first
    }
    var resumeLabel: String {
        guard let e = resumeEpisode else { return "Ver primer episodio" }
        let started = Catalog.shared.history.contains { $0.kind == .episode && $0.group == item.name }
        return started ? "Continuar T\(e.season) · E\(e.episode)" : "Ver primer episodio"
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                if item.kind == .series { episodesSection }
                let rel = cat.related(item)
                if !rel.isEmpty { ShelfRow(title: "Más como este", items: rel) { PosterCard(item: $0) } }
            }.padding(.bottom, 40)
        }
        .navigationTitle(item.name)
        .task {
            guard item.kind == .series, st.episodes.isEmpty else { return }
            st.loading = true
            do {
                if let (prov, _) = ExtraSources.shared.provider(for: item.url) { st.episodes = try await prov.episodes(item) }
                else { st.episodes = try await plutoEpisodes(series: item) }
                st.season = resumeEpisode?.season ?? seasons.first ?? 1
            } catch { st.failed = true }
            st.loading = false
        }
    }

    var header: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if item.kind == .classic { RemoteImage(url: item.logo).blur(radius: 30).opacity(0.6) }
                else { RemoteImage(url: item.backdrop.isEmpty ? item.logo : item.backdrop) }
            }.frame(height: 380).frame(maxWidth: .infinity).clipped()
            LinearGradient(stops: [.init(color: .clear, location: 0.3), .init(color: pageBG, location: 1)], startPoint: .top, endPoint: .bottom)
            LinearGradient(colors: [pageBG.opacity(0.9), .clear], startPoint: .leading, endPoint: .center)
            HStack(alignment: .bottom, spacing: 24) {
                RemoteImage(url: item.logo, label: item.name).frame(width: 170, height: 170 * 500 / 347)
                    .clipShape(RoundedRectangle(cornerRadius: 10)).shadow(color: .black.opacity(0.5), radius: 14, y: 6)
                VStack(alignment: .leading, spacing: 10) {
                    Text(item.name).font(.system(size: 32, weight: .heavy)).lineLimit(2)
                    Text(meta(item)).font(.callout).foregroundStyle(.secondary)
                    if !item.summary.isEmpty {
                        Text(item.summary).lineLimit(st.expanded ? nil : 3).foregroundStyle(.secondary).frame(maxWidth: 560, alignment: .leading)
                        if item.summary.count > 180 { Button(st.expanded ? "Menos" : "Más") { st.expanded.toggle() }.buttonStyle(.link).foregroundStyle(accent) }
                    }
                    HStack(spacing: 10) {
                        if item.kind == .series {
                            Button { if let e = resumeEpisode { PlayerModel.shared.play(e, queue: st.episodes) } } label: {
                                Label(resumeLabel, systemImage: "play.fill").padding(.horizontal, 6)
                            }.buttonStyle(.borderedProminent).tint(accent).foregroundStyle(.black).controlSize(.large).disabled(st.episodes.isEmpty)
                        } else {
                            Button { PlayerModel.shared.play(item) } label: {
                                Label(ProgressStore.shared.resumePoint(item.id) != nil ? "Continuar" : "Reproducir", systemImage: "play.fill").padding(.horizontal, 6)
                            }
                                .buttonStyle(.borderedProminent).tint(accent).foregroundStyle(.black).controlSize(.large)
                                .keyboardShortcut(.defaultAction)
                        }
                        Button { cat.toggleList(item) } label: {
                            Label(cat.inList(item) ? "En Mi lista" : "Mi lista", systemImage: cat.inList(item) ? "checkmark" : "plus")
                        }.buttonStyle(.bordered).controlSize(.large)
                        Button { cat.toggleFav(item) } label: {
                            Label(cat.isFav(item) ? "En Favoritos" : "Favoritos", systemImage: cat.isFav(item) ? "star.fill" : "star")
                        }.buttonStyle(.bordered).controlSize(.large)
                    }.padding(.top, 4)
                }
            }.padding(.horizontal, pagePad).padding(.bottom, 24)
        }
    }

    var episodesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Episodios").font(.title3.weight(.semibold))
                Spacer()
                if seasons.count > 1 {
                    Picker("Temporada", selection: $st.season) { ForEach(seasons, id: \.self) { Text("Temporada \($0)").tag($0) } }
                        .pickerStyle(.menu).frame(width: 170)
                }
            }.padding(.horizontal, pagePad)
            if st.loading { LoadingRow(text: "Cargando episodios…") }
            else if st.failed { EmptyState(icon: "wifi.exclamationmark", title: "No se pudieron cargar los episodios") }
            else {
                LazyVStack(spacing: 2) {
                    ForEach(st.episodes.filter { $0.season == st.season }) { e in EpisodeRow(ep: e, queue: st.episodes) }
                }.padding(.horizontal, pagePad - 8)
            }
        }
    }
}

struct EpisodeRow: View {
    let ep: Channel
    var queue: [Channel] = []
    @ObservedObject private var ps = ProgressStore.shared
    @StateObject private var h = HoverState()
    @ObservedObject private var pm = PlayerModel.shared
    var body: some View {
        HStack(spacing: 14) {
            Text("\(ep.episode)").font(.callout.monospacedDigit()).foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
            VStack(alignment: .leading, spacing: 3) {
                Text(ep.name).font(.callout.weight(.medium)).lineLimit(1)
                if !ep.summary.isEmpty { Text(ep.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
            }
            Spacer()
            if let f = ps.fraction(ep.id) {
                ZStack(alignment: .leading) { Capsule().fill(.white.opacity(0.15)); Capsule().fill(accent).frame(width: 60 * f) }.frame(width: 60, height: 4)
            }
            if ep.minutes > 0 { Text("\(ep.minutes) min").font(.caption).foregroundStyle(.secondary) }
            Image(systemName: pm.current?.id == ep.id ? "speaker.wave.2.fill" : "play.fill")
                .foregroundStyle(h.on || pm.current?.id == ep.id ? accent : .clear).frame(width: 22)
        }
        .padding(.horizontal, 8).frame(minHeight: 60)
        .background(h.on ? Color.white.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onHover { v in h.on = v }
        .onTapGesture { PlayerModel.shared.play(ep, queue: queue) }
        .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text("Episodio \(ep.episode): \(ep.name)"))
        .accessibilityAction { PlayerModel.shared.play(ep, queue: queue) }
    }
}

// MARK: - Mi lista / páginas simples
struct GridOrEmpty: View {
    let title: String
    let items: [Channel]
    let empty: String
    @ObservedObject var cat = Catalog.shared
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageTitle(title: title, subtitle: items.isEmpty ? "" : "\(items.count) títulos")
                if items.isEmpty { EmptyState(icon: "plus.rectangle.on.rectangle", title: "Su lista está vacía", message: empty) }
                else { ItemGrid(items: items) }
            }.padding(.bottom, 40)
        }.navigationTitle(title)
    }
}

// MARK: - Perfiles
final class ProfileUI: ObservableObject { @Published var adding = false; @Published var newName = ""; @Published var open = false }

struct ProfileMenu: View {
    @ObservedObject var pr = Profiles.shared
    @StateObject var ui = ProfileUI()
    var body: some View {
        Button { ui.open.toggle() } label: {
            HStack(spacing: 8) {
                Text(String(pr.current.name.prefix(1)).uppercased()).font(.caption.weight(.bold)).foregroundStyle(.black)
                    .frame(width: 24, height: 24).background(profileColors[pr.current.color % profileColors.count], in: Circle())
                Text(pr.current.name).font(.callout.weight(.medium)).lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(.secondary)
            }.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Cambiar de perfil")
        .popover(isPresented: $ui.open, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Perfiles").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.horizontal, 8)
                ForEach(pr.all) { p in
                    Button { ui.open = false; if p.id != pr.current.id { pr.switchTo(p) } } label: {
                        HStack(spacing: 8) {
                            Text(String(p.name.prefix(1)).uppercased()).font(.caption.weight(.bold)).foregroundStyle(.black)
                                .frame(width: 22, height: 22).background(profileColors[p.color % profileColors.count], in: Circle())
                            Text(p.name)
                            Spacer()
                            if p.id == pr.current.id { Image(systemName: "checkmark").foregroundStyle(accent) }
                        }.padding(.horizontal, 8).frame(height: 30).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                Divider().padding(.vertical, 4)
                if pr.all.count < 6 {
                    Button { ui.open = false; ui.adding = true } label: { Label("Agregar perfil…", systemImage: "plus").padding(.horizontal, 8).frame(height: 28) }
                        .buttonStyle(.plain)
                }
                if pr.current.id != "p1" {
                    Button(role: .destructive) { ui.open = false; pr.remove(pr.current) } label: {
                        Label("Eliminar perfil «\(pr.current.name)»", systemImage: "trash").padding(.horizontal, 8).frame(height: 28)
                    }.buttonStyle(.plain).foregroundStyle(.red)
                }
            }.padding(10).frame(width: 240)
        }
        .sheet(isPresented: $ui.adding) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Nuevo perfil").font(.title3.weight(.semibold))
                Text("Cada perfil tiene su propio historial, favoritos, Mi lista y «Seguir viendo».").font(.callout).foregroundStyle(.secondary)
                TextField("Nombre", text: $ui.newName).textFieldStyle(.roundedBorder).frame(width: 280)
                HStack {
                    Spacer()
                    Button("Cancelar") { ui.adding = false; ui.newName = "" }.keyboardShortcut(.cancelAction)
                    Button("Crear") { pr.add(ui.newName); ui.adding = false; ui.newName = "" }
                        .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).tint(accent)
                        .disabled(ui.newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }.padding(22)
        }
    }
}

/// Quita el prefijo de la fuente en los chips ("Plex · Cine" -> "Cine").
func shortCat(_ s: String) -> String { s.components(separatedBy: " · ").last ?? s }
