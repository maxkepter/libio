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
import 'package:fe/shared/widgets/app_button.dart';
import 'package:fe/shared/widgets/app_card.dart';
import 'package:fe/shared/widgets/app_text_field.dart';
import 'package:fe/shared/widgets/role_guard.dart';
import 'package:fe/shared/widgets/status_badge.dart';

class LibraryClosureScreen extends StatefulWidget {
  const LibraryClosureScreen({super.key});

  @override
  State<LibraryClosureScreen> createState() => _LibraryClosureScreenState();
}

class _LibraryClosureScreenState extends State<LibraryClosureScreen> {
  final _reasonCtrl = TextEditingController(
    text: 'Đóng cửa thư viện cuối ngày - Tự động check-out',
  );
  late final AccessApiService _accessService;

  bool _initialized = false;
  bool _loading = true;
  bool _submitting = false;
  bool _markTodayClosed = false;

  List<Map<String, dynamic>> _activeReaders = [];
  List<Map<String, dynamic>> _autoCheckOutLogs = [];
  String? _errorMsg;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _accessService = AccessApiService(context.read<ApiClient>());
      _loadData();
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      final results = await Future.wait([
        _accessService.getActiveReaders(),
        _accessService.getAccessLogs(
          page: 1,
          size: 15,
          action: 'AUTO_CHECK_OUT',
        ),
      ]);

      if (!mounted) return;
      final active = results[0] as List<Map<String, dynamic>>;
      final autoLogsRes = results[1] as Map<String, dynamic>;
      final rawList = autoLogsRes['data'] is List
          ? (autoLogsRes['data'] as List)
                .whereType<Map<String, dynamic>>()
                .toList()
          : <Map<String, dynamic>>[];

      setState(() {
        _activeReaders = active;
        _autoCheckOutLogs = rawList;
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
        _errorMsg = 'Không thể tải dữ liệu: $e';
        _loading = false;
      });
    }
  }

  Future<void> _confirmAndTriggerClosure() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận Đóng cửa & Auto Check-out'),
        content: Text(
          'Hệ thống sẽ tự động ghi nhận AUTO_CHECK_OUT cho toàn bộ ${_activeReaders.length} bạn đọc còn đang ở trong thư viện.\n\nBạn có chắc chắn muốn thực hiện?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận đóng cửa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _submitting = true;
      _errorMsg = null;
    });

    try {
      final res = await _accessService.triggerClosure(
        reason: _reasonCtrl.text.trim(),
        markTodayClosed: _markTodayClosed,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(
            res['message']?.toString() ?? 'Đã đóng cửa và auto check-out.',
          ),
        ),
      );

      setState(() {
        _submitting = false;
      });
      await _loadData();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.message;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Lỗi khi đóng cửa: $e';
        _loading = false;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const [UserRole.admin],
      child: Scaffold(
        backgroundColor: AppColors.neutral50,
        appBar: AppBar(
          title: const Text('Đóng cửa & Auto Check-out'),
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.charcoal900,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Làm mới',
              onPressed: _loading ? null : _loadData,
            ),
          ],
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: AppSpacing.p5,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Khối thao tác đóng cửa
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'Chốt đóng cửa & Giải phóng bạn đọc',
                                      style: AppTextStyles.h3,
                                    ),
                                    StatusBadge(
                                      label:
                                          'Đang trong thư viện: ${_activeReaders.length}',
                                      color: _activeReaders.isEmpty
                                          ? AppColors.success
                                          : AppColors.warning,
                                      backgroundColor: _activeReaders.isEmpty
                                          ? AppColors.successLight
                                          : AppColors.warningLight,
                                      icon: Icons.people_alt_outlined,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.s2),
                                Text(
                                  'Khi đóng cửa cuối ngày hoặc đóng cửa khẩn cấp, hệ thống sẽ chuyển trạng thái các bạn đọc quên check-out sang AUTO_CHECK_OUT.',
                                  style: AppTextStyles.bodySm.copyWith(
                                    color: AppColors.charcoal500,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.s3),
                                AppTextField(
                                  controller: _reasonCtrl,
                                  labelText: 'Lý do đóng cửa / Auto check-out',
                                  prefixIcon: Icons.event_busy_rounded,
                                ),
                                const SizedBox(height: AppSpacing.s2),
                                Material(
                                  color: Colors.transparent,
                                  child: CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    value: _markTodayClosed,
                                    onChanged: (v) {
                                      setState(() {
                                        _markTodayClosed = v ?? false;
                                      });
                                    },
                                    title: Text(
                                      'Đánh dấu đóng cửa ngày hôm nay trên Lịch đặc biệt (Chặn check-in mới)',
                                      style: AppTextStyles.bodySm,
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  ),
                                ),
                                if (_errorMsg != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _errorMsg!,
                                    style: AppTextStyles.bodySm.copyWith(
                                      color: AppColors.danger,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.s3),
                                AppButton(
                                  text: _submitting
                                      ? 'Đang xử lý...'
                                      : 'Đóng cửa & Tự động Check-out (${_activeReaders.length} người)',
                                  icon: Icons.lock_clock_rounded,
                                  onPressed: _submitting
                                      ? null
                                      : _confirmAndTriggerClosure,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: AppSpacing.s4),

                          // Danh sách bạn đọc đang ở trong thư viện
                          Text(
                            'Bạn đọc hiện đang ở TRONG thư viện (${_activeReaders.length})',
                            style: AppTextStyles.h3,
                          ),
                          const SizedBox(height: AppSpacing.s2),
                          if (_activeReaders.isEmpty)
                            AppCard(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'Hiện không có bạn đọc nào đang ở trong thư viện.',
                                  style: AppTextStyles.bodySm.copyWith(
                                    color: AppColors.charcoal500,
                                  ),
                                ),
                              ),
                            )
                          else
                            ..._activeReaders.map((r) {
                              final dt = DateTime.tryParse(
                                r['checkedInAt']?.toString() ?? '',
                              )?.toLocal();
                              final timeStr = dt != null
                                  ? DateFormat('HH:mm dd/MM/yyyy').format(dt)
                                  : '---';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: AppCard(
                                  padding: AppSpacing.p4,
                                  child: Row(
                                    children: [
                                      const CircleAvatar(
                                        backgroundColor: AppColors.successLight,
                                        child: Icon(
                                          Icons.person_pin_circle_rounded,
                                          color: AppColors.success,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              r['fullName']?.toString() ??
                                                  '---',
                                              style: AppTextStyles.body
                                                  .copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            Text(
                                              '${r['email'] ?? ''} • Vào lúc $timeStr (${r['method'] ?? ''})',
                                              style: AppTextStyles.bodySm
                                                  .copyWith(
                                                    color:
                                                        AppColors.charcoal500,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () async {
                                          await Navigator.pushNamed(
                                            context,
                                            AppRoutes.manualAccess,
                                            arguments: {
                                              'readerId': r['readerId']
                                                  ?.toString(),
                                            },
                                          );
                                          _loadData();
                                        },
                                        icon: const Icon(
                                          Icons.logout_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('Cho ra lẻ'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),

                          const SizedBox(height: AppSpacing.s4),

                          // Danh sách vi phạm quên check-out (AUTO_CHECK_OUT) gần đây
                          Text(
                            'Lịch sử Tự động Check-out (Quên Check-out) gần đây',
                            style: AppTextStyles.h3,
                          ),
                          const SizedBox(height: AppSpacing.s2),
                          if (_autoCheckOutLogs.isEmpty)
                            AppCard(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'Chưa có trường hợp AUTO_CHECK_OUT nào.',
                                  style: AppTextStyles.bodySm.copyWith(
                                    color: AppColors.charcoal500,
                                  ),
                                ),
                              ),
                            )
                          else
                            ..._autoCheckOutLogs.map((log) {
                              final dt = DateTime.tryParse(
                                log['occurredAt']?.toString() ?? '',
                              )?.toLocal();
                              final timeStr = dt != null
                                  ? DateFormat('HH:mm dd/MM/yyyy').format(dt)
                                  : '---';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: AppCard(
                                  padding: AppSpacing.p4,
                                  child: Row(
                                    children: [
                                      const CircleAvatar(
                                        backgroundColor: AppColors.warningLight,
                                        child: Icon(
                                          Icons.warning_amber_rounded,
                                          color: AppColors.warning,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              log['readerName']?.toString() ??
                                                  '---',
                                              style: AppTextStyles.body
                                                  .copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            Text(
                                              'Lý do: ${log['reason'] ?? '---'}',
                                              style: AppTextStyles.bodySm
                                                  .copyWith(
                                                    color:
                                                        AppColors.charcoal600,
                                                  ),
                                            ),
                                            Text(
                                              'Thời gian: $timeStr',
                                              style: AppTextStyles.bodySm
                                                  .copyWith(
                                                    color:
                                                        AppColors.charcoal500,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const StatusBadge(
                                        label: 'AUTO_OUT',
                                        color: AppColors.warning,
                                        backgroundColor: AppColors.warningLight,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
