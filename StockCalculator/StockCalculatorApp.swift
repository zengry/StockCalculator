//
//  StockCalculatorApp.swift
//  StockCalculator
//
//  Created by danny on 2026/9/16.
//

import SwiftUI

@main
struct StockCalculatorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
            #if targetEnvironment(macCatalyst)
                .frame(minWidth: 360, minHeight: 640)
            #endif
        }
        .defaultSize(width: 400, height: 720)
    }
}
