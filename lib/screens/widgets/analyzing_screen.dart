import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/aura_theme.dart';
import '../../theme/aura_tokens.dart';

class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({
    super.key,
    required this.title,
    required this.subtitle,
    this.autoPopAfter = const Duration(milliseconds: 1400),
    this.showCloseButton = false,
    this.phases,
    this.tips,
  });

  static const defaultPhases = [
    'Launching engine',
    'Preparing audio stream',
    'Decoding waveform',
    'Detecting speech',
    'Cleaning transcript',
    'Extracting key points',
    'Building summary',
    'Packaging results',
  ];

  static const defaultTips = [
    'Longer recordings may take a little more time to summarize.',
    'AURA cleans the transcript before creating the summary.',
    'Summary points are extracted separately from the paragraph summary.',
    'Clear audio usually gives better transcript quality.',
    'Context helps AURA tailor the summary to your recording.',
    'Your transcript and summary are saved together after processing.',
  ];

  final String title;
  final String subtitle;
  final Duration? autoPopAfter;
  final bool showCloseButton;
  final List<String>? phases;
  final List<String>? tips;

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _coreController;
  late final AnimationController _pulseController;
  late final AnimationController _scanController;
  late List<String> _phases;
  late List<String> _tips;

  Timer? _phaseTimer;
  Timer? _tipTimer;
  Timer? _autoPopTimer;
  int _phaseIndex = 0;
  int _tipIndex = 0;

  @override
  void initState() {
    super.initState();
    _phases = _normalizedItems(widget.phases, AnalyzingScreen.defaultPhases);
    _tips = _normalizedItems(widget.tips, AnalyzingScreen.defaultTips);

    _coreController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6500),
    )..repeat();

    _phaseTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (!mounted) return;
      setState(() => _phaseIndex = (_phaseIndex + 1) % _phases.length);
    });

    _tipTimer = Timer.periodic(const Duration(milliseconds: 4600), (_) {
      if (!mounted) return;
      setState(() => _tipIndex = (_tipIndex + 1) % _tips.length);
    });

    final autoPopAfter = widget.autoPopAfter;
    if (autoPopAfter != null) {
      _autoPopTimer = Timer(autoPopAfter, () {
        if (!mounted) return;
        Navigator.of(context).pop();
      });
    }
  }

  @override
  void didUpdateWidget(covariant AnalyzingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phases != widget.phases) {
      _phases = _normalizedItems(widget.phases, AnalyzingScreen.defaultPhases);
      _phaseIndex = _phaseIndex.clamp(0, _phases.length - 1).toInt();
    }
    if (oldWidget.tips != widget.tips) {
      _tips = _normalizedItems(widget.tips, AnalyzingScreen.defaultTips);
      _tipIndex = _tipIndex.clamp(0, _tips.length - 1).toInt();
    }
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _tipTimer?.cancel();
    _autoPopTimer?.cancel();
    _coreController.dispose();
    _pulseController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  List<String> _normalizedItems(List<String>? items, List<String> fallback) {
    final cleaned = (items ?? fallback)
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    return cleaned.isEmpty ? fallback : cleaned;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: AuraSpacing.lg),
                child: Text(
                  'AURA',
                  style: AuraTypography.headlineLarge(
                    colors.textPrimary,
                  ).copyWith(letterSpacing: 5),
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final coreSize = math
                    .min(constraints.maxWidth * 0.54, 184.0)
                    .clamp(128.0, 184.0)
                    .toDouble();
                const topReserved = 72.0;
                const bottomReserved = 116.0;
                final centerHeight = math.max(
                  0.0,
                  constraints.maxHeight - topReserved - bottomReserved,
                );

                return Padding(
                  padding: const EdgeInsets.only(
                    top: topReserved,
                    bottom: bottomReserved,
                  ),
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AuraSpacing.xl,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: centerHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: _ProcessingCore(
                                size: coreSize,
                                coreAnimation: _coreController,
                                pulseAnimation: _pulseController,
                                colors: colors,
                              ),
                            ),
                            const SizedBox(height: AuraSpacing.xxl),
                            Text(
                              widget.title,
                              style: AuraTypography.headlineMedium(
                                colors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AuraSpacing.sm),
                            Text(
                              widget.subtitle,
                              style: AuraTypography.bodyMedium(
                                colors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AuraSpacing.xl),
                            _PhasePill(
                              phase: _phases[_phaseIndex],
                              colors: colors,
                            ),
                            const SizedBox(height: AuraSpacing.lg),
                            _ScanStrip(
                              animation: _scanController,
                              colors: colors,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AuraSpacing.base,
                  AuraSpacing.sm,
                  AuraSpacing.base,
                  AuraSpacing.lg,
                ),
                child: _TipPanel(tip: _tips[_tipIndex], colors: colors),
              ),
            ),
          ),
          if (widget.showCloseButton)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(AuraSpacing.sm),
                  child: IconButton(
                    tooltip: 'Close preview',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.close_rounded, color: colors.textPrimary),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProcessingCore extends StatelessWidget {
  const _ProcessingCore({
    required this.size,
    required this.coreAnimation,
    required this.pulseAnimation,
    required this.colors,
  });

  final double size;
  final Animation<double> coreAnimation;
  final Animation<double> pulseAnimation;
  final AuraThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([coreAnimation, pulseAnimation]),
      builder: (context, _) {
        return CustomPaint(
          size: Size.square(size),
          painter: _ProcessingCorePainter(
            rotation: coreAnimation.value,
            pulse: pulseAnimation.value,
            colors: colors,
          ),
        );
      },
    );
  }
}

class _PhasePill extends StatelessWidget {
  const _PhasePill({required this.phase, required this.colors});

  final String phase;
  final AuraThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedSwitcher(
        duration: AuraMotion.normal,
        child: Container(
          key: ValueKey(phase),
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpacing.base,
            vertical: AuraSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: AuraRadius.fullBr,
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.memory_rounded, size: 16, color: colors.accentSoft),
              const SizedBox(width: AuraSpacing.sm),
              Flexible(
                child: Text(
                  phase,
                  style: AuraTypography.titleSmall(colors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanStrip extends StatelessWidget {
  const _ScanStrip({required this.animation, required this.colors});

  final Animation<double> animation;
  final AuraThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 260,
        height: 8,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            return CustomPaint(
              painter: _ScanStripPainter(
                progress: animation.value,
                colors: colors,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TipPanel extends StatelessWidget {
  const _TipPanel({required this.tip, required this.colors});

  final String tip;
  final AuraThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AuraMotion.normal,
      child: Container(
        key: ValueKey(tip),
        constraints: const BoxConstraints(maxWidth: 420),
        margin: const EdgeInsets.symmetric(horizontal: AuraSpacing.sm),
        padding: const EdgeInsets.all(AuraSpacing.base),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.78),
          borderRadius: AuraRadius.mdBr,
          border: Border.all(color: colors.border),
          boxShadow: AuraElevation.low(Colors.black),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.tips_and_updates_rounded,
              color: colors.accent,
              size: 18,
            ),
            const SizedBox(width: AuraSpacing.sm),
            Expanded(
              child: Text(
                tip,
                style: AuraTypography.bodySmall(colors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProcessingCorePainter extends CustomPainter {
  const _ProcessingCorePainter({
    required this.rotation,
    required this.pulse,
    required this.colors,
  });

  final double rotation;
  final double pulse;
  final AuraThemeColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final shortest = size.shortestSide;
    final pulseScale = 0.92 + Curves.easeInOut.transform(pulse) * 0.08;
    final accent = colors.accent;
    final baseStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 3; i++) {
      final radius = shortest * (0.32 + i * 0.1) * pulseScale;
      final rect = Rect.fromCircle(center: center, radius: radius);
      final direction = i.isEven ? 1.0 : -1.0;
      final start = rotation * math.pi * 2 * direction + i * 0.9;
      final sweep = math.pi * (0.58 + i * 0.12);
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        baseStroke
          ..strokeWidth = 2.2 - i * 0.25
          ..color = accent.withValues(alpha: 0.72 - i * 0.15),
      );
    }

    const barCount = 9;
    final barWidth = shortest * 0.018;
    final gap = shortest * 0.018;
    final totalWidth = barCount * barWidth + (barCount - 1) * gap;
    final startX = center.dx - totalWidth / 2;
    final wavePaint = Paint()
      ..color = accent
      ..style = PaintingStyle.fill;

    for (var i = 0; i < barCount; i++) {
      final wave = math.sin(rotation * math.pi * 4 + i * 0.78);
      final height = shortest * (0.08 + (wave + 1) * 0.035);
      final x = startX + i * (barWidth + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + barWidth / 2, center.dy),
          width: barWidth,
          height: height,
        ),
        Radius.circular(barWidth),
      );
      canvas.drawRRect(rect, wavePaint);
    }

    final tickPaint = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.35);
    for (var i = 0; i < 24; i++) {
      final angle = i / 24 * math.pi * 2 + rotation * math.pi * 0.4;
      final outer = shortest * 0.48;
      final inner = shortest * (i % 3 == 0 ? 0.43 : 0.45);
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * inner,
        center + Offset(math.cos(angle), math.sin(angle)) * outer,
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProcessingCorePainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.pulse != pulse ||
        oldDelegate.colors != colors;
  }
}

class _ScanStripPainter extends CustomPainter {
  const _ScanStripPainter({required this.progress, required this.colors});

  final double progress;
  final AuraThemeColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final track = RRect.fromRectAndRadius(Offset.zero & size, radius);
    canvas.drawRRect(track, Paint()..color = colors.surfaceElevated);

    final segmentWidth = size.width * 0.38;
    final left = (size.width + segmentWidth) * progress - segmentWidth;
    final segment = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, 0, segmentWidth, size.height),
      radius,
    );
    canvas.save();
    canvas.clipRRect(track);
    canvas.drawRRect(
      segment,
      Paint()..color = colors.accent.withValues(alpha: 0.85),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScanStripPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.colors != colors;
  }
}
