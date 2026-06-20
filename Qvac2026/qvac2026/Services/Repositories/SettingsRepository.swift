//
//  SettingsRepository.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 14/06/26.
//

import Foundation
import SQLite

final class SettingsRepository {
    private let db: Connection

    private let table        = Table("settings")
    private let colKey       = Expression<String>("key")
    private let colValue     = Expression<String>("value")
    private let colUpdatedAt = Expression<Double>("updated_at")

    init(db: Connection) {
        self.db = db
    }

    func string(forKey key: String) -> String? {
        guard let rows = try? db.prepare(table.filter(colKey == key)) else { return nil }
        return rows.map { $0[colValue] }.first
    }

    func set(_ value: String, forKey key: String) {
        do {
            try db.run(table.insert(or: .replace,
                colKey       <- key,
                colValue     <- value,
                colUpdatedAt <- Date().timeIntervalSince1970
            ))
        } catch {
            print("SettingsRepository set error: \(error)")
        }
    }

    func bool(forKey key: String) -> Bool? {
        string(forKey: key).map { $0 == "true" }
    }

    func setBool(_ value: Bool, forKey key: String) {
        set(value ? "true" : "false", forKey: key)
    }

    func remove(key: String) {
        let target = table.filter(colKey == key)
        do {
            try db.run(target.delete())
        } catch {
            print("SettingsRepository remove error: \(error)")
        }
    }

    func all() -> [AppSetting] {
        guard let rows = try? db.prepare(table.order(colKey.asc)) else { return [] }
        return rows.map {
            AppSetting(
                key:       $0[colKey],
                value:     $0[colValue],
                updatedAt: Date(timeIntervalSince1970: $0[colUpdatedAt])
            )
        }
    }
}
