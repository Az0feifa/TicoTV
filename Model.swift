// TicoTV — estado de la app: navegación, catálogo, búsqueda global y reproductor
import SwiftUI
import AVKit
import Combine

// MARK: - Tema
let accent = Color(red: 0.95, green: 0.64, blue: 0.23)      // ámbar "luz de cine"
let liveRed = Color(red: 0.90, green: 0.28, blue: 0.30)
let pageBG = Color(white: 0.07)
let cardBG = Color(white: 0.14)
let pagePad: CGFloat = 32

func norm(_ s: String) -> String { s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) }

func meta(_ c: Channel) -> String {
    var p: [String] = []
    switch c.kind {
    case .movie: p.append("Película")
    case .series: p.append("Serie")
    case .classic: p.append("Cine clásico")
    case .episode: p.append(c.group)
    case .live: p.append(c.group.isEmpty ? "En vivo" : c.group)
    }
    if !c.year.isEmpty { p.append(c.year) }
    if c.minutes > 0 { p.append(c.minutes >= 60 ? "\(c.minutes / 60) h \(c.minutes % 60) min" : "\(c.minutes) min") }
    if !c.rating.isEmpty { p.append(c.rating) }
    return p.joined(separator: " · ")
}

// MARK: - Navegación
enum Dest: String, CaseIterable, Identifiable, Hashable {
    case inicio = "Inicio", buscar = "Buscar", vivo = "En vivo", peliculas = "Películas", series = "Series", milista = "Mi lista", favoritos = "Favoritos"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .inicio: return "house"
        case .buscar: return "magnifyingglass"
        case .vivo: return "dot.radiowaves.left.and.right"
        case .peliculas: return "film"
        case .series: return "tv"
        case .favoritos: return "star"
        case .milista: return "plus.rectangle.on.rectangle"
        }
    }
}

enum Route: Hashable {
    case detail(Channel)
    case grid(String, [Channel])
}

@MainActor final class Nav: ObservableObject {
    static let shared = Nav()
    @Published var dest: Dest? = .inicio
    @Published var path: [Route] = []
    @Published var columns: NavigationSplitViewVisibility = .all
    @Published var searchFocusTick = 0
    func go(_ d: Dest) { dest = d; path = [] }
    func open(_ c: Channel) { path.append(.detail(c)) }
    func showAll(_ title: String, _ items: [Channel]) { path.append(.grid(title, items)) }
    func focusSearch() { go(.buscar); searchFocusTick += 1 }
}

// MARK: - Géneros (agrupan las ~140 categorías de Pluto en chips)
struct Genre: Identifiable, Hashable { let name: String; let keys: [String]; var id: String { name } }
let classicChip = "Cine clásico"
let movieGenres: [Genre] = [
    Genre(name: "Todo", keys: []),
    Genre(name: "Nuevo", keys: ["nuevo", "recomend", "imperdible", "semana", "destacado", "maratonear"]),
    Genre(name: "Acción", keys: ["acción", "accion", "adrenalina"]),
    Genre(name: "Comedia", keys: ["comedia", "humor"]),
    Genre(name: "Drama", keys: ["drama"]),
    Genre(name: "Terror", keys: ["terror", "horror", "plutoween", "malditos", "oscuridad", "nanita", "final girls"]),
    Genre(name: "Suspenso y crimen", keys: ["suspenso", "crimen", "thriller"]),
    Genre(name: "Romance", keys: ["romance", "amor"]),
    Genre(name: "Ciencia ficción", keys: ["sci-fi", "ficción", "star trek"]),
    Genre(name: "Familia", keys: ["familia", "kids", "animad", "peli-kids", "perruno"]),
    Genre(name: "En español", keys: ["español", "latino", "mexicana"]),
    Genre(name: "Documentales", keys: ["document"]),
    Genre(name: "Clásicos", keys: ["clásico", "retro", "hollywood"]),
]
let seriesGenres: [Genre] = [
    Genre(name: "Todo", keys: []),
    Genre(name: "Drama", keys: ["drama"]),
    Genre(name: "Comedia", keys: ["comedia", "stand up", "sketch"]),
    Genre(name: "Crimen", keys: ["crimen", "investig", "policía", "policial", "corte"]),
    Genre(name: "Anime", keys: ["anime", "naruto", "one piece", "bleach", "pokémon", "boruto", "inuyasha", "yu-gi", "bakugan"]),
    Genre(name: "Novelas", keys: ["novela"]),
    Genre(name: "Reality", keys: ["reality", "mtv", "competencia", "cocina", "masterchef", "desafio"]),
    Genre(name: "Infantil", keys: ["nick", "kids", "junior", "preescolar", "caricatura", "canta"]),
    Genre(name: "Terror y misterio", keys: ["terror", "paranormal", "misterio", "suspenso"]),
    Genre(name: "Documentales", keys: ["historia", "ciencia", "naturaleza", "fauna", "civilizaciones", "smithsonian"]),
]
func matches(_ g: Genre, _ cat: String) -> Bool { g.keys.isEmpty || g.keys.contains { norm(cat).contains(norm($0)) } }

// MARK: - Catálogo
struct Shelf: Identifiable, Hashable { let id: String; let name: String; let items: [Channel] }
struct LiveCat: Identifiable, Hashable { let name: String; let ids: Set<String>; var id: String { name } }
enum LoadState { case idle, loading, ok, failed }

@MainActor final class Catalog: ObservableObject {
    static let shared = Catalog()
    @Published var plutoLive: [Channel] = []
    @Published var liveCats: [LiveCat] = []
    @Published var vod: [Shelf] = []
    @Published var vodIndex: [Channel] = []
    @Published var plutoState: LoadState = .idle
    @Published var iptv: [String: [Channel]] = [:]
    @Published var archive: [String: [Channel]] = [:]
    @Published var failed: Set<String> = []
    @Published var favorites: [Channel] = []
    @Published var history: [Channel] = []
    @Published var recents: [String] = []
    @Published var dead: Set<String> = []
    @Published var watchlist: [Channel] = []
    @Published var lastRefresh = Date()

    init() { reloadUserData() }
    private func k(_ key: String) -> String { Profiles.shared.keyPrefix + key }
    func reloadUserData() {
        favorites = load("favorites.v2"); history = load("history.v1"); watchlist = load("watchlist.v1")
        recents = UserDefaults.standard.stringArray(forKey: k("recents.v1")) ?? []
        ProgressStore.shared.reload()
    }
    /// Solo se aceptan favoritos guardados cuyo enlace interno o remoto sea válido.
    static func validStored(_ c: Channel) -> Bool {
        if c.isArchive || c.url.hasPrefix("pluto:") || c.url.hasPrefix("plutoseries:") { return true }
        if let (_, payload) = ExtraSources.shared.provider(for: c.url) { return !payload.isEmpty && payload.count < 400 }
        return isSafeRemoteURL(c.url)
    }
    private func load(_ key: String) -> [Channel] {
        guard let d = UserDefaults.standard.data(forKey: k(key)), let f = try? JSONDecoder().decode([Channel].self, from: d) else { return [] }
        return f.filter(Catalog.validStored)
    }
    private func save(_ v: [Channel], _ key: String) { if let d = try? JSONEncoder().encode(v) { UserDefaults.standard.set(d, forKey: k(key)) } }

    /// Vuelve a descargar todo (catálogo actualizado de Pluto, listas de canales y cine clásico).
    func refresh() async {
        await PlutoClient.shared.invalidate()
        dead = []                                   // archive (dominio público) se conserva
        await loadPluto(force: true)
        for u in Set(iptv.keys).union([crURL]) {    // recarga las listas abiertas sin vaciar la pantalla
            let old = iptv.removeValue(forKey: u)
            await loadIPTV(u)
            if iptv[u] == nil, let old { iptv[u] = old; failed.remove(u) }
        }
        lastRefresh = Date()
    }
    func inList(_ c: Channel) -> Bool { watchlist.contains { $0.id == c.id } }
    func toggleList(_ c: Channel) {
        if inList(c) { watchlist.removeAll { $0.id == c.id } } else { watchlist.insert(c, at: 0) }
        save(watchlist, "watchlist.v1")
    }

    func loadPluto(force: Bool = false) async {
        if plutoState == .loading || (plutoState == .ok && !force) { return }
        plutoState = .loading
        do {
            async let l = plutoLiveAll()
            async let v = plutoVodShelves()
            let (live, cats) = try await l
            plutoLive = live; liveCats = cats
            vod = try await v
            var seen = Set<String>(); var idx: [Channel] = []
            for s in vod { for c in s.items where !seen.contains(c.id) { seen.insert(c.id); idx.append(c) } }
            vodIndex = idx
            plutoState = .ok
        } catch { plutoState = .failed }
    }
    func loadIPTV(_ url: String) async {
        if iptv[url] != nil { return }
        failed.remove(url)
        guard let u = URL(string: url), let d = try? await fetchCapped(u) else { failed.insert(url); return }
        var seen = Set<String>()
        iptv[url] = parseM3U(String(decoding: d, as: UTF8.self)).filter { seen.insert($0.id).inserted }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    func loadArchive(_ q: String) async {
        if archive[q] != nil { return }
        failed.remove(q)
        guard let r = try? await archiveSearch(q, rows: 60) else { failed.insert(q); return }
        archive[q] = r
    }

    func liveChannels(_ cat: String?) -> [Channel] {
        guard let cat, let c = liveCats.first(where: { $0.name == cat }) else { return alive(plutoLive) }
        return alive(plutoLive.filter { c.ids.contains($0.pid) })
    }
    func alive(_ l: [Channel]) -> [Channel] { l.filter { !dead.contains($0.id) } }
    var heroItem: Channel? {
        let shelf = vod.first { norm($0.name).contains("nuevo") } ?? vod.first
        let pool = shelf?.items.filter { $0.kind == .movie && !$0.backdrop.isEmpty } ?? []
        guard !pool.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return pool[day % pool.count]
    }
    var homeShelves: [Shelf] { Array(vod.filter { $0.items.count >= 6 && !norm($0.name).contains("destacado") }.prefix(8)) }
    func related(_ c: Channel) -> [Channel] {
        let pool = vod + ExtraSources.shared.allShelves
        return Array((pool.first { s in s.items.contains { $0.id == c.id } }?.items ?? []).filter { $0.id != c.id }.prefix(20))
    }

    func isFav(_ c: Channel) -> Bool { favorites.contains { $0.id == c.id } }
    func toggleFav(_ c: Channel) {
        if isFav(c) { favorites.removeAll { $0.id == c.id } } else { favorites.insert(c, at: 0) }
        save(favorites, "favorites.v2")
    }
    func addHistory(_ c: Channel) {
        history.removeAll { $0.id == c.id }; history.insert(c, at: 0)
        if history.count > 40 { history.removeLast(history.count - 40) }
        save(history, "history.v1")
    }
    func addRecent(_ q: String) {
        let t = q.trimmingCharacters(in: .whitespaces); guard t.count >= 2 else { return }
        recents.removeAll { norm($0) == norm(t) }; recents.insert(String(t.prefix(60)), at: 0)
        if recents.count > 8 { recents.removeLast(recents.count - 8) }
        UserDefaults.standard.set(recents, forKey: k("recents.v1"))
    }
    func clearRecents() { recents = []; UserDefaults.standard.removeObject(forKey: k("recents.v1")) }
    func markDead(_ c: Channel) { if c.kind == .live { dead.insert(c.id) } }
}

// MARK: - Búsqueda global
enum SKind: String, CaseIterable, Identifiable { case vivo = "Canales en vivo", peli = "Películas", serie = "Series", clasico = "Cine clásico"; var id: String { rawValue } }

@MainActor final class SearchModel: ObservableObject {
    @Published var q = ""
    @Published var scope: SKind? = nil
    @Published var res: [SKind: [Channel]] = [:]
    @Published var loading: Set<SKind> = []
    @Published var failed: Set<SKind> = []
    @Published var searched = ""
    private var bag = Set<AnyCancellable>()
    private var task: Task<Void, Never>?
    private var lastRun = ""

    init() {
        $q.removeDuplicates().debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .sink { [weak self] t in Task { @MainActor in self?.run(t) } }
            .store(in: &bag)
    }
    var tooShort: Bool { q.trimmingCharacters(in: .whitespaces).count < 2 }
    var total: Int { res.values.reduce(0) { $0 + $1.count } }

    func run(_ raw: String, force: Bool = false) {
        let t = raw.trimmingCharacters(in: .whitespaces)
        if !force && t == lastRun && t.count >= 2 { return }
        lastRun = t
        task?.cancel()
        guard t.count >= 2 else { res = [:]; loading = []; failed = []; searched = ""; return }
        searched = t
        res = local(t); failed = []
        loading = [.vivo, .peli, .serie, .clasico]
        task = Task { @MainActor [weak self] in
            async let p = SearchModel.pluto(t)
            async let a = SearchModel.archive(t)
            let pr = await p
            guard let self, !Task.isCancelled else { return }
            if let pr {
                self.add(.peli, pr.0.filter { $0.kind == .movie })
                self.add(.serie, pr.0.filter { $0.kind == .series })
                let ids = Set(pr.1); self.add(.vivo, Catalog.shared.plutoLive.filter { ids.contains($0.pid) })
            } else { self.failed.formUnion([.peli, .serie]) }
            self.loading.subtract([.vivo, .peli, .serie])
            for p in allProviders {
                let r = await p.search(t)
                guard !Task.isCancelled else { return }
                self.add(.vivo, r.filter { $0.kind == .live }); self.add(.peli, r.filter { $0.kind == .movie }); self.add(.serie, r.filter { $0.kind == .series })
            }
            let ar = await a
            guard !Task.isCancelled else { return }
            if let ar { self.add(.clasico, ar) } else { self.failed.insert(.clasico) }
            self.loading.remove(.clasico)
        }
    }
    private func add(_ k: SKind, _ items: [Channel]) {
        var cur = res[k] ?? []; var seen = Set(cur.map(\.id))
        for c in items where !seen.contains(c.id) { cur.append(c); seen.insert(c.id) }
        res[k] = cur
    }
    private func local(_ t: String) -> [SKind: [Channel]] {
        let n = norm(t); let c = Catalog.shared
        func hit(_ x: Channel) -> Bool { norm(x.name).contains(n) }
        var live = c.alive(c.plutoLive.filter(hit)); var seen = Set(live.map(\.id))
        for list in c.iptv.values { for x in c.alive(list) where hit(x) && !seen.contains(x.id) { live.append(x); seen.insert(x.id) } }
        for x in c.alive(ExtraSources.shared.allLive) where hit(x) && !seen.contains(x.id) { live.append(x); seen.insert(x.id) }
        var vod = c.vodIndex.filter(hit); var sv = Set(vod.map(\.id))
        for sh in ExtraSources.shared.allShelves { for x in sh.items where hit(x) && !sv.contains(x.id) { vod.append(x); sv.insert(x.id) } }
        var cl: [Channel] = []; var s2 = Set<String>()
        for list in c.archive.values { for x in list where hit(x) && !s2.contains(x.id) { cl.append(x); s2.insert(x.id) } }
        return [.vivo: Array(live.prefix(80)), .peli: vod.filter { $0.kind == .movie }, .serie: vod.filter { $0.kind == .series }, .clasico: cl]
    }
    nonisolated static func pluto(_ t: String) async -> ([Channel], [String])? { try? await plutoSearch(t) }
    nonisolated static func archive(_ t: String) async -> [Channel]? {
        let special = CharacterSet(charactersIn: "+-&|!(){}[]^\"~*?:\\/")
        let safe = String(String(t.unicodeScalars.map { special.contains($0) ? " " : Character($0) }).prefix(80)).lowercased()
        guard !safe.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let q = "(collection:feature_films OR collection:Film_Noir OR collection:SciFi_Horror OR collection:silent_films OR collection:classic_cartoons) AND title:(\(safe))"
        return try? await archiveSearch(q, rows: 40)
    }
}

// MARK: - Reproductor
@MainActor final class PlayerModel: ObservableObject {
    static let shared = PlayerModel()
    let player = AVPlayer()
    @Published var status = ""
    @Published var failedNow = false
    @Published var current: Channel?
    @Published var expanded = false
    @Published var isPlaying = false
    @Published var upNext: Channel?
    @Published var upNextCountdown = 0
    @Published var queue: [Channel] = []          // episodios de la serie actual (para "siguiente")
    private var obs: NSKeyValueObservation?
    private var tcObs: NSKeyValueObservation?
    private var monitor: Any?
    private var timeObs: Any?
    private var endObs: NSObjectProtocol?
    private var countdownTimer: Timer?
    private var lastSave = Date.distantPast
    private var upNextDismissed: String?

    init() {
        tcObs = player.observe(\.timeControlStatus) { [weak self] p, _ in
            let playing = p.timeControlStatus != .paused
            DispatchQueue.main.async { self?.isPlaying = playing; self?.publishNowPlaying() }
        }
        timeObs = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 5, preferredTimescale: 1), queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.tickProgress() }
        }
        DispatchQueue.main.async { NowPlayingCenter.setup() }   // diferido: evita re-entrar en PlayerModel.shared
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self else { return e }
            return MainActor.assumeIsolated { self.handleKey(e) } ? nil : e
        }
    }

    func play(_ c: Channel, queue q: [Channel]? = nil) {
        if c.kind == .series { Nav.shared.open(c); return }
        saveProgressNow()
        cancelUpNext()
        player.pause(); player.replaceCurrentItem(with: nil)   // evita grabar progreso del ítem viejo bajo el id nuevo
        if let q { queue = q } else if c.kind != .episode { queue = [] }
        current = c; failedNow = false
        expand()
        Catalog.shared.addHistory(c)
        if c.isArchive {
            status = "Buscando la película…"
            Task { @MainActor in
                let u = try? await archiveStreamURL(c.archiveID)
                guard self.current?.id == c.id else { return }
                if let u {
                    var m = c; m.url = u.absoluteString; m.archiveID = ""; self.start(m, original: c)
                } else { self.fail("Esta película no tiene un formato reproducible.", c) }
            }
        } else if c.url.hasPrefix("pluto:") {
            status = "Conectando con Pluto TV…"
            Task { @MainActor in
                let u = try? await PlutoClient.shared.streamURL(String(c.url.dropFirst(6)))
                guard self.current?.id == c.id else { return }
                if let u = u ?? nil {
                    var m = c; m.url = u.absoluteString; self.start(m, original: c)
                } else { self.fail("Pluto TV no respondió. Intente de nuevo en un momento.", c) }
            }
        } else if let (prov, payload) = ExtraSources.shared.provider(for: c.url) {
            status = "Conectando con \(prov.name)…"
            Task { @MainActor in
                let u = try? await prov.streamURL(payload)
                guard self.current?.id == c.id else { return }
                if let u = u ?? nil {
                    var m = c; m.url = u.absoluteString; self.start(m, original: c)
                } else { self.fail("\(prov.name) no respondió. Intente de nuevo en un momento.", c) }
            }
        } else { start(c, original: c) }
    }
    private func start(_ c: Channel, original: Channel) {
        guard isSafeRemoteURL(c.url), let u = URL(string: c.url) else { fail("Enlace no permitido por seguridad.", original); return }
        var headers: [String: String] = [:]
        if !c.userAgent.isEmpty { headers["User-Agent"] = c.userAgent }
        if !c.referer.isEmpty, isSafeRemoteURL(c.referer) { headers["Referer"] = c.referer }
        let item = AVPlayerItem(asset: AVURLAsset(url: u, options: headers.isEmpty ? nil : ["AVURLAssetHTTPHeaderFieldsKey": headers]))
        status = "Conectando…"
        let resume = original.kind == .live ? nil : ProgressStore.shared.resumePoint(original.id)
        if let endObs { NotificationCenter.default.removeObserver(endObs) }
        endObs = NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.itemEnded(original) }
        }
        obs = item.observe(\.status) { [weak self] it, _ in
            DispatchQueue.main.async {
                guard let self, self.current?.id == original.id else { return }
                switch it.status {
                case .readyToPlay:
                    if self.status.hasPrefix("Conectando") || self.status.hasPrefix("Buscando") { self.status = "" }
                    self.preferSpanish(it)
                    if let r = resume, it.currentTime().seconds < 5 {
                        it.seek(to: CMTime(seconds: r - 3, preferredTimescale: 600), completionHandler: nil)
                        self.toast("Continuando donde quedó")
                    }
                    self.publishNowPlaying()
                case .failed: self.fail("«\(original.name)» no está transmitiendo ahora.", original)
                default: break
                }
            }
        }
        player.replaceCurrentItem(with: item)
        player.play()
    }
    private func fail(_ msg: String, _ c: Channel) { status = msg; failedNow = true; Catalog.shared.markDead(c) }

    func expand() { expanded = true; NSApp.keyWindow?.makeFirstResponder(nil) }
    func minimize() { expanded = false }
    func stop() {
        saveProgressNow(); cancelUpNext(); SleepTimer.shared.set(.off)
        player.pause(); player.replaceCurrentItem(with: nil)
        current = nil; expanded = false; status = ""; failedNow = false; queue = []
        NowPlayingCenter.update(nil, playing: false, pos: 0, dur: 0)
    }

    // MARK: progreso
    private func tickProgress() {
        guard let c = current, c.kind != .live, let item = player.currentItem else { return }
        let pos = item.currentTime().seconds, dur = item.duration.seconds
        ProgressStore.shared.update(c.id, pos: pos, dur: dur)
        if Date().timeIntervalSince(lastSave) > 30 { ProgressStore.shared.persist(); lastSave = Date() }
        // Mostrar el aviso del siguiente episodio en los últimos 25 s
        if dur.isFinite, dur > 120, dur - pos < 25, upNext == nil, upNextCountdown == 0, upNextDismissed != c.id, let n = nextEpisode(), SleepTimer.shared.mode != .endOfItem {
            upNext = n; startCountdown(Int(max(5, min(15, dur - pos))))
        }
        publishNowPlaying()
    }
    func saveProgressNow() {
        guard let c = current, c.kind != .live, let item = player.currentItem else { return }
        ProgressStore.shared.update(c.id, pos: item.currentTime().seconds, dur: item.duration.seconds)
        ProgressStore.shared.persist()
    }
    func publishNowPlaying() {
        let item = player.currentItem
        NowPlayingCenter.update(current, playing: isPlaying, pos: item?.currentTime().seconds ?? 0, dur: item?.duration.seconds ?? 0)
    }
    func toast(_ t: String) {
        status = t
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in if self?.status == t { self?.status = "" } }
    }

    // MARK: siguiente episodio
    func nextEpisode() -> Channel? {
        guard let c = current, c.kind == .episode, let i = queue.firstIndex(where: { $0.id == c.id }), i + 1 < queue.count else { return nil }
        return queue[i + 1]
    }
    private func prevEpisode() -> Channel? {
        guard let c = current, c.kind == .episode, let i = queue.firstIndex(where: { $0.id == c.id }), i > 0 else { return nil }
        return queue[i - 1]
    }
    private func itemEnded(_ c: Channel) {
        guard current?.id == c.id else { return }
        let d = player.currentItem?.duration.seconds ?? 0
        ProgressStore.shared.update(c.id, pos: d, dur: d); ProgressStore.shared.persist()   // visto completo
        if SleepTimer.shared.mode == .endOfItem { SleepTimer.shared.fire(); return }
        if upNextDismissed != c.id, let n = nextEpisode() {
            if upNext == nil { upNext = n }
            playUpNext()
        }
    }
    private func startCountdown(_ s: Int) {
        countdownTimer?.invalidate(); upNextCountdown = s
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isPlaying else { return }      // en pausa, la cuenta se detiene
                self.upNextCountdown -= 1
                if self.upNextCountdown <= 0 { self.playUpNext() }
            }
        }
    }
    func playUpNext() {
        countdownTimer?.invalidate(); upNextCountdown = 0
        guard let n = upNext else { return }
        upNext = nil
        play(n, queue: queue)
    }
    func cancelUpNext() { countdownTimer?.invalidate(); upNextCountdown = 0; upNext = nil }
    func dismissUpNext() { upNextDismissed = current?.id; cancelUpNext() }
    @discardableResult func playNextAny() -> Bool { if let n = nextEpisode() { play(n, queue: queue); return true }; return false }
    @discardableResult func playPrevAny() -> Bool { if let p = prevEpisode() { play(p, queue: queue); return true }; return false }
    func togglePause() { guard current != nil else { return }; isPlaying ? player.pause() : player.play() }
    func seek(_ s: Double) {
        guard current?.kind != .live else { return }
        player.seek(to: CMTimeAdd(player.currentTime(), CMTime(seconds: s, preferredTimescale: 600)))
    }
    private func handleKey(_ e: NSEvent) -> Bool {
        let typing = NSApp.keyWindow?.firstResponder is NSTextView
        if e.keyCode == 53, !expanded, !typing, !Nav.shared.path.isEmpty { Nav.shared.path.removeLast(); return true }
        guard current != nil, expanded else { return false }
        if typing { return false }
        if !e.modifierFlags.intersection([.command, .control, .option]).isEmpty { return false }
        switch e.keyCode {
        case 36, 76: return true                                              // return: no relanzar el botón por defecto oculto
        case 49: togglePause(); return true                                   // espacio
        case 53:                                                              // esc
            if let w = NSApp.keyWindow, w.styleMask.contains(.fullScreen) { w.toggleFullScreen(nil) } else { minimize() }
            return true
        case 123: seek(-10); return true                                      // ←
        case 124: seek(10); return true                                       // →
        default: break
        }
        if e.charactersIgnoringModifiers?.lowercased() == "n" { return playNextAny() }   // n en cualquier distribución
        if e.charactersIgnoringModifiers?.lowercased() == "f" { NSApp.keyWindow?.toggleFullScreen(nil); return true }
        return false
    }
}
