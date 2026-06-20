//
//  AppSetting.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 14/06/26.
//

import Foundation

struct AppSetting: Identifiable {
    var id: String { key }
    var key: String
    var value: String
    var updatedAt: Date
}
