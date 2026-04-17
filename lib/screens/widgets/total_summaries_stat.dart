import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../providers/auth_provider.dart';
import '../../services/summaries_library_events.dart';
import '../../services/summaries_storage.dart';
import '../../theme/aura_theme.dart';
import '../../theme/aura_tokens.dart';

class SummaryTotalsCard extends StatefulWidget {
  const SummaryTotalsCard({super.key});

  @override
  State<SummaryTotalsCard> createState() => _SummaryTotalsCardState();
}

class _SummaryTotalsCardState extends State<SummaryTotalsCard> {
  static final Map<String, _SummaryTotalsSnapshot> _cacheByUidKey = {};

  bool _isLoading = true;
  int _summariesCount = 0;

  String? _effectiveUid;

  late final VoidCallback _revisionListener;

  @override
  void initState() {
    super.initState();

    _restoreFromCache();

    _revisionListener = () {
      if (!mounted) return;
      unawaited(_load(showLoading: false));
    };
    SummariesLibraryEvents.revision.addListener(_revisionListener);

    unawaited(_loadIfStale());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final authProvider = AuraAuthProvider.of(context);
    final nextUid = authProvider.isGuest ? null : authProvider.user?.uid;
    if (nextUid == _effectiveUid) return;

    _effectiveUid = nextUid;

    _restoreFromCache();
    unawaited(_loadIfStale());
  }

  @override
  void dispose() {
    SummariesLibraryEvents.revision.removeListener(_revisionListener);
    super.dispose();
  }

  String _uidKey() {
    final normalized = _effectiveUid?.trim();
    return (normalized == null || normalized.isEmpty) ? '_guest' : normalized;
  }

  void _restoreFromCache() {
    final key = _uidKey();
    final snapshot = _cacheByUidKey[key];
    if (snapshot == null) return;

    if (!mounted) return;
    setState(() {
      _summariesCount = snapshot.count;
      _isLoading = false;
    });
  }

  Future<void> _loadIfStale() async {
    final key = _uidKey();
    final currentRevision = SummariesLibraryEvents.revision.value;
    final cached = _cacheByUidKey[key];

    if (cached != null && cached.revision == currentRevision && cached.isValid) {
      if (_isLoading) {
        _restoreFromCache();
      }
      return;
    }

    final shouldShowLoading = cached == null;
    await _load(showLoading: shouldShowLoading);
  }

  Future<void> _load({required bool showLoading}) async {
    if (mounted && showLoading) {
      setState(() => _isLoading = true);
    }

    try {
      final items = await SummariesStorage.load(_effectiveUid);

      var count = 0;
      for (final item in items) {
        if (File(item.filePath).existsSync()) {
          count++;
        }
      }

      final revision = SummariesLibraryEvents.revision.value;
      _cacheByUidKey[_uidKey()] = _SummaryTotalsSnapshot(
        revision: revision,
        count: count,
        isValid: true,
      );

      if (!mounted) return;
      setState(() {
        _summariesCount = count;
        _isLoading = false;
      });
    } catch (_) {
      _cacheByUidKey[_uidKey()] = _SummaryTotalsSnapshot(
        revision: SummariesLibraryEvents.revision.value,
        count: 0,
        isValid: false,
      );

      if (!mounted) return;
      setState(() {
        _summariesCount = 0;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);

    final valueText = _isLoading ? '—' : _summariesCount.toString();
    final meta = _isLoading
        ? 'Calculating…'
        : _summariesCount == 0
            ? 'No summaries yet'
            : '$_summariesCount summaries';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MiniStatCard(
          icon: Icons.auto_awesome_rounded,
          label: 'Total summaries',
          value: valueText,
        ),
        const SizedBox(height: AuraSpacing.xs),
        Text(
          meta,
          style: AuraTypography.caption(colors.textTertiary),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _SummaryTotalsSnapshot {
  const _SummaryTotalsSnapshot({
    required this.revision,
    required this.count,
    required this.isValid,
  });

  final int revision;
  final int count;
  final bool isValid;
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
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

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AuraRadius.lgBr,
        border: Border.all(color: colors.border),
        boxShadow: AuraElevation.low(Colors.black),
      ),
      padding: const EdgeInsets.all(AuraSpacing.md),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surfaceElevated,
              border: Border.all(color: colors.border),
            ),
            child: Icon(icon, size: 18, color: colors.accent),
          ),
          const SizedBox(width: AuraSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AuraTypography.caption(colors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AuraTypography.titleMedium(colors.textPrimary).copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
