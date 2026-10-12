import 'package:flutter/material.dart';

class SignalPill extends StatelessWidget {
  final String signalType;
  final double? strength;

  const SignalPill({
    super.key,
    required this.signalType,
    this.strength,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;

    switch (signalType.toUpperCase()) {
      case 'BUY WATCH':
        bg = Colors.green.shade900.withOpacity(0.4);
        text = Colors.greenAccent;
        break;
      case 'HOLD':
        bg = Colors.blue.shade900.withOpacity(0.4);
        text = Colors.lightBlueAccent;
        break;
      case 'SELL/EXIT WATCH':
        bg = Colors.red.shade900.withOpacity(0.4);
        text = Colors.redAccent;
        break;
      default:
        bg = Colors.grey.shade800;
        text = Colors.grey.shade400;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: text.withOpacity(0.5), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            signalType,
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
          if (strength != null && strength! > 0) ...[
            const SizedBox(width: 4),
            Text(
              '${strength!.toInt()}%',
              style: TextStyle(
                color: text.withOpacity(0.8),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
