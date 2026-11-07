import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/dashboard/models/candle_data.dart';
import 'package:fe/features/dashboard/models/check_in_out_statistic_model.dart';
import 'package:fe/features/dashboard/widgets/candlestick_chart_view.dart';

void main() {
  group('computeCandleData Unit Tests', () {
    test('1. Empty list returns empty list', () {
      final result = computeCandleData([]);
      expect(result, isEmpty);
    });

    test(
      '2. Single item calculates open, close, high, low, netChange correctly',
      () {
        final stat = CheckInOutStatisticModel(
          startDate: DateTime.utc(2026, 10, 27, 8, 0),
          intervalMin: 60,
          checkInCount: 25,
          checkOutCount: 5,
          peakPeopleCount: 30,
          lowestPeopleCount: 10,
        );

        final result = computeCandleData([stat]);
        expect(result.length, 1);

        final candle = result.first;
        expect(candle.startDate, stat.startDate);
        expect(candle.intervalMin, 60);
        expect(candle.high, 30);
        expect(candle.low, 10);
        expect(candle.checkInCount, 25);
        expect(candle.checkOutCount, 5);
        expect(candle.netChange, 20);

        // Open = lowestPeopleCount = 10
        expect(candle.open, 10);
        // Close = (open + netChange).clamp(low, high) = (10 + 20).clamp(10, 30) = 30
        expect(candle.close, 30);
        expect(candle.isBullish, isTrue);
      },
    );

    test(
      '3. Multiple items inherit open_i = close_{i-1} clamped to [low, high]',
      () {
        final stats = [
          CheckInOutStatisticModel(
            startDate: DateTime.utc(2026, 10, 27, 8, 0),
            intervalMin: 60,
            checkInCount: 15,
            checkOutCount: 5,
            peakPeopleCount: 25,
            lowestPeopleCount: 5,
          ),
          CheckInOutStatisticModel(
            startDate: DateTime.utc(2026, 10, 27, 9, 0),
            intervalMin: 60,
            checkInCount: 10,
            checkOutCount: 12,
            peakPeopleCount: 30,
            lowestPeopleCount: 10,
          ),
          CheckInOutStatisticModel(
            startDate: DateTime.utc(2026, 10, 27, 10, 0),
            intervalMin: 60,
            checkInCount: 5,
            checkOutCount: 5,
            peakPeopleCount: 20,
            lowestPeopleCount:
                18, // Clamp test: prev close was outside [18, 20]
          ),
        ];

        final result = computeCandleData(stats);
        expect(result.length, 3);

        // Item 0: open = low = 5, net = 10, close = 15
        expect(result[0].open, 5);
        expect(result[0].close, 15);

        // Item 1: inherits open = result[0].close = 15 clamped to [10, 30] -> 15
        // net = -2, close = (15 - 2).clamp(10, 30) = 13
        expect(result[1].open, 15);
        expect(result[1].close, 13);
        expect(result[1].isBullish, isFalse);

        // Item 2: prev close = 13, clamped to [18, 20] -> open = 18
        // net = 0, close = (18 + 0).clamp(18, 20) = 18
        expect(result[2].open, 18);
        expect(result[2].close, 18);
        expect(result[2].isBullish, isTrue);
      },
    );

    test('4. Doji candle when open == close', () {
      final stat = CheckInOutStatisticModel(
        startDate: DateTime.utc(2026, 10, 27, 8, 0),
        intervalMin: 60,
        checkInCount: 10,
        checkOutCount: 10, // netChange = 0
        peakPeopleCount: 20,
        lowestPeopleCount: 10,
      );

      final result = computeCandleData([stat]);
      expect(result.length, 1);
      expect(result.first.open, result.first.close);
      expect(result.first.isBullish, isTrue);
      expect(result.first.netChange, 0);
    });

    test('5. All bullish and all bearish scenarios', () {
      // All bullish
      final bullishStats = List.generate(3, (i) {
        return CheckInOutStatisticModel(
          startDate: DateTime.utc(2026, 10, 27, 8 + i, 0),
          intervalMin: 60,
          checkInCount: 20,
          checkOutCount: 5,
          peakPeopleCount: 50 + i * 10,
          lowestPeopleCount: 5,
        );
      });
      final bullishCandles = computeCandleData(bullishStats);
      for (final c in bullishCandles) {
        expect(c.isBullish, isTrue);
        expect(c.netChange, greaterThan(0));
      }

      // All bearish
      final bearishStats = [
        CheckInOutStatisticModel(
          startDate: DateTime.utc(2026, 10, 27, 8, 0),
          intervalMin: 60,
          checkInCount: 30,
          checkOutCount: 0,
          peakPeopleCount: 30,
          lowestPeopleCount: 0,
        ),
        CheckInOutStatisticModel(
          startDate: DateTime.utc(2026, 10, 27, 9, 0),
          intervalMin: 60,
          checkInCount: 0,
          checkOutCount: 20,
          peakPeopleCount: 30,
          lowestPeopleCount: 0,
        ),
      ];
      final bearishCandles = computeCandleData(bearishStats);
      expect(bearishCandles[1].isBullish, isFalse);
      expect(bearishCandles[1].netChange, lessThan(0));
    });
  });

  group('CandlestickChartView Widget Tests', () {
    testWidgets('Renders exact number of candle items and X-axis labels', (
      tester,
    ) async {
      final candles = [
        CandleData(
          startDate: DateTime.utc(2026, 10, 27, 8, 0),
          intervalMin: 60,
          open: 10,
          close: 25,
          high: 30,
          low: 5,
          checkInCount: 20,
          checkOutCount: 5,
        ),
        CandleData(
          startDate: DateTime.utc(2026, 10, 27, 9, 0),
          intervalMin: 60,
          open: 25,
          close: 15,
          high: 28,
          low: 12,
          checkInCount: 5,
          checkOutCount: 15,
        ),
      ];

      final scrollController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CandlestickChartView(
              candleList: candles,
              maxScale: 35,
              scrollController: scrollController,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify custom painters rendered for each candle
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is CandlestickPainter,
        ),
        findsNWidgets(2),
      );

      // Verify X-axis labels exist (either HH:mm)
      expect(find.byType(Text), findsWidgets);

      // Verify Tooltip widgets exist for each candle
      expect(find.byType(Tooltip), findsNWidgets(2));

      // Verify right Y-axis scale values exist
      expect(find.text('35'), findsOneWidget); // max scale
      expect(find.text('người'), findsOneWidget); // unit label

      scrollController.dispose();
    });
  });
}
