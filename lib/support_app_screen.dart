import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Addresses reproduced from the user's supplied payment QR codes.
/// No donation goes through the app's own backend.
class SupportDestinations {
  static const upiId = 'jaglanpriyanka23@okicici';
  static const upiName = 'priyanka jaglan';
  static const upiUri =
      'upi://pay?pa=jaglanpriyanka23@okicici&pn=priyanka%20jaglan&aid=uGICAgIDtw-zpCg';
  static const binanceRecipient = 'User-9069d';
  static const binanceUrl = 'https://app.binance.com/uni-qr/GMmEhqkN';
  static const iosSupportEmail = 'prihul.rtk@gmail.com';
}

enum SupportMethod { upi, binance }

/// A standalone, optional support page. No ads or prompts during study.
/// Scannable QRs work offline, without a wallet or payment SDK in this app.
class SupportAppScreen extends StatefulWidget {
  const SupportAppScreen({super.key});

  @override
  State<SupportAppScreen> createState() => _SupportAppScreenState();
}

class _SupportAppScreenState extends State<SupportAppScreen> {
  SupportMethod method = SupportMethod.upi;

  Future<void> copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  Future<void> openExternal(String url, String fallback) async {
    try {
      final launched = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
      if (launched) return;
    } catch (_) {
      // The corresponding payment/email app may not be installed.
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(fallback),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final upi = method == SupportMethod.upi;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final paymentQr = upi
        ? SupportDestinations.upiUri : SupportDestinations.binanceUrl;
    final destination = upi
        ? SupportDestinations.upiId : SupportDestinations.binanceRecipient;

    return Scaffold(
      appBar: AppBar(title: const Text('Support Police B1 Test')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.onPrimaryContainer,
                    child: const Icon(Icons.volunteer_activism_outlined, size: 30),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Help keep learning free',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your optional contribution can help us add more questions '
                  'and improve the app for everyone.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SegmentedButton<SupportMethod>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: SupportMethod.upi,
                      icon: Icon(Icons.account_balance_outlined),
                      label: Text('UPI'),
                    ),
                    ButtonSegment(
                      value: SupportMethod.binance,
                      icon: Icon(Icons.currency_bitcoin_outlined),
                      label: Text('Crypto'),
                    ),
                  ],
                  selected: {method},
                  onSelectionChanged: (selected) {
                    setState(() => method = selected.first);
                  },
                ),
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
                    child: Column(
                      children: [
                        Text(
                          upi ? 'Donate using UPI' : 'Donate using Binance Pay',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          upi
                              ? 'Scan with any compatible UPI app'
                              : 'Scan with the Binance app',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        // The QR encodes exactly the destination supplied by
                        // the publisher, and is generated entirely offline.
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Semantics(
                            label: upi ? 'UPI donation QR code' : 'Binance Pay donation QR code',
                            child: QrImageView(
                              data: paymentQr,
                              version: QrVersions.auto,
                              size: 250,
                              errorCorrectionLevel: QrErrorCorrectLevel.M,
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.all(7),
                              gapless: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          destination,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (upi)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Recipient: ${SupportDestinations.upiName}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => openExternal(
                              paymentQr,
                              upi
                                  ? 'No UPI app is available. Scan the QR from another device.'
                                  : 'Binance could not be opened. Scan the QR with the Binance app.',
                            ),
                            icon: const Icon(Icons.open_in_new, size: 19),
                            label: Text(upi ? 'Open UPI app' : 'Open Binance Pay'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => copy(
                              upi ? SupportDestinations.upiId : SupportDestinations.binanceUrl,
                              upi ? 'UPI ID' : 'Binance payment link',
                            ),
                            icon: const Icon(Icons.copy_outlined, size: 19),
                            label: Text(upi ? 'Copy UPI ID' : 'Copy payment link'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: scheme.secondaryContainer,
                      foregroundColor: scheme.onSecondaryContainer,
                      child: const Icon(Icons.mail_outline),
                    ),
                    title: const Text(
                      'iOS users & support',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Text(SupportDestinations.iosSupportEmail),
                    ),
                    trailing: IconButton(
                      tooltip: 'Copy email address',
                      icon: const Icon(Icons.copy_outlined),
                      onPressed: () => copy(
                        SupportDestinations.iosSupportEmail, 'Email address',
                      ),
                    ),
                    onTap: () => openExternal(
                      'mailto:${SupportDestinations.iosSupportEmail}'
                      '?subject=Police%20B1%20Test%20support',
                      'No email app found. Copy the address instead.',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Contributions are voluntary. Everyone can use all existing '
                  'questions and features for free, whether or not they donate. '
                  'Donations do not unlock content or benefits. Payment is handled '
                  'by the selected UPI or Binance app, not by Police B1 Test.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
