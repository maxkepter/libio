import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fe/common/models/page_res.dart';
import 'package:fe/core/constants/api_constants.dart';
import 'package:fe/core/network/api_client.dart';
import 'package:fe/core/network/api_exception.dart';
import 'package:fe/core/storage/token_storage.dart';
import 'package:fe/features/access/data/services/access_api_service.dart';
import 'package:fe/features/access/presentation/screens/access_history_screen.dart';
import 'package:fe/features/access/presentation/screens/admin_report_screen.dart';
import 'package:fe/features/access/presentation/screens/library_closure_screen.dart';
import 'package:fe/features/access/presentation/screens/manual_access_screen.dart';
import 'package:fe/features/auth/data/services/auth_service.dart';
import 'package:fe/features/auth/domain/dtos/login_req.dart';
import 'package:fe/features/auth/domain/models/auth_res.dart';
import 'package:fe/features/auth/domain/models/role.dart';
import 'package:fe/features/auth/domain/models/user_res.dart';
import 'package:fe/features/auth/presentation/providers/auth_provider.dart';
import 'package:fe/features/user/data/services/user_api_service.dart';
import 'package:fe/features/user/domain/models/reader_res.dart';
import 'package:fe/features/user/presentation/providers/user_provider.dart';

class FakeTokenStorage implements TokenStorage {
  String? _at = 'fake_admin_jwt';
  String? _rt = 'fake_admin_rt';
  UserRes? _user = const UserRes(
    userId: 'admin-1',
    email: 'admin@libio.vn',
    role: UserRole.admin,
  );

  @override
  Future<void> clear() async {
    _at = null;
    _rt = null;
    _user = null;
  }

  @override
  Future<String?> getAccessToken() async => _at;

  @override
  Future<String?> getRefreshToken() async => _rt;

  @override
  Future<UserRes?> getUser() async => _user;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _at = accessToken;
    _rt = refreshToken;
  }

  @override
  Future<void> saveUser(UserRes user) async {
    _user = user;
  }
}

class FakeAuthService extends AuthService {
  FakeAuthService(super.apiClient);

  @override
  Future<AuthRes> login(LoginReq req) async {
    return const AuthRes(
      accessToken: 'fake_admin_jwt',
      refreshToken: 'fake_admin_rt',
      user: UserRes(
        userId: 'admin-1',
        email: 'admin@libio.vn',
        role: UserRole.admin,
      ),
    );
  }
}

class FakeApiClient extends ApiClient {
  String? lastGetPath;
  Map<String, dynamic>? lastGetQuery;
  String? lastPostPath;
  Map<String, dynamic>? lastPostBody;
  bool shouldThrow = false;

  Map<String, dynamic> readerStateResponse = {
    'readerId': 'reader-1',
    'fullName': 'Nguyễn Văn A',
    'email': 'nguyenvana@fpt.edu.vn',
    'state': 'OUT',
    'suggestedAction': 'CHECK_IN',
    'latestLog': {
      'action': 'CHECK_OUT',
      'method': 'QR',
      'occurredAt': '2026-10-27T08:00:00.000Z',
    },
  };

  Map<String, dynamic> manualActionResponse = {
    'message': 'Đã thực hiện CHECK_IN thủ công thành công.',
    'data': {
      'id': 'log-101',
      'readerId': 'reader-1',
      'action': 'CHECK_IN',
      'method': 'MANUAL',
      'state': 'IN',
      'reason': 'Quên mang điện thoại (không có QR)',
    },
  };

  Map<String, dynamic> accessLogsResponse = {
    'page': 1,
    'size': 20,
    'total': 2,
    'totalPages': 1,
    'data': [
      {
        'id': 'log-1',
        'readerId': 'reader-1',
        'readerName': 'Nguyễn Văn A',
        'readerEmail': 'nguyenvana@fpt.edu.vn',
        'action': 'CHECK_IN',
        'method': 'QR',
        'gateName': 'Cổng Chính A',
        'staffName': 'Thủ thư Minh',
        'reason': null,
        'occurredAt': '2026-10-27T07:30:00.000Z',
      },
      {
        'id': 'log-2',
        'readerId': 'reader-2',
        'readerName': 'Trần Thị B',
        'readerEmail': 'tranthib@fpt.edu.vn',
        'action': 'AUTO_CHECK_OUT',
        'method': 'MANUAL',
        'gateName': null,
        'staffName': 'Admin Phúc',
        'reason': 'Đóng cửa thư viện cuối ngày - Tự động check-out',
        'occurredAt': '2026-10-27T11:00:00.000Z',
      },
    ],
  };

  List<Map<String, dynamic>> activeReadersResponse = [
    {
      'readerId': 'reader-1',
      'fullName': 'Nguyễn Văn A',
      'email': 'nguyenvana@fpt.edu.vn',
      'method': 'QR',
      'checkedInAt': '2026-10-27T07:30:00.000Z',
    },
  ];

  Map<String, dynamic> triggerClosureResponse = {
    'message': 'Đã đóng cửa thư viện và tự động check-out 1 bạn đọc.',
    'autoCheckedOutCount': 1,
  };

  Map<String, dynamic> reportSummaryResponse = {
    'currentInsideCount': 4,
    'totalCheckIns': 25,
    'totalCheckOuts': 20,
    'totalAutoCheckOuts': 1,
    'totalTransactions': 46,
    'byMethod': {'QR': 30, 'FACE': 12, 'MANUAL': 4},
    'dailyStats': [
      {
        'date': '2026-10-27',
        'checkIns': 25,
        'checkOuts': 20,
        'autoCheckOuts': 1,
      },
    ],
  };

  FakeApiClient() : super(baseUrl: 'http://localhost:3000');

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool requiresAuth = false,
  }) async {
    lastGetPath = path;
    lastGetQuery = query;
    if (shouldThrow) {
      throw const ApiException('Lỗi kết nối máy chủ giả lập', statusCode: 500);
    }

    if (path.startsWith('/checkin-out/reader-state/')) {
      return readerStateResponse;
    }
    if (path == ApiConstants.accessLogs) {
      return accessLogsResponse;
    }
    if (path == ApiConstants.activeReaders) {
      return activeReadersResponse;
    }
    if (path == ApiConstants.reportSummary) {
      return reportSummaryResponse;
    }
    if (path == ApiConstants.readers) {
      return {
        'data': [
          {
            'id': 'reader-1',
            'fullName': 'Nguyễn Văn A',
            'phone': '0901234567',
            'user': {
              'userId': 'u-1',
              'email': 'nguyenvana@fpt.edu.vn',
              'role': 'READER',
            },
          },
          {
            'id': 'reader-2',
            'fullName': 'Trần Thị B',
            'phone': '0987654321',
            'user': {
              'userId': 'u-2',
              'email': 'tranthib@fpt.edu.vn',
              'role': 'READER',
            },
          },
        ],
        'total': 2,
        'req': {'page': 1, 'size': 10},
      };
    }
    return <String, dynamic>{};
  }

  @override
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) async {
    lastPostPath = path;
    lastPostBody = body;
    if (shouldThrow) {
      throw const ApiException('Thao tác thất bại giả lập', statusCode: 400);
    }

    if (path == ApiConstants.manualCheckInOut) {
      readerStateResponse = {
        ...readerStateResponse,
        'state': 'IN',
        'suggestedAction': 'CHECK_OUT',
      };
      return manualActionResponse;
    }
    if (path == ApiConstants.triggerClosure) {
      activeReadersResponse = [];
      return triggerClosureResponse;
    }
    return <String, dynamic>{};
  }
}

class FakeUserApiService extends UserApiService {
  FakeUserApiService(super.apiClient);

  @override
  Future<PageRes<ReaderRes>> getReaders({
    int page = 1,
    int size = 10,
    String? fullName,
    String? phone,
    String? dateOfBirth,
  }) async {
    final all = const [
      ReaderRes(
        id: 'reader-1',
        fullName: 'Nguyễn Văn A',
        phone: '0901234567',
        user: UserRes(
          userId: 'u-1',
          email: 'nguyenvana@fpt.edu.vn',
          role: UserRole.reader,
        ),
      ),
      ReaderRes(
        id: 'reader-2',
        fullName: 'Trần Thị B',
        phone: '0987654321',
        user: UserRes(
          userId: 'u-2',
          email: 'tranthib@fpt.edu.vn',
          role: UserRole.reader,
        ),
      ),
    ];
    final filtered = (fullName != null && fullName.isNotEmpty)
        ? all
              .where(
                (r) =>
                    r.fullName.toLowerCase().contains(fullName.toLowerCase()),
              )
              .toList()
        : all;

    return PageRes<ReaderRes>(
      data: filtered,
      total: filtered.length,
      page: page,
      size: size,
    );
  }
}

class FakeAdminAuthProvider extends AuthProvider {
  FakeAdminAuthProvider(ApiClient apiClient)
    : super(
        authService: FakeAuthService(apiClient),
        tokenStorage: FakeTokenStorage(),
      );

  @override
  UserRes? get currentUser => const UserRes(
    userId: 'admin-1',
    email: 'admin@libio.vn',
    role: UserRole.admin,
  );

  @override
  String? get accessToken => 'fake_admin_jwt';

  @override
  bool get isAuthenticated => true;
}

Widget _buildTestableScreen({
  required Widget child,
  required FakeApiClient apiClient,
}) {
  final authProvider = FakeAdminAuthProvider(apiClient);
  final userProvider = UserProvider(
    apiService: FakeUserApiService(apiClient),
  );

  return MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: apiClient),
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<UserProvider>.value(value: userProvider),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // =========================================================================
  // 1. UNIT TESTS: AccessApiService
  // =========================================================================
  group('AccessApiService Unit Tests', () {
    late FakeApiClient fakeClient;
    late AccessApiService service;

    setUp(() {
      fakeClient = FakeApiClient();
      service = AccessApiService(fakeClient);
    });

    test('getReaderAccessState returns reader state & suggestedAction', () async {
      final res = await service.getReaderAccessState('reader-1');
      expect(fakeClient.lastGetPath, '/checkin-out/reader-state/reader-1');
      expect(res['readerId'], 'reader-1');
      expect(res['state'], 'OUT');
      expect(res['suggestedAction'], 'CHECK_IN');
    });

    test('manualCheckInOut sends POST /checkin-out/manual with body', () async {
      final res = await service.manualCheckInOut(
        readerId: 'reader-1',
        reason: 'Quên mang điện thoại (không có QR)',
        action: 'CHECK_IN',
      );
      expect(fakeClient.lastPostPath, ApiConstants.manualCheckInOut);
      expect(fakeClient.lastPostBody?['readerId'], 'reader-1');
      expect(
        fakeClient.lastPostBody?['reason'],
        'Quên mang điện thoại (không có QR)',
      );
      expect(fakeClient.lastPostBody?['action'], 'CHECK_IN');
      expect(res['data']['state'], 'IN');
    });

    test('getAccessLogs forwards query filters (action, method, search, from, to)', () async {
      final res = await service.getAccessLogs(
        page: 2,
        size: 15,
        action: 'CHECK_IN',
        method: 'MANUAL',
        search: 'Nguyễn Văn A',
        from: '2026-10-27T00:00:00.000Z',
        to: '2026-10-27T23:59:59.999Z',
      );
      expect(fakeClient.lastGetPath, ApiConstants.accessLogs);
      expect(fakeClient.lastGetQuery?['page'], 2);
      expect(fakeClient.lastGetQuery?['size'], 15);
      expect(fakeClient.lastGetQuery?['action'], 'CHECK_IN');
      expect(fakeClient.lastGetQuery?['method'], 'MANUAL');
      expect(fakeClient.lastGetQuery?['search'], 'Nguyễn Văn A');
      expect(fakeClient.lastGetQuery?['from'], '2026-10-27T00:00:00.000Z');
      expect(res['total'], 2);
    });

    test('getActiveReaders returns list of active readers inside library', () async {
      final list = await service.getActiveReaders();
      expect(fakeClient.lastGetPath, ApiConstants.activeReaders);
      expect(list.length, 1);
      expect(list.first['fullName'], 'Nguyễn Văn A');
    });

    test('triggerClosure sends POST /access/closures/trigger', () async {
      final res = await service.triggerClosure(
        reason: 'Đóng cửa khẩn cấp',
        markTodayClosed: true,
      );
      expect(fakeClient.lastPostPath, ApiConstants.triggerClosure);
      expect(fakeClient.lastPostBody?['reason'], 'Đóng cửa khẩn cấp');
      expect(fakeClient.lastPostBody?['markTodayClosed'], isTrue);
      expect(res['autoCheckedOutCount'], 1);
    });

    test('getReportSummary fetches KPI summary with from/to query', () async {
      final res = await service.getReportSummary(
        from: '2026-10-20T00:00:00.000Z',
        to: '2026-10-27T23:59:59.999Z',
      );
      expect(fakeClient.lastGetPath, ApiConstants.reportSummary);
      expect(res['currentInsideCount'], 4);
      expect(res['totalCheckIns'], 25);
      expect(res['byMethod']['QR'], 30);
    });
  });

  // =========================================================================
  // 2. WIDGET & FLOW TESTS: ManualAccessScreen (Màn hình Ra/Vào Thủ Công)
  // =========================================================================
  group('ManualAccessScreen Widget & Flow Tests', () {
    late FakeApiClient fakeClient;

    setUp(() {
      fakeClient = FakeApiClient();
    });

    testWidgets(
      'chọn bạn đọc -> hiển thị trạng thái OUT -> chọn lý do nhanh -> bấm Duyệt CHECK-IN thành công',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final widget = _buildTestableScreen(
          apiClient: fakeClient,
          child: const ManualAccessScreen(),
        );
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        // Hiển thị tiêu đề & danh sách bạn đọc
        expect(find.text('Ra / Vào Thủ Công'), findsOneWidget);
        expect(find.text('1. Tìm và chọn bạn đọc'), findsOneWidget);
        expect(find.text('Nguyễn Văn A'), findsOneWidget);
        expect(find.text('Trần Thị B'), findsOneWidget);

        // Chạm chọn bạn đọc "Nguyễn Văn A"
        await tester.tap(find.text('Nguyễn Văn A'));
        await tester.pumpAndSettle();

        // Hiển thị Bước 2 với trạng thái "Đang ở NGOÀI (OUT)"
        expect(
          find.text('2. Xác nhận trạng thái & Lý do duyệt'),
          findsOneWidget,
        );
        expect(find.text('Đang ở NGOÀI (OUT)'), findsOneWidget);
        expect(
          find.text('Duyệt CHECK-IN Thủ Công (Cho vào)'),
          findsOneWidget,
        );

        // Chọn nhanh lý do chip "Quên mang điện thoại (không có QR)"
        await tester.tap(find.text('Quên mang điện thoại (không có QR)'));
        await tester.pumpAndSettle();

        // Bấm nút Duyệt CHECK-IN Thủ Công
        await tester.tap(find.text('Duyệt CHECK-IN Thủ Công (Cho vào)'));
        await tester.pumpAndSettle();

        // Kiểm tra API POST được gọi đúng dữ liệu và hiển thị thẻ kết quả
        expect(fakeClient.lastPostPath, ApiConstants.manualCheckInOut);
        expect(fakeClient.lastPostBody?['readerId'], 'reader-1');
        expect(
          fakeClient.lastPostBody?['reason'],
          'Quên mang điện thoại (không có QR)',
        );
        expect(
          find.text('Kết quả duyệt thủ công vừa thực hiện'),
          findsOneWidget,
        );
        expect(find.text('Đang TRONG thư viện (IN)'), findsOneWidget);
      },
    );
  });

  // =========================================================================
  // 3. WIDGET & FLOW TESTS: AccessHistoryScreen (Màn hình Lịch sử Ra/Vào)
  // =========================================================================
  group('AccessHistoryScreen Widget & Flow Tests', () {
    late FakeApiClient fakeClient;

    setUp(() {
      fakeClient = FakeApiClient();
    });

    testWidgets(
      'hiển thị bộ lọc lịch hôm nay, danh sách log và lọc theo PopupMenuButton',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final widget = _buildTestableScreen(
          apiClient: fakeClient,
          child: const AccessHistoryScreen(),
        );
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        // Kiểm tra tiêu đề, tổng số lượt và danh sách bản ghi
        expect(find.text('Lịch sử Ra / Vào Thư viện'), findsOneWidget);
        expect(find.text('Tổng: 2 lượt'), findsOneWidget);
        expect(find.text('Nguyễn Văn A'), findsOneWidget);
        expect(find.text('Trần Thị B'), findsOneWidget);
        expect(find.text('CHECK_IN (QR)'), findsOneWidget);
        expect(find.text('AUTO_CHECK_OUT (MANUAL)'), findsOneWidget);

        // Mở droplist "Mọi hành động" và chọn "Check-in (Vào)"
        await tester.tap(find.text('Mọi hành động'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Check-in (Vào)').last);
        await tester.pumpAndSettle();

        expect(fakeClient.lastGetQuery?['action'], 'CHECK_IN');

        // Mở droplist "Mọi phương thức" và chọn "Duyệt thủ công"
        await tester.tap(find.text('Mọi phương thức'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Duyệt thủ công').last);
        await tester.pumpAndSettle();

        expect(fakeClient.lastGetQuery?['method'], 'MANUAL');

        // Bấm nút lùi 1 ngày ("Ngày trước") -> xuất hiện nút "Về hôm nay"
        await tester.tap(find.byTooltip('Ngày trước'));
        await tester.pumpAndSettle();
        expect(find.text('Về hôm nay'), findsOneWidget);
      },
    );
  });

  // =========================================================================
  // 4. WIDGET & FLOW TESTS: LibraryClosureScreen (Đóng cửa & Auto Check-out)
  // =========================================================================
  group('LibraryClosureScreen Widget & Flow Tests', () {
    late FakeApiClient fakeClient;

    setUp(() {
      fakeClient = FakeApiClient();
    });

    testWidgets(
      'hiển thị danh sách bạn đọc đang IN và xác nhận Đóng cửa & Auto Check-out',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final widget = _buildTestableScreen(
          apiClient: fakeClient,
          child: const LibraryClosureScreen(),
        );
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        // Hiển thị số lượng đang trong thư viện: 1
        expect(find.text('Đóng cửa & Auto Check-out'), findsOneWidget);
        expect(find.text('Đang trong thư viện: 1'), findsOneWidget);
        expect(
          find.text('Bạn đọc hiện đang ở TRONG thư viện (1)'),
          findsOneWidget,
        );

        // Tích chọn đánh dấu đóng cửa ngày hôm nay trên Lịch đặc biệt
        await tester.tap(
          find.text(
            'Đánh dấu đóng cửa ngày hôm nay trên Lịch đặc biệt (Chặn check-in mới)',
          ),
        );
        await tester.pumpAndSettle();

        // Bấm nút "Đóng cửa & Tự động Check-out (1 người)"
        await tester.tap(
          find.text('Đóng cửa & Tự động Check-out (1 người)'),
        );
        await tester.pumpAndSettle();

        // Hộp thoại xác nhận xuất hiện
        expect(
          find.text('Xác nhận Đóng cửa & Auto Check-out'),
          findsOneWidget,
        );

        // Bấm "Xác nhận đóng cửa"
        await tester.tap(find.text('Xác nhận đóng cửa'));
        await tester.pumpAndSettle();

        // Đảm bảo API triggerClosure được gọi và danh sách đang IN về 0
        expect(fakeClient.lastPostPath, ApiConstants.triggerClosure);
        expect(fakeClient.lastPostBody?['markTodayClosed'], isTrue);
        expect(find.text('Đang trong thư viện: 0'), findsOneWidget);
      },
    );
  });

  // =========================================================================
  // 5. WIDGET & FLOW TESTS: AdminReportScreen (Báo cáo & Thống kê)
  // =========================================================================
  group('AdminReportScreen Widget & Flow Tests', () {
    late FakeApiClient fakeClient;

    setUp(() {
      fakeClient = FakeApiClient();
    });

    testWidgets(
      'hiển thị 4 thẻ KPI, tỷ lệ phương thức định danh và lọc theo khoảng thời gian',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final widget = _buildTestableScreen(
          apiClient: fakeClient,
          child: const AdminReportScreen(),
        );
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        // Kiểm tra 4 thẻ KPI hiển thị đúng số liệu từ reportSummaryResponse
        expect(find.text('Báo cáo & Thống kê'), findsOneWidget);
        expect(find.text('Đang trong thư viện'), findsOneWidget);
        expect(find.text('4'), findsOneWidget);
        expect(find.text('Tổng lượt Check-in'), findsOneWidget);
        expect(find.text('25'), findsOneWidget);
        expect(find.text('Tổng lượt Check-out'), findsOneWidget);
        expect(find.text('20'), findsOneWidget);
        expect(find.text('Tự động Check-out'), findsOneWidget);
        expect(find.text('1'), findsOneWidget);

        // Kiểm tra phần tỷ lệ theo phương thức định danh
        expect(
          find.text('Tỷ lệ theo Phương thức Định danh (Tổng: 46 lượt)'),
          findsOneWidget,
        );
        expect(find.text('Mã QR (QR Code)'), findsOneWidget);
        expect(find.text('Khuôn mặt (Face Biometric)'), findsOneWidget);
        expect(find.text('Duyệt thủ công (Manual Access)'), findsOneWidget);

        // Chuyển bộ lọc sang "7 ngày qua"
        await tester.tap(find.text('7 ngày qua'));
        await tester.pumpAndSettle();

        expect(fakeClient.lastGetPath, ApiConstants.reportSummary);
        expect(find.text('Trong 7 ngày'), findsOneWidget);
      },
    );
  });
}
