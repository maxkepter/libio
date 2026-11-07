import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fe/core/theme/app_colors.dart';
import 'package:fe/core/theme/app_spacing.dart';
import 'package:fe/core/theme/app_text_styles.dart';
import 'package:fe/shared/widgets/app_card.dart';
import 'package:fe/shared/widgets/status_badge.dart';
import '../models/occupancy_model.dart';

class OccupancyCard extends StatelessWidget {
  final OccupancyModel? occupancy;
  final bool isLoading;
  final VoidCallback onRefresh;

  const OccupancyCard({
    super.key,
    required this.occupancy,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (occupancy == null && isLoading) {
      return const AppCard(
        child: SizedBox(
          height: 140,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final data =
        occupancy ??
        OccupancyModel(
          currentOccupants: 0,
          maxCapacity: 500,
          occupancyRate: 0.0,
          status: OccupancyStatus.normal,
          updatedAt: DateTime.now(),
        );

    final rateClamped = (data.occupancyRate / 100.0).clamp(0.0, 1.0);
    final formattedTime = DateFormat(
      'HH:mm:ss dd/MM/yyyy',
    ).format(data.updatedAt.toLocal());

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: data.status.lightColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.groups_rounded,
                        color: data.status.color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sức chứa hiện tại',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.h3.copyWith(
                              color: AppColors.charcoal900,
                            ),
                          ),
                          Text(
                            'Số lượng người đang có mặt trong thư viện',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.charcoal500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: data.statusLabel,
                color: data.statusColor,
                backgroundColor: data.status.lightColor,
                icon: data.isNormal
                    ? Icons.check_circle_outline
                    : (data.isWarning
                          ? Icons.warning_amber_rounded
                          : Icons.error_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${data.currentOccupants}',
                style: AppTextStyles.h1.copyWith(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal900,
                ),
              ),
              Text(
                ' / ${data.maxCapacity} người',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.charcoal500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${data.occupancyRate.toStringAsFixed(1)}%',
                style: AppTextStyles.h2.copyWith(
                  color: data.statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: rateClamped,
              minHeight: 12,
              backgroundColor: AppColors.neutral200,
              valueColor: AlwaysStoppedAnimation<Color>(data.statusColor),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cập nhật: $formattedTime',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.charcoal400,
                ),
              ),
              TextButton.icon(
                onPressed: isLoading ? null : onRefresh,
                icon: isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Làm mới'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.charcoal700,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
