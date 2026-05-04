import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/auth_provider.dart';
import '../services/recordings_library_events.dart';
import '../services/recordings_storage.dart';
import '../services/summaries_library_events.dart';
import '../services/summaries_storage.dart';
import '../theme/aura_theme.dart';
import '../theme/aura_tokens.dart';
import '../widgets/aura_snack_bar.dart';

class StorageSettingsScreen extends StatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  State<StorageSettingsScreen> createState() => _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends State<StorageSettingsScreen> {
  String? _effectiveUid;
  bool _hasLoadedOnce = false;

  bool _isLoading = true;
  bool _isClearing = false;

  int _recordingsCount = 0;
  int _recordingsBytes = 0;
  int _summariesCount = 0;
  int _summariesBytes = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = AuraAuthProvider.of(context);
    if (!authProvider.initialized) return;
    final nextUid = authProvider.isGuest ? null : authProvider.user?.uid;
    if (_hasLoadedOnce && nextUid == _effectiveUid) return;
    _effectiveUid = nextUid;
    _hasLoadedOnce = true;
    unawaited(_load());
  }

  Future<void> _load() async {
    if (mounted) setState(() => _isLoading = true);

    int recordingsCount = 0;
    int recordingsBytes = 0;
    int summariesCount = 0;
    int summariesBytes = 0;

    try {
      final dir = await RecordingsStorage.getUserRecordingsDir(_effectiveUid);
      final entities = dir.listSync();
      for (final e in entities) {
        if (e is! File) continue;
        if (!e.path.toLowerCase().endsWith('.m4a')) continue;
        final name = e.path.split(RegExp(r'[\\/]')).last.toLowerCase();
        if (name.startsWith('recording_')) continue;
        recordingsCount++;
        try {
          recordingsBytes += await e.length();
        } catch (_) {}
      }
    } catch (_) {}

    try {
      final summaries = await SummariesStorage.load(_effectiveUid);
      summariesCount = summaries.length;
      // Approximate metadata footprint via the JSON payload sizes.
      for (final s in summaries) {
        summariesBytes += s.transcript.length;
        summariesBytes += s.summary.length;
        summariesBytes += s.summaryPoints.fold<int>(
          0,
          (total, point) => total + point.length,
        );
        summariesBytes += (s.translation ?? '').length;
        summariesBytes += s.description.length;
        summariesBytes +=
            s.fileName.length + s.filePath.length + s.category.length;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _recordingsCount = recordingsCount;
      _recordingsBytes = recordingsBytes;
      _summariesCount = summariesCount;
      _summariesBytes = summariesBytes;
      _isLoading = false;
    });
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    if (unit == 0) return '${size.toStringAsFixed(0)} ${units[unit]}';
    return '${size.toStringAsFixed(size >= 10 ? 0 : 1)} ${units[unit]}';
  }

  Future<void> _confirmClearRecordings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogColors = AuraThemeColors.of(ctx);
        final destructiveColor = AuraSemanticColors.subtleDestructive(ctx);
        return AlertDialog(
          backgroundColor: dialogColors.surface,
          title: Text(
            'Clear all recordings?',
            style: AuraTypography.titleMedium(dialogColors.textPrimary),
          ),
          content: Text(
            'This will delete all $_recordingsCount recording${_recordingsCount == 1 ? '' : 's'} and any summaries linked to them. This cannot be undone.',
            style: AuraTypography.bodyMedium(dialogColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: AuraTypography.bodyMedium(dialogColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Delete',
                style: AuraTypography.bodyMedium(
                  destructiveColor,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isClearing = true);

    try {
      final dir = await RecordingsStorage.getUserRecordingsDir(_effectiveUid);
      final entities = dir.listSync();
      for (final e in entities) {
        if (e is! File) continue;
        if (!e.path.toLowerCase().endsWith('.m4a')) continue;
        try {
          await e.delete();
        } catch (_) {}
      }

      // Recordings are gone — the linked summary entries become orphans, so
      // clear the summary index too. (UI elsewhere already filters out
      // summaries whose files don't exist, but clearing here is cleaner.)
      await SummariesStorage.save(_effectiveUid, []);

      RecordingsLibraryEvents.notifyChanged();
      SummariesLibraryEvents.notifyChanged();
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isClearing = false);
    await _load();

    if (!mounted) return;
    showAuraSnackBar(
      context,
      message: 'Recordings cleared',
      duration: auraBriefSnackBarDuration,
    );
  }

  Future<void> _confirmClearSummaries() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogColors = AuraThemeColors.of(ctx);
        final destructiveColor = AuraSemanticColors.subtleDestructive(ctx);
        return AlertDialog(
          backgroundColor: dialogColors.surface,
          title: Text(
            'Clear all summaries?',
            style: AuraTypography.titleMedium(dialogColors.textPrimary),
          ),
          content: Text(
            'This will delete all $_summariesCount summar${_summariesCount == 1 ? 'y' : 'ies'}. Your recordings will not be touched. This cannot be undone.',
            style: AuraTypography.bodyMedium(dialogColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: AuraTypography.bodyMedium(dialogColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Delete',
                style: AuraTypography.bodyMedium(
                  destructiveColor,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isClearing = true);
    try {
      await SummariesStorage.save(_effectiveUid, []);
      SummariesLibraryEvents.notifyChanged();
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isClearing = false);
    await _load();

    if (!mounted) return;
    showAuraSnackBar(
      context,
      message: 'Summaries cleared',
      duration: auraBriefSnackBarDuration,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    final totalBytes = _recordingsBytes + _summariesBytes;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
          icon: Icon(Icons.arrow_back_rounded, color: colors.iconDefault),
        ),
        title: Text(
          'Storage',
          style: AuraTypography.titleLarge(colors.textPrimary),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpacing.base,
          vertical: AuraSpacing.lg,
        ),
        children: [
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AuraRadius.mdBr,
              border: Border.all(color: colors.border),
            ),
            padding: const EdgeInsets.all(AuraSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total used by AURA',
                  style: AuraTypography.caption(
                    colors.textSecondary,
                  ).copyWith(letterSpacing: 0.4),
                ),
                const SizedBox(height: 6),
                Text(
                  _isLoading ? '—' : _formatBytes(totalBytes),
                  style: AuraTypography.headlineLarge(
                    colors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: AuraSpacing.xxl),
          _SectionHeader(title: 'Recordings'),
          const SizedBox(height: AuraSpacing.sm),
          _Card(
            children: [
              _StatRow(
                icon: Icons.mic_rounded,
                label: 'Saved recordings',
                value: _isLoading ? '—' : _recordingsCount.toString(),
              ),
              Divider(height: 1, color: colors.border),
              _StatRow(
                icon: Icons.sd_storage_rounded,
                label: 'Audio file size',
                value: _isLoading ? '—' : _formatBytes(_recordingsBytes),
              ),
              Divider(height: 1, color: colors.border),
              _ActionRow(
                icon: Icons.delete_outline_rounded,
                label: 'Clear all recordings',
                isDestructive: true,
                onTap: (_isLoading || _isClearing || _recordingsCount == 0)
                    ? null
                    : _confirmClearRecordings,
              ),
            ],
          ),
          const SizedBox(height: AuraSpacing.xxl),
          _SectionHeader(title: 'Summaries'),
          const SizedBox(height: AuraSpacing.sm),
          _Card(
            children: [
              _StatRow(
                icon: Icons.auto_awesome_rounded,
                label: 'Saved summaries',
                value: _isLoading ? '—' : _summariesCount.toString(),
              ),
              Divider(height: 1, color: colors.border),
              _StatRow(
                icon: Icons.description_outlined,
                label: 'Metadata size',
                value: _isLoading ? '—' : _formatBytes(_summariesBytes),
              ),
              Divider(height: 1, color: colors.border),
              _ActionRow(
                icon: Icons.delete_outline_rounded,
                label: 'Clear all summaries',
                isDestructive: true,
                onTap: (_isLoading || _isClearing || _summariesCount == 0)
                    ? null
                    : _confirmClearSummaries,
              ),
            ],
          ),
          const SizedBox(height: AuraSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.xs),
            child: Text(
              'Clearing recordings will also remove any summaries that reference them. Clearing summaries leaves your recordings untouched.',
              style: AuraTypography.caption(colors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: AuraSpacing.xs),
      child: Text(
        title.toUpperCase(),
        style: AuraTypography.overline(
          colors.textTertiary,
        ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 1.5),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AuraRadius.mdBr,
        border: Border.all(color: colors.border),
      ),
      child: ClipRRect(
        borderRadius: AuraRadius.mdBr,
        child: Column(children: children),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpacing.base,
        vertical: AuraSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.iconDefault),
          const SizedBox(width: AuraSpacing.md),
          Expanded(
            child: Text(
              label,
              style: AuraTypography.bodyLarge(colors.textPrimary),
            ),
          ),
          Text(
            value,
            style: AuraTypography.bodyMedium(colors.textSecondary).copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    final destructiveColor = AuraSemanticColors.subtleDestructive(context);
    final disabled = onTap == null;
    final foreground = disabled
        ? colors.textTertiary
        : isDestructive
        ? destructiveColor
        : colors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpacing.base,
            vertical: AuraSpacing.md,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: AuraSpacing.md),
              Expanded(
                child: Text(label, style: AuraTypography.bodyLarge(foreground)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
