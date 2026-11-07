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
import 'package:fe/features/user/domain/models/reader_res.dart';
import 'package:fe/features/user/presentation/providers/user_provider.dart';
import 'package:fe/shared/widgets/app_button.dart';
import 'package:fe/shared/widgets/app_card.dart';
import 'package:fe/shared/widgets/app_text_field.dart';
import 'package:fe/shared/widgets/role_guard.dart';
import 'package:fe/shared/widgets/status_badge.dart';

class ManualAccessScreen extends StatefulWidget {
  final String? initialReaderId;

  const ManualAccessScreen({super.key, this.initialReaderId});

  @override
  State<ManualAccessScreen> createState() => _ManualAccessScreenState();
}

class _ManualAccessScreenState extends State<ManualAccessScreen> {
  static const List<String> _quickReasons = [
    'Quên mang điện thoại (không có QR)',
    'Lỗi nhận diện khuôn mặt tại quầy',
    'Thiết bị quét tại cổng gặp sự cố',
    'Khách / Bạn đọc được cấp phép đặc biệt',
  ];

  final _searchCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  late final AccessApiService _accessService;

  bool _initialized = false;
  bool _loadingState = false;
  bool _submitting = false;

  ReaderRes? _selectedReader;
  Map<String, dynamic>? _readerState;
  Map<String, dynamic>? _lastResult;
  String? _errorMsg;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _accessService = AccessApiService(context.read<ApiClient>());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<UserProvider>().loadReaders(page: 1);
      });
      if (widget.initialReaderId != null &&
          widget.initialReaderId!.isNotEmpty) {
        _loadReaderStateById(widget.initialReaderId!);
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReaderStateById(
    String readerId, {
    ReaderRes? reader,
    bool keepLastResult = false,
  }) async {
    setState(() {
      if (reader != null) _selectedReader = reader;
      _loadingState = true;
      _errorMsg = null;
      if (!keepLastResult) _lastResult = null;
    });

    try {
      final stateData = await _accessService.getReaderAccessState(readerId);
      if (!mounted) return;
      setState(() {
        _readerState = stateData;
        _loadingState = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.message;
        _loadingState = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Lỗi kiểm tra trạng thái: $e';
        _loadingState = false;
      });
    }
  }

  Future<void> _submitManualAccess() async {
    final readerId =
        _readerState?['readerId']?.toString() ?? _selectedReader?.id;
    if (readerId == null || readerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn bạn đọc trước.')),
      );
      return;
    }

    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn hoặc nhập lý do duyệt thủ công.'),
        ),
      );
      return;
    }

    final suggestedAction = _readerState?['suggestedAction']?.toString();

    setState(() {
      _submitting = true;
      _errorMsg = null;
    });

    try {
      final res = await _accessService.manualCheckInOut(
        readerId: readerId,
        reason: reason,
        action: suggestedAction,
      );
      if (!mounted) return;

      final data = res['data'] is Map<String, dynamic>
          ? res['data'] as Map<String, dynamic>
          : <String, dynamic>{};

      setState(() {
        _lastResult = data;
        _submitting = false;
        _reasonCtrl.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(res['message']?.toString() ?? 'Thao tác thành công.'),
        ),
      );

      await _loadReaderStateById(
        readerId,
        reader: _selectedReader,
        keepLastResult: true,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.message;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Lỗi thực hiện: $e';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final readers = userProvider.readersPage?.data ?? [];
    final isCurrentlyIn = _readerState?['state'] == 'IN';

    return RoleGuard(
      allowedRoles: const [UserRole.admin, UserRole.staff],
      child: Scaffold(
        backgroundColor: AppColors.neutral50,
        appBar: AppBar(
          title: const Text('Ra / Vào Thủ Công'),
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.charcoal900,
          elevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: AppSpacing.p5,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Bước 1: Tìm và chọn bạn đọc
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '1. Tìm và chọn bạn đọc',
                            style: AppTextStyles.h3,
                          ),
                          const SizedBox(height: AppSpacing.s3),
                          AppTextField(
                            controller: _searchCtrl,
                            hintText: 'Nhập họ tên hoặc SĐT bạn đọc để tìm...',
                            prefixIcon: Icons.search_rounded,
                            textInputAction: TextInputAction.search,
                            onFieldSubmitted: (v) {
                              context.read<UserProvider>().loadReaders(
                                page: 1,
                                search: v,
                              );
                            },
                            suffix: IconButton(
                              icon: const Icon(
                                Icons.search_rounded,
                                color: AppColors.charcoal500,
                              ),
                              onPressed: () {
                                context.read<UserProvider>().loadReaders(
                                  page: 1,
                                  search: _searchCtrl.text,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s3),
                          if (userProvider.isLoading && readers.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (readers.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                'Không tìm thấy bạn đọc phù hợp.',
                                style: AppTextStyles.bodySm.copyWith(
                                  color: AppColors.charcoal500,
                                ),
                              ),
                            )
                          else
                            Material(
                              color: Colors.transparent,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 220,
                                ),
                                child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: readers.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final r = readers[index];
                                  final isSelected =
                                      (_readerState?['readerId'] ??
                                          _selectedReader?.id) ==
                                      r.id;
                                  return ListTile(
                                    dense: true,
                                    selected: isSelected,
                                    selectedTileColor: AppColors.accent100,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    leading: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: isSelected
                                          ? AppColors.accent600
                                          : AppColors.neutral200,
                                      child: Icon(
                                        Icons.person_outline_rounded,
                                        size: 18,
                                        color: isSelected
                                            ? AppColors.white
                                            : AppColors.charcoal700,
                                      ),
                                    ),
                                    title: Text(
                                      r.fullName,
                                      style: AppTextStyles.body.copyWith(
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Text(
                                      r.user?.email ?? r.phone ?? '---',
                                      style: AppTextStyles.bodySm.copyWith(
                                        color: AppColors.charcoal500,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(
                                            Icons.check_circle_rounded,
                                            color: AppColors.accent600,
                                          )
                                        : const Icon(
                                            Icons.chevron_right_rounded,
                                            color: AppColors.charcoal400,
                                          ),
                                    onTap: () => _loadReaderStateById(
                                      r.id,
                                      reader: r,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.s4),

                    // Bước 2: Trạng thái hiện tại & Form duyệt
                    if (_loadingState)
                      const AppCard(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    else if (_readerState != null)
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
                                  '2. Xác nhận trạng thái & Lý do duyệt',
                                  style: AppTextStyles.h3,
                                ),
                                StatusBadge(
                                  label: isCurrentlyIn
                                      ? 'Đang TRONG thư viện (IN)'
                                      : 'Đang ở NGOÀI (OUT)',
                                  color: isCurrentlyIn
                                      ? AppColors.success
                                      : AppColors.charcoal600,
                                  backgroundColor: isCurrentlyIn
                                      ? AppColors.successLight
                                      : AppColors.neutral200,
                                  icon: isCurrentlyIn
                                      ? Icons.login_rounded
                                      : Icons.logout_rounded,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.s3),
                            _infoLine(
                              'Họ và tên:',
                              _readerState?['fullName']?.toString() ?? '---',
                            ),
                            const SizedBox(height: 4),
                            _infoLine(
                              'Email:',
                              _readerState?['email']?.toString() ?? '---',
                            ),
                            if (_readerState?['latestLog'] is Map) ...[
                              const SizedBox(height: 4),
                              _infoLine(
                                'Lần cuối:',
                                _formatLatestLog(
                                  _readerState!['latestLog']
                                      as Map<String, dynamic>,
                                ),
                              ),
                            ],
                            const Divider(height: 24),
                            Text(
                              'Chọn nhanh lý do phổ biến:',
                              style: AppTextStyles.bodySm.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.charcoal700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _quickReasons.map((r) {
                                final active = _reasonCtrl.text.trim() == r;
                                return ActionChip(
                                  label: Text(r),
                                  backgroundColor: active
                                      ? AppColors.accent100
                                      : AppColors.neutral100,
                                  side: BorderSide(
                                    color: active
                                        ? AppColors.accent500
                                        : AppColors.neutral200,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _reasonCtrl.text = r;
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: AppSpacing.s3),
                            AppTextField(
                              controller: _reasonCtrl,
                              labelText: 'Lý do duyệt thủ công (*)',
                              hintText:
                                  'Nhập lý do cho phép bạn đọc ra/vào thủ công...',
                              prefixIcon: Icons.edit_note_rounded,
                            ),
                            if (_errorMsg != null) ...[
                              const SizedBox(height: AppSpacing.s3),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.dangerLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _errorMsg!,
                                  style: AppTextStyles.bodySm.copyWith(
                                    color: AppColors.danger,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.s4),
                            AppButton(
                              text: _submitting
                                  ? 'Đang xử lý...'
                                  : isCurrentlyIn
                                  ? 'Duyệt CHECK-OUT Thủ Công (Cho ra)'
                                  : 'Duyệt CHECK-IN Thủ Công (Cho vào)',
                              icon: isCurrentlyIn
                                  ? Icons.logout_rounded
                                  : Icons.login_rounded,
                              onPressed: _submitting
                                  ? null
                                  : _submitManualAccess,
                            ),
                          ],
                        ),
                      ),

                    if (_lastResult != null) ...[
                      const SizedBox(height: AppSpacing.s4),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Kết quả duyệt thủ công vừa thực hiện',
                                  style: AppTextStyles.h3.copyWith(
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.s2),
                            _infoLine(
                              'Hành động:',
                              _lastResult?['action']?.toString() ?? '---',
                            ),
                            _infoLine(
                              'Phương thức:',
                              _lastResult?['method']?.toString() ?? 'MANUAL',
                            ),
                            _infoLine(
                              'Trạng thái mới:',
                              _lastResult?['state'] == 'IN'
                                  ? 'Đang trong thư viện (IN)'
                                  : 'Đã ra ngoài (OUT)',
                            ),
                            _infoLine(
                              'Lý do ghi nhận:',
                              _lastResult?['reason']?.toString() ?? '---',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatLatestLog(Map<String, dynamic> log) {
    final action = log['action']?.toString() ?? '';
    final method = log['method']?.toString() ?? '';
    final rawTime = log['occurredAt']?.toString();
    String formattedTime = '';
    if (rawTime != null) {
      final dt = DateTime.tryParse(rawTime)?.toLocal();
      if (dt != null) {
        formattedTime = DateFormat('HH:mm dd/MM/yyyy').format(dt);
      }
    }
    return '$action ($method) lúc $formattedTime';
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.charcoal500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.charcoal900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
