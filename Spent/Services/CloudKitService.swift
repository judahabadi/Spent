import Foundation
import CloudKit

@Observable
final class CloudKitService {
    var isSyncing = false
    var lastSyncDate: Date?
    var syncError: Error?

    private let container = CKContainer(identifier: "iCloud.app.spent")
    private var database: CKDatabase { container.privateCloudDatabase }

    // Save a daily receipt to CloudKit
    func save(receipt: DailyReceipt) async {
        await MainActor.run { isSyncing = true }
        defer { Task { await MainActor.run { self.isSyncing = false } } }

        do {
            let record = try receiptToRecord(receipt)
            _ = try await database.save(record)
            await MainActor.run { self.lastSyncDate = .now }
        } catch {
            await MainActor.run { self.syncError = error }
        }
    }

    // Fetch receipts for a date range
    func fetchReceipts(from start: Date, to end: Date) async -> [DailyReceipt] {
        let predicate = NSPredicate(format: "date >= %@ AND date <= %@", start as CVarArg, end as CVarArg)
        let query = CKQuery(recordType: "DailyReceipt", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        do {
            let result = try await database.records(matching: query)
            return result.matchResults.compactMap { _, recordResult in
                guard let record = try? recordResult.get() else { return nil }
                return try? recordToReceipt(record)
            }
        } catch {
            await MainActor.run { self.syncError = error }
            return []
        }
    }

    // Save streak record
    func save(streak: StreakRecord) async {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(streak)
            let record = CKRecord(recordType: "StreakRecord", recordID: CKRecord.ID(recordName: "singleton-streak"))
            record["data"] = data as CKRecordValue
            _ = try await database.save(record)
        } catch {
            await MainActor.run { self.syncError = error }
        }
    }

    func fetchStreak() async -> StreakRecord {
        do {
            let recordID = CKRecord.ID(recordName: "singleton-streak")
            let record = try await database.record(for: recordID)
            guard let data = record["data"] as? Data else { return .empty }
            return (try? JSONDecoder().decode(StreakRecord.self, from: data)) ?? .empty
        } catch {
            return .empty
        }
    }

    private func receiptToRecord(_ receipt: DailyReceipt) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: receipt.id.uuidString)
        let record = CKRecord(recordType: "DailyReceipt", recordID: recordID)
        let encoder = JSONEncoder()
        record["date"] = receipt.date as CKRecordValue
        record["data"] = try encoder.encode(receipt) as CKRecordValue
        return record
    }

    private func recordToReceipt(_ record: CKRecord) throws -> DailyReceipt {
        guard let data = record["data"] as? Data else { throw CloudKitError.invalidRecord }
        return try JSONDecoder().decode(DailyReceipt.self, from: data)
    }

    enum CloudKitError: Error {
        case invalidRecord
    }
}
