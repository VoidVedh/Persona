import Foundation

/// Subsequence fuzzy matcher with scoring heuristics tailored for application launching.
public enum FuzzyMatcher {
    /// Scores a candidate string against a search query, choosing the highest-scoring subsequence alignment.
    ///
    /// - Parameters:
    ///   - query: Search string typed by the user.
    ///   - candidate: Candidate target name (e.g. application name).
    /// - Returns: Score and matched character indices, or `nil` if query is not a subsequence.
    public static func score(query: String, candidate: String) -> (score: Int, matchedIndices: [Int])? {
        if query.isEmpty {
            return (0, [])
        }

        let qChars = Array(query.lowercased())
        let cChars = Array(candidate)
        let cLower = Array(candidate.lowercased())

        let m = qChars.count
        let n = cChars.count
        guard m <= n else { return nil }

        // Precompute static per-position bonuses (prefix, word boundary, camelCase)
        var posBonus = [Int](repeating: 0, count: n)
        for i in 0..<n {
            if i == 0 {
                posBonus[i] += 30
            } else {
                let prev = cChars[i - 1]
                if prev == " " || prev == "-" || prev == "_" || prev == "." || prev == "/" {
                    posBonus[i] += 12
                } else if cChars[i].isUppercase && prev.isLowercase {
                    posBonus[i] += 8
                }
            }
        }

        var bestScore = Int.min
        var bestIndices: [Int] = []
        var currentIndices = [Int](repeating: 0, count: m)

        func search(qIdx: Int, minCIdx: Int, prevMatch: Int, consecutive: Int, accScore: Int) {
            if qIdx == m {
                if accScore > bestScore {
                    bestScore = accScore
                    bestIndices = currentIndices
                }
                return
            }

            let target = qChars[qIdx]
            let maxStart = n - (m - qIdx)
            guard minCIdx <= maxStart else { return }

            var foundFirstPlain = false
            for cIdx in minCIdx...maxStart {
                guard cLower[cIdx] == target else { continue }

                let isBoundary = (cIdx == 0) || (posBonus[cIdx] > 0) || (cIdx == prevMatch + 1)
                // Explore the first plain match and any word-boundary/consecutive matches
                if !isBoundary && foundFirstPlain {
                    continue
                }
                if !isBoundary {
                    foundFirstPlain = true
                }

                var stepScore = posBonus[cIdx]
                let nextConsecutive: Int
                if prevMatch >= 0 && cIdx == prevMatch + 1 {
                    nextConsecutive = consecutive + 1
                    stepScore += 8 * nextConsecutive
                } else {
                    nextConsecutive = 0
                    if prevMatch >= 0 {
                        let gap = cIdx - prevMatch - 1
                        stepScore -= gap
                    }
                }

                currentIndices[qIdx] = cIdx
                search(
                    qIdx: qIdx + 1,
                    minCIdx: cIdx + 1,
                    prevMatch: cIdx,
                    consecutive: nextConsecutive,
                    accScore: accScore + stepScore
                )
            }
        }

        search(qIdx: 0, minCIdx: 0, prevMatch: -2, consecutive: 0, accScore: 0)

        guard bestScore > Int.min else {
            return nil
        }
        return (bestScore, bestIndices)
    }

    /// Ranks candidates against a search query, returning matching items sorted by score descending.
    public static func rank<T>(
        items: [T],
        query: String,
        name: (T) -> String
    ) -> [(item: T, score: Int, matchedIndices: [Int])] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            return items.map { ($0, 0, []) }
        }

        var results: [(item: T, score: Int, matchedIndices: [Int])] = []
        for item in items {
            let candidate = name(item)
            if let match = score(query: trimmed, candidate: candidate) {
                results.append((item, match.score, match.matchedIndices))
            }
        }

        results.sort {
            if $0.score != $1.score {
                return $0.score > $1.score
            }
            return name($0.item).localizedCaseInsensitiveCompare(name($1.item)) == .orderedAscending
        }

        return results
    }
}
