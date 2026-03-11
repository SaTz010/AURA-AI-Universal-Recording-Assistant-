import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';
import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';

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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  static const platform = MethodChannel('com.aura.recording/audio');
  String? _recordingStatus = '';
  bool _isProcessing = false; // Guards against concurrent start/stop calls
  late Stopwatch _recordingStopwatch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recordingStopwatch = Stopwatch();

    // Pulse animation for the sonar rings
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    // Mic button scale animation for press feedback
    _micController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Sound wave animation controller
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // If recording is still active when widget is disposed, stop it
    if (_isRecording) {
      platform.invokeMethod('stopRecording').catchError((_) {});
      platform.invokeMethod('setWakeLock', {'enabled': false}).catchError((_) {});
    }
    _pulseController.dispose();
    _micController.dispose();
    _waveController.dispose();
    _recordingStopwatch.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If the app is being killed, attempt to finalize the recording
    if (state == AppLifecycleState.detached && _isRecording) {
      _stopRecording();
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
      // Request microphone permission
      final permission = await Permission.microphone.request();
      if (!permission.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')),
          );
        }
        return;
      }

      // Get application documents directory
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Call platform method to start recording
      await platform.invokeMethod('startRecording', {'path': filePath});

      // Acquire partial wakelock — keeps CPU active when screen is off
      await platform.invokeMethod('setWakeLock', {'enabled': true}).catchError((_) {});

      // IMPORTANT: Set _isRecording BEFORE starting the timer loop.
      // Previously this was set AFTER Future.doWhile, causing the loop
      // to exit immediately on its first iteration (race condition).
      setState(() {
        _isRecording = true;
        _recordingStatus = 'Recording...';
      });

      _recordingStopwatch.start();

      // Update UI every 100ms for the recording timer display
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
          const SnackBar(content: Text('Recording started'), duration: Duration(seconds: 1)),
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
      // Call platform method to stop recording
      final result = await platform.invokeMethod('stopRecording');
      final path = result as String?;

      // Release wakelock
      await platform.invokeMethod('setWakeLock', {'enabled': false}).catchError((_) {});

      _recordingStopwatch.stop();
      _recordingStopwatch.reset();

      setState(() {
        _isRecording = false;
        _recordingStatus = path != null ? 'Recording saved: ${File(path).path.split('/').last}' : 'Recording failed';
      });

      _micController.reverse();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording saved: $path')),
        );
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

  void _onMicPressed() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  Widget _buildSoundWaveVisualization() {
    final colors = AuraThemeColors.of(context);
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Column(
          children: [
            // Sound Wave Bars
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(7, (index) {
                double waveHeight = 8.0 +
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
            // Recording Timer
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
            AuraSpacing.xl, AuraSpacing.xl, AuraSpacing.xl, AuraSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle indicator
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AuraSpacing.lg),
                  decoration: BoxDecoration(
                    color: sheetColors.textTertiary.withOpacity(0.3),
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
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colors.background,
      drawer: _buildDrawer(context),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpacing.xl,
                vertical: AuraSpacing.base,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Material(
                    color: Colors.transparent,
                    borderRadius: AuraRadius.smBr,
                    child: InkWell(
                      borderRadius: AuraRadius.smBr,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _scaffoldKey.currentState?.openDrawer();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(AuraSpacing.xs),
                        child: Icon(
                          Icons.menu_rounded,
                          color: colors.iconDefault,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 26),
                ],
              ),
            ),

            // ── Branding ─────────────────────────────────────────
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
                      color: colors.textTertiary.withOpacity(0.5),
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

            // ── Mic button ───────────────────────────────────────
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pulsing sonar rings
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
                                  color: colors.accent.withOpacity(
                                    (1 - _pulseAnimation.value) * 0.25,
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
                                  color: colors.accent.withOpacity(
                                    (1 - _pulseAnimation.value) * 0.12,
                                  ),
                                  width: 1,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    // Main mic button
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _onMicPressed();
                      },
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 1.0, end: 0.92)
                            .animate(CurvedAnimation(
                          parent: _micController,
                          curve: AuraMotion.standard,
                        )),
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
                                _isRecording
                                    ? Icons.stop_rounded
                                    : Icons.mic_rounded,
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

            // ── Bottom section ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: Column(
                children: [
                  // Wave visualisation
                  if (_isRecording)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AuraSpacing.xl),
                      child: _buildSoundWaveVisualization(),
                    ),

                  // Helper text / status
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

                  // Divider
                  Container(
                    width: 48,
                    height: 1,
                    decoration: BoxDecoration(
                      color: colors.divider,
                      borderRadius: AuraRadius.fullBr,
                    ),
                  ),

                  const SizedBox(height: AuraSpacing.xl),

                  // Import button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: AuraRadius.mdBr,
                      onTap: _showUploadSheet,
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
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Drawer(
      backgroundColor: colors.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AuraSpacing.xl),
          children: [
            // ── Drawer header ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpacing.xl,
                vertical: AuraSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AURA', style: AuraTypography.headlineLarge(colors.textPrimary)),
                  const SizedBox(height: AuraSpacing.sm),
                  Text(
                    'AI Universal Recording Assistant',
                    style: AuraTypography.overline(colors.textSecondary),
                  ),
                ],
              ),
            ),

            Divider(color: colors.divider),

            const SizedBox(height: AuraSpacing.xl),

            _buildDrawerMenuItem(context, icon: Icons.mic_rounded, label: 'Recordings', onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/recordings');
            }),
            _buildDrawerMenuItem(context, icon: Icons.person_rounded, label: 'Profile', onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/profile');
            }),
            _buildDrawerMenuItem(context, icon: Icons.settings_rounded, label: 'Settings', onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/settings');
            }),
            _buildDrawerMenuItem(context, icon: Icons.history_rounded, label: 'History', onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/history');
            }),
            _buildDrawerMenuItem(context, icon: Icons.info_rounded, label: 'About', onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/about');
            }),

            const SizedBox(height: AuraSpacing.xl),
            Divider(color: colors.divider),
            const SizedBox(height: AuraSpacing.xl),

            _buildDrawerMenuItem(
              context,
              icon: Icons.logout_rounded,
              label: 'Logout',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/logout');
              },
              isHighlighted: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isHighlighted = false,
  }) {
    final colors = AuraThemeColors.of(context);
    final itemColor = isHighlighted ? colors.textPrimary : colors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpacing.base,
        vertical: AuraSpacing.xxs,
      ),
      child: Material(
        color: isHighlighted
            ? colors.textTertiary.withOpacity(0.12)
            : Colors.transparent,
        borderRadius: AuraRadius.smBr,
        child: InkWell(
          borderRadius: AuraRadius.smBr,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpacing.base,
              vertical: AuraSpacing.md,
            ),
            child: Row(
              children: [
                Icon(icon, color: itemColor, size: 22),
                const SizedBox(width: AuraSpacing.base),
                Text(
                  label,
                  style: AuraTypography.bodyLarge(itemColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
