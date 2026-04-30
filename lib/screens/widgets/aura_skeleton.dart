import 'package:flutter/material.dart';

import '../../theme/aura_theme.dart';
import '../../theme/aura_tokens.dart';

/// Wraps a subtree of [AuraSkeletonBox]es so they all shimmer in sync.
///
/// Owns a single [AnimationController] (1.4s loop) and exposes it to
/// descendants via an [InheritedWidget]. Per-box [AnimatedBuilder]s
/// rebuild only their own paint on each tick — the rest of the tree
/// is untouched.
class AuraSkeletonGroup extends StatefulWidget {
  const AuraSkeletonGroup({super.key, required this.child});

  final Widget child;

  @override
  State<AuraSkeletonGroup> createState() => _AuraSkeletonGroupState();
}

class _AuraSkeletonGroupState extends State<AuraSkeletonGroup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SkeletonScope(animation: _controller, child: widget.child);
  }
}

class _SkeletonScope extends InheritedWidget {
  const _SkeletonScope({required this.animation, required super.child});

  final Animation<double> animation;

  static Animation<double>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_SkeletonScope>()
        ?.animation;
  }

  @override
  bool updateShouldNotify(_SkeletonScope oldWidget) =>
      animation != oldWidget.animation;
}

/// A single placeholder shape with a shimmering sheen.
///
/// Must be a descendant of an [AuraSkeletonGroup] for the animation to run;
/// renders as a static block otherwise (graceful fallback).
class AuraSkeletonBox extends StatelessWidget {
  const AuraSkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = AuraThemeColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? Color.lerp(colors.surfaceElevated, Colors.white, 0.04)!
        : Color.lerp(colors.surfaceElevated, Colors.black, 0.04)!;
    final highlightColor = isDark
        ? Color.lerp(colors.surfaceElevated, Colors.white, 0.10)!
        : Color.lerp(colors.surfaceElevated, Colors.black, 0.08)!;

    final radius = borderRadius ?? AuraRadius.smBr;
    final animation = _SkeletonScope.maybeOf(context);

    if (animation == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: baseColor, borderRadius: radius),
      );
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        // Map [0, 1] to [-0.3, 1.3] so the sheen enters from off-screen left,
        // sweeps across, and exits off-screen right before looping.
        final progress = -0.3 + animation.value * 1.6;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: const Alignment(-1.0, -0.4),
              end: const Alignment(1.0, 0.4),
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                (progress - 0.25).clamp(0.0, 1.0),
                progress.clamp(0.0, 1.0),
                (progress + 0.25).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}
