//
//  StockCalculatorApp.swift
//  StockCalculator
//
//  Created by danny on 2026/9/16.
//

import SwiftUI
import UIKit

@main
struct StockCalculatorApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Mac 上的初始窗口尺寸
        .defaultSize(width: 400, height: 600)
    }
}

// MARK: - 窗口尺寸限制（iOS App 运行在 Mac 时生效）

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: .windowApplication)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        // 系统默认最小尺寸偏大，放宽到 iPhone SE 级别
        windowScene.sizeRestrictions?.minimumSize = CGSize(width: 320, height: 480)
    }
}
