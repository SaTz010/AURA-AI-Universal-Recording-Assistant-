import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';
import '../theme/theme_provider.dart';

// ════════════════════════════════════════════════════════════════════════
//  Shared placeholder screen
// ════════════════════════════════════════════════════════════════════════

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: _BackButton(),
        title: Text(title, style: AuraTypography.titleLarge(colors.textPrimary)),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surfaceElevated,
              ),
              child: Icon(icon, size: 48, color: colors.textTertiary),
            ),
            const SizedBox(height: AuraSpacing.xl),
            Text(title, style: AuraTypography.headlineMedium(colors.textPrimary)),
            const SizedBox(height: AuraSpacing.sm),
            Text(
              'Coming Soon',
              style: AuraTypography.bodyMedium(colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared styled back button used across screens
class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AuraRadius.smBr,
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
        child: Padding(
          padding: const EdgeInsets.all(AuraSpacing.sm),
          child: Icon(Icons.arrow_back_rounded, color: colors.iconDefault),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
//  Profile Screen
// ════════════════════════════════════════════════════════════════════════

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(title: 'Profile', icon: Icons.person_rounded);
  }
}

// ════════════════════════════════════════════════════════════════════════
//  Recordings Screen
// ════════════════════════════════════════════════════════════════════════

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  List<FileSystemEntity> _recordings = [];
  bool _isLoading = true;
  late final AudioPlayer _audioPlayer;
  String? _playingFilePath;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.durationStream.listen((duration) {
      setState(() => _duration = duration ?? Duration.zero);
    });
    _audioPlayer.positionStream.listen((position) {
      setState(() => _position = position);
    });
    _loadRecordings();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadRecordings() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = dir.listSync();
      final recordingFiles = files
          .where((file) => file.path.endsWith('.m4a'))
          .toList();
      recordingFiles.sort((a, b) =>
          File(b.path).lastModifiedSync().compareTo(
              File(a.path).lastModifiedSync()));
      setState(() { _recordings = recordingFiles; _isLoading = false; });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _playRecording(String filePath) async {
    try {
      if (_playingFilePath == filePath && _audioPlayer.playing) {
        await _audioPlayer.pause();
        setState(() => _playingFilePath = null);
      } else {
        await _audioPlayer.setFilePath(filePath);
        await _audioPlayer.play();
        setState(() => _playingFilePath = filePath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: $e')),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _deleteRecording(String filePath) async {
    try {
      await File(filePath).delete();
      await _loadRecordings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting recording: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: _BackButton(),
        title: Text('Recordings', style: AuraTypography.titleLarge(colors.textPrimary)),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.accent))
          : _recordings.isEmpty
              ? _buildEmptyState(colors)
              : _buildRecordingsList(colors),
    );
  }

  Widget _buildEmptyState(AuraThemeColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surfaceElevated,
            ),
            child: Icon(Icons.mic_rounded, size: 48, color: colors.textTertiary),
          ),
          const SizedBox(height: AuraSpacing.xl),
          Text('No Recordings', style: AuraTypography.headlineMedium(colors.textPrimary)),
          const SizedBox(height: AuraSpacing.sm),
          Text(
            'Start recording to see your files here',
            style: AuraTypography.bodyMedium(colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingsList(AuraThemeColors colors) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpacing.base,
        vertical: AuraSpacing.lg,
      ),
      separatorBuilder: (_, __) => const SizedBox(height: AuraSpacing.sm),
      itemCount: _recordings.length,
      itemBuilder: (context, index) {
        final file = File(_recordings[index].path);
        final fileName = file.path.split('/').last;
        final fileSize = file.lengthSync();
        final lastModified = file.lastModifiedSync();
        final formattedDate =
            '${lastModified.year}-${lastModified.month.toString().padLeft(2, '0')}-${lastModified.day.toString().padLeft(2, '0')} '
            '${lastModified.hour.toString().padLeft(2, '0')}:${lastModified.minute.toString().padLeft(2, '0')}';
        final isPlaying = _playingFilePath == file.path;

        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AuraRadius.mdBr,
            border: Border.all(color: colors.border),
            boxShadow: AuraElevation.low(Colors.black),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AuraSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Play/pause button
                    Material(
                      color: Colors.transparent,
                      borderRadius: AuraRadius.fullBr,
                      child: InkWell(
                        borderRadius: AuraRadius.fullBr,
                        onTap: () => _playRecording(file.path),
                        child: Icon(
                          isPlaying
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_filled_rounded,
                          color: colors.accent,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(width: AuraSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            style: AuraTypography.bodyLarge(colors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AuraSpacing.xxs),
                          Text(
                            '$formattedDate  \u2022  ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB',
                            style: AuraTypography.caption(colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    // Delete button
                    Material(
                      color: Colors.transparent,
                      borderRadius: AuraRadius.fullBr,
                      child: InkWell(
                        borderRadius: AuraRadius.fullBr,
                        onTap: () => _showDeleteDialog(context, fileName, file.path, colors),
                        child: Padding(
                          padding: const EdgeInsets.all(AuraSpacing.sm),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: colors.textTertiary,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Playback slider
                if (isPlaying) ...[
                  const SizedBox(height: AuraSpacing.sm),
                  Slider(
                    value: _position.inSeconds.toDouble(),
                    max: _duration.inSeconds.toDouble().clamp(1, double.infinity),
                    onChanged: (v) =>
                        _audioPlayer.seek(Duration(seconds: v.toInt())),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(_position),
                            style: AuraTypography.caption(colors.textSecondary)),
                        Text(_formatDuration(_duration),
                            style: AuraTypography.caption(colors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteDialog(
      BuildContext context, String fileName, String filePath, AuraThemeColors colors) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Recording?'),
        content: Text('Are you sure you want to delete $fileName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _deleteRecording(filePath);
            },
            child: Text(
              'Delete',
              style: TextStyle(
                color: colors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
//  Settings Screen — with Appearance section
// ════════════════════════════════════════════════════════════════════════

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    final themeNotifier = AuraThemeProvider.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: _BackButton(),
        title: Text('Settings', style: AuraTypography.titleLarge(colors.textPrimary)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpacing.base,
          vertical: AuraSpacing.xl,
        ),
        children: [
          // ── Appearance section ──────────────────────────────────────
          _SectionHeader(title: 'Appearance'),
          const SizedBox(height: AuraSpacing.sm),
          _SettingsCard(
            children: [
              _ThemeOptionTile(
                title: 'Dark Mode',
                subtitle: 'Deep space dark theme',
                icon: Icons.dark_mode_rounded,
                isSelected: themeNotifier.themeMode == ThemeMode.dark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  themeNotifier.setThemeMode(ThemeMode.dark);
                },
              ),
              Divider(height: 1, color: colors.border),
              _ThemeOptionTile(
                title: 'Light Mode',
                subtitle: 'Clean bright interface',
                icon: Icons.light_mode_rounded,
                isSelected: themeNotifier.themeMode == ThemeMode.light,
                onTap: () {
                  HapticFeedback.selectionClick();
                  themeNotifier.setThemeMode(ThemeMode.light);
                },
              ),
            ],
          ),

          const SizedBox(height: AuraSpacing.xxl),

          // ── General section ─────────────────────────────────────────
          _SectionHeader(title: 'General'),
          const SizedBox(height: AuraSpacing.sm),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.notifications_rounded,
                title: 'Notifications',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textTertiary,
                ),
              ),
              Divider(height: 1, color: colors.border),
              _SettingsTile(
                icon: Icons.storage_rounded,
                title: 'Storage',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textTertiary,
                ),
              ),
            ],
          ),

          const SizedBox(height: AuraSpacing.xxl),

          // ── About section ───────────────────────────────────────────
          _SectionHeader(title: 'About'),
          const SizedBox(height: AuraSpacing.sm),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'Version',
                trailing: Text(
                  '1.0.0',
                  style: AuraTypography.bodySmall(colors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: AuraSpacing.xs),
      child: Text(
        title.toUpperCase(),
        style: AuraTypography.overline(colors.textTertiary).copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AuraRadius.mdBr,
        border: Border.all(color: colors.border),
        boxShadow: AuraElevation.low(Colors.black),
      ),
      child: ClipRRect(
        borderRadius: AuraRadius.mdBr,
        child: Column(
          children: children,
        ),
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Material(
      color: isSelected ? colors.shimmer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpacing.base,
            vertical: AuraSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.accent.withOpacity(0.15)
                      : colors.surfaceElevated,
                  borderRadius: AuraRadius.smBr,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected ? colors.accent : colors.textTertiary,
                ),
              ),
              const SizedBox(width: AuraSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AuraTypography.bodyLarge(colors.textPrimary)),
                    const SizedBox(height: AuraSpacing.xxs),
                    Text(subtitle, style: AuraTypography.caption(colors.textSecondary)),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: AuraMotion.fast,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? colors.accent : colors.textTertiary,
                    width: isSelected ? 6 : 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpacing.base,
            vertical: AuraSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: AuraRadius.smBr,
                ),
                child: Icon(icon, size: 20, color: colors.textTertiary),
              ),
              const SizedBox(width: AuraSpacing.md),
              Expanded(
                child: Text(title, style: AuraTypography.bodyLarge(colors.textPrimary)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
//  History Screen
// ════════════════════════════════════════════════════════════════════════

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(title: 'History', icon: Icons.history_rounded);
  }
}

// ════════════════════════════════════════════════════════════════════════
//  About Screen
// ════════════════════════════════════════════════════════════════════════

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(title: 'About', icon: Icons.info_rounded);
  }
}

// ════════════════════════════════════════════════════════════════════════
//  Logout Screen
// ════════════════════════════════════════════════════════════════════════

class LogoutScreen extends StatelessWidget {
  const LogoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surfaceElevated,
              ),
              child: Icon(Icons.logout_rounded, size: 48, color: colors.textTertiary),
            ),
            const SizedBox(height: AuraSpacing.xl),
            Text('Logout', style: AuraTypography.headlineMedium(colors.textPrimary)),
            const SizedBox(height: AuraSpacing.sm),
            Text(
              'You have been logged out',
              style: AuraTypography.bodyMedium(colors.textSecondary),
            ),
            const SizedBox(height: AuraSpacing.xxl),
            ElevatedButton(
              onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
