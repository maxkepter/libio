import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:fe/core/theme/app_colors.dart';
import 'package:fe/core/theme/app_text_styles.dart';
import 'package:fe/features/library/domain/models/library_schedule.dart';
import 'package:fe/features/library/presentation/providers/schedule_provider.dart';
import 'package:fe/features/library/presentation/screens/special_days_tab.dart';
import 'package:fe/features/library/presentation/screens/weekly_hours_tab.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ScheduleProvider>().loadAll();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.neutral50,
        appBar: AppBar(
          title: const Text('Lịch mở cửa thư viện'),
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.charcoal900,
          elevation: 0,
          bottom: const TabBar(
            labelColor: AppColors.charcoal900,
            unselectedLabelColor: AppColors.charcoal500,
            indicatorColor: AppColors.accent500,
            tabs: [
              Tab(text: 'Giờ hàng tuần'),
              Tab(text: 'Ngày đặc biệt'),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              const _StatusBanner(),
              const Expanded(
                child: TabBarView(
                  children: [WeeklyHoursTab(), SpecialDaysTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner();

  @override
  Widget build(BuildContext context) {
    final status = context.select<ScheduleProvider, OpenStatus?>(
      (p) => p.status,
    );
    if (status == null) return const SizedBox.shrink();

    final isOpen = status.isOpen;
    final color = isOpen ? AppColors.success : AppColors.danger;
    final bg = isOpen ? AppColors.successLight : AppColors.dangerLight;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isOpen ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOpen ? 'Thư viện đang MỞ CỬA' : 'Thư viện đang ĐÓNG CỬA',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  status.reasonLabel,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.charcoal600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
