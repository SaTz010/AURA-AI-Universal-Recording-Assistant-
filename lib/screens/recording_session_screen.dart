import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../services/recording_service.dart';
import '../services/recordings_library_events.dart';
import '../services/recordings_storage.dart';
import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';
import '../providers/auth_provider.dart';
import '../widgets/aura_snack_bar.dart';

class RecordingSessionScreen extends StatefulWidget {
  const RecordingSessionScreen({super.key});

  @override
  State<RecordingSessionScreen> createState() => _RecordingSessionScreenState();
}

class _RecordingSessionScreenState extends State<RecordingSessionScreen> {
  final RecordingService _service = RecordingService.instance;

  String? _effectiveUid;
  bool _hasStarted = false;
  bool _isInitializing = true;
  bool _isStopping = false;

  void _onForegroundData(Object data) {
    if (data == 'stop') {
      unawaited(_stopRecording());
    }
  }

  @override
  void initState() {
    super.initState();
    FlutterForegroundTask.addTaskDataCallback(_onForegroundData);
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

    if (_service.isRecording) {
      // Rehydrate UI from existing session (e.g. user reopened the app).
      _isInitializing = false;
    } else {
      unawaited(_startRecordingSession());
    }
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onForegroundData);
    super.dispose();
  }

  Future<void> _startRecordingSession() async {
    setState(() => _isInitializing = true);

    final hasPerm = await _service.hasPermission();
    if (!hasPerm) {
      if (!mounted) return;
      showAuraSnackBar(
        context,
        message: 'Microphone permission is needed to record audio.',
      );
      Navigator.pop(context);
      return;
    }

    final notifPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notifPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    final ok = await _service.start(_effectiveUid);
    if (!mounted) return;
    if (!ok) {
      showAuraSnackBar(
        context,
        message: 'We could not start recording. Please try again.',
      );
      Navigator.pop(context);
      return;
    }

    setState(() => _isInitializing = false);
  }

  Future<void> _cancelRecording() async {
    if (_isStopping) return;
    if (!_service.isRecording) {
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() => _isStopping = true);
    await _service.cancel();
    if (!mounted) return;
    setState(() => _isStopping = false);
    Navigator.pop(context);
  }

  Future<void> _stopRecording() async {
    if (_isStopping || !_service.isRecording) return;
    setState(() => _isStopping = true);

    unawaited(
      Future<void>.delayed(const Duration(seconds: 6), () {
        if (!mounted || !_isStopping) return;
        showAuraSnackBar(
          context,
          message: 'Finalizing recording... please wait.',
        );
      }),
    );

    final path = await _service.stop();
    if (!mounted) return;

    if (path == null) {
      setState(() => _isStopping = false);
      Navigator.pop(context);
      return;
    }

    final recordedFile = File(path);
    final isReady = await _waitForRecordingFileReady(recordedFile);
    if (!mounted) return;
    if (!isReady) {
      showAuraSnackBar(
        context,
        message: 'Recording could not be saved. Please try again.',
      );
      setState(() => _isStopping = false);
      Navigator.pop(context);
      return;
    }

    final defaultName = await _getNextAuraRecordingBaseName();
    if (!mounted) return;

    final userInput = await _showRecordingNameDialog(defaultName);
    final chosenBaseName = _sanitizeRecordingName(
      userInput == null || userInput.trim().isEmpty ? defaultName : userInput,
    );
    final renamedPath = await _renameRecordingFile(
      recordedFile,
      chosenBaseName,
    );
    final finalName = renamedPath != null
        ? File(renamedPath).path.split(RegExp(r'[\\/]')).last
        : recordedFile.path.split(RegExp(r'[\\/]')).last;

    if (!mounted) return;
    RecordingsLibraryEvents.notifyChanged();
    setState(() => _isStopping = false);
    Navigator.pop(context, finalName);
  }

  Future<bool> _waitForRecordingFileReady(File file) async {
    try {
      if (!await file.exists()) return false;

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
      final baseName = fileName.replaceAll(
        RegExp(r'\.m4a$', caseSensitive: false),
        '',
      );
      final match = auraPattern.firstMatch(baseName);
      if (match != null) {
        final parsed = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (parsed > maxIndex) {
          maxIndex = parsed;
        }
      }
    }
    return 'AURA_${maxIndex + 1}';
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
              hintText: 'AURA_1',
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

  Future<String?> _renameRecordingFile(
    File originalFile,
    String preferredBaseName,
  ) async {
    final safeBase = preferredBaseName.isEmpty ? 'AURA_1' : preferredBaseName;
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

    return PopScope(
      canPop: !_service.isRecording || _isInitializing,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _service.isRecording) {
          showAuraSnackBar(
            context,
            message: 'Use Stop to save or Cancel to discard.',
          );
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.background,
          elevation: 0,
          leading: IconButton(
            onPressed: _service.isRecording
                ? null
                : () => Navigator.pop(context),
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
                                  color: const Color(
                                    0xFFFF4D4F,
                                  ).withValues(alpha: 0.35),
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
                            style: AuraTypography.bodyLarge(
                              colors.textSecondary,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: AuraSpacing.sm),
                      ValueListenableBuilder<Duration>(
                        valueListenable: _service.elapsedNotifier,
                        builder: (context, elapsed, _) {
                          return Text(
                            _formatRecordingTime(elapsed),
                            textAlign: TextAlign.center,
                            style:
                                AuraTypography.displayLarge(
                                  colors.textPrimary,
                                ).copyWith(
                                  letterSpacing: 2,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          );
                        },
                      ),
                      const SizedBox(height: AuraSpacing.lg),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 420,
                              maxHeight: 360,
                            ),
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
                                    child: ValueListenableBuilder<List<double>>(
                                      valueListenable:
                                          _service.amplitudesNotifier,
                                      builder: (context, amps, _) {
                                        return CustomPaint(
                                          painter: _LiveWaveformPainter(
                                            amplitudes: amps,
                                            color: colors.accent,
                                          ),
                                          size: Size.infinite,
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: AuraSpacing.md),
                                  Text(
                                    'Recording your audio clearly and continuously.',
                                    textAlign: TextAlign.center,
                                    style: AuraTypography.bodyMedium(
                                      colors.textSecondary,
                                    ),
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
                              onPressed: _isStopping ? null : _cancelRecording,
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Cancel'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colors.textPrimary,
                                side: BorderSide(color: colors.border),
                                padding: const EdgeInsets.symmetric(
                                  vertical: AuraSpacing.md,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: AuraRadius.mdBr,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AuraSpacing.md),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isStopping ? null : _stopRecording,
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

class _LiveWaveformPainter extends CustomPainter {
  _LiveWaveformPainter({required this.amplitudes, required this.color});

  final List<double> amplitudes;
  final Color color;

  static const double _barWidth = 2.2;
  static const double _spacing = 3.4;

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = _barWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final centerY = size.height / 2;
    final maxBars = ((size.width + _spacing) / (_barWidth + _spacing)).floor();
    final start = amplitudes.length > maxBars ? amplitudes.length - maxBars : 0;
    final visible = amplitudes.sublist(start);

    final totalWidth =
        visible.length * _barWidth + (visible.length - 1) * _spacing;
    var x = (size.width - totalWidth) / 2;
    if (x < 0) x = 0;

    for (final amp in visible) {
      final h = (amp * size.height * 0.95).clamp(2.0, size.height);
      canvas.drawLine(
        Offset(x, centerY - h / 2),
        Offset(x, centerY + h / 2),
        paint,
      );
      x += _barWidth + _spacing;
    }
  }

  @override
  bool shouldRepaint(covariant _LiveWaveformPainter oldDelegate) {
    return oldDelegate.amplitudes != amplitudes || oldDelegate.color != color;
  }
}
