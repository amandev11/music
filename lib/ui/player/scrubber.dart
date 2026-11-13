import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../backend/backend.dart';
import '../../core/models.dart';

/// Apple-style thin scrubber that thickens while dragged. Position comes from the extrapolating
/// clock; while the thumb is down it shows the finger, and the seek is sent on release only.
class Scrubber extends StatefulWidget {
  const Scrubber({super.key, this.waveform});
  final List<double>? waveform;

  @override
  State<Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends State<Scrubber> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final clock = AppController.I.clock;
    final backend = AppController.I.backend;
    return ValueListenableBuilder<List<double>>(
      valueListenable: AppController.I.waveform,
      builder: (context, wave, _) => _build(context, clock, backend, AppController.I.settings.waveformBar && wave.isNotEmpty ? wave : null),
    );
  }

  Widget _build(BuildContext context, PositionClock clock, Backend backend, List<double>? wave) {
    return AnimatedBuilder(
      animation: clock,
      builder: (context, _) {
        final dur = clock.durationMs;
        final f = _drag ?? clock.fraction;
        final pos = (_drag != null ? _drag! * dur : clock.positionMs.toDouble()).round();
        return Column(mainAxisSize: MainAxisSize.min, children: [
          LayoutBuilder(builder: (context, c) {
            void setFrom(double dx) => setState(() => _drag = (dx / c.maxWidth).clamp(0.0, 1.0));
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (d) => setFrom(d.localPosition.dx),
              onHorizontalDragUpdate: (d) => setFrom(d.localPosition.dx),
              onHorizontalDragEnd: (_) {
                final target = ((_drag ?? 0) * dur).round();
                setState(() => _drag = null);
                backend.seek(target);
              },
              onTapUp: (d) => backend.seek(((d.localPosition.dx / c.maxWidth).clamp(0.0, 1.0) * dur).round()),
              child: SizedBox(
                height: wave != null && wave.isNotEmpty ? 44 : 28,
                child: wave != null && wave.isNotEmpty
                    ? CustomPaint(
                        size: Size.infinite,
                        painter: _WavePainter(wave, f.clamp(0.0, 1.0), _drag != null),
                      )
                    : Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    height: _drag != null ? 10 : 5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(fit: StackFit.expand, children: [
                        const ColoredBox(color: Color(0x4DFFFFFF)),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: f.clamp(0.0, 1.0),
                          child: const ColoredBox(color: Color(0xE6FFFFFF)),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            );
          }),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(formatTime(pos), style: const TextStyle(fontSize: 12, color: Color(0x99FFFFFF), fontFeatures: [FontFeature.tabularFigures()])),
            Text('-${formatTime((dur - pos).clamp(0, 1 << 30))}',
                style: const TextStyle(fontSize: 12, color: Color(0x99FFFFFF), fontFeatures: [FontFeature.tabularFigures()])),
          ]),
        ]);
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.bars, this.progress, this.dragging);
  final List<double> bars;
  final double progress;
  final bool dragging;

  @override
  void paint(Canvas canvas, Size size) {
    final n = bars.length;
    final slot = size.width / n;
    final w = (slot * 0.62).clamp(1.5, 5.0);
    final done = Paint()..color = const Color(0xF2FFFFFF);
    final todo = Paint()..color = const Color(0x4DFFFFFF);
    final mid = size.height / 2;
    final maxH = size.height * (dragging ? 1.0 : 0.86);
    for (var i = 0; i < n; i++) {
      final h = (bars[i] * maxH).clamp(3.0, maxH);
      final x = i * slot + slot / 2;
      final played = (i + 0.5) / n <= progress;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, mid), width: w, height: h), Radius.circular(w / 2)),
        played ? done : todo,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter o) => o.progress != progress || o.bars != bars || o.dragging != dragging;
}
