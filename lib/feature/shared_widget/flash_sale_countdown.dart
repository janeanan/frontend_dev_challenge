import 'package:flutter/material.dart';

/// Live mm:ss countdown until a flash sale ends.
/// Shows 'Ended' once [endsAt] is in the past.
class FlashSaleCountdown extends StatefulWidget {
  final DateTime endsAt;
  final Color color;

  const FlashSaleCountdown({
    super.key,
    required this.endsAt,
    this.color = Colors.white,
  });

  @override
  State<FlashSaleCountdown> createState() => _FlashSaleCountdownState();
}

class _FlashSaleCountdownState extends State<FlashSaleCountdown> {
  late final Stream<dynamic> _tickStream;

  @override
  void initState() {
    super.initState();
    _tickStream = Stream.periodic(const Duration(seconds: 1));
  }

  String _buildText() {
    final remaining = widget.endsAt.difference(DateTime.now());
    if (remaining.isNegative) return 'Ended';
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60);
    final s = remaining.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _tickStream,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 12, color: widget.color),
            const SizedBox(width: 3),
            Text(
              _buildText(),
              style: TextStyle(
                color: widget.color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      },
    );
  }
}
