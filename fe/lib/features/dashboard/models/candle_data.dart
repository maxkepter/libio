import 'package:fe/features/dashboard/models/check_in_out_statistic_model.dart';

class CandleData {
  final DateTime startDate;
  final int intervalMin;
  final int open; // Ước tính lượng người đầu kỳ
  final int close; // Ước tính lượng người cuối kỳ
  final int high; // peakPeopleCount
  final int low; // lowestPeopleCount
  final int checkInCount;
  final int checkOutCount;

  const CandleData({
    required this.startDate,
    required this.intervalMin,
    required this.open,
    required this.close,
    required this.high,
    required this.low,
    required this.checkInCount,
    required this.checkOutCount,
  });

  bool get isBullish => close >= open;
  int get netChange => checkInCount - checkOutCount;
}

/// Thuật toán chuyển đổi danh sách CheckInOutStatisticModel thành chuỗi CandleData liên tục
List<CandleData> computeCandleData(List<CheckInOutStatisticModel> stats) {
  if (stats.isEmpty) return const [];

  // Sắp xếp tăng dần theo startDate
  final sortedStats = List<CheckInOutStatisticModel>.from(stats)
    ..sort((a, b) => a.startDate.compareTo(b.startDate));

  final List<CandleData> result = [];

  for (int i = 0; i < sortedStats.length; i++) {
    final item = sortedStats[i];
    final high = item.peakPeopleCount;
    final low = item.lowestPeopleCount;
    final net = item.checkInCount - item.checkOutCount;

    int open;
    if (i == 0) {
      open = low;
    } else {
      final prevClose = result[i - 1].close;
      open = prevClose.clamp(low, high);
    }

    final close = (open + net).clamp(low, high);

    result.add(
      CandleData(
        startDate: item.startDate,
        intervalMin: item.intervalMin,
        open: open,
        close: close,
        high: high,
        low: low,
        checkInCount: item.checkInCount,
        checkOutCount: item.checkOutCount,
      ),
    );
  }

  return result;
}
