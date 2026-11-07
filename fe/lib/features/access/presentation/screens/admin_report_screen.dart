import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:fe/core/constants/route_constants.dart';
import 'package:fe/core/network/api_client.dart';
import 'package:fe/core/network/api_exception.dart';
import 'package:fe/core/theme/app_colors.dart';
import 'package:fe/core/theme/app_spacing.dart';
import 'package:fe/core/theme/app_text_styles.dart';
import 'package:fe/features/access/data/services/access_api_service.dart';
import 'package:fe/features/auth/domain/models/role.dart';
import 'package:fe/shared/widgets/app_card.dart';
import 'package:fe/shared/widgets/role_guard.dart';
import 'package:fe/shared/widgets/status_badge.dart';

class AdminReportScreen extends StatefulWidget {
  const AdminReportScreen({super.key});

  @override
  State<AdminReportScreen> createState() => _AdminReportScreenState();
}

class _AdminReportScreenState extends State<AdminReportScreen> {
  late final AccessApiService _accessService;

  bool _initialized = false;
  bool _loading = true;
  String? _errorMsg;
  int _daysRange = 1;
  DateTime? _customDate;

  Map<String, dynamic>? _summary;

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _customDate ?? now,
      firstDate: DateTime(2024, 1, 1),
      lastDate: now,
      helpText: 'Chọn ngày xem báo cáo ra/vào',
      cancelText: 'Hủy',
      confirmText: 'Chọn ngày',
    );
    if (picked != null) {
      setState(() {
        _customDate = picked;
        _daysRange = 0;
      });
      _loadReport();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _accessService = AccessApiService(context.read<ApiClient>());
      _loadReport();
    }
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final now = DateTime.now();
    final DateTime from;
    final DateTime to;
    if (_customDate != null && _daysRange == 0) {
      from = DateTime(
        _customDate!.year,
        _customDate!.month,
        _customDate!.day,
        0,
        0,
        0,
      );
      to = DateTime(
        _customDate!.year,
        _customDate!.month,
        _customDate!.day,
        23,
        59,
        59,
        999,
      );
    } else {
      from = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: _daysRange - 1));
      to = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    }

    try {
      final res = await _accessService.getReportSummary(
        from: from.toUtc().toIso8601String(),
        to: to.toUtc().toIso8601String(),
      );
      if (!mounted) return;
      setState(() {
        _summary = res;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Lỗi tải báo cáo: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentInside =
        (_summary?['currentInsideCount'] as num?)?.toInt() ?? 0;
    final totalCheckIns = (_summary?['totalCheckIns'] as num?)?.toInt() ?? 0;
    final totalCheckOuts = (_summary?['totalCheckOuts'] as num?)?.toInt() ?? 0;
    final totalAutoOuts =
        (_summary?['totalAutoCheckOuts'] as num?)?.toInt() ?? 0;
    final totalTx = (_summary?['totalTransactions'] as num?)?.toInt() ?? 0;

    final byMethod = _summary?['byMethod'] is Map
        ? Map<String, dynamic>.from(_summary!['byMethod'] as Map)
        : <String, dynamic>{};

    final dailyStats = _summary?['dailyStats'] is List
        ? (_summary!['dailyStats'] as List)
              .whereType<Map<String, dynamic>>()
              .toList()
        : <Map<String, dynamic>>[];

    return RoleGuard(
      allowedRoles: const [UserRole.admin, UserRole.staff],
      child: Scaffold(
        backgroundColor: AppColors.neutral50,
        appBar: AppBar(
          title: const Text('Báo cáo & Thống kê'),
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.charcoal900,
          elevation: 0,
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.accessHistory);
              },
              icon: const Icon(Icons.history_rounded, size: 18),
              label: const Text('Chi tiết Log'),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Làm mới',
              onPressed: _loading ? null : _loadReport,
            ),
          ],
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _errorMsg != null
              ? Center(
                  child: Text(
                    _errorMsg!,
                    style: AppTextStyles.body.copyWith(color: AppColors.danger),
                  ),
                )
              : SingleChildScrollView(
                  padding: AppSpacing.p5,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 850),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Bộ chọn khoảng thời gian
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Khoảng thời gian thống kê',
                                style: AppTextStyles.h3,
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _rangeChip('Hôm nay', 1),
                                  _rangeChip('7 ngày qua', 7),
                                  _rangeChip('30 ngày qua', 30),
                                  ActionChip(
                                    avatar: const Icon(
                                      Icons.calendar_month_rounded,
                                      size: 16,
                                      color: AppColors.accent600,
                                    ),
                                    backgroundColor:
                                        _customDate != null && _daysRange == 0
                                        ? AppColors.accent100
                                        : AppColors.white,
                                    label: Text(
                                      _customDate != null && _daysRange == 0
                                          ? 'Ngày ${DateFormat('dd/MM/yyyy').format(_customDate!)}'
                                          : 'Chọn ngày...',
                                    ),
                                    onPressed: _pickCustomDate,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s3),

                          // 4 Thẻ chỉ số KPI
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _kpiCard(
                                    title: 'Đang trong thư viện',
                                    value: '$currentInside',
                                    subtitle: 'Bạn đọc đang IN',
                                    color: AppColors.info,
                                    icon: Icons.people_alt_rounded,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s3),
                                Expanded(
                                  child: _kpiCard(
                                    title: 'Tổng lượt Check-in',
                                    value: '$totalCheckIns',
                                    subtitle: _customDate != null && _daysRange == 0
                                        ? 'Ngày ${DateFormat('dd/MM/yyyy').format(_customDate!)}'
                                        : 'Trong $_daysRange ngày',
                                    color: AppColors.success,
                                    icon: Icons.login_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s3),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _kpiCard(
                                    title: 'Tổng lượt Check-out',
                                    value: '$totalCheckOuts',
                                    subtitle: 'Check-out hợp lệ',
                                    color: AppColors.accent600,
                                    icon: Icons.logout_rounded,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s3),
                                Expanded(
                                  child: _kpiCard(
                                    title: 'Tự động Check-out',
                                    value: '$totalAutoOuts',
                                    subtitle: 'Quên check-out',
                                    color: AppColors.warning,
                                    icon: Icons.timer_off_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: AppSpacing.s4),

                          // Phân bổ theo phương thức định danh
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tỷ lệ theo Phương thức Định danh (Tổng: $totalTx lượt)',
                                  style: AppTextStyles.h3,
                                ),
                                const SizedBox(height: AppSpacing.s3),
                                _methodProgressRow(
                                  label: 'Mã QR (QR Code)',
                                  count: (byMethod['QR'] as num?)?.toInt() ?? 0,
                                  total: totalTx,
                                  color: AppColors.info,
                                ),
                                const SizedBox(height: 12),
                                _methodProgressRow(
                                  label: 'Khuôn mặt (Face Biometric)',
                                  count:
                                      (byMethod['FACE'] as num?)?.toInt() ?? 0,
                                  total: totalTx,
                                  color: AppColors.success,
                                ),
                                const SizedBox(height: 12),
                                _methodProgressRow(
                                  label: 'Duyệt thủ công (Manual Access)',
                                  count:
                                      (byMethod['MANUAL'] as num?)?.toInt() ??
                                      0,
                                  total: totalTx,
                                  color: AppColors.accent600,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: AppSpacing.s4),

                          // Thống kê theo ngày
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Biến động Lưu lượng Theo Ngày',
                                  style: AppTextStyles.h3,
                                ),
                                const SizedBox(height: AppSpacing.s3),
                                if (dailyStats.isEmpty)
                                  Text(
                                    'Chưa có phát sinh lượt ra/vào trong khoảng thời gian này.',
                                    style: AppTextStyles.bodySm.copyWith(
                                      color: AppColors.charcoal500,
                                    ),
                                  )
                                else
                                  ...dailyStats.reversed.map((day) {
                                    final dateStr =
                                        day['date']?.toString() ?? '---';
                                    final cIn =
                                        (day['checkIns'] as num?)?.toInt() ?? 0;
                                    final cOut =
                                        (day['checkOuts'] as num?)?.toInt() ??
                                        0;
                                    final aOut =
                                        (day['autoCheckOuts'] as num?)
                                            ?.toInt() ??
                                        0;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 110,
                                            child: Text(
                                              dateStr,
                                              style: AppTextStyles.mono
                                                  .copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Wrap(
                                              spacing: 8,
                                              runSpacing: 4,
                                              children: [
                                                StatusBadge(
                                                  label: 'Vào: $cIn',
                                                  color: AppColors.success,
                                                  backgroundColor:
                                                      AppColors.successLight,
                                                ),
                                                StatusBadge(
                                                  label: 'Ra: $cOut',
                                                  color: AppColors.info,
                                                  backgroundColor:
                                                      AppColors.infoLight,
                                                ),
                                                if (aOut > 0)
                                                  StatusBadge(
                                                    label: 'Auto-Out: $aOut',
                                                    color: AppColors.warning,
                                                    backgroundColor:
                                                        AppColors.warningLight,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _rangeChip(String label, int days) {
    final selected = _daysRange == days && _customDate == null;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.accent100,
      onSelected: (_) {
        setState(() {
          _daysRange = days;
          _customDate = null;
        });
        _loadReport();
      },
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return AppCard(
      padding: AppSpacing.p4,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.charcoal500,
                  ),
                ),
                Text(
                  value,
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.charcoal900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.charcoal400,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodProgressRow({
    required String label,
    required int count,
    required int total,
    required Color color,
  }) {
    final ratio = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;
    final percent = (ratio * 100).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              '$count lượt ($percent%)',
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.charcoal600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: AppColors.neutral200,
            color: color,
          ),
        ),
      ],
    );
  }
}
