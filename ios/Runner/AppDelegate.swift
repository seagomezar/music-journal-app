import Flutter
import AVFoundation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let captureChannel = FlutterMethodChannel(
      name: "flute/capture_lifecycle",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    captureChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "begin":
        do {
          let session = AVAudioSession.sharedInstance()
          try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.allowBluetooth, .defaultToSpeaker]
          )
          try session.setActive(true)
          result(nil)
        } catch {
          result(
            FlutterError(
              code: "capture_audio_session_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }

      case "end":
        // Leave the shared audio session active so the background metronome is
        // not interrupted when capture ends.
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
