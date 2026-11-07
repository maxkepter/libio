import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fe/core/network/api_client.dart';
import 'package:fe/features/library/data/services/schedule_api_service.dart';
import 'package:fe/features/library/domain/dtos/schedule_req.dart';
import 'package:fe/features/library/domain/models/library_schedule.dart';
import 'package:fe/features/library/presentation/providers/schedule_provider.dart';
import 'package:fe/features/library/presentation/screens/schedule_screen.dart';

class FakeScheduleApiService extends ScheduleApiService {
  List<WeeklyDayReq>? lastWeeklySaved;
  ScheduleCreateReq? lastCreatedSpecial;
  String? lastDeletedId;

  List<LibrarySchedule> weeklyList = const [
    LibrarySchedule(
      id: 'w-1',
      type: 'WEEKLY',
      dayOfWeek: 1,
      openTime: '07:00:00',
      closeTime: '21:00:00',
      isClosed: false,
    ),
    LibrarySchedule(
      id: 'w-0',
      type: 'WEEKLY',
      dayOfWeek: 0,
      isClosed: true,
    ),
  ];

  List<LibrarySchedule> specialList = const [
    LibrarySchedule(
      id: 'sp-1',
      type: 'SPECIAL',
      specificDate: '2026-09-02',
      isClosed: true,
      note: 'Nghỉ lễ Quốc Khánh 2/9',
    ),
  ];

  OpenStatus statusRes = const OpenStatus(
    isOpen: true,
    reason: 'OPEN',
    checkedAt: '2026-10-27T09:00:00',
  );

  FakeScheduleApiService() : super(ApiClient(baseUrl: 'http://localhost:3000'));

  @override
  Future<List<LibrarySchedule>> getWeekly() async => weeklyList;

  @override
  Future<List<LibrarySchedule>> getSpecial() async => specialList;

  @override
  Future<OpenStatus> getStatus(DateTime at) async => statusRes;

  @override
  Future<void> setWeekly(List<WeeklyDayReq> days) async {
    lastWeeklySaved = days;
  }

  @override
  Future<LibrarySchedule> createSchedule(ScheduleCreateReq req) async {
    lastCreatedSpecial = req;
    final created = LibrarySchedule(
      id: 'sp-2',
      type: req.type,
      specificDate: req.specificDate,
      openTime: req.openTime,
      closeTime: req.closeTime,
      isClosed: req.isClosed,
      note: req.note,
    );
    specialList = [...specialList, created];
    return created;
  }

  @override
  Future<void> deleteSchedule(String id) async {
    lastDeletedId = id;
    specialList = specialList.where((s) => s.id != id).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScheduleProvider Unit Tests', () {
    late FakeScheduleApiService fakeService;
    late ScheduleProvider provider;

    setUp(() {
      fakeService = FakeScheduleApiService();
      provider = ScheduleProvider(service: fakeService);
    });

    test('loadAll loads weekly, special schedules and current OpenStatus', () async {
      await provider.loadAll();

      expect(provider.isLoading, isFalse);
      expect(provider.weekly.length, 2);
      expect(provider.weeklyOf(1)?.openTime, '07:00:00');
      expect(provider.special.length, 1);
      expect(provider.special.first.note, 'Nghỉ lễ Quốc Khánh 2/9');
      expect(provider.status?.isOpen, isTrue);
      expect(provider.status?.reasonLabel, 'Đang mở cửa');
    });

    test('saveWeekly sends 7 days payload and refreshes status', () async {
      final days = [
        const WeeklyDayReq(
          dayOfWeek: 1,
          isClosed: false,
          openTime: '08:00',
          closeTime: '20:00',
        ),
      ];
      final ok = await provider.saveWeekly(days);
      expect(ok, isTrue);
      expect(fakeService.lastWeeklySaved?.first.openTime, '08:00');
    });

    test('createSpecial and deleteSpecial update special schedule list', () async {
      await provider.loadAll();
      final created = await provider.createSpecial(
        const ScheduleCreateReq(
          type: 'SPECIAL',
          specificDate: '2026-11-20',
          isClosed: true,
          note: 'Chào mừng ngày Nhà giáo Việt Nam 20/11',
        ),
      );
      expect(created, isTrue);
      expect(provider.special.length, 2);

      final deleted = await provider.deleteSpecial('sp-1');
      expect(deleted, isTrue);
      expect(fakeService.lastDeletedId, 'sp-1');
      expect(provider.special.length, 1);
    });
  });

  group('ScheduleScreen Widget & Flow Tests', () {
    testWidgets(
      'hiển thị trạng thái Thư viện đang MỞ CỬA, tab Giờ hàng tuần và tab Ngày đặc biệt',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeService = FakeScheduleApiService();
        final scheduleProvider = ScheduleProvider(service: fakeService);

        await tester.pumpWidget(
          ChangeNotifierProvider<ScheduleProvider>.value(
            value: scheduleProvider,
            child: const MaterialApp(home: ScheduleScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Kiểm tra banner trạng thái & các thứ trong tuần
        expect(find.text('Lịch mở cửa thư viện'), findsOneWidget);
        expect(find.text('Thư viện đang MỞ CỬA'), findsOneWidget);
        expect(find.text('Thứ Hai'), findsOneWidget);
        expect(find.text('Chủ nhật'), findsOneWidget);

        // Bấm nút "Lưu giờ hàng tuần"
        await tester.tap(find.text('Lưu giờ hàng tuần'));
        await tester.pumpAndSettle();
        expect(fakeService.lastWeeklySaved?.length, 7);

        // Chuyển sang tab "Ngày đặc biệt"
        await tester.tap(find.text('Ngày đặc biệt'));
        await tester.pumpAndSettle();

        expect(find.text('2026-09-02'), findsOneWidget);
        expect(find.text('Nghỉ lễ Quốc Khánh 2/9'), findsOneWidget);
      },
    );
  });
}
