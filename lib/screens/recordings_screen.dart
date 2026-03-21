import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';
import 'widgets/main_bottom_nav.dart';

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

  Future<void> _onBottomNavTapped(int index) async {
    if (index == 1) return;

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/history');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/summary');
        break;
    }
  }

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
      final recordingFiles = files.where((file) => file.path.endsWith('.m4a')).toList();
      recordingFiles.sort(
        (a, b) => File(b.path).lastModifiedSync().compareTo(File(a.path).lastModifiedSync()),
      );
      setState(() {
        _recordings = recordingFiles;
        _isLoading = false;
      });
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing audio: $e')),
      );
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting recording: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      bottomNavigationBar: MainBottomNav(
        selectedIndex: 1,
        onTap: _onBottomNavTapped,
      ),
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: _ScreenBackButton(),
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
      separatorBuilder: (_, separatorIndex) => const SizedBox(height: AuraSpacing.sm),
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
                            '$formattedDate  •  ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB',
                            style: AuraTypography.caption(colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
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
                if (isPlaying) ...[
                  const SizedBox(height: AuraSpacing.sm),
                  Slider(
                    value: _position.inSeconds.toDouble(),
                    max: _duration.inSeconds.toDouble().clamp(1, double.infinity),
                    onChanged: (v) => _audioPlayer.seek(Duration(seconds: v.toInt())),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: AuraTypography.caption(colors.textSecondary),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: AuraTypography.caption(colors.textSecondary),
                        ),
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
    BuildContext context,
    String fileName,
    String filePath,
    AuraThemeColors colors,
  ) {
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

class _ScreenBackButton extends StatelessWidget {
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
