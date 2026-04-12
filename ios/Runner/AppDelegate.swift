import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let channelName = "com.aura.recording/audio"
  private var audioRecorder: AVAudioRecorder?
  private var recordingUrl: URL?
  private var isPaused = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: channelName,
        binaryMessenger: controller.binaryMessenger
      )

      channel.setMethodCallHandler { [weak self] call, result in
        guard let self else {
          result(
            FlutterError(
              code: "UNAVAILABLE",
              message: "App delegate is unavailable",
              details: nil
            )
          )
          return
        }

        switch call.method {
        case "startRecording":
          guard
            let arguments = call.arguments as? [String: Any],
            let path = arguments["path"] as? String
          else {
            result(
              FlutterError(
                code: "INVALID_ARGS",
                message: "Path is required",
                details: nil
              )
            )
            return
          }
          self.startRecording(path: path, result: result)
        case "stopRecording":
          self.stopRecording(result: result)
        case "pauseRecording":
          self.pauseRecording(result: result)
        case "resumeRecording":
          self.resumeRecording(result: result)
        case "getAmplitude":
          self.getAmplitude(result: result)
        case "setWakeLock":
          result(nil)
        case "getDeviceAudioCapabilities":
          result(
            [
              "sampleRate": 44_100,
              "channels": 1,
              "platform": "iOS"
            ]
          )
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func startRecording(path: String, result: @escaping FlutterResult) {
    let session = AVAudioSession.sharedInstance()

    do {
      try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
      try session.setActive(true)

      let url = URL(fileURLWithPath: path)
      let settings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44_100,
        AVNumberOfChannelsKey: 1,
        AVEncoderBitRateKey: 128_000,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
      ]

      let recorder = try AVAudioRecorder(url: url, settings: settings)
      recorder.isMeteringEnabled = true

      guard recorder.record() else {
        result(
          FlutterError(
            code: "RECORDING_ERROR",
            message: "Unable to start recording",
            details: nil
          )
        )
        return
      }

      audioRecorder = recorder
      recordingUrl = url
      isPaused = false

      result(
        [
          "path": path,
          "sampleRate": 44_100,
          "bitRate": 128_000,
          "channels": 1
        ]
      )
    } catch {
      result(
        FlutterError(
          code: "RECORDING_ERROR",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func stopRecording(result: @escaping FlutterResult) {
    guard let recorder = audioRecorder else {
      result(
        FlutterError(
          code: "NOT_RECORDING",
          message: "No active recording to stop",
          details: nil
        )
      )
      return
    }

    recorder.stop()
    audioRecorder = nil
    isPaused = false

    let path = recordingUrl?.path
    recordingUrl = nil

    do {
      try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    } catch {
      // Session teardown failure should not block the saved file from returning.
    }

    result(path)
  }

  private func getAmplitude(result: FlutterResult) {
    guard let recorder = audioRecorder, recorder.isRecording, !isPaused else {
      result(0.0)
      return
    }

    recorder.updateMeters()
    let averagePower = recorder.averagePower(forChannel: 0)
    let normalized = max(0.0, min(1.0, pow(10.0, averagePower / 20.0)))
    result(normalized)
  }

  private func pauseRecording(result: FlutterResult) {
    guard let recorder = audioRecorder, recorder.isRecording else {
      result(
        FlutterError(
          code: "NOT_RECORDING",
          message: "No active recording to pause",
          details: nil
        )
      )
      return
    }

    recorder.pause()
    isPaused = true
    result(nil)
  }

  private func resumeRecording(result: FlutterResult) {
    guard let recorder = audioRecorder else {
      result(
        FlutterError(
          code: "NOT_RECORDING",
          message: "No active recording to resume",
          details: nil
        )
      )
      return
    }

    guard isPaused else {
      result(nil)
      return
    }

    if recorder.record() {
      isPaused = false
      result(nil)
    } else {
      result(
        FlutterError(
          code: "RESUME_ERROR",
          message: "Unable to resume recording",
          details: nil
        )
      )
    }
  }
}
