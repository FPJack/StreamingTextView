//
//  AppDelegate.swift
//  ZLStreamingTextView_Example
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 用导航控制器包裹根控制器，方便各页面使用 push 跳转。
        let window = UIWindow(frame: UIScreen.main.bounds)
        let root = ViewController()
        window.rootViewController = UINavigationController(rootViewController: root)
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
