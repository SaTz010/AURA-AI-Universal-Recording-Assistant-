import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/aura_theme.dart';
import '../../theme/aura_tokens.dart';

class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({
    super.key,
    required this.title,
    required this.subtitle,
    this.autoPopAfter = const Duration(milliseconds: 1400),
  });

  final String title;
  final String subtitle;
  final Duration autoPopAfter;

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen> {
  Timer? _dotsTimer;
  Timer? _autoPopTimer;
  int _dots = 0;

  @override
  void initState() {
    super.initState();

    _dotsTimer = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (!mounted) return;
      setState(() => _dots = (_dots + 1) % 4);
    });

    _autoPopTimer = Timer(widget.autoPopAfter, () {
      if (!mounted) return;
      Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _dotsTimer?.cancel();
    _autoPopTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    final dots = '.' * _dots;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.xl),
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
                  child: Center(
                    child: CircularProgressIndicator(
                      color: colors.accent,
                    ),
                  ),
                ),
                const SizedBox(height: AuraSpacing.xl),
                Text(
                  '${widget.title}$dots',
                  style: AuraTypography.headlineMedium(colors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AuraSpacing.sm),
                Text(
                  widget.subtitle,
                  style: AuraTypography.bodyMedium(colors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
