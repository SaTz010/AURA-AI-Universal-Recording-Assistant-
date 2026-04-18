import 'dart:async';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';

import '../services/recordings_library_events.dart';
import '../services/recordings_storage.dart';
import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';
import '../providers/auth_provider.dart';

class RecordingSessionScreen extends StatefulWidget {
  const RecordingSessionScreen({super.key});

  @override
  State<RecordingSessionScreen> createState() => _RecordingSessionScreenState();
}

class _RecordingSessionScreenState extends State<RecordingSessionScreen>
    with WidgetsBindingObserver {
  final Stopwatch _recordingStopwatch = Stopwatch();
  final RecorderController _recorderController = RecorderController();

  String? _effectiveUid;
  bool _hasStarted = false;

  static const RecorderSettings _speechRecorderSettings = RecorderSettings(
    // 44.1kHz AAC in MP4 is broadly supported across Android OEMs.
    // 16kHz AAC can produce empty/corrupt files on some devices.
    sampleRate: 44100,
    bitRate: 128000,
    androidEncoderSettings: AndroidEncoderSettings(androidEncoder: AndroidEncoder.aacLc),
    iosEncoderSettings: IosEncoderSetting(iosEncoder: IosEncoder.kAudioFormatMPEG4AAC),
  );

  Timer? _ticker;
  String? _recordingPath;
  Duration _elapsedDuration = Duration.zero;
  bool _isInitializing = true;
  bool _isRecording = false;
  bool _isBusy = false;
  bool _isStopping = false;

  Future<void> _cancelRecording() async {
    if (_isBusy || _isStopping) return;

    // If we're not actively recording, Cancel behaves like a normal back.
    if (!_isRecording) {
      if (mounted) Navigator.pop(context);
      return;
    }

    _isBusy = true;
    if (mounted) {
      setState(() => _isStopping = true);
    }

    // Stop timers/UI immediately.
    _recordingStopwatch.stop();

    try {
      // Ensure we fully finalize the platform recorder before touching the file.
      await _stopRecorderGracefully();

      final path = _recordingPath;
      if (path != null) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {
          // Best effort deletion.
        }
      }
    } catch (_) {
      // Best effort cancel.
    } finally {
      _recordingStopwatch
        ..stop()
        ..reset();

      if (mounted) {
        setState(() {
          _isRecording = false;
          _isStopping = false;
        });
        Navigator.pop(context);
      }
      _isBusy = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      if (!_isRecording) return;
      setState(() {
        _elapsedDuration = _recordingStopwatch.elapsed;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final authProvider = AuraAuthProvider.of(context);
    if (!authProvider.initialized) return;

    final nextUid = authProvider.isGuest ? null : authProvider.user?.uid;
    _effectiveUid = nextUid;

    if (_hasStarted) return;
    _hasStarted = true;
    unawaited(_startRecordingSession());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _recordingStopwatch.stop();
    _recorderController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached && _isRecording) {
      unawaited(_stopRecording(popWhenDone: false));
    }
  }

  Future<void> _startRecordingSession() async {
    setState(() {
      _isInitializing = true;
    });

    var recordingStarted = false;

    try {
      final hasPermission = await _recorderController.checkPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
        Navigator.pop(context);
        return;
      }

      final dir = await RecordingsStorage.getUserRecordingsDir(_effectiveUid);
      final filePath = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorderController.record(
        path: filePath,
        recorderSettings: _speechRecorderSettings,
      );
      recordingStarted = true;
      _recordingPath = filePath;
      _recordingStopwatch
        ..reset()
        ..start();

      if (!mounted) return;
      setState(() {
        _elapsedDuration = Duration.zero;
        _isRecording = true;
        _isInitializing = false;
      });
    } catch (error) {
      if (recordingStarted) {
        try {
          await _recorderController.stop();
        } catch (_) {}
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting recording: $error')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _stopRecording({bool popWhenDone = true}) async {
    if (_isBusy || !_isRecording) return;
    _isBusy = true;

    if (mounted) {
      setState(() => _isStopping = true);
    }

    // Stop the UI timer immediately so the app doesn't look "stuck recording"
    // while the recorder finalizes the file.
    _recordingStopwatch.stop();
    if (mounted) {
      setState(() {
        _elapsedDuration = _recordingStopwatch.elapsed;
      });
    }

    unawaited(Future<void>.delayed(const Duration(seconds: 6), () {
      if (!mounted || !_isStopping) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finalizing recording… please wait')),
      );
    }));

    try {
      final path = await _stopRecorderGracefully() ?? _recordingPath;

      _recordingStopwatch
        ..stop()
        ..reset();

      if (!mounted) return;
      setState(() {
        _isRecording = false;
      });

      if (path == null || !popWhenDone) {
        if (popWhenDone && mounted) {
          Navigator.pop(context);
        }
        return;
      }

      final recordedFile = File(path);
      final isReady = await _waitForRecordingFileReady(recordedFile);
      if (!isReady) {
        if (popWhenDone && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording could not be saved. Please try again.')),
          );
          Navigator.pop(context);
        }
        return;
      }

      final defaultName = await _getNextAuraRecordingBaseName();
      if (!mounted) return;

      final userInput = await _showRecordingNameDialog(defaultName);
      final chosenBaseName = _sanitizeRecordingName(
        userInput == null || userInput.trim().isEmpty ? defaultName : userInput,
      );
      final renamedPath = await _renameRecordingFile(recordedFile, chosenBaseName);
      final finalName = renamedPath != null
          ? File(renamedPath).path.split(RegExp(r'[\\/]')).last
          : recordedFile.path.split(RegExp(r'[\\/]')).last;

      if (!mounted) return;
      RecordingsLibraryEvents.notifyChanged();
      Navigator.pop(context, finalName);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error stopping recording: $error')),
      );
      if (popWhenDone) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isStopping = false);
      }
      _isBusy = false;
    }
  }

  Future<String?> _stopRecorderGracefully() async {
    // Important: Future.timeout does NOT cancel the underlying stop() call.
    // If we proceed while the platform recorder is still finalizing, we can
    // end up renaming/copying a file that's still being written, leading to
    // corrupt recordings.
    final stopFuture = _recorderController.stop();

    try {
      return await stopFuture.timeout(const Duration(seconds: 20));
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Finalizing recording… please keep the app open.')),
        );
      }
      // Wait for the original stop() to actually complete.
      return await stopFuture;
    }
  }

  Future<bool> _waitForRecordingFileReady(File file) async {
    try {
      if (!await file.exists()) return false;

      // Wait briefly for the encoder to flush. Some devices report 0 bytes
      // immediately after stop() even though the file becomes valid shortly.
      const maxWait = Duration(seconds: 3);
      const interval = Duration(milliseconds: 150);

      var waited = Duration.zero;
      var lastSize = -1;
      var stableCount = 0;

      while (waited <= maxWait) {
        final size = await file.length();
        if (size > 0) {
          if (size == lastSize) {
            stableCount += 1;
            if (stableCount >= 2) return true;
          } else {
            stableCount = 0;
          }
        }

        lastSize = size;
        await Future<void>.delayed(interval);
        waited += interval;
      }

      return await file.exists() && await file.length() > 0;
    } catch (_) {
      return false;
    }
  }

  String _formatRecordingTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<String> _getNextAuraRecordingBaseName() async {
    final dir = await RecordingsStorage.getUserRecordingsDir(_effectiveUid);
    final entries = dir.listSync();
    final auraPattern = RegExp(r'^Aura_(\d+)$', caseSensitive: false);
    var maxIndex = 0;

    for (final entry in entries) {
      if (entry is! File || !entry.path.toLowerCase().endsWith('.m4a')) {
        continue;
      }

      final fileName = entry.path.split('/').last;
      final baseName = fileName.replaceAll(RegExp(r'\.m4a$', caseSensitive: false), '');
      final match = auraPattern.firstMatch(baseName);
      if (match != null) {
        final parsed = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (parsed > maxIndex) {
          maxIndex = parsed;
        }
      }
    }

    return 'Aura_${maxIndex + 1}';
  }

  String _sanitizeRecordingName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  Future<String?> _showRecordingNameDialog(String defaultName) async {
    final controller = TextEditingController(text: defaultName);
    final colors = AuraThemeColors.of(context);

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.surface,
          title: const Text('Name your recording'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Recording name',
              hintText: 'Aura_1',
            ),
            onSubmitted: (value) => Navigator.pop(dialogContext, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, defaultName),
              child: const Text('Use default'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _renameRecordingFile(File originalFile, String preferredBaseName) async {
    final safeBase = preferredBaseName.isEmpty ? 'Aura_1' : preferredBaseName;
    final dir = await RecordingsStorage.getUserRecordingsDir(_effectiveUid);
    var attempt = 0;

    while (attempt < 1000) {
      final suffix = attempt == 0 ? '' : '_$attempt';
      final candidatePath = '${dir.path}/$safeBase$suffix.m4a';
      final candidateFile = File(candidatePath);

      if (!await candidateFile.exists()) {
        try {
          final renamed = await originalFile.rename(candidatePath);
          return renamed.path;
        } catch (_) {
          // If rename fails (e.g., cross-device move or file lock), fall back to copy.
          try {
            await originalFile.copy(candidatePath);
            await originalFile.delete();
            return candidatePath;
          } catch (_) {
            return null;
          }
        }
      }

      attempt++;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    final displayedDuration = _elapsedDuration;

    return PopScope(
      canPop: !_isRecording || _isInitializing,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isRecording) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Use Stop to save or Cancel to discard.')),
          );
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.background,
          elevation: 0,
          leading: IconButton(
            onPressed: _isRecording ? null : () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
          ),
          title: Text(
            'Recording',
            style: AuraTypography.titleLarge(colors.textPrimary),
          ),
          centerTitle: true,
        ),
        body: _isInitializing
            ? Center(child: CircularProgressIndicator(color: colors.accent))
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AuraSpacing.xl,
                    AuraSpacing.lg,
                    AuraSpacing.xl,
                    AuraSpacing.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4D4F),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF4D4F).withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AuraSpacing.sm),
                          Text(
                            'Recording in progress',
                            textAlign: TextAlign.center,
                            style: AuraTypography.bodyLarge(colors.textSecondary).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AuraSpacing.sm),
                      Text(
                        _formatRecordingTime(displayedDuration),
                        textAlign: TextAlign.center,
                        style: AuraTypography.displayLarge(colors.textPrimary).copyWith(
                          letterSpacing: 2,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: AuraSpacing.lg),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 360),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AuraSpacing.lg,
                                vertical: AuraSpacing.md,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: AuraRadius.xlBr,
                                border: Border.all(color: colors.border),
                                boxShadow: AuraElevation.low(Colors.black),
                              ),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final waveformHeight = constraints.maxHeight.clamp(
                                          160.0,
                                          320.0,
                                        );
                                        return Align(
                                          alignment: Alignment.center,
                                          child: AudioWaveforms(
                                            enableGesture: false,
                                            size: Size(
                                              constraints.maxWidth,
                                              waveformHeight.toDouble(),
                                            ),
                                            recorderController: _recorderController,
                                            waveStyle: WaveStyle(
                                              waveColor: colors.accent,
                                              extendWaveform: true,
                                              showMiddleLine: false,
                                              spacing: 3.4,
                                              scaleFactor: 400,
                                              waveThickness: 2.2,
                                              waveformRenderMode: WaveformRenderMode.ltr,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: AuraSpacing.md),
                                  Text(
                                    'Recording your audio clearly and continuously.',
                                    textAlign: TextAlign.center,
                                    style: AuraTypography.bodyMedium(colors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AuraSpacing.xl),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: (_isBusy || _isStopping) ? null : _cancelRecording,
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Cancel'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colors.textPrimary,
                                side: BorderSide(color: colors.border),
                                padding: const EdgeInsets.symmetric(vertical: AuraSpacing.md),
                                shape: RoundedRectangleBorder(borderRadius: AuraRadius.mdBr),
                              ),
                            ),
                          ),
                          const SizedBox(width: AuraSpacing.md),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (_isBusy || _isStopping) ? null : () => _stopRecording(),
                              icon: const Icon(Icons.stop_rounded),
                              label: Text(_isStopping ? 'Stopping…' : 'Stop'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
