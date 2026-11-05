import AppKit
import Foundation
import PersonaCore
import SwiftUI

public struct LauncherMatch: Identifiable, Equatable {
    public let id: String
    public let item: LauncherItem
    public let score: Int
    public let matchedIndices: [Int]

    public init(item: LauncherItem, score: Int, matchedIndices: [Int]) {
        self.id = item.id
        self.item = item
        self.score = score
        self.matchedIndices = matchedIndices
    }
}

/// A single row in the Persona 3 Reload Floating App Launcher.
/// Uses zero Swift macros for CommandLineTools compatibility.
public struct LauncherRow: View {
    public let match: LauncherMatch
    public let rowIndex: Int
    public let isSelected: Bool
    public let onActivate: () -> Void

    public init(
        match: LauncherMatch,
        rowIndex: Int,
        isSelected: Bool,
        onActivate: @escaping () -> Void = {}
    ) {
        self.match = match
        self.rowIndex = rowIndex
        self.isSelected = isSelected
        self.onActivate = onActivate
    }

    private var isDestructive: Bool {
        if case .action(let entry) = match.item {
            return entry.isDestructive
        }
        return false
    }

    private var detailText: String {
        switch match.item {
        case .action(let act):
            return act.detail
        case .app(let app):
            return app.bundleId
        }
    }

    private var badgeText: String {
        if isDestructive { return "EXIT" }
        return match.item.isAction ? "CMD" : "APP"
    }

    public var body: some View {
        Button(action: onActivate) {
            ZStack {
                if isSelected {
                    SkewedPill(skewDegrees: ThemeTokens.skewDegrees)
                        .fill(isDestructive ? ThemeColors.alert : ThemeColors.cyan)
                        .shadow(
                            color: (isDestructive ? ThemeColors.alert : ThemeColors.cyan).opacity(0.65),
                            radius: 8,
                            x: 0,
                            y: 0
                        )
                } else if isDestructive {
                    SkewedPill(skewDegrees: ThemeTokens.skewDegrees)
                        .fill(ThemeColors.alert.opacity(0.14))
                        .overlay(
                            SkewedPill(skewDegrees: ThemeTokens.skewDegrees)
                                .stroke(ThemeColors.alert.opacity(0.55), lineWidth: 1)
                        )
                } else {
                    SkewedPill(skewDegrees: ThemeTokens.skewDegrees)
                        .fill(ThemeColors.midnight.opacity(0.55))
                        .overlay(
                            SkewedPill(skewDegrees: ThemeTokens.skewDegrees)
                                .stroke(ThemeColors.steel.opacity(0.35), lineWidth: 1)
                        )
                }

                HStack(spacing: 12) {
                    iconView
                        .frame(width: 26, height: 26)

                    VStack(alignment: .leading, spacing: 1) {
                        highlightedTitle
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text(detailText)
                            .font(Fonts.body(11))
                            .foregroundColor(subtitleColor)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer(minLength: 8)

                    if rowIndex < 9 {
                        Text("⌘\(rowIndex + 1)")
                            .font(Fonts.body(11, bold: true))
                            .foregroundColor(shortcutColor)
                    }

                    ChevronBadge(arrowWidth: 6)
                        .fill(badgeBackground)
                        .frame(width: 46, height: 20)
                        .overlay(
                            Text(badgeText)
                                .font(Fonts.display(11))
                                .foregroundColor(badgeForeground)
                        )
                }
                .padding(.horizontal, 18)
            }
            .frame(height: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("launcher.row.\(rowIndex)")
    }

    @ViewBuilder
    private var iconView: some View {
        switch match.item {
        case .action(let act):
            Image(systemName: act.iconName)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(iconForeground)
        case .app:
            if let img = AppIndexer.shared.icon(for: match.item) {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(iconForeground)
            }
        }
    }

    private var highlightedTitle: Text {
        let chars = Array(match.item.name)
        let matchedSet = Set(match.matchedIndices)
        var combined = Text("")

        for (idx, ch) in chars.enumerated() {
            let s = String(ch)
            if matchedSet.contains(idx) {
                let piece = Text(s)
                    .font(Fonts.body(15, bold: true))
                    .foregroundColor(matchedCharColor)
                combined = combined + piece
            } else {
                let piece = Text(s)
                    .font(Fonts.body(15, bold: isSelected))
                    .foregroundColor(baseTitleColor)
                combined = combined + piece
            }
        }
        return combined
    }

    private var baseTitleColor: Color {
        if isSelected {
            return isDestructive ? ThemeColors.white : ThemeColors.midnight
        }
        return isDestructive ? ThemeColors.alert : ThemeColors.ice
    }

    private var matchedCharColor: Color {
        if isSelected {
            return isDestructive ? ThemeColors.warn : ThemeColors.abyss
        }
        return ThemeColors.cyan
    }

    private var subtitleColor: Color {
        if isSelected {
            return isDestructive ? ThemeColors.white.opacity(0.85) : ThemeColors.midnight.opacity(0.75)
        }
        return ThemeColors.steel
    }

    private var iconForeground: Color {
        if isSelected {
            return isDestructive ? ThemeColors.white : ThemeColors.midnight
        }
        return isDestructive ? ThemeColors.alert : ThemeColors.cyan
    }

    private var shortcutColor: Color {
        if isSelected {
            return isDestructive ? ThemeColors.white.opacity(0.85) : ThemeColors.midnight.opacity(0.75)
        }
        return ThemeColors.steel
    }

    private var badgeBackground: Color {
        if isSelected {
            return ThemeColors.midnight.opacity(0.85)
        }
        if isDestructive {
            return ThemeColors.alert.opacity(0.28)
        }
        return match.item.isAction ? ThemeColors.royalBlue.opacity(0.45) : ThemeColors.abyss.opacity(0.75)
    }

    private var badgeForeground: Color {
        if isSelected {
            return isDestructive ? ThemeColors.alert : ThemeColors.cyan
        }
        if isDestructive {
            return ThemeColors.alert
        }
        return ThemeColors.cyan
    }
}
