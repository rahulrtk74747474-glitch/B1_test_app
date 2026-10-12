import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Voluntary creator tips only: 100% sent directly to the chosen recipient.
/// These values match the two QR codes supplied by the app publisher.
class DonationDestinations {
  static const upiId = 'jaglanpriyanka23@okicici';
  static const upiName = 'priyanka jaglan';
  static const upiPaymentUri =
      'upi://pay?pa=jaglanpriyanka23@okicici&pn=priyanka%20jaglan&aid=uGICAgIDtw-zpCg';
  static const binanceRecipient = 'User-9069d';
  static const binancePaymentUrl = 'https://app.binance.com/uni-qr/GMmEhqkN';
}

enum DonationMethod { upi, binance }

/// Standalone voluntary donation page. No question, ad or review behavior is
/// touched. The app has no payment SDK and never processes donor credentials.
class SupportPoliceB1Screen extends StatefulWidget {
  const SupportPoliceB1Screen({super.key});

  @override
  State<SupportPoliceB1Screen> createState() => _SupportPoliceB1ScreenState();
}

class _SupportPoliceB1ScreenState extends State<SupportPoliceB1Screen> {
  DonationMethod selectedMethod = DonationMethod.upi;

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  Future<void> _open(String destination) async {
    try {
      final launched = await launchUrl(
        Uri.parse(destination),
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (_) {
      // App is optional; the QR can still be scanned from another device.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Payment app unavailable. You can scan the QR on another device.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isUpi = selectedMethod == DonationMethod.upi;
    final scheme = Theme.of(context).colorScheme;
    final paymentData = isUpi
        ? DonationDestinations.upiPaymentUri
        : DonationDestinations.binancePaymentUrl;
    final destinationLabel = isUpi
        ? DonationDestinations.upiId
        : DonationDestinations.binanceRecipient;

    return Scaffold(
      appBar: AppBar(title: const Text('Support Police B1 Test')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                const Icon(Icons.volunteer_activism_outlined, size: 48),
                const SizedBox(height: 12),
                Text('Help keep Police B1 Test free',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                const Text(
                  'Optional tips support the developer in expanding the question '
                  'bank and improving the free app for everyone.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                SegmentedButton<DonationMethod>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: DonationMethod.upi,
                      icon: Icon(Icons.account_balance_outlined),
                      label: Text('UPI'),
                    ),
                    ButtonSegment(
                      value: DonationMethod.binance,
                      icon: Icon(Icons.currency_bitcoin_outlined),
                      label: Text('Crypto'),
                    ),
                  ],
                  selected: {selectedMethod},
                  onSelectionChanged: (value) =>
                      setState(() => selectedMethod = value.first),
                ),
                const SizedBox(height: 14),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
                    child: Column(children: [
                      Text(isUpi ? 'UPI contribution' : 'Binance Pay contribution',
                        style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(isUpi
                          ? 'Scan using a compatible UPI payment app'
                          : 'Scan using the Binance app',
                        textAlign: TextAlign.center),
                      const SizedBox(height: 18),
                      // Deterministic QRs reproduce the publisher's exact
                      // decoded QR payloads and render without internet.
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: QrImageView(
                          data: paymentData,
                          version: QrVersions.auto,
                          size: 252,
                          backgroundColor: Colors.white,
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                          padding: const EdgeInsets.all(6),
                          gapless: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SelectableText(destinationLabel,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                      if (isUpi) ...[
                        const SizedBox(height: 4),
                        Text('UPI account name: ${DonationDestinations.upiName}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(width: double.infinity, child: FilledButton.icon(
                        icon: const Icon(Icons.open_in_new),
                        label: Text(isUpi ? 'Open UPI app' : 'Open Binance Pay'),
                        onPressed: () => _open(paymentData),
                      )),
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: OutlinedButton.icon(
                        icon: const Icon(Icons.copy),
                        label: Text(isUpi ? 'Copy UPI ID' : 'Copy payment link'),
                        onPressed: () => _copy(isUpi
                            ? DonationDestinations.upiId : paymentData,
                          isUpi ? 'UPI ID' : 'Payment link'),
                      )),
                    ]),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Donations are completely voluntary. Everyone gets the same '
                  'questions and app features, whether or not they contribute. '
                  'No perks, priority access or digital items are provided in '
                  'return. Payments go directly to the recipient through the '
                  'UPI or Binance app; Police B1 Test does not process them. '
                  'Always check the recipient in your payment app before sending.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
