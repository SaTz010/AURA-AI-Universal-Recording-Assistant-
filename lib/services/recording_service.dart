import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:record/record.dart';

import 'recordings_storage.dart';

enum RecordingState { idle, recording, stopping }

@pragma('vm:entry-point')
void recordingForegroundEntry() {
  FlutterForegroundTask.setTaskHandler(_RecordingForegroundHandler());
}

class _RecordingForegroundHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') {
      FlutterForegroundTask.sendDataToMain('stop');
    }
  }
}

class RecordingService {
  RecordingService._();
  static final RecordingService instance = RecordingService._();

  static const int _serviceId = 4242;
  static const int _maxAmplitudeBars = 200;

  final AudioRecorder _recorder = AudioRecorder();
  final Stopwatch _stopwatch = Stopwatch();

  final ValueNotifier<RecordingState> stateNotifier =
      ValueNotifier(RecordingState.idle);
  final ValueNotifier<Duration> elapsedNotifier =
      ValueNotifier(Duration.zero);
  final ValueNotifier<List<double>> amplitudesNotifier =
      ValueNotifier(const []);

  Timer? _ticker;
  Timer? _notificationTicker;
  StreamSubscription<Amplitude>? _amplitudeSub;
  String? _currentPath;
  String? _currentUid;
  bool _foregroundInited = false;

  bool get isRecording => stateNotifier.value == RecordingState.recording;
  bool get isStopping => stateNotifier.value == RecordingState.stopping;
  String? get currentPath => _currentPath;
  String? get currentUid => _currentUid;

  Future<bool> hasPermission() => _recorder.hasPermission();

  void _initForegroundTask() {
    if (_foregroundInited) return;
    _foregroundInited = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'aura_recording',
        channelName: 'Recording',
        channelDescription: 'Shown while AURA is recording audio.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  Future<bool> start(String? uid) async {
    if (stateNotifier.value != RecordingState.idle) return false;

    final granted = await _recorder.hasPermission();
    if (!granted) return false;

    _initForegroundTask();

    final dir = await RecordingsStorage.getUserRecordingsDir(uid);
    final path =
        '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

    try {
      await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        notificationTitle: 'AURA is recording',
        notificationText: '00:00',
        callback: recordingForegroundEntry,
      );
    } catch (_) {
      // Foreground service start can fail (e.g. notifications denied on
      // Android 14+). Continue with recording anyway — the user just won't
      // get the background guarantee.
    }

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 128000,
          numChannels: 1,
        ),
        path: path,
      );
    } catch (e) {
      try {
        await FlutterForegroundTask.stopService();
      } catch (_) {}
      return false;
    }

    _currentPath = path;
    _currentUid = uid;
    _stopwatch
      ..reset()
      ..start();

    elapsedNotifier.value = Duration.zero;
    amplitudesNotifier.value = const [];
    stateNotifier.value = RecordingState.recording;

    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      elapsedNotifier.value = _stopwatch.elapsed;
    });

    _notificationTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateNotification();
    });

    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((amp) {
      // amp.current is dBFS; ~-60 dB ≈ silence, 0 dB ≈ peak.
      final normalized = ((amp.current + 60.0) / 60.0).clamp(0.0, 1.0);
      final next = List<double>.from(amplitudesNotifier.value)..add(normalized);
      if (next.length > _maxAmplitudeBars) {
        next.removeRange(0, next.length - _maxAmplitudeBars);
      }
      amplitudesNotifier.value = next;
    });

    return true;
  }

  Future<String?> stop() async {
    if (stateNotifier.value != RecordingState.recording) return null;
    stateNotifier.value = RecordingState.stopping;

    _stopwatch.stop();
    _ticker?.cancel();
    _ticker = null;
    _notificationTicker?.cancel();
    _notificationTicker = null;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;

    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      path = _currentPath;
    }

    try {
      await FlutterForegroundTask.stopService();
    } catch (_) {}

    final result = path ?? _currentPath;
    _currentPath = null;
    _currentUid = null;

    _stopwatch.reset();
    elapsedNotifier.value = Duration.zero;
    amplitudesNotifier.value = const [];
    stateNotifier.value = RecordingState.idle;

    return result;
  }

  Future<void> cancel() async {
    if (stateNotifier.value == RecordingState.idle) return;
    final path = await stop();
    if (path != null) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  Future<void> _updateNotification() async {
    final e = _stopwatch.elapsed;
    final mins = e.inMinutes.toString().padLeft(2, '0');
    final secs = (e.inSeconds % 60).toString().padLeft(2, '0');
    try {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'AURA is recording',
        notificationText: '$mins:$secs',
      );
    } catch (_) {}
  }
}
