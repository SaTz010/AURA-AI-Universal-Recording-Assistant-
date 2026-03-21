import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';
import 'widgets/main_bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  late AnimationController _micController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;

  bool _isRecording = false;
  int _selectedBottomIndex = 0;

  static const platform = MethodChannel('com.aura.recording/audio');
  String? _recordingStatus = '';
  bool _isProcessing = false;
  late Stopwatch _recordingStopwatch;
  Timer? _recordingStatusTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recordingStopwatch = Stopwatch();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    _micController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    if (_isRecording) {
      platform.invokeMethod('stopRecording').catchError((_) {});
      platform.invokeMethod('setWakeLock', {'enabled': false}).catchError((_) {});
    }

    _pulseController.dispose();
    _micController.dispose();
    _waveController.dispose();
    _recordingStopwatch.stop();
    _recordingStatusTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached && _isRecording) {
      _stopRecording();
    }
  }

  void _setRecordingStatus(String message, {Duration? clearAfter}) {
    _recordingStatusTimer?.cancel();
    if (mounted) {
      setState(() {
        _recordingStatus = message;
      });
    }

    if (clearAfter != null) {
      _recordingStatusTimer = Timer(clearAfter, () {
        if (!mounted) return;
        setState(() {
          _recordingStatus = '';
        });
      });
    }
  }

  String _formatRecordingTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _startRecording() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final permission = await Permission.microphone.request();
      if (!permission.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')),
          );
        }
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await platform.invokeMethod('startRecording', {'path': filePath});
      await platform.invokeMethod('setWakeLock', {'enabled': true}).catchError((_) {});

      setState(() {
        _isRecording = true;
      });
      _setRecordingStatus('Recording...');

      _recordingStopwatch.start();

      Future.doWhile(() async {
        if (!_isRecording) return false;
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          setState(() {});
        }
        return true;
      });

      _micController.forward();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording started'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting recording: $e')),
        );
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _stopRecording() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final result = await platform.invokeMethod('stopRecording');
      final path = result as String?;

      await platform.invokeMethod('setWakeLock', {'enabled': false}).catchError((_) {});

      _recordingStopwatch.stop();
      _recordingStopwatch.reset();

      setState(() {
        _isRecording = false;
      });
      _setRecordingStatus(path != null ? 'Finalizing recording...' : 'Recording failed');

      _micController.reverse();

      if (path != null) {
        final recordedFile = File(path);
        if (await recordedFile.exists()) {
          final defaultName = await _getNextAuraRecordingBaseName();
          if (!mounted) return;

          final userInput = await _showRecordingNameDialog(defaultName);
          final chosenBaseName = _sanitizeRecordingName(
            userInput == null || userInput.trim().isEmpty ? defaultName : userInput,
          );
          final renamedPath = await _renameRecordingFile(recordedFile, chosenBaseName);
          final finalName = renamedPath != null
              ? File(renamedPath).path.split('/').last
              : recordedFile.path.split('/').last;

          if (!mounted) return;
          _setRecordingStatus(
            'Recording saved: $finalName',
            clearAfter: const Duration(seconds: 5),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Recording saved: $finalName')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error stopping recording: $e')),
        );
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<String> _getNextAuraRecordingBaseName() async {
    final dir = await getApplicationDocumentsDirectory();
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
    final dir = await getApplicationDocumentsDirectory();
    var attempt = 0;

    while (attempt < 1000) {
      final suffix = attempt == 0 ? '' : '_$attempt';
      final candidatePath = '${dir.path}/$safeBase$suffix.m4a';
      final candidateFile = File(candidatePath);

      if (!await candidateFile.exists()) {
        final renamed = await originalFile.rename(candidatePath);
        return renamed.path;
      }

      attempt++;
    }

    return null;
  }

  void _onMicPressed() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  void _showRecordingLockMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stop recording to access other sections.'),
        duration: Duration(milliseconds: 900),
      ),
    );
  }

  Future<void> _onBottomNavTapped(int index) async {
    if (_isRecording) {
      _showRecordingLockMessage();
      return;
    }

    if (index == _selectedBottomIndex) return;
    setState(() => _selectedBottomIndex = index);

    switch (index) {
      case 0:
        return;
      case 1:
        await Navigator.pushNamed(context, '/recordings');
        break;
      case 2:
        await Navigator.pushNamed(context, '/history');
        break;
      case 3:
        await Navigator.pushNamed(context, '/summary');
        break;
    }

    if (mounted) {
      setState(() => _selectedBottomIndex = 0);
    }
  }

  Widget _buildSoundWaveVisualization() {
    final colors = AuraThemeColors.of(context);
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(7, (index) {
                final waveHeight = 8.0 +
                    (16.0 * sin((_waveController.value * 2 * pi) + (index * pi / 3.5)));
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3.5),
                  child: AnimatedContainer(
                    duration: AuraMotion.instant,
                    width: 3.5,
                    height: waveHeight.abs().clamp(4.0, 28.0),
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: AuraRadius.fullBr,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: AuraSpacing.md),
            Text(
              _formatRecordingTime(_recordingStopwatch.elapsed),
              style: AuraTypography.titleMedium(colors.textSecondary).copyWith(
                letterSpacing: 2.0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showUploadSheet() {
    final colors = AuraThemeColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AuraRadius.lg)),
      ),
      builder: (sheetContext) {
        final sheetColors = AuraThemeColors.of(sheetContext);
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AuraSpacing.xl,
            AuraSpacing.xl,
            AuraSpacing.xl,
            AuraSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AuraSpacing.lg),
                  decoration: BoxDecoration(
                    color: sheetColors.textTertiary.withValues(alpha: 0.3),
                    borderRadius: AuraRadius.fullBr,
                  ),
                ),
              ),
              Text(
                'Upload audio',
                style: AuraTypography.titleMedium(sheetColors.textPrimary),
              ),
              const SizedBox(height: AuraSpacing.sm),
              Text(
                'Choose an audio file from your device.',
                style: AuraTypography.bodySmall(sheetColors.textSecondary),
              ),
              const SizedBox(height: AuraSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: AuraSpacing.sm),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('File picker not implemented')),
                      );
                    },
                    child: const Text('Choose file'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);

    return PopScope(
      canPop: !_isRecording,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isRecording) {
          _showRecordingLockMessage();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        bottomNavigationBar: MainBottomNav(
          selectedIndex: _selectedBottomIndex,
          onTap: _onBottomNavTapped,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpacing.xl,
                  vertical: AuraSpacing.base,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              if (_isRecording) {
                                _showRecordingLockMessage();
                                return;
                              }
                              HapticFeedback.lightImpact();
                              Navigator.pushNamed(context, '/profile');
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(AuraSpacing.xxs),
                              child: CircleAvatar(
                                radius: 17,
                                backgroundColor: colors.surfaceElevated,
                                child: Icon(
                                  Icons.person_rounded,
                                  color: colors.iconDefault,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AuraSpacing.sm),
                        Text(
                          'Hi, Sanskar ',
                          style: AuraTypography.bodyMedium(colors.textPrimary).copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Material(
                      color: Colors.transparent,
                      borderRadius: AuraRadius.smBr,
                      child: InkWell(
                        borderRadius: AuraRadius.smBr,
                        onTap: () {
                          if (_isRecording) {
                            _showRecordingLockMessage();
                            return;
                          }
                          HapticFeedback.lightImpact();
                          Navigator.pushNamed(context, '/settings');
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(AuraSpacing.xs),
                          child: Icon(
                            Icons.settings_rounded,
                            color: colors.iconDefault,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AuraSpacing.xxl),
                child: Column(
                  children: [
                    Text(
                      'AURA',
                      style: AuraTypography.headlineLarge(colors.textPrimary),
                    ),
                    const SizedBox(height: AuraSpacing.sm),
                    Container(
                      width: 40,
                      height: 2,
                      decoration: BoxDecoration(
                        color: colors.textTertiary.withValues(alpha: 0.5),
                        borderRadius: AuraRadius.fullBr,
                      ),
                    ),
                    const SizedBox(height: AuraSpacing.base),
                    Text(
                      'Record now or import\nexisting audio files to get started',
                      textAlign: TextAlign.center,
                      style: AuraTypography.bodyLarge(colors.textSecondary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 220 + (_pulseAnimation.value * 40),
                                height: 220 + (_pulseAnimation.value * 40),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.accent.withValues(
                                      alpha: (1 - _pulseAnimation.value) * 0.25,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              Container(
                                width: 190 + (_pulseAnimation.value * 30),
                                height: 190 + (_pulseAnimation.value * 30),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.accent.withValues(
                                      alpha: (1 - _pulseAnimation.value) * 0.12,
                                    ),
                                    width: 1,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          _onMicPressed();
                        },
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 1.0, end: 0.92).animate(
                            CurvedAnimation(
                              parent: _micController,
                              curve: AuraMotion.standard,
                            ),
                          ),
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.micButton,
                              boxShadow: AuraElevation.glow(colors.micButton),
                            ),
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: AuraMotion.fast,
                                transitionBuilder: (child, anim) =>
                                    ScaleTransition(scale: anim, child: child),
                                child: Icon(
                                  _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                                  key: ValueKey(_isRecording),
                                  size: 56,
                                  color: colors.micIcon,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 80),
                child: Column(
                  children: [
                    if (_isRecording)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AuraSpacing.xl),
                        child: _buildSoundWaveVisualization(),
                      ),
                    AnimatedSwitcher(
                      duration: AuraMotion.fast,
                      child: _isRecording
                          ? const SizedBox.shrink()
                          : Text(
                              'Tap to start recording',
                              key: const ValueKey('tap-hint'),
                              style: AuraTypography.bodyMedium(colors.textSecondary),
                            ),
                    ),
                    if (_recordingStatus != null &&
                        _recordingStatus!.isNotEmpty &&
                        !_isRecording)
                      Padding(
                        padding: const EdgeInsets.only(top: AuraSpacing.sm),
                        child: Text(
                          _recordingStatus!,
                          textAlign: TextAlign.center,
                          style: AuraTypography.overline(colors.accent),
                        ),
                      ),
                    const SizedBox(height: AuraSpacing.xl),
                    Container(
                      width: 48,
                      height: 1,
                      decoration: BoxDecoration(
                        color: colors.divider,
                        borderRadius: AuraRadius.fullBr,
                      ),
                    ),
                    const SizedBox(height: AuraSpacing.xl),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: AuraRadius.mdBr,
                        onTap: () {
                          if (_isRecording) {
                            _showRecordingLockMessage();
                            return;
                          }
                          _showUploadSheet();
                        },
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.72,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AuraSpacing.base,
                            vertical: AuraSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: AuraRadius.mdBr,
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                color: colors.accent,
                                size: 20,
                              ),
                              const SizedBox(width: AuraSpacing.sm),
                              Text(
                                'Import existing audio',
                                style: AuraTypography.labelSmall(colors.accent),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
