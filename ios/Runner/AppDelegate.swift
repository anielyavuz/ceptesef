import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let appGroupId = "group.com.turneight.ceptesef"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Share intent platform channel
    let controller = window?.rootViewController as! FlutterViewController
    let shareChannel = FlutterMethodChannel(
      name: "com.turneight.ceptesef/share",
      binaryMessenger: controller.binaryMessenger
    )

    shareChannel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      switch call.method {
      case "getSharedItems":
        let userDefaults = UserDefaults(suiteName: self.appGroupId)
        if let data = userDefaults?.data(forKey: "SharedItems"),
           let jsonString = String(data: data, encoding: .utf8) {
          result(jsonString)
        } else {
          result(nil)
        }
      case "clearSharedItems":
        let userDefaults = UserDefaults(suiteName: self.appGroupId)
        userDefaults?.removeObject(forKey: "SharedItems")
        userDefaults?.synchronize()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Share extension'dan gelen ceptesef:// URL'sini yakala
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if url.scheme == "ceptesef" && url.host == "share" {
      // Uygulama foreground'a geldi — Flutter tarafı polling ile paylaşımı alacak
      return true
    }
    return super.application(app, open: url, options: options)
  }
}