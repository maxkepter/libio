import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:fe/core/network/api_client.dart';
import 'package:fe/core/network/api_exception.dart';
import 'package:fe/core/theme/app_colors.dart';
import 'package:fe/core/theme/app_spacing.dart';
import 'package:fe/core/theme/app_text_styles.dart';
import 'package:fe/features/access/data/services/access_api_service.dart';
import 'package:fe/features/auth/domain/models/role.dart';
import 'package:fe/shared/widgets/app_card.dart';
import 'package:fe/shared/widgets/app_text_field.dart';
import 'package:fe/shared/widgets/role_guard.dart';
import 'package:fe/shared/widgets/status_badge.dart';

class AccessHistoryScreen extends StatefulWidget {
  const AccessHistoryScreen({super.key});

  @override
  State<AccessHistoryScreen> createState() => _AccessHistoryScreenState();
}

class _AccessHistoryScreenState extends State<AccessHistoryScreen> {
  final _searchCtrl = TextEditingController();
  late final AccessApiService _accessService;

  bool _initialized = false;
  bool _loading = true;
  String? _errorMsg;

  String _selectedAction = '';
  String _selectedMethod = '';
  DateTime _selectedDate = DateTime.now();
  int _page = 1;
  int _total = 0;
  int _totalPages = 1;
  List<Map<String, dynamic>> _logs = [];

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(now) ? now : _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: now,
      helpText: 'Chọn ngày xem lịch sử ra/vào',
      cancelText: 'Hủy',
      confirmText: 'Chọn ngày',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _loadLogs(page: 1);
    }
  }

  void _shiftDay(int deltaDays) {
    final target = _selectedDate.add(Duration(days: deltaDays));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (DateTime(target.year, target.month, target.day).isAfter(today)) {
      return;
    }
    setState(() {
      _selectedDate = target;
    });
    _loadLogs(page: 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _accessService = AccessApiService(context.read<ApiClient>());
      _loadLogs(page: 1);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLogs({int page = 1}) async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final startOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      0,
      0,
      0,
    );
    final endOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      23,
      59,
      59,
      999,
    );

    try {
      final res = await _accessService.getAccessLogs(
        page: page,
        size: 20,
        action: _selectedAction.isEmpty ? null : _selectedAction,
        method: _selectedMethod.isEmpty ? null : _selectedMethod,
        search: _searchCtrl.text.trim(),
        from: startOfDay.toUtc().toIso8601String(),
        to: endOfDay.toUtc().toIso8601String(),
      );

      if (!mounted) return;
      final list = res['data'] is List
          ? (res['data'] as List).whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];

      setState(() {
        _logs = list;
        _page = (res['page'] as num?)?.toInt() ?? page;
        _total = (res['total'] as num?)?.toInt() ?? list.length;
        _totalPages = (res['totalPages'] as num?)?.toInt() ?? 1;
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
        _errorMsg = 'Lỗi tải lịch sử: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const [UserRole.admin, UserRole.staff],
      child: Scaffold(
        backgroundColor: AppColors.neutral50,
        appBar: AppBar(
          title: const Text('Lịch sử Ra / Vào Thư viện'),
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.charcoal900,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Làm mới',
              onPressed: _loading ? null : () => _loadLogs(page: _page),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Thanh chọn ngày (Calendar filter)
                        AppCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Ngày trước',
                                    onPressed: _loading
                                        ? null
                                        : () => _shiftDay(-1),
                                    icon: const Icon(
                                      Icons.chevron_left_rounded,
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _loading ? null : _pickDate,
                                    icon: const Icon(
                                      Icons.calendar_month_rounded,
                                      size: 18,
                                      color: AppColors.accent600,
                                    ),
                                    label: Text(
                                      '${DateFormat('dd/MM/yyyy').format(_selectedDate)}${_isToday ? ' (Hôm nay)' : ''}',
                                      style: AppTextStyles.body.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.charcoal900,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: AppColors.neutral300,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Ngày tiếp theo',
                                    onPressed: _loading || _isToday
                                        ? null
                                        : () => _shiftDay(1),
                                    icon: const Icon(
                                      Icons.chevron_right_rounded,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!_isToday)
                                    TextButton(
                                      onPressed: _loading
                                          ? null
                                          : () {
                                              setState(() {
                                                _selectedDate = DateTime.now();
                                              });
                                              _loadLogs(page: 1);
                                            },
                                      child: const Text('Về hôm nay'),
                                    ),
                                  StatusBadge(
                                    label: 'Tổng: $_total lượt',
                                    color: AppColors.info,
                                    backgroundColor: AppColors.infoLight,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        AppTextField(
                          controller: _searchCtrl,
                          hintText: 'Tìm theo tên bạn đọc, email, hoặc lý do...',
                          prefixIcon: Icons.search_rounded,
                          textInputAction: TextInputAction.search,
                          onFieldSubmitted: (_) => _loadLogs(page: 1),
                          suffix: IconButton(
                            icon: const Icon(
                              Icons.search_rounded,
                              color: AppColors.charcoal500,
                            ),
                            onPressed: () => _loadLogs(page: 1),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _dropdownFilter(
                                value: _selectedAction,
                                options: const [
                                  _FilterOption(
                                    value: '',
                                    label: 'Mọi hành động',
                                    icon: Icons.swap_vert_rounded,
                                  ),
                                  _FilterOption(
                                    value: 'CHECK_IN',
                                    label: 'Check-in (Vào)',
                                    icon: Icons.login_rounded,
                                  ),
                                  _FilterOption(
                                    value: 'CHECK_OUT',
                                    label: 'Check-out (Ra)',
                                    icon: Icons.logout_rounded,
                                  ),
                                  _FilterOption(
                                    value: 'AUTO_CHECK_OUT',
                                    label: 'Auto Check-out',
                                    icon: Icons.timer_off_outlined,
                                  ),
                                ],
                                onChanged: (val) {
                                  setState(() => _selectedAction = val);
                                  _loadLogs(page: 1);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _dropdownFilter(
                                value: _selectedMethod,
                                options: const [
                                  _FilterOption(
                                    value: '',
                                    label: 'Mọi phương thức',
                                    icon: Icons.tune_rounded,
                                  ),
                                  _FilterOption(
                                    value: 'QR',
                                    label: 'Mã QR',
                                    icon: Icons.qr_code_scanner_rounded,
                                  ),
                                  _FilterOption(
                                    value: 'FACE',
                                    label: 'Khuôn mặt',
                                    icon: Icons.face_retouching_natural,
                                  ),
                                  _FilterOption(
                                    value: 'MANUAL',
                                    label: 'Duyệt thủ công',
                                    icon: Icons.how_to_reg_rounded,
                                  ),
                                ],
                                onChanged: (val) {
                                  setState(() => _selectedMethod = val);
                                  _loadLogs(page: 1);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _errorMsg != null
                        ? Center(
                            child: Text(
                              _errorMsg!,
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.danger,
                              ),
                            ),
                          )
                        : _logs.isEmpty
                        ? Center(
                            child: Text(
                              'Không có lượt ra/vào nào trong ngày ${DateFormat('dd/MM/yyyy').format(_selectedDate)}.',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.charcoal500,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: AppSpacing.p4,
                            itemCount: _logs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = _logs[index];
                              return _buildLogCard(item);
                            },
                          ),
                  ),
                  if (_totalPages > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: _page > 1 && !_loading
                                ? () => _loadLogs(page: _page - 1)
                                : null,
                            child: const Text('Trước'),
                          ),
                          Text(
                            'Trang $_page / $_totalPages • Tổng $_total lượt',
                            style: AppTextStyles.bodySm,
                          ),
                          TextButton(
                            onPressed: _page < _totalPages && !_loading
                                ? () => _loadLogs(page: _page + 1)
                                : null,
                            child: const Text('Sau'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropdownFilter({
    required String value,
    required List<_FilterOption> options,
    required ValueChanged<String> onChanged,
  }) {
    final current = options.firstWhere(
      (o) => o.value == value,
      orElse: () => options.first,
    );

    return PopupMenuButton<String>(
      initialValue: value,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 4),
      color: AppColors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.neutral200),
      ),
      onSelected: onChanged,
      itemBuilder: (context) => options.map((opt) {
        final isSelected = opt.value == value;
        return PopupMenuItem<String>(
          value: opt.value,
          height: 40,
          child: Row(
            children: [
              Icon(
                opt.icon,
                size: 18,
                color: isSelected ? AppColors.accent600 : AppColors.charcoal500,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  opt.label,
                  style: AppTextStyles.bodySm.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.accent600
                        : AppColors.charcoal900,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: AppColors.accent600,
                ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: value.isNotEmpty ? AppColors.accent100 : AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value.isNotEmpty ? AppColors.accent500 : AppColors.neutral300,
          ),
        ),
        child: Row(
          children: [
            Icon(
              current.icon,
              size: 16,
              color: value.isNotEmpty
                  ? AppColors.accent600
                  : AppColors.charcoal500,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                current.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.charcoal900,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppColors.charcoal600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> item) {
    final action = item['action']?.toString() ?? '';
    final method = item['method']?.toString() ?? '';
    final reason = item['reason']?.toString();
    final staffName = item['staffName']?.toString();
    final gateName = item['gateName']?.toString();

    final dt = DateTime.tryParse(
      item['occurredAt']?.toString() ?? '',
    )?.toLocal();
    final timeStr = dt != null
        ? DateFormat('HH:mm:ss dd/MM/yyyy').format(dt)
        : '---';

    final isCheckIn = action == 'CHECK_IN';
    final isAutoOut = action == 'AUTO_CHECK_OUT';

    final Color badgeColor = isCheckIn
        ? AppColors.success
        : isAutoOut
        ? AppColors.warning
        : AppColors.info;
    final Color badgeBg = isCheckIn
        ? AppColors.successLight
        : isAutoOut
        ? AppColors.warningLight
        : AppColors.infoLight;

    return AppCard(
      padding: AppSpacing.p4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: badgeBg,
                child: Icon(
                  isCheckIn
                      ? Icons.login_rounded
                      : isAutoOut
                      ? Icons.timer_off_outlined
                      : Icons.logout_rounded,
                  color: badgeColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['readerName']?.toString() ?? '---',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      item['readerEmail']?.toString() ?? '---',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.charcoal500,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: '$action ($method)',
                color: badgeColor,
                backgroundColor: badgeBg,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              Text(
                'Thời gian: $timeStr',
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.charcoal600,
                ),
              ),
              if (gateName != null && gateName.isNotEmpty)
                Text(
                  'Cổng: $gateName',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.charcoal600,
                  ),
                ),
              if (staffName != null && staffName.isNotEmpty)
                Text(
                  'Người duyệt: $staffName',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.charcoal600,
                  ),
                ),
            ],
          ),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Lý do: $reason',
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.accent600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterOption {
  final String value;
  final String label;
  final IconData icon;

  const _FilterOption({
    required this.value,
    required this.label,
    required this.icon,
  });
}
