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
    try? configureSharedAudioSession()

    let captureChannel = FlutterMethodChannel(
      name: "flute/capture_lifecycle",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    captureChannel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "begin":
        do {
          try self?.configureSharedAudioSession()
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
        // Keep the shared audio session in default speaker mode so the
        // background metronome retains full output volume after capture ends.
        try? self?.configureSharedAudioSession()
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func configureSharedAudioSession() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(
      .playAndRecord,
      mode: .default,
      options: [
        .defaultToSpeaker,
        .allowBluetooth,
        .allowBluetoothA2DP,
        .mixWithOthers,
      ]
    )
    try session.setActive(true)
  }
}
