import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:b1_test_app/support_app_screen.dart';

void main() {
  test('UPI destination matches the publisher supplied QR', () {
    expect(SupportDestinations.upiId, 'jaglanpriyanka23@okicici');
    expect(SupportDestinations.upiUri,
      'upi://pay?pa=jaglanpriyanka23@okicici&pn=priyanka%20jaglan&aid=uGICAgIDtw-zpCg');
  });

  test('Binance destination and iOS contact are preserved', () {
    expect(SupportDestinations.binanceUrl,
      'https://app.binance.com/uni-qr/GMmEhqkN');
    expect(SupportDestinations.iosSupportEmail, 'prihul.rtk@gmail.com');
  });

  testWidgets('Support screen keeps one QR visible and swaps destinations',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SupportAppScreen()),
    );
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Donate using UPI'), findsOneWidget);
    expect(find.text('Help keep learning free'), findsOneWidget);
    expect(find.text(SupportDestinations.upiId), findsOneWidget);

    await tester.tap(find.text('Crypto'));
    await tester.pump();
    expect(find.text('Donate using Binance Pay'), findsOneWidget);
    expect(find.text(SupportDestinations.binanceRecipient), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
  });
}
