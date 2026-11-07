import 'package:flutter/foundation.dart';
import '../models/check_in_out_statistic_model.dart';
import '../models/occupancy_model.dart';
import '../services/dashboard_api_service.dart';

enum DashboardTimeFilter {
  today('Hôm nay', 0),
  last24Hours('24h qua', 1),
  last7Days('7 ngày qua', 7),
  last30Days('30 ngày qua', 30),
  custom('Tùy chỉnh', -1);

  final String label;
  final int days;

  const DashboardTimeFilter(this.label, this.days);
}

class DashboardProvider extends ChangeNotifier {
  final DashboardApiService _apiService;

  OccupancyModel? _occupancy;
  List<CheckInOutStatisticModel> _stats = [];

  bool _isLoadingOccupancy = false;
  bool _isLoadingStats = false;
  String? _errorMessage;

  DashboardTimeFilter _selectedFilter = DashboardTimeFilter.today;
  int _selectedIntervalMin = 60;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  DashboardProvider({required DashboardApiService apiService})
    : _apiService = apiService;

  OccupancyModel? get occupancy => _occupancy;
  List<CheckInOutStatisticModel> get stats => _stats;
  bool get isLoading => _isLoadingOccupancy || _isLoadingStats;
  bool get isLoadingOccupancy => _isLoadingOccupancy;
  bool get isLoadingStats => _isLoadingStats;
  String? get errorMessage => _errorMessage;

  DashboardTimeFilter get selectedFilter => _selectedFilter;
  int get selectedIntervalMin => _selectedIntervalMin;
  DateTime? get customStartDate => _customStartDate;
  DateTime? get customEndDate => _customEndDate;

  int get totalCheckIn =>
      _stats.fold(0, (sum, item) => sum + item.checkInCount);

  int get totalCheckOut =>
      _stats.fold(0, (sum, item) => sum + item.checkOutCount);

  int get peakPeople => _stats.isEmpty
      ? 0
      : _stats.map((e) => e.peakPeopleCount).reduce((a, b) => a > b ? a : b);

  int get lowestPeople => _stats.isEmpty
      ? 0
      : _stats.map((e) => e.lowestPeopleCount).reduce((a, b) => a < b ? a : b);

  Future<void> init() async {
    await Future.wait([fetchOccupancy(), fetchStatistics()]);
  }

  Future<void> refresh() async {
    await init();
  }

  Future<void> fetchOccupancy() async {
    _isLoadingOccupancy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _occupancy = await _apiService.getOccupancy();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('ApiException: ', '');
    } finally {
      _isLoadingOccupancy = false;
      notifyListeners();
    }
  }

  (DateTime, DateTime, int) _resolveDateRangeAndInterval() {
    final now = DateTime.now();

    switch (_selectedFilter) {
      case DashboardTimeFilter.today:
        final start = DateTime(now.year, now.month, now.day, 0, 0, 0);
        return (start, now, _selectedIntervalMin);

      case DashboardTimeFilter.last24Hours:
        final start = now.subtract(const Duration(hours: 24));
        return (start, now, _selectedIntervalMin);

      case DashboardTimeFilter.last7Days:
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6));
        return (start, now, _selectedIntervalMin);

      case DashboardTimeFilter.last30Days:
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 29));
        return (start, now, _selectedIntervalMin);

      case DashboardTimeFilter.custom:
        final start =
            _customStartDate ??
            DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(const Duration(days: 7));
        final end = _customEndDate != null && _customEndDate!.isBefore(now)
            ? _customEndDate!
            : now;
        return (start, end, _selectedIntervalMin);
    }
  }

  Future<void> fetchStatistics() async {
    _isLoadingStats = true;
    _errorMessage = null;
    notifyListeners();

    final (start, end, interval) = _resolveDateRangeAndInterval();

    try {
      _stats = await _apiService.getCheckInOutStatistic(
        startDate: start,
        endDate: end,
        intervalMin: interval,
      );
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('ApiException: ', '');
    } finally {
      _isLoadingStats = false;
      notifyListeners();
    }
  }

  void changeFilter(DashboardTimeFilter filter) {
    if (_selectedFilter == filter) return;
    _selectedFilter = filter;
    if (filter == DashboardTimeFilter.last30Days && _selectedIntervalMin < 60) {
      _selectedIntervalMin = 1440;
    }
    fetchStatistics();
  }

  void setIntervalMin(int intervalMin) {
    if (_selectedIntervalMin == intervalMin) return;
    _selectedIntervalMin = intervalMin;
    fetchStatistics();
  }

  void setCustomRange(DateTime start, DateTime end) {
    _selectedFilter = DashboardTimeFilter.custom;
    _customStartDate = start;
    _customEndDate = end;
    fetchStatistics();
  }
}
