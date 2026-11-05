import AppKit
import Foundation
import PersonaCore
import SwiftUI

/// Observable state model for the Floating P3R App Launcher.
/// Uses `ObservableObject` and `@Published` (zero Swift macros) for CommandLineTools compatibility.
@MainActor
public final class LauncherViewModel: ObservableObject {
    @Published public var query: String = ""
    @Published public var matches: [LauncherMatch] = []
    @Published public var selectedIndex: Int = 0

    public var onActivateItem: ((LauncherItem, Bool) -> Void)?
    public var onCancel: (() -> Void)?

    public init(initialQuery: String = "") {
        updateQuery(initialQuery)
    }

    public func updateQuery(_ newQuery: String) {
        self.query = newQuery
        let raw = AppIndexer.shared.search(query: newQuery)
        self.matches = raw.map {
            LauncherMatch(item: $0.item, score: $0.score, matchedIndices: $0.matchedIndices)
        }
        self.selectedIndex = 0
    }

    public func moveSelectionUp() {
        guard !matches.isEmpty else {
            selectedIndex = 0
            return
        }
        if selectedIndex > 0 {
            selectedIndex -= 1
        } else {
            selectedIndex = matches.count - 1
        }
    }

    public func moveSelectionDown() {
        guard !matches.isEmpty else {
            selectedIndex = 0
            return
        }
        if selectedIndex + 1 < matches.count {
            selectedIndex += 1
        } else {
            selectedIndex = 0
        }
    }

    public var selectedMatch: LauncherMatch? {
        guard selectedIndex >= 0 && selectedIndex < matches.count else { return nil }
        return matches[selectedIndex]
    }

    public func activateSelected(revealInFinder: Bool = false) {
        guard let match = selectedMatch else { return }
        onActivateItem?(match.item, revealInFinder)
    }

    public func activate(at index: Int, revealInFinder: Bool = false) {
        guard index >= 0 && index < matches.count else { return }
        selectedIndex = index
        onActivateItem?(matches[index].item, revealInFinder)
    }
}

/// Persona 3 Reload Floating App & Command Launcher View.
/// Uses `@ObservedObject` without `@State`, `@Observable`, or `#Preview` macros.
public struct LauncherView: View {
    @ObservedObject public var viewModel: LauncherViewModel

    public init(viewModel: LauncherViewModel) {
        self.viewModel = viewModel
    }

    private var visibleSlice: ArraySlice<(offset: Int, element: LauncherMatch)> {
        let enumerated = Array(viewModel.matches.enumerated())
        let maxVisible = 8
        guard enumerated.count > maxVisible else {
            return enumerated[...]
        }
        let start = max(0, min(viewModel.selectedIndex - maxVisible + 1, enumerated.count - maxVisible))
        let end = min(enumerated.count, start + maxVisible)
        return enumerated[start..<end]
    }

    public var body: some View {
        ZStack {
            ThemeColors.abyss

            // Outer skewed comic-book frame
            AngledPanel(cutSize: 18, skewDegrees: -1.5)
                .fill(ThemeColors.midnight.opacity(0.95))
                .overlay(
                    Halftone(dotColor: ThemeColors.cyan.opacity(0.14), spacing: 12, maxRadius: 2.5)
                        .clipShape(AngledPanel(cutSize: 18, skewDegrees: -1.5))
                )
                .overlay(
                    AngledPanel(cutSize: 18, skewDegrees: -1.5)
                        .stroke(ThemeColors.cyan, lineWidth: 1.5)
                )

            VStack(spacing: 10) {
                searchHeader
                    .padding(.top, 12)
                    .padding(.horizontal, 14)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [ThemeColors.cyan, ThemeColors.royalBlue.opacity(0.4), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1.5)
                    .padding(.horizontal, 14)

                if viewModel.matches.isEmpty {
                    Spacer()
                    VStack(spacing: 6) {
                        Text("NO MATCHING TARGETS")
                            .font(Fonts.display(20))
                            .foregroundColor(ThemeColors.cyan)
                        Text("TRY ANOTHER QUERY OR PRESS ESC TO DISMISS")
                            .font(Fonts.body(12))
                            .foregroundColor(ThemeColors.steel)
                    }
                    Spacer()
                } else {
                    VStack(spacing: 4) {
                        ForEach(Array(visibleSlice), id: \.element.id) { pair in
                            LauncherRow(
                                match: pair.element,
                                rowIndex: pair.offset,
                                isSelected: pair.offset == viewModel.selectedIndex,
                                onActivate: {
                                    viewModel.activate(at: pair.offset)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 14)

                    Spacer(minLength: 0)
                }

                footerBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
        }
        .frame(width: 640, height: 472)
    }

    private var searchHeader: some View {
        HStack(spacing: 10) {
            ChevronBadge(arrowWidth: 10)
                .fill(ThemeColors.cyan)
                .frame(width: 96, height: 30)
                .overlay(
                    Text("SEARCH ▸")
                        .font(Fonts.display(15))
                        .foregroundColor(ThemeColors.midnight)
                )

            HStack(spacing: 2) {
                if viewModel.query.isEmpty {
                    Text("TYPE APP OR COMMAND…")
                        .font(Fonts.display(18))
                        .foregroundColor(ThemeColors.steel)
                } else {
                    Text(viewModel.query.uppercased())
                        .font(Fonts.display(20))
                        .foregroundColor(ThemeColors.white)
                }

                Rectangle()
                    .fill(ThemeColors.cyan)
                    .frame(width: 2, height: 18)
            }

            Spacer()

            SkewedPill(skewDegrees: ThemeTokens.skewDegrees)
                .fill(ThemeColors.midnight)
                .overlay(
                    SkewedPill(skewDegrees: ThemeTokens.skewDegrees)
                        .stroke(ThemeColors.cyan.opacity(0.6), lineWidth: 1)
                )
                .frame(width: 84, height: 24)
                .overlay(
                    Text("\(viewModel.matches.count) ITEMS")
                        .font(Fonts.body(11, bold: true))
                        .foregroundColor(ThemeColors.cyan)
                )
        }
        .frame(height: 36)
        .accessibilityIdentifier("launcher.search")
    }

    private var footerBar: some View {
        HStack(spacing: 14) {
            Text("↑↓ NAVIGATE")
                .font(Fonts.body(11))
                .foregroundColor(ThemeColors.steel)
            Text("⏎ LAUNCH")
                .font(Fonts.body(11))
                .foregroundColor(ThemeColors.steel)
            Text("⌘⏎ REVEAL")
                .font(Fonts.body(11))
                .foregroundColor(ThemeColors.steel)
            Text("ESC DISMISS")
                .font(Fonts.body(11))
                .foregroundColor(ThemeColors.steel)
            Spacer()
            Text("PERSONA // TARTARUS COMMANDER")
                .font(Fonts.display(12))
                .foregroundColor(ThemeColors.cyan.opacity(0.75))
        }
    }
}

