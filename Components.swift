// TicoTV — componentes visuales reutilizables
import SwiftUI
import AVKit

final class HoverState: ObservableObject { @Published var on = false }

struct RemoteImage: View {
    let url: String
    var fit = false
    var label = ""
    var body: some View {
        AsyncImage(url: isSafeImageURL(url)) { phase in
            if let img = phase.image {
                if fit { img.resizable().scaledToFit() } else { img.resizable().scaledToFill() }
            } else {
                ZStack {
                    cardBG
                    if !label.isEmpty {
                        Text(label).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding(10)
                    }
                }
            }
        }
    }
}

// Póster vertical (películas y series)
struct PosterCard: View {
    let item: Channel
    var width: CGFloat = 150
    @StateObject private var h = HoverState()
    @ObservedObject private var cat = Catalog.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RemoteImage(url: item.logo, label: item.name)
                .frame(width: width, height: width * 500 / 347)
                .overlay { ProgressBarOverlay(id: item.id) }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(accent, lineWidth: h.on ? 2 : 0))
                .overlay(alignment: .bottomTrailing) {
                    if h.on {
                        Button { PlayerModel.shared.play(item) } label: {
                            Image(systemName: item.kind == .series ? "list.bullet" : "play.fill")
                                .font(.system(size: 13, weight: .bold)).frame(width: 34, height: 34)
                        }
                        .buttonStyle(.plain).foregroundStyle(.black).background(accent, in: Circle())
                        .padding(8).transition(.opacity)
                        .help(item.kind == .series ? "Ver episodios" : "Reproducir")
                    }
                }
                .overlay(alignment: .topLeading) {
                    if cat.isFav(item) || h.on {
                        Button { cat.toggleFav(item) } label: {
                            Image(systemName: cat.isFav(item) ? "star.fill" : "star").font(.caption.weight(.bold))
                                .foregroundStyle(accent).frame(width: 26, height: 26).background(.black.opacity(0.55), in: Circle())
                        }.buttonStyle(.plain).padding(6).help(cat.isFav(item) ? "Quitar de Favoritos" : "Agregar a Favoritos")
                    }
                }
                .shadow(color: .black.opacity(h.on ? 0.5 : 0.2), radius: h.on ? 12 : 4, y: h.on ? 6 : 2)
                .scaleEffect(h.on ? 1.04 : 1)
            Text(item.name).font(.callout.weight(.medium)).lineLimit(2)
                .frame(width: width, alignment: .leading)
            Text(subline).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                .frame(width: width, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onHover { v in withAnimation(.snappy(duration: 0.18)) { h.on = v } }
        .onTapGesture { Nav.shared.open(item) }
        .focusable()
        .onKeyPress(.return) { Nav.shared.open(item); return .handled }
        .onKeyPress(.space) { PlayerModel.shared.play(item); return .handled }
        .contextMenu { ItemMenu(item: item) }
        .accessibilityElement(children: .ignore).accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text([item.name, subline].filter { !$0.isEmpty }.joined(separator: ", ")))
        .accessibilityAction { Nav.shared.open(item) }
        .accessibilityAction(named: Text(item.kind == .series ? "Ver episodios" : "Reproducir")) { PlayerModel.shared.play(item) }
        .accessibilityAction(named: Text(cat.isFav(item) ? "Quitar de Favoritos" : "Agregar a Favoritos")) { cat.toggleFav(item) }
    }
    var subline: String { [item.kind == .series ? "Serie" : (item.kind == .classic ? "Clásico" : ""), item.year].filter { !$0.isEmpty }.joined(separator: " · ") }
}

// Tarjeta horizontal 16:9 (canales en vivo, seguir viendo)
struct WideCard: View {
    let item: Channel
    var width: CGFloat = 240
    @StateObject private var h = HoverState()
    @ObservedObject private var pm = PlayerModel.shared
    @ObservedObject private var guide = GuideStore.shared
    var isLogo: Bool { item.kind == .live }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if isLogo {
                    cardBG
                    RemoteImage(url: item.logo, fit: true, label: item.name).padding(.horizontal, 26).padding(.vertical, 22)
                } else {
                    RemoteImage(url: item.backdrop.isEmpty ? item.logo : item.backdrop, label: item.name)
                }
            }
            .frame(width: width, height: width * 9 / 16)
            .overlay { if !isLogo { ProgressBarOverlay(id: item.id) } }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .topLeading) {
                if item.kind == .live { LiveBadge(playing: pm.current?.id == item.id).padding(8) }
            }
            .overlay {
                if h.on {
                    ZStack {
                        Color.black.opacity(0.35)
                        Image(systemName: "play.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(.black)
                            .frame(width: 44, height: 44).background(accent, in: Circle())
                    }.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)).transition(.opacity)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(accent, lineWidth: h.on ? 2 : 0))
            .shadow(color: .black.opacity(h.on ? 0.5 : 0.2), radius: h.on ? 12 : 4, y: h.on ? 6 : 2)
            .scaleEffect(h.on ? 1.03 : 1)
            Text(item.name).font(.callout.weight(.medium)).lineLimit(1).frame(width: width, alignment: .leading)
            if item.kind == .live, let now = guide.now(item.pid) {
                Text("Ahora: \(now.title)").font(.caption).foregroundStyle(.secondary).lineLimit(1).frame(width: width, alignment: .leading)
                    .help(guide.next(item.pid).map { "Después (\(hourFmt.string(from: $0.start))): \($0.title)" } ?? now.title)
            } else {
                Text(meta(item)).font(.caption).foregroundStyle(.secondary).lineLimit(1).frame(width: width, alignment: .leading)
            }
        }
        .contentShape(Rectangle())
        .onHover { v in withAnimation(.snappy(duration: 0.18)) { h.on = v } }
        .onTapGesture { item.kind == .live || item.kind == .episode ? PlayerModel.shared.play(item) : Nav.shared.open(item) }
        .focusable()
        .onKeyPress(.return) { item.kind == .live || item.kind == .episode ? PlayerModel.shared.play(item) : Nav.shared.open(item); return .handled }
        .contextMenu { ItemMenu(item: item) }
        .accessibilityElement(children: .ignore).accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text("\(item.name), \(meta(item))"))
        .accessibilityAction { item.kind == .live || item.kind == .episode ? PlayerModel.shared.play(item) : Nav.shared.open(item) }
    }
}

struct LiveBadge: View {
    var playing = false
    var body: some View {
        Text(playing ? "VIENDO" : "EN VIVO").font(.system(size: 9, weight: .heavy)).tracking(0.6)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(playing ? accent : liveRed, in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(playing ? .black : .white)
    }
}

struct ItemMenu: View {
    let item: Channel
    @ObservedObject private var cat = Catalog.shared
    var body: some View {
        Button(item.kind == .series ? "Ver episodios" : "Reproducir") { PlayerModel.shared.play(item) }
        if item.kind != .live && item.kind != .episode { Button("Ver detalles") { Nav.shared.open(item) } }
        Divider()
        Button(cat.isFav(item) ? "Quitar de Favoritos" : "Agregar a Favoritos") { cat.toggleFav(item) }
        if item.kind != .live && item.kind != .episode {
            Button(cat.inList(item) ? "Quitar de Mi lista" : "Agregar a Mi lista") { cat.toggleList(item) }
        }
    }
}

// Fila horizontal con título y "Ver todo"
struct ShelfRow<Card: View>: View {
    let title: String
    let items: [Channel]
    var subtitle: String = ""
    @ViewBuilder let card: (Channel) -> Card
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title).font(.title3.weight(.semibold))
                if !subtitle.isEmpty { Text(subtitle).font(.callout).foregroundStyle(.secondary) }
                Spacer()
                if items.count > 6 {
                    Button("Ver todo") { Nav.shared.showAll(title, items) }.buttonStyle(.link).foregroundStyle(accent)
                }
            }.padding(.horizontal, pagePad)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 16) { ForEach(items.prefix(40)) { card($0) } }
                    .padding(.horizontal, pagePad).padding(.vertical, 8)
            }
        }
    }
}

// Rejilla adaptable
struct ItemGrid: View {
    let items: [Channel]
    var body: some View {
        let wide = items.first.map { $0.kind == .live || $0.kind == .episode } ?? false
        LazyVGrid(columns: [GridItem(.adaptive(minimum: wide ? 230 : 150, maximum: wide ? 280 : 190), spacing: 20, alignment: .top)],
                  alignment: .leading, spacing: 26) {
            ForEach(items) { c in
                if wide { WideCard(item: c, width: 230) } else { PosterCard(item: c) }
            }
        }.padding(.horizontal, pagePad)
    }
}

// Chips de filtro
struct ChipBar: View {
    let options: [String]
    let selected: String
    let pick: (String) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { o in
                    let on = o == selected
                    Button { pick(o) } label: {
                        Text(o).font(.callout.weight(on ? .semibold : .regular))
                            .padding(.horizontal, 13).frame(height: 28)
                            .background(on ? accent : Color.white.opacity(0.08), in: Capsule())
                            .foregroundStyle(on ? Color.black : Color.primary)
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, pagePad)
        }
    }
}

struct PageTitle: View {
    let title: String
    var subtitle = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 28, weight: .bold))
            if !subtitle.isEmpty { Text(subtitle).font(.callout).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, pagePad).padding(.top, 22)
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    var message = ""
    var action: (String, () -> Void)? = nil
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 34, weight: .light)).foregroundStyle(.secondary)
            Text(title).font(.title3.weight(.semibold))
            if !message.isEmpty { Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 380) }
            if let a = action { Button(a.0, action: a.1).buttonStyle(.bordered).padding(.top, 4) }
        }.frame(maxWidth: .infinity).padding(.vertical, 60)
    }
}

struct LoadingRow: View {
    var text = "Cargando…"
    var body: some View {
        HStack(spacing: 8) { ProgressView().controlSize(.small); Text(text).foregroundStyle(.secondary) }
            .padding(.horizontal, pagePad).padding(.vertical, 20)
    }
}

// MARK: - Reproductor
struct PlayerSurface: NSViewRepresentable {
    let player: AVPlayer
    func makeNSView(context: Context) -> AVPlayerView {
        let v = AVPlayerView(); v.player = player; v.controlsStyle = .floating
        v.allowsPictureInPicturePlayback = true; v.showsFullScreenToggleButton = true
        return v
    }
    func updateNSView(_ v: AVPlayerView, context: Context) {}
}

final class FadeState: ObservableObject {
    @Published var visible = true
    private var work: DispatchWorkItem?
    func poke() {
        visible = true; work?.cancel()
        let w = DispatchWorkItem { [weak self] in withAnimation(.easeOut(duration: 0.3)) { self?.visible = false } }
        work = w; DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: w)
    }
}

struct PlayerOverlay: View {
    @ObservedObject var pm = PlayerModel.shared
    @StateObject private var fade = FadeState()
    var body: some View {
        ZStack(alignment: .top) {
            PlayerSurface(player: pm.player).background(Color.black)
            if !pm.status.isEmpty {
                VStack(spacing: 12) {
                    if pm.failedNow {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash").font(.system(size: 34)).foregroundStyle(.secondary)
                    } else { ProgressView().controlSize(.large) }
                    Text(pm.status).font(.callout).foregroundStyle(.secondary)
                    if pm.failedNow { Button("Volver") { pm.stop() }.buttonStyle(.bordered) }
                    if pm.status.hasPrefix("Se detuvo") { Button("Seguir viendo") { pm.status = ""; pm.player.play() }.buttonStyle(.bordered) }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if fade.visible || pm.failedNow {
                HStack(spacing: 12) {
                    Button { pm.minimize() } label: { Image(systemName: "chevron.down").frame(width: 30, height: 30) }
                        .buttonStyle(.plain).background(.ultraThinMaterial, in: Circle()).help("Minimizar (esc)")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pm.current?.name ?? "").font(.headline).lineLimit(1)
                        if let c = pm.current { Text(meta(c)).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                    }
                    Spacer()
                    Text("espacio: pausa · f: pantalla completa · esc: minimizar" + (pm.nextEpisode() != nil ? " · n: siguiente" : ""))
                        .font(.caption2).foregroundStyle(.secondary)
                    PlayerExtras()
                    if pm.nextEpisode() != nil {
                        Button { pm.playNextAny() } label: { Image(systemName: "forward.end.fill").frame(width: 30, height: 30) }
                            .buttonStyle(.plain).background(.ultraThinMaterial, in: Circle()).help("Siguiente episodio (n)")
                    }
                    Button { pm.stop() } label: { Image(systemName: "xmark").frame(width: 30, height: 30) }
                        .buttonStyle(.plain).background(.ultraThinMaterial, in: Circle()).help("Cerrar")
                }
                .padding(14)
                .background(LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom))
                .transition(.opacity)
            }
        }
        .overlay(alignment: .bottomTrailing) { UpNextCard() }
        .animation(.snappy, value: pm.upNext)
        .onContinuousHover { _ in fade.poke() }
        .onAppear { fade.poke() }
    }
}

struct NowPlayingBar: View {
    @ObservedObject var pm = PlayerModel.shared
    var body: some View {
        if let c = pm.current, !pm.expanded {
            HStack(spacing: 12) {
                RemoteImage(url: c.kind == .live ? c.logo : (c.backdrop.isEmpty ? c.logo : c.backdrop), fit: c.kind == .live)
                    .frame(width: 72, height: 40).background(cardBG).clipShape(RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Reproduciendo").font(.caption2.weight(.semibold)).foregroundStyle(accent)
                    Text(c.name).font(.callout.weight(.medium)).lineLimit(1)
                }
                Spacer()
                Button { pm.togglePause() } label: { Image(systemName: pm.isPlaying ? "pause.fill" : "play.fill").frame(width: 28, height: 28) }
                    .buttonStyle(.plain).help("Pausa / reanudar")
                PlayerExtras()
                Button("Ampliar") { pm.expand() }.buttonStyle(.bordered)
                Button { pm.stop() } label: { Image(systemName: "xmark").frame(width: 28, height: 28) }.buttonStyle(.plain).help("Cerrar")
            }
            .padding(.horizontal, 16).frame(height: 56)
            .background(.bar)
            .overlay(alignment: .bottom) { Divider() }
        }
    }
}
