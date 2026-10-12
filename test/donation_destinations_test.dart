import 'package:flutter_test/flutter_test.dart';
import 'package:b1_test_app/support_police_b1_screen.dart';

void main() {
  test('UPI QR contains the publisher-supplied recipient and does not set amount', () {
    final uri = Uri.parse(DonationDestinations.upiPaymentUri);
    expect(uri.scheme, 'upi');
    expect(uri.host, 'pay');
    expect(uri.queryParameters['pa'], DonationDestinations.upiId);
    expect(uri.queryParameters['pn'], DonationDestinations.upiName);
    expect(uri.queryParameters.containsKey('am'), false);
  });

  test('Binance QR opens the supplied Binance Pay payment link', () {
    final uri = Uri.parse(DonationDestinations.binancePaymentUrl);
    expect(uri.scheme, 'https');
    expect(uri.host, 'app.binance.com');
    expect(uri.path, '/uni-qr/GMmEhqkN');
  });
}
