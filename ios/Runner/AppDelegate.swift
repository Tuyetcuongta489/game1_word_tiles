import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Tự động nhận diện bản TestFlight (sandboxReceipt) hoặc bản Debug trong Xcode
    let isTestFlight = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    #if DEBUG
    let isDebug = true
    #else
    let isDebug = false
    #endif

    // Chỉ bật DebugView trên TestFlight/Debug; bản App Store thật sẽ xóa sạch cờ debug
    if isTestFlight || isDebug {
      UserDefaults.standard.set(true, forKey: "/google/firebase/debug_mode")
      UserDefaults.standard.set(true, forKey: "/google/measurement/debug_mode")
      UserDefaults.standard.synchronize()
      print("[AppDelegate] Firebase Analytics DebugView is ENABLED for TestFlight/Debug.")
    } else {
      UserDefaults.standard.removeObject(forKey: "/google/firebase/debug_mode")
      UserDefaults.standard.removeObject(forKey: "/google/measurement/debug_mode")
      UserDefaults.standard.synchronize()
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
