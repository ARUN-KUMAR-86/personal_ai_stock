import 'package:flutter/material.dart';

class MarketBadge extends StatelessWidget {
  final String status;
  final String serverTime;

  const MarketBadge({
    super.key,
    required this.status,
    required this.serverTime,
  });

  @override
  Widget build(BuildContext context) {
    Color indicatorColor;
    String label;

    switch (status.toUpperCase()) {
      case 'OPEN':
        indicatorColor = Colors.greenAccent;
        label = 'MARKET OPEN';
        break;
      case 'PRE_MARKET':
        indicatorColor = Colors.amberAccent;
        label = 'PRE-MARKET';
        break;
      default:
        indicatorColor = Colors.redAccent;
        label = 'MARKET CLOSED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E222D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: indicatorColor,
              boxShadow: [
                BoxShadow(
                  color: indicatorColor.withOpacity(0.6),
                  blurRadius: 4,
                  spreadRadius: 1,
                )
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: indicatorColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
