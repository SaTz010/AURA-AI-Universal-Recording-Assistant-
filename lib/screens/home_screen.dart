import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';
import 'recording_session_screen.dart';
import 'widgets/dashboard_lower_content.dart';
import 'widgets/main_bottom_nav.dart';
import 'widgets/total_recorded_stat.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _micController;
  late final Animation<double> _pulseAnimation;

  int _selectedBottomIndex = 0;
  String _recordingStatus = '';
  bool _isOpeningRecording = false;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _micController.dispose();
    super.dispose();
  }

  Future<void> _openRecordingSession() async {
    if (_isOpeningRecording) return;
    _isOpeningRecording = true;

    await _micController.forward();
    await _micController.reverse();

    if (!mounted) {
      _isOpeningRecording = false;
      return;
    }

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const RecordingSessionScreen()),
    );

    _isOpeningRecording = false;

    if (!mounted || result == null || result.isEmpty) return;

    setState(() {
      _recordingStatus = 'Recording saved: $result';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Recording saved: $result')),
    );
  }

  Future<void> _onBottomNavTapped(int index) async {
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
    final currentUser = FirebaseAuth.instance.currentUser;
    final userDocStream = currentUser == null
        ? null
        : FirebaseFirestore.instance.collection('users').doc(currentUser.uid).snapshots();

    return Scaffold(
      backgroundColor: colors.background,
      bottomNavigationBar: MainBottomNav(
        selectedIndex: _selectedBottomIndex,
        onTap: _onBottomNavTapped,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 140,
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpacing.xl,
                  vertical: AuraSpacing.base,
                ),
                color: colors.background,
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: userDocStream,
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data();
                    final name = (data?['name'] as String?)?.trim();
                    final photoUrl = (data?['photoUrl'] as String?)?.trim();

                    final fallbackName = (currentUser?.displayName?.trim().isNotEmpty ?? false)
                        ? currentUser!.displayName!.trim()
                        : 'there';

                    final displayName = (name != null && name.isNotEmpty) ? name : fallbackName;
                    final effectivePhoto = (photoUrl != null && photoUrl.isNotEmpty)
                        ? photoUrl
                        : currentUser?.photoURL;

                    return Row(
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
                                  HapticFeedback.lightImpact();
                                  Navigator.pushNamed(context, '/profile');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(AuraSpacing.xxs),
                                  child: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: colors.surfaceElevated,
                                    backgroundImage: (effectivePhoto != null &&
                                            effectivePhoto.isNotEmpty)
                                        ? NetworkImage(effectivePhoto)
                                        : null,
                                    child: (effectivePhoto == null || effectivePhoto.isEmpty)
                                        ? Icon(
                                            Icons.person_rounded,
                                            color: colors.iconDefault,
                                            size: 22,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AuraSpacing.md),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Hello,',
                                  style: AuraTypography.caption(colors.textSecondary).copyWith(
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 170),
                                  child: Text(
                                    displayName,
                                    overflow: TextOverflow.ellipsis,
                                    style: AuraTypography.bodyLarge(colors.textPrimary).copyWith(
                                      fontWeight: FontWeight.w600,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AuraSpacing.xxs),
                                const TotalRecordedStat(maxWidth: 170),
                              ],
                            ),
                          ],
                        ),
                        Material(
                          color: Colors.transparent,
                          borderRadius: AuraRadius.smBr,
                          child: InkWell(
                            borderRadius: AuraRadius.smBr,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _showUploadSheet();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(AuraSpacing.xs),
                              child: Icon(
                                Icons.cloud_upload_outlined,
                                color: colors.iconDefault,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  0,
                  AuraSpacing.huge,
                  0,
                  AuraSpacing.xxl,
                ),
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
                      'Record now or import \n existing audio files to get started',
                      textAlign: TextAlign.center,
                      style: AuraTypography.bodyLarge(colors.textSecondary),
                    ),
                  ],
                ),
              ),
              Center(
                child: SizedBox(
                  width: 260,
                  height: 260,
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
                          _openRecordingSession();
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
                              child: Icon(
                                Icons.mic_rounded,
                                size: 56,
                                color: colors.micIcon,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AuraSpacing.xxl),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AuraSpacing.xl,
                  0,
                  AuraSpacing.xl,
                  AuraSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AuraSpacing.xl),
                        child: Column(
                          children: [
                            Text(
                              'Tap to start recording',
                              style: AuraTypography.bodyMedium(colors.textSecondary),
                            ),
                            const SizedBox(height: AuraSpacing.sm),
                            Container(
                              width: 44,
                              height: 2,
                              decoration: BoxDecoration(
                                color: colors.textTertiary.withValues(alpha: 0.45),
                                borderRadius: AuraRadius.fullBr,
                              ),
                            ),
                            if (_recordingStatus.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: AuraSpacing.sm),
                                child: Text(
                                  _recordingStatus,
                                  textAlign: TextAlign.center,
                                  style: AuraTypography.overline(colors.accent),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AuraSpacing.lg),
                    DashboardLowerContent(
                      onUploadAudio: _showUploadSheet,
                      onSummarize: () => _onBottomNavTapped(3),
                      onViewAllRecent: () => _onBottomNavTapped(1),
                      onRecentFileTap: (_) => _onBottomNavTapped(1),
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
