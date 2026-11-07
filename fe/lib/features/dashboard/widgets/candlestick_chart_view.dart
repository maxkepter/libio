import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fe/core/theme/app_colors.dart';
import 'package:fe/core/theme/app_text_styles.dart';
import '../models/candle_data.dart';

class CandlestickChartView extends StatelessWidget {
  final List<CandleData> candleList;
  final int maxScale;
  final ScrollController scrollController;

  const CandlestickChartView({
    super.key,
    required this.candleList,
    required this.maxScale,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Scrollbar(
              controller: scrollController,
              thumbVisibility: true,
              trackVisibility: true,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                    PointerDeviceKind.stylus,
                  },
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: candleList.map((candle) {
                      return _buildCandleColumn(candle);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          _buildRightYAxis(),
        ],
      ),
    );
  }

  Widget _buildRightYAxis() {
    final effectiveMax = maxScale <= 0 ? 1 : maxScale;
    final midVal = (effectiveMax / 2).round();

    return Container(
      width: 44,
      padding: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.neutral200, width: 1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: 120.0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    '$effectiveMax',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal600,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    '$midVal',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      color: AppColors.charcoal400,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    '0',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      color: AppColors.charcoal400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'người',
            style: AppTextStyles.caption.copyWith(
              fontSize: 9,
              color: AppColors.charcoal400,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildCandleColumn(CandleData candle) {
    final effectiveMax = maxScale <= 0 ? 1 : maxScale;
    const double chartHeight = 120.0;

    final timeLabel = candle.intervalMin >= 1440
        ? DateFormat('dd/MM').format(candle.startDate.toLocal())
        : DateFormat('HH:mm').format(candle.startDate.toLocal());

    final timeFull = DateFormat(
      'HH:mm dd/MM',
    ).format(candle.startDate.toLocal());
    final netSign = candle.netChange >= 0
        ? '+${candle.netChange}'
        : '${candle.netChange}';

    final tooltipMsg =
        'Thời gian: $timeFull\n'
        'Cao nhất: ${candle.high} | Thấp nhất: ${candle.low}\n'
        'Đầu kỳ: ${candle.open} → Cuối kỳ: ${candle.close}\n'
        'Vào: +${candle.checkInCount} | Ra: -${candle.checkOutCount}\n'
        'Biến động ròng: $netSign';

    return Container(
      width: 48,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Tooltip(
            message: tooltipMsg,
            child: SizedBox(
              height: chartHeight,
              width: 48,
              child: CustomPaint(
                painter: CandlestickPainter(
                  candle: candle,
                  maxScale: effectiveMax,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            timeLabel,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              color: AppColors.charcoal500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class CandlestickPainter extends CustomPainter {
  final CandleData candle;
  final int maxScale;

  const CandlestickPainter({required this.candle, required this.maxScale});

  @override
  void paint(Canvas canvas, Size size) {
    final double safeMax = maxScale.toDouble();
    final double h = size.height;
    final double centerX = size.width / 2;

    double yFromVal(int val) {
      final ratio = (val / safeMax).clamp(0.0, 1.0);
      return h - (ratio * h);
    }

    final double yHigh = yFromVal(candle.high);
    final double yLow = yFromVal(candle.low);
    final double yOpen = yFromVal(candle.open);
    final double yClose = yFromVal(candle.close);

    final wickPaint = Paint()
      ..color = AppColors.charcoal600
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(centerX, yHigh), Offset(centerX, yLow), wickPaint);

    final isBullish = candle.isBullish;
    final bodyColor = isBullish ? AppColors.success : AppColors.danger;

    final bodyPaint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill;

    const double bodyWidth = 16.0;
    final double top = yOpen < yClose ? yOpen : yClose;
    final double bottom = yOpen > yClose ? yOpen : yClose;
    double bodyHeight = bottom - top;
    if (bodyHeight < 2.5) {
      bodyHeight = 2.5;
    }

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, top + (bodyHeight / 2)),
        width: bodyWidth,
        height: bodyHeight,
      ),
      const Radius.circular(2.0),
    );

    canvas.drawRRect(rect, bodyPaint);
  }

  @override
  bool shouldRepaint(covariant CandlestickPainter oldDelegate) {
    return oldDelegate.candle != candle || oldDelegate.maxScale != maxScale;
  }
}
