import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/dashboard/models/check_in_out_statistic_model.dart';
import 'package:fe/features/dashboard/widgets/candlestick_chart_view.dart';
import 'package:fe/features/dashboard/widgets/check_in_out_chart.dart';

void main() {
  testWidgets(
    'CheckInOutChart displays all items, supports scrolling and mode toggle',
    (tester) async {
      // Generate 30 items (> 15 items)
      final baseTime = DateTime.utc(2026, 10, 27, 8, 0, 0);
      final stats = List.generate(30, (i) {
        return CheckInOutStatisticModel(
          startDate: baseTime.add(Duration(hours: i)),
          intervalMin: 60,
          checkInCount: 10 + i,
          checkOutCount: 5 + (i % 3),
          peakPeopleCount: 20 + i,
          lowestPeopleCount: 5,
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CheckInOutChart(stats: stats, isLoading: false),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Default mode: Bar chart
      expect(
        find.text('Biểu đồ biến động Check-in / Check-out'),
        findsOneWidget,
      );
      expect(
        find.text('30 mốc • Kéo chuột/vuốt ngang để xem thêm'),
        findsOneWidget,
      );

      // Verify Legends in Bar Mode
      expect(find.text('Check-in'), findsOneWidget);
      expect(find.text('Check-out'), findsOneWidget);

      // Verify left and right scroll navigation buttons exist
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      // Scroll right via button tap
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();

      // Drag horizontally directly on chart
      final horizontalScrollable = find.byWidgetPredicate(
        (w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      );
      expect(horizontalScrollable, findsOneWidget);

      await tester.drag(horizontalScrollable, const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Toggle to Candlestick Mode
      final candleToggle = find.byTooltip('Biểu đồ nến');
      expect(candleToggle, findsOneWidget);
      await tester.tap(candleToggle);
      await tester.pumpAndSettle();

      // Verify Title & Legends changed in Candlestick Mode
      expect(find.text('Biểu đồ nến biến động số người'), findsOneWidget);
      expect(find.text('Tăng'), findsOneWidget);
      expect(find.text('Giảm'), findsOneWidget);
      expect(find.text('Đỉnh/Đáy'), findsOneWidget);

      // CandlestickChartView should now be rendered
      expect(find.byType(CandlestickChartView), findsOneWidget);

      // Scroll buttons still functional in candlestick mode
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();

      // Toggle back to Bar Mode
      final barToggle = find.byTooltip('Biểu đồ cột');
      expect(barToggle, findsOneWidget);
      await tester.tap(barToggle);
      await tester.pumpAndSettle();

      expect(
        find.text('Biểu đồ biến động Check-in / Check-out'),
        findsOneWidget,
      );
      expect(find.text('Check-in'), findsOneWidget);

      // Verify right Y-axis unit exists for bar chart
      expect(find.text('lượt'), findsOneWidget);

      // Verify detail list expandable toggle exists and works
      final expandBtn = find.text('Xem tất cả 30 mốc');
      expect(expandBtn, findsOneWidget);
      await tester.ensureVisible(expandBtn);
      await tester.tap(expandBtn);
      await tester.pumpAndSettle();

      expect(find.text('Thu gọn danh sách'), findsOneWidget);
    },
  );
}
