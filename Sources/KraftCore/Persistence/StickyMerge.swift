import Foundation

/// Per-record merge of two copies of the store (this Mac, the file on disk, later an iPhone).
///
/// Rules, applied to each id independently:
/// 1. Union by id — a record only one side knows is kept.
/// 2. The side with the newer change wins. A record's change time is `updatedAt`, or `deletedAt`
///    when that is later, so a tombstone beats every edit made before the delete.
/// 3. Same change time: the tombstone wins; still tied, the greater canonical JSON wins.
///    Every device therefore picks the same winner, whichever side it calls "local".
public enum StickyMerge {
    /// Merged records: `local` order first, then records only `remote` knows, in its order.
    public static func merge(local: [Sticky], remote: [Sticky]) -> [Sticky] {
        let remoteByID = Dictionary(remote.map { ($0.id, $0) }, uniquingKeysWith: winner)
        let localIDs = Set(local.map(\.id))
        let merged = local.map { mine in remoteByID[mine.id].map { winner(mine, $0) } ?? mine }
        let added = remote.filter { !localIDs.contains($0.id) }
        return dedupe(merged + added)
    }

    /// The record that survives when two copies of the same id disagree.
    public static func winner(_ a: Sticky, _ b: Sticky) -> Sticky {
        if a == b { return a }
        let ta = changeTime(a), tb = changeTime(b)
        if ta != tb { return ta > tb ? a : b }
        let aDeleted = a.deletedAt != nil, bDeleted = b.deletedAt != nil
        if aDeleted != bDeleted { return aDeleted ? a : b }
        let ca = StickyFileCodec.canonical(a), cb = StickyFileCodec.canonical(b)
        return ca.lexicographicallyPrecedes(cb) ? b : a
    }

    /// Drops tombstones deleted more than `maxAge` ago. Older copies elsewhere could resurrect them,
    /// so the window is long (90 days by default).
    public static func purgeTombstones(_ records: [Sticky], now: Date, maxAge: TimeInterval = 90 * 86_400) -> [Sticky] {
        records.filter { record in
            guard let deletedAt = record.deletedAt else { return true }
            return now.timeIntervalSince(deletedAt) <= maxAge
        }
    }

    static func changeTime(_ s: Sticky) -> Date {
        max(s.updatedAt, s.deletedAt ?? .distantPast)
    }

    /// A hand-edited file can repeat an id; keep one winner per id in first-seen order.
    private static func dedupe(_ records: [Sticky]) -> [Sticky] {
        var index: [Sticky.ID: Int] = [:]
        var out: [Sticky] = []
        for r in records {
            if let i = index[r.id] {
                out[i] = winner(out[i], r)
            } else {
                index[r.id] = out.count
                out.append(r)
            }
        }
        return out
    }
}
