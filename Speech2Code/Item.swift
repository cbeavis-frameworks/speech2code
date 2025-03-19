//
//  Item.swift
//  Speech2Code
//
//  Created by Chris Beavis on 13/03/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
