import UIKit

#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let bleManager = VPBleCentralManage.sharedBleManager()
        bleManager?.isLogEnable = true
        bleManager?.peripheralManage = VPPeripheralManage.shareVPPeripheralManager()

#if canImport(FirebaseCore)
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil,
           FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
#endif

        if let centralIdentifiers = launchOptions?[.bluetoothCentrals] {
            print("Bluetooth central restore identifiers: \(centralIdentifiers)")
        }

        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
