import 'package:flutter/material.dart';

class ZedLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final double fontSize;

  const ZedLogo({
    super.key,
    this.size = 32.0,
    this.showText = false,
    this.fontSize = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    final logoBadge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A), // Deep Slate Navy
            Color(0xFF1E293B),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF38BDF8).withOpacity(0.6), // Cyan-blue outline
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Stylized 'Z' Letter
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF38BDF8), // Electric cyan
                  Color(0xFF2563EB), // Royal blue
                ],
              ).createShader(bounds),
              child: Text(
                'Z',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w900,
                  fontSize: size * 0.62,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            // Bullish pulse upward tick
            Positioned(
              right: size * 0.12,
              top: size * 0.15,
              child: Container(
                width: size * 0.18,
                height: size * 0.18,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF10B981), // Neon profit green
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF10B981),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!showText) return logoBadge;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        logoBadge,
        const SizedBox(width: 8),
        Text(
          'ZED',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: fontSize,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
