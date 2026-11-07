import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fe/core/theme/app_colors.dart';
import 'package:fe/core/theme/app_spacing.dart';
import 'package:fe/core/theme/app_text_styles.dart';
import 'package:fe/shared/widgets/app_card.dart';
import '../models/check_in_out_statistic_model.dart';
import '../models/candle_data.dart';
import 'candlestick_chart_view.dart';

enum ChartViewMode { bar, candlestick }

class CheckInOutChart extends StatefulWidget {
  final List<CheckInOutStatisticModel> stats;
  final bool isLoading;

  const CheckInOutChart({
    super.key,
    required this.stats,
    required this.isLoading,
  });

  @override
  State<CheckInOutChart> createState() => _CheckInOutChartState();
}

class _CheckInOutChartState extends State<CheckInOutChart> {
  final ScrollController _scrollController = ScrollController();
  ChartViewMode _viewMode = ChartViewMode.bar;
  bool _showAllDetails = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollBy(double offset) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + offset).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading && widget.stats.isEmpty) {
      return const AppCard(
        child: SizedBox(
          height: 240,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (widget.stats.isEmpty) {
      return AppCard(
        child: SizedBox(
          height: 180,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.bar_chart_outlined,
                  size: 40,
                  color: AppColors.neutral500,
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  'Không có dữ liệu lượt ra/vào trong khoảng thời gian này.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.charcoal500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    int maxCount = 1;
    int maxPeople = 1;
    for (final s in widget.stats) {
      if (s.checkInCount > maxCount) maxCount = s.checkInCount;
      if (s.checkOutCount > maxCount) maxCount = s.checkOutCount;
      if (s.peakPeopleCount > maxPeople) maxPeople = s.peakPeopleCount;
    }

    final candleList = _viewMode == ChartViewMode.candlestick
        ? computeCandleData(widget.stats)
        : const <CandleData>[];

    final isCandle = _viewMode == ChartViewMode.candlestick;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCandle
                ? 'Biểu đồ nến biến động số người'
                : 'Biểu đồ biến động Check-in / Check-out',
            style: AppTextStyles.h3.copyWith(color: AppColors.charcoal900),
          ),
          const SizedBox(height: 2),
          Text(
            '${widget.stats.length} mốc • Kéo chuột/vuốt ngang để xem thêm',
            style: AppTextStyles.caption.copyWith(color: AppColors.charcoal500),
          ),
          const SizedBox(height: AppSpacing.s3),
          Wrap(
            spacing: AppSpacing.s3,
            runSpacing: AppSpacing.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildViewModeToggle(),
              if (!isCandle) ...[
                _legendItem('Check-in', AppColors.success),
                _legendItem('Check-out', AppColors.accent500),
              ] else ...[
                _legendItem('Tăng', AppColors.success),
                _legendItem('Giảm', AppColors.danger),
                _legendItem('Đỉnh/Đáy', AppColors.charcoal500),
              ],
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => _scrollBy(-200),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.neutral100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.neutral300),
                      ),
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        size: 20,
                        color: AppColors.charcoal700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _scrollBy(200),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.neutral100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.neutral300),
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.charcoal700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          if (isCandle)
            CandlestickChartView(
              candleList: candleList,
              maxScale: maxPeople,
              scrollController: _scrollController,
            )
          else
            _buildBarChart(context, maxCount),
          const SizedBox(height: AppSpacing.s3),
          const Divider(color: AppColors.neutral200),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'Bảng kê chi tiết từng mốc',
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.charcoal700,
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          _buildDetailList(widget.stats, isCandle),
        ],
      ),
    );
  }

  Widget _buildViewModeToggle() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.neutral300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton(
            mode: ChartViewMode.bar,
            icon: Icons.bar_chart_rounded,
            tooltip: 'Biểu đồ cột',
          ),
          _buildToggleButton(
            mode: ChartViewMode.candlestick,
            icon: Icons.candlestick_chart_rounded,
            tooltip: 'Biểu đồ nến',
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required ChartViewMode mode,
    required IconData icon,
    required String tooltip,
  }) {
    final isSelected = _viewMode == mode;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          if (_viewMode != mode) {
            setState(() {
              _viewMode = mode;
            });
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 18,
            color: isSelected ? AppColors.charcoal900 : AppColors.charcoal500,
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(BuildContext context, int maxCount) {
    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
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
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: widget.stats.map((stat) {
                      return _buildBarGroup(stat, maxCount);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          _buildRightYAxis(maxCount, 'lượt'),
        ],
      ),
    );
  }

  Widget _buildRightYAxis(int maxCount, String unit) {
    final effectiveMax = maxCount <= 0 ? 1 : maxCount;
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
            unit,
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

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.charcoal600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBarGroup(CheckInOutStatisticModel stat, int maxCount) {
    const double maxBarHeight = 120.0;
    final inHeight = (stat.checkInCount / maxCount * maxBarHeight).clamp(
      4.0,
      maxBarHeight,
    );
    final outHeight = (stat.checkOutCount / maxCount * maxBarHeight).clamp(
      4.0,
      maxBarHeight,
    );

    final timeLabel = stat.intervalMin >= 1440
        ? DateFormat('dd/MM').format(stat.startDate.toLocal())
        : DateFormat('HH:mm').format(stat.startDate.toLocal());

    return Container(
      width: 48,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // In bar
              Tooltip(
                message:
                    'Vào: ${stat.checkInCount} lượt\nThời gian: ${stat.startDate.toLocal()}',
                child: Container(
                  width: 14,
                  height: inHeight,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 3),
              // Out bar
              Tooltip(
                message:
                    'Ra: ${stat.checkOutCount} lượt\nThời gian: ${stat.startDate.toLocal()}',
                child: Container(
                  width: 14,
                  height: outHeight,
                  decoration: const BoxDecoration(
                    color: AppColors.accent500,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
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

  Widget _buildDetailList(List<CheckInOutStatisticModel> stats, bool isCandle) {
    final displayedList = _showAllDetails
        ? stats.reversed.toList()
        : stats.reversed.take(10).toList();

    return Column(
      children: [
        ...displayedList.map((s) {
          final timeStr = DateFormat(
            'HH:mm dd/MM',
          ).format(s.startDate.toLocal());
          final net = s.checkInCount - s.checkOutCount;
          final isBullish = net >= 0;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    timeStr,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.charcoal700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.arrow_downward,
                        size: 14,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${s.checkInCount}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.arrow_upward,
                        size: 14,
                        color: AppColors.accent600,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${s.checkOutCount}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.accent600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCandle)
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isBullish
                                        ? AppColors.success
                                        : AppColors.danger)
                                    .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            net >= 0 ? '+$net' : '$net',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isBullish
                                  ? AppColors.success
                                  : AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Cao: ${s.peakPeopleCount} | Thấp: ${s.lowestPeopleCount}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.charcoal400,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          );
        }),
        if (stats.length > 10)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s2),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showAllDetails = !_showAllDetails;
                });
              },
              icon: Icon(
                _showAllDetails ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              label: Text(
                _showAllDetails
                    ? 'Thu gọn danh sách'
                    : 'Xem tất cả ${stats.length} mốc',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.accent600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
