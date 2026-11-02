import AppKit
import Foundation
import PersonaCore
import PersonaKit
import SwiftUI

public enum ProbeRender: Probe {
    public static func run(args: [String]) -> Int32 {
        guard args.count >= 2 else {
            fputs("Usage: --probe render <shapes|topbar|hud|wallpaper> <out.png> [--w W] [--h H] [--scale S] [--notch N]\n", stderr)
            return 1
        }
        let targetName = args[0]
        let outPath = args[1]

        let width = CGFloat(ProbeIO.double(of: "--w", in: args, default: 800))
        let height = CGFloat(ProbeIO.double(of: "--h", in: args, default: 400))
        let scale = CGFloat(ProbeIO.double(of: "--scale", in: args, default: 2.0))
        let notchGap = CGFloat(ProbeIO.double(of: "--notch", in: args, default: 0))

        Fonts.register()

        let viewToRender: AnyView
        switch targetName {
        case "shapes":
            viewToRender = AnyView(shapesSheet())
        case "topbar":
            let screen: ScreenModel
            if notchGap > 0 {
                screen = ScreenModel(
                    id: 1,
                    uuid: "notch-sim",
                    frame: CGRect(x: 0, y: 0, width: width, height: height + 600),
                    safeTop: 38,
                    auxLeft: CGRect(x: 0, y: height + 562, width: (width - notchGap) * 0.5, height: 38),
                    auxRight: CGRect(x: (width + notchGap) * 0.5, y: height + 562, width: (width - notchGap) * 0.5, height: 38)
                )
            } else {
                screen = ScreenModel(id: 1, uuid: "plain", frame: CGRect(x: 0, y: 0, width: width, height: height + 600))
            }
            viewToRender = AnyView(TopBarView(screen: screen))
        case "hud":
            let screen = ScreenModel(id: 1, uuid: "hud-sim", frame: CGRect(x: 0, y: 0, width: width, height: height))
            viewToRender = AnyView(HUDView(screen: screen))
        case "wallpaper":
            viewToRender = AnyView(WallpaperView())
        default:
            fputs("Unknown render target: \(targetName)\n", stderr)
            return 1
        }

        let renderedView = viewToRender
            .frame(width: width, height: height)

        let renderer = ImageRenderer(content: renderedView)
        renderer.scale = scale

        guard let cgImage = renderer.cgImage else {
            fputs("Error: ImageRenderer failed to create CGImage\n", stderr)
            return 1
        }

        let url = URL(fileURLWithPath: outPath)
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            fputs("Error: Failed to create image destination at \(outPath)\n", stderr)
            return 1
        }

        CGImageDestinationAddImage(dest, cgImage, nil)
        if !CGImageDestinationFinalize(dest) {
            fputs("Error: Failed to finalize PNG write to \(outPath)\n", stderr)
            return 1
        }

        print("Rendered \(targetName) to \(outPath) (\(Int(width))x\(Int(height)) @\(Int(scale))x)")
        return 0
    }

    private static func shapesSheet() -> some View {
        ZStack {
            ThemeColors.abyss.ignoresSafeArea()

            VStack(spacing: 20) {
                Text("PERSONA 3 RELOAD - GEOMETRIC SHAPES")
                    .font(Fonts.display(20))
                    .foregroundColor(ThemeColors.cyan)

                HStack(spacing: 16) {
                    SkewedPill()
                        .fill(ThemeColors.cyan)
                        .frame(width: 120, height: 32)
                        .overlay(Text("SKEWED PILL").font(Fonts.display(12)).foregroundColor(ThemeColors.midnight))

                    AngledPanel(cutSize: 10)
                        .fill(ThemeColors.midnight)
                        .overlay(AngledPanel(cutSize: 10).stroke(ThemeColors.cyan, lineWidth: 1.5))
                        .frame(width: 140, height: 36)
                        .overlay(Text("ANGLED PANEL").font(Fonts.display(12)).foregroundColor(ThemeColors.white))

                    ChevronBadge(arrowWidth: 12)
                        .fill(ThemeColors.royalBlue)
                        .frame(width: 130, height: 32)
                        .overlay(Text("CHEVRON").font(Fonts.display(12)).foregroundColor(ThemeColors.white))

                    HexRing()
                        .stroke(ThemeColors.cyan, lineWidth: 2)
                        .frame(width: 48, height: 48)
                }

                Halftone(dotColor: ThemeColors.cyan.opacity(0.4), spacing: 10, maxRadius: 3)
                    .frame(width: 320, height: 60)
                    .background(ThemeColors.midnight.opacity(0.6))
            }
            .padding()
        }
    }
}
