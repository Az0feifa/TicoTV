// TicoTV — funciones tipo Apple TV: seguir donde quedó, siguiente episodio, temporizador,
// guía de programación, AirPlay, teclas multimedia, Mi lista, perfiles, recomendaciones,
// subtítulos/idioma y actualización automática del catálogo.
import SwiftUI
import AVKit
import MediaPlayer

// MARK: - Perfiles
struct Profile: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var color: Int      // índice de paleta
}
let profileColors: [Color] = [accent, Color(red: 0.36, green: 0.72, blue: 0.95), Color(red: 0.94, green: 0.42, blue: 0.62),
                              Color(red: 0.45, green: 0.82, blue: 0.52), Color(red: 0.70, green: 0.55, blue: 0.95)]

@MainActor final class Profiles: ObservableObject {
    static let shared = Profiles()
    @Published var all: [Profile] = []
    @Published var current: Profile
    init() {
        let d = UserDefaults.standard
        var list = (d.data(forKey: "profiles.v1").flatMap { try? JSONDecoder().decode([Profile].self, from: $0) }) ?? []
        var seen = Set<String>()
        list = Array(list.filter { isSafeID($0.id, max: 32) && seen.insert($0.id).inserted }.prefix(6)).map {
            Profile(id: $0.id, name: String($0.name.prefix(20)), color: abs($0.color % profileColors.count))
        }
        if !list.contains(where: { $0.id == "p1" }) { list.insert(Profile(id: "p1", name: "Principal", color: 0), at: 0) }
        all = list
        let cid = d.string(forKey: "profiles.current") ?? list[0].id
        current = list.first { $0.id == cid } ?? list[0]
    }
    /// Prefijo de las claves de UserDefaults de cada perfil ("" para el principal: conserva datos previos).
    var keyPrefix: String { current.id == "p1" ? "" : "prof.\(current.id)." }
    func save() {
        if let d = try? JSONEncoder().encode(all) { UserDefaults.standard.set(d, forKey: "profiles.v1") }
        UserDefaults.standard.set(current.id, forKey: "profiles.current")
    }
    func add(_ name: String) {
        let n = String(name.trimmingCharacters(in: .whitespaces).prefix(20)); guard !n.isEmpty, all.count < 6 else { return }
        let p = Profile(id: "p\(Int(Date().timeIntervalSince1970))", name: n, color: all.count % profileColors.count)
        all.append(p); save(); switchTo(p)
    }
    func remove(_ p: Profile) {
        guard p.id != "p1" else { return }
        all.removeAll { $0.id == p.id }
        if current.id == p.id { switchTo(all[0]) } else { save() }
        for k in ["favorites.v2", "history.v1", "recents.v1", "watchlist.v1", "progress.v1"] { UserDefaults.standard.removeObject(forKey: "prof.\(p.id).\(k)") }
    }
    func switchTo(_ p: Profile) {
        PlayerModel.shared.stop()          // guarda el progreso en el perfil saliente
        current = p; save()
        Catalog.shared.reloadUserData()
        Nav.shared.go(.inicio)
    }
}

// MARK: - Progreso ("Seguir donde quedó")
struct Progress: Codable { var pos: Double; var dur: Double; var at: Date }

@MainActor final class ProgressStore: ObservableObject {
    static let shared = ProgressStore()
    private(set) var map: [String: Progress] = [:]      // sin @Published: se avisa al persistir, no cada 5 s
    private var key: String { Profiles.shared.keyPrefix + "progress.v1" }
    init() { reload() }
    func reload() {
        objectWillChange.send()
        map = (UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode([String: Progress].self, from: $0) }) ?? [:]
    }
    func fraction(_ id: String) -> Double? {
        guard let p = map[id], p.dur > 0 else { return nil }
        let f = p.pos / p.dur; return p.pos >= 30 && f < 0.95 ? max(f, 0.03) : nil
    }
    func resumePoint(_ id: String) -> Double? {
        guard let p = map[id], p.dur > 60, p.pos > 30, p.pos < p.dur * 0.95 else { return nil }
        return p.pos
    }
    func update(_ id: String, pos: Double, dur: Double) {
        guard dur.isFinite, dur > 60, pos.isFinite else { return }
        map[id] = Progress(pos: pos, dur: dur, at: Date())
        if map.count > 300 { for k in map.sorted(by: { $0.value.at < $1.value.at }).prefix(map.count - 300).map(\.key) { map[k] = nil } }
    }
    func persist() {
        if let d = try? JSONEncoder().encode(map) { UserDefaults.standard.set(d, forKey: key) }
        objectWillChange.send()
        Catalog.shared.objectWillChange.send()      // refresca "Seguir viendo"
    }
}

// MARK: - Temporizador para dormir
enum SleepMode: Equatable { case off, minutes(Int), endOfItem }

@MainActor final class SleepTimer: ObservableObject {
    static let shared = SleepTimer()
    @Published var mode: SleepMode = .off
    @Published var remaining: Int = 0      // segundos
    private var timer: Timer?
    func set(_ m: SleepMode) {
        timer?.invalidate(); mode = m
        if case .minutes(let n) = m {
            remaining = n * 60
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
        }
    }
    private func tick() {
        remaining -= 1
        if remaining <= 0 { fire() }
    }
    func fire() {
        timer?.invalidate(); mode = .off
        PlayerModel.shared.cancelUpNext()
        PlayerModel.shared.player.pause()
        PlayerModel.shared.status = "Se detuvo por el temporizador. Buenas noches."
    }
    var label: String {
        switch mode {
        case .off: return "Temporizador"
        case .endOfItem: return "Al terminar"
        case .minutes: return String(format: "%d:%02d", remaining / 60, remaining % 60)
        }
    }
}

// MARK: - Guía de programación (Pluto TV)
struct GuideSlot: Hashable { let title: String; let start: Date; let stop: Date }

@MainActor final class GuideStore: ObservableObject {
    static let shared = GuideStore()
    @Published var slots: [String: [GuideSlot]] = [:]     // pid -> programas
    private var loadedAt = Date.distantPast
    private let iso: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f }()
    func load(force: Bool = false) async {
        if !force && Date().timeIntervalSince(loadedAt) < 15 * 60 { return }
        let ids = Catalog.shared.plutoLive.map(\.pid)
        guard !ids.isEmpty, let g = try? await PlutoClient.shared.guide(ids) else { return }
        var out: [String: [GuideSlot]] = [:]
        for (k, v) in g {
            out[k] = v.compactMap { t in
                guard let a = iso.date(from: t.start), let b = iso.date(from: t.stop) else { return nil }
                return GuideSlot(title: String(t.title.prefix(120)), start: a, stop: b)
            }
        }
        slots = out; loadedAt = Date()
    }
    func now(_ pid: String) -> GuideSlot? { let d = Date(); return slots[pid]?.first { $0.start <= d && d < $0.stop } }
    func next(_ pid: String) -> GuideSlot? { let d = Date(); return slots[pid]?.first { $0.start > d } }
}

let hourFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "h:mm a"; f.amSymbol = "a. m."; f.pmSymbol = "p. m."; return f }()

// MARK: - Centro de control y teclas multimedia
@MainActor enum NowPlayingCenter {
    static var configured = false
    static func setup() {
        guard !configured else { return }; configured = true
        let c = MPRemoteCommandCenter.shared(); let pm = PlayerModel.shared
        c.playCommand.addTarget { _ in pm.player.play(); return .success }
        c.pauseCommand.addTarget { _ in pm.player.pause(); return .success }
        c.togglePlayPauseCommand.addTarget { _ in pm.togglePause(); return .success }
        c.skipForwardCommand.preferredIntervals = [10]; c.skipBackwardCommand.preferredIntervals = [10]
        c.skipForwardCommand.addTarget { _ in pm.seek(10); return .success }
        c.skipBackwardCommand.addTarget { _ in pm.seek(-10); return .success }
        c.nextTrackCommand.addTarget { _ in pm.playNextAny() ? .success : .noSuchContent }
        c.previousTrackCommand.addTarget { _ in pm.playPrevAny() ? .success : .noSuchContent }
    }
    static func update(_ c: Channel?, playing: Bool, pos: Double, dur: Double) {
        guard let c else { MPNowPlayingInfoCenter.default().nowPlayingInfo = nil; MPNowPlayingInfoCenter.default().playbackState = .stopped; return }
        var info: [String: Any] = [MPMediaItemPropertyTitle: c.name, MPMediaItemPropertyArtist: meta(c),
                                   MPNowPlayingInfoPropertyIsLiveStream: c.kind == .live,
                                   MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0]
        if dur.isFinite && dur > 0 { info[MPMediaItemPropertyPlaybackDuration] = dur; info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = pos }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = playing ? .playing : .paused
    }
}

// MARK: - AirPlay
struct AirPlayButton: NSViewRepresentable {
    let player: AVPlayer
    func makeNSView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView(); v.player = player; v.isRoutePickerButtonBordered = false
        v.setRoutePickerButtonColor(.white, for: .normal); v.setRoutePickerButtonColor(NSColor(accent), for: .active)
        return v
    }
    func updateNSView(_ v: AVRoutePickerView, context: Context) {}
}

// MARK: - Subtítulos e idioma
struct MediaOption: Hashable { let label: String; let index: Int }

extension PlayerModel {
    func options(_ c: AVMediaCharacteristic) -> [MediaOption] {
        guard let item = player.currentItem, item.status == .readyToPlay,       // no bloquear el hilo principal cargando el asset
              let g = item.asset.mediaSelectionGroup(forMediaCharacteristic: c) else { return [] }
        return g.options.enumerated().map { MediaOption(label: $1.displayName(with: Locale(identifier: "es")), index: $0) }
    }
    func select(_ c: AVMediaCharacteristic, _ idx: Int?) {
        guard let item = player.currentItem, let g = item.asset.mediaSelectionGroup(forMediaCharacteristic: c) else { return }
        if let idx, idx < g.options.count { item.select(g.options[idx], in: g) } else { item.select(nil, in: g) }
        objectWillChange.send()
    }
    func selectedIndex(_ c: AVMediaCharacteristic) -> Int? {
        guard let item = player.currentItem, item.status == .readyToPlay, let g = item.asset.mediaSelectionGroup(forMediaCharacteristic: c),
              let o = item.currentMediaSelection.selectedMediaOption(in: g) else { return nil }
        return g.options.firstIndex(of: o)
    }
    /// Preferir audio y subtítulos en español cuando existan.
    func preferSpanish(_ item: AVPlayerItem) {
        let es = [Locale(identifier: "es-419"), Locale(identifier: "es-MX"), Locale(identifier: "es-ES"), Locale(identifier: "es")]
        if let g = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible),
           let o = AVMediaSelectionGroup.mediaSelectionOptions(from: g.options, filteredAndSortedAccordingToPreferredLanguages: es.map(\.identifier)).first {
            item.select(o, in: g)
        }
        if let g = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
            let audioIsSpanish = item.currentMediaSelection.selectedMediaOption(in: item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) ?? g)?
                .locale?.language.languageCode?.identifier == "es"
            if !audioIsSpanish, let o = AVMediaSelectionGroup.mediaSelectionOptions(from: g.options, with: Locale(identifier: "es")).first {
                item.select(o, in: g)
            }
        }
    }
}

// MARK: - Controles extra del reproductor (temporizador, idioma/subtítulos, AirPlay)
struct PlayerExtras: View {
    @ObservedObject var pm = PlayerModel.shared
    @ObservedObject var sleep = SleepTimer.shared
    var body: some View {
        HStack(spacing: 10) {
            let subs = pm.options(.legible), auds = pm.options(.audible)
            if subs.count + auds.count > 1 {
                Menu {
                    if auds.count > 1 {
                        Section("Idioma del audio") {
                            ForEach(auds, id: \.self) { o in
                                Button { pm.select(.audible, o.index) } label: { checkLabel(o.label, pm.selectedIndex(.audible) == o.index) }
                            }
                        }
                    }
                    if !subs.isEmpty {
                        Section("Subtítulos") {
                            Button { pm.select(.legible, nil) } label: { checkLabel("Desactivados", pm.selectedIndex(.legible) == nil) }
                            ForEach(subs, id: \.self) { o in
                                Button { pm.select(.legible, o.index) } label: { checkLabel(o.label, pm.selectedIndex(.legible) == o.index) }
                            }
                        }
                    }
                } label: { Image(systemName: "captions.bubble") }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 30).help("Idioma y subtítulos")
            }
            Menu {
                Button { sleep.set(.off) } label: { checkLabel("Desactivado", sleep.mode == .off) }
                ForEach([15, 30, 45, 60, 90], id: \.self) { n in
                    Button("En \(n) minutos") { sleep.set(.minutes(n)) }
                }
                if pm.current?.kind != .live { Button { sleep.set(.endOfItem) } label: { checkLabel("Al terminar este episodio o película", sleep.mode == .endOfItem) } }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: sleep.mode == .off ? "moon.zzz" : "moon.zzz.fill")
                    if sleep.mode != .off { Text(sleep.label).font(.caption.monospacedDigit()) }
                }
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("Temporizador para dormir")
            .foregroundStyle(sleep.mode == .off ? Color.primary : accent)
            AirPlayButton(player: pm.player).frame(width: 30, height: 30).help("Enviar a un televisor (AirPlay)")
        }
    }
    func checkLabel(_ t: String, _ on: Bool) -> some View {
        HStack { Text(t); if on { Image(systemName: "checkmark") } }
    }
}

// MARK: - Aviso de siguiente episodio
struct UpNextCard: View {
    @ObservedObject var pm = PlayerModel.shared
    var body: some View {
        if let n = pm.upNext, pm.upNextCountdown > 0 {
            HStack(spacing: 14) {
                RemoteImage(url: n.backdrop.isEmpty ? n.logo : n.backdrop).frame(width: 128, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Siguiente episodio en \(pm.upNextCountdown) s").font(.caption.weight(.semibold)).foregroundStyle(accent)
                    Text("T\(n.season) · E\(n.episode)  \(n.name)").font(.callout.weight(.medium)).lineLimit(2)
                    HStack {
                        Button("Ver ahora") { pm.playUpNext() }.buttonStyle(.borderedProminent).tint(accent).foregroundStyle(.black)
                        Button("Cancelar") { pm.dismissUpNext() }.buttonStyle(.bordered)
                    }.padding(.top, 2)
                }
            }
            .padding(14).frame(width: 420, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding(28)
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }
}

// MARK: - Barra de progreso para pósters/tarjetas
struct ProgressBarOverlay: View {
    let id: String
    @ObservedObject var ps = ProgressStore.shared
    var body: some View {
        if let f = ps.fraction(id) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(.black.opacity(0.55))
                    Rectangle().fill(accent).frame(width: g.size.width * f)
                }
            }.frame(height: 4).frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

// MARK: - Recomendaciones "Porque vio…"
extension Catalog {
    func recommendations() -> (String, [Channel])? {
        guard let seed = history.first(where: { $0.kind == .movie || $0.kind == .series || $0.kind == .episode }) else { return nil }
        let name = seed.kind == .episode ? seed.group : seed.name
        let base = seed.kind == .episode ? (vodIndex.first { $0.name == seed.group } ?? seed) : seed
        let seen = Set(history.map(\.id))
        let rec = related(base).filter { !seen.contains($0.id) }
        return rec.count >= 4 ? (name, rec) : nil
    }
    var continueWatching: [Channel] {
        history.filter { $0.kind != .live && ProgressStore.shared.fraction($0.id) != nil }
    }
}

// MARK: - Fuentes adicionales registradas
@MainActor final class ExtraSources: ObservableObject {
    static let shared = ExtraSources()
    @Published var catalogs: [String: ProviderCatalog] = [:]     // id -> catálogo
    @Published var failed: Set<String> = []
    @Published var loading = false
    func load(force: Bool = false) async {
        if loading { return }
        if !force && !catalogs.isEmpty { return }
        loading = true; defer { loading = false }
        await withTaskGroup(of: (String, ProviderCatalog?).self) { g in
            for p in allProviders {
                g.addTask { (p.id, try? await p.load()) }
            }
            for await (id, cat) in g {
                if let cat { catalogs[id] = cat; failed.remove(id) } else { failed.insert(id) }
            }
        }
    }
    func provider(for url: String) -> (any StreamProvider.Type, String)? {
        for p in allProviders where url.hasPrefix(p.id + ":") { return (p, String(url.dropFirst(p.id.count + 1))) }
        return nil
    }
    var allLive: [Channel] { allProviders.flatMap { catalogs[$0.id]?.live ?? [] } }
    var allShelves: [Shelf] { allProviders.flatMap { catalogs[$0.id]?.shelves ?? [] } }
    func name(_ id: String) -> String { allProviders.first { $0.id == id }?.name ?? id }
    func liveProviderNames() -> [String] {
        var out: [String] = []
        for p in allProviders { if let c = catalogs[p.id], !c.live.isEmpty { out.append(p.name) } }
        return out
    }
}

// MARK: - Actualización automática
@MainActor enum AutoRefresh {
    static var timer: Timer?
    static var activeObs: NSObjectProtocol?
    static func start() {
        timer?.invalidate()
        if let activeObs { NotificationCenter.default.removeObserver(activeObs) }
        timer = Timer.scheduledTimer(withTimeInterval: 3 * 3600, repeats: true) { _ in
            Task { @MainActor in await refreshAll() }
        }
        activeObs = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in
                if Date().timeIntervalSince(Catalog.shared.lastRefresh) > 3 * 3600 { await refreshAll() }
                await GuideStore.shared.load()
            }
        }
    }
    static func refreshAll() async {
        await Catalog.shared.refresh()
        await PlexClient.shared.clear()
        await ExtraSources.shared.load(force: true)
        await GuideStore.shared.load(force: true)
    }
}

func providerNames() -> [String] { var out: [String] = []; for p in allProviders { out.append(p.name) }; return out }
func creditsLine() -> String {
    (["Contenido gratuito y legal", "iptv-org", "Pluto TV", "archive.org"] + providerNames()).joined(separator: " · ")
}
