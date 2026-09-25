import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.margin = const EdgeInsets.only(bottom: 14), this.borderRadius = 22, this.blur = 18});
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double borderRadius;
  final double blur;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: H.glass,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: H.glassBorder, width: 1.2),
              boxShadow: [BoxShadow(color: H.purple.withValues(alpha: 0.18), blurRadius: 28, offset: const Offset(0, 10))],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GradientBg extends StatelessWidget {
  const GradientBg({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(-0.6, -0.7), radius: 1.4, colors: [Color(0xFF3B1A7A), H.bgDeep])),
      child: Stack(children: [
        Positioned(top: -40, right: -30, child: _orb(160, H.purple.withValues(alpha: 0.35))),
        Positioned(bottom: 120, left: -50, child: _orb(200, H.pink.withValues(alpha: 0.22))),
        Positioned(top: 180, right: -20, child: _orb(90, H.purpleSoft.withValues(alpha: 0.25))),
        child,
      ]),
    );
  }
  Widget _orb(double size, Color color) {
    return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)])));
  }
}
