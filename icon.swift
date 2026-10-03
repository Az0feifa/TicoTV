// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Copyright (C) 2026 Az0feifa <https://github.com/Az0feifa>
// Convierte el logo de Gerald (assets/logo-original.png) en un ícono de macOS 1024x1024
// Uso: mkicon <logo.png> <salida.png>
import AppKit
let args = CommandLine.arguments
guard args.count >= 3, let src = NSImage(contentsOfFile: args[1]) else { fatalError("uso: mkicon logo.png salida.png") }
let S: CGFloat = 1024
let out = NSImage(size: NSSize(width: S, height: S))
out.lockFocus()
NSGraphicsContext.current?.imageInterpolation = .high
// Placa redondeada estilo macOS (824 px centrada), oscura para que resalte el logo
let plate = NSRect(x: 100, y: 100, width: 824, height: 824)
let path = NSBezierPath(roundedRect: plate, xRadius: 185, yRadius: 185)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow(); shadow.shadowBlurRadius = 24; shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.shadowColor = NSColor.black.withAlphaComponent(0.35); shadow.set()
NSGradient(colors: [NSColor(red: 0.12, green: 0.13, blue: 0.24, alpha: 1), NSColor(red: 0.03, green: 0.04, blue: 0.10, alpha: 1)])!.draw(in: path, angle: -90)
NSGraphicsContext.restoreGraphicsState()
// Logo centrado en el área segura, conservando proporción
let box = plate.insetBy(dx: 64, dy: 64)
let r = min(box.width / src.size.width, box.height / src.size.height)
let w = src.size.width * r, h = src.size.height * r
NSGraphicsContext.saveGraphicsState()
path.addClip()
src.draw(in: NSRect(x: box.midX - w / 2, y: box.midY - h / 2, width: w, height: h), from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()
out.unlockFocus()
guard let tiff = out.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { fatalError("no se pudo generar PNG") }
try png.write(to: URL(fileURLWithPath: args[2]))
