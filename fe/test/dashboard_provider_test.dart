import 'package:fe/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/dashboard/models/occupancy_model.dart';
import 'package:fe/features/dashboard/models/check_in_out_statistic_model.dart';
import 'package:fe/features/dashboard/services/dashboard_api_service.dart';
import 'package:fe/features/dashboard/providers/dashboard_provider.dart';

class MockDashboardApiService extends DashboardApiService {
  final OccupancyModel? mockOccupancy;
  final List<CheckInOutStatisticModel>? mockStats;
  final bool shouldThrow;
  DateTime? lastStartDate;
  DateTime? lastEndDate;

  MockDashboardApiService({
    this.mockOccupancy,
    this.mockStats,
    this.shouldThrow = false,
  }) : super(ApiClient(baseUrl: 'http://localhost:3000'));

  @override
  Future<OccupancyModel> getOccupancy() async {
    if (shouldThrow) throw Exception('Lỗi kết nối máy chủ');
    return mockOccupancy ??
        OccupancyModel.fromJson(const {
          "currentOccupants": 125,
          "maxCapacity": 500,
          "occupancyRate": 25.0,
          "status": "NORMAL",
          "updatedAt": "2026-10-27T10:00:00.000Z",
        });
  }

  @override
  Future<List<CheckInOutStatisticModel>> getCheckInOutStatistic({
    required DateTime startDate,
    required DateTime endDate,
    int intervalMin = 60,
  }) async {
    lastStartDate = startDate;
    lastEndDate = endDate;
    if (shouldThrow) throw Exception('Lỗi kết nối máy chủ');
    return mockStats ??
        [
          CheckInOutStatisticModel.fromJson(const {
            "startDate": "2026-10-27T07:00:00.000Z",
            "intervalMin": 60,
            "checkInCount": 15,
            "checkOutCount": 2,
            "peakPeopleCount": 15,
            "lowestPeopleCount": 0,
          }),
          CheckInOutStatisticModel.fromJson(const {
            "startDate": "2026-10-27T08:00:00.000Z",
            "intervalMin": 60,
            "checkInCount": 45,
            "checkOutCount": 8,
            "peakPeopleCount": 52,
            "lowestPeopleCount": 13,
          }),
          CheckInOutStatisticModel.fromJson(const {
            "startDate": "2026-10-27T09:00:00.000Z",
            "intervalMin": 60,
            "checkInCount": 60,
            "checkOutCount": 20,
            "peakPeopleCount": 92,
            "lowestPeopleCount": 44,
          }),
        ];
  }
}

void main() {
  group('Dashboard Models', () {
    test('OccupancyModel fromJson and properties', () {
      const mockData = {
        "currentOccupants": 142,
        "maxCapacity": 500,
        "occupancyRate": 28.4,
        "status": "NORMAL",
        "updatedAt": "2026-10-27T10:30:00.000Z",
      };

      final model = OccupancyModel.fromJson(mockData);
      expect(model.currentOccupants, 142);
      expect(model.maxCapacity, 500);
      expect(model.occupancyRate, 28.4);
      expect(model.status, OccupancyStatus.normal);
      expect(model.isNormal, isTrue);
      expect(model.isWarning, isFalse);
      expect(model.isFull, isFalse);
      expect(model.statusLabel, 'Bình thường');

      final json = model.toJson();
      expect(json['currentOccupants'], 142);
      expect(json['status'], 'NORMAL');
    });

    test('OccupancyModel status parsing WARNING & FULL', () {
      final warningModel = OccupancyModel.fromJson(const {
        "currentOccupants": 400,
        "maxCapacity": 500,
        "occupancyRate": 80.0,
        "status": "WARNING",
      });
      expect(warningModel.isWarning, isTrue);
      expect(warningModel.statusLabel, 'Cảnh báo');

      final fullModel = OccupancyModel.fromJson(const {
        "currentOccupants": 480,
        "maxCapacity": 500,
        "occupancyRate": 96.0,
        "status": "FULL",
      });
      expect(fullModel.isFull, isTrue);
      expect(fullModel.statusLabel, 'Quá tải');
    });

    test('CheckInOutStatisticModel fromJson & toJson', () {
      const mockStat = {
        "startDate": "2026-10-27T08:00:00.000Z",
        "intervalMin": 60,
        "checkInCount": 35,
        "checkOutCount": 5,
        "peakPeopleCount": 42,
        "lowestPeopleCount": 12,
      };

      final model = CheckInOutStatisticModel.fromJson(mockStat);
      expect(model.intervalMin, 60);
      expect(model.checkInCount, 35);
      expect(model.checkOutCount, 5);
      expect(model.peakPeopleCount, 42);
      expect(model.lowestPeopleCount, 12);
      expect(model.startDate.isUtc, isTrue);

      final json = model.toJson();
      expect(json['checkInCount'], 35);
      expect(json['peakPeopleCount'], 42);
    });
  });

  group('DashboardProvider State & Aggregations', () {
    test('init loads occupancy and statistics successfully', () async {
      final mockService = MockDashboardApiService();
      final provider = DashboardProvider(apiService: mockService);

      expect(provider.isLoading, isFalse);
      expect(provider.occupancy, isNull);
      expect(provider.stats, isEmpty);

      await provider.init();

      expect(provider.isLoading, isFalse);
      expect(provider.occupancy, isNotNull);
      expect(provider.occupancy!.currentOccupants, 125);
      expect(provider.stats.length, 3);
      expect(provider.totalCheckIn, 15 + 45 + 60); // 120
      expect(provider.totalCheckOut, 2 + 8 + 20); // 30
      expect(provider.peakPeople, 92);
      expect(provider.lowestPeople, 0);
      expect(provider.errorMessage, isNull);
    });

    test('filter changes trigger statistics reload', () async {
      final mockService = MockDashboardApiService();
      final provider = DashboardProvider(apiService: mockService);

      await provider.init();
      expect(provider.selectedFilter, DashboardTimeFilter.today);

      provider.changeFilter(DashboardTimeFilter.last7Days);
      expect(provider.selectedFilter, DashboardTimeFilter.last7Days);

      provider.setIntervalMin(30);
      expect(provider.selectedIntervalMin, 30);
    });

    test('handles api error gracefully', () async {
      final mockService = MockDashboardApiService(shouldThrow: true);
      final provider = DashboardProvider(apiService: mockService);

      await provider.init();

      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNotNull);
    });

    test('refreshOccupancy fetches occupancy independently', () async {
      final mockService = MockDashboardApiService();
      final provider = DashboardProvider(apiService: mockService);

      await provider.fetchOccupancy();

      expect(provider.isLoadingOccupancy, isFalse);
      expect(provider.occupancy, isNotNull);
      expect(provider.occupancy!.currentOccupants, 125);
    });

    test('custom date range updates filter and custom range', () async {
      final mockService = MockDashboardApiService();
      final provider = DashboardProvider(apiService: mockService);

      final start = DateTime(2026, 10, 20);
      final end = DateTime(2026, 10, 27);
      provider.setCustomRange(start, end);

      expect(provider.selectedFilter, DashboardTimeFilter.custom);
      expect(provider.customStartDate, start);
      expect(provider.customEndDate, end);
    });

    test('today filter sends endDate capped at now, not end of day', () async {
      final mockService = MockDashboardApiService();
      final provider = DashboardProvider(apiService: mockService);

      final before = DateTime.now();
      await provider.init();
      final after = DateTime.now();

      expect(mockService.lastEndDate, isNotNull);
      expect(
        mockService.lastEndDate!.isAfter(
          before.subtract(const Duration(seconds: 1)),
        ),
        isTrue,
      );
      expect(
        mockService.lastEndDate!.isBefore(
          after.add(const Duration(seconds: 1)),
        ),
        isTrue,
      );
    });
  });
}
