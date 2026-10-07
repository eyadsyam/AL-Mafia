import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mafia_master/app/l10n/app_localizations.dart';
import 'package:mafia_master/platform/links/external_link.dart';
import 'package:mafia_master/ui/theme/mafia_theme.dart';

/// Local verification target for A1's delayed coin-order navigation.
///
/// It performs no server request: the awaited operation below is the local
/// stand-in for an accepted order, and the destination is localhost. This
/// target is never used by the production entrypoint.
void main() => runApp(const _A1WebProbe());

class _A1WebProbe extends StatelessWidget {
  const _A1WebProbe();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('ar'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: MafiaTheme.dark,
    home: const _ProbeScreen(),
  );
}

class _ProbeScreen extends StatefulWidget {
  const _ProbeScreen();

  @override
  State<_ProbeScreen> createState() => _ProbeScreenState();
}

class _ProbeScreenState extends State<_ProbeScreen> {
  late final ProviderContainer _providers;

  @override
  void initState() {
    super.initState();
    _providers = ProviderContainer();
  }

  @override
  void dispose() {
    _providers.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final reservation = _providers.read(externalLinkReserverProvider)(
      'https://127.0.0.1:9443/a1-payment',
    );
    await Future<void>.delayed(context.motion.standard);
    if (!mounted) {
      reservation.cancel();
      return;
    }
    if (!await reservation.commit() && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.coinOpenFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final s = context.spacing;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(s.screenMargin),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.pay2StepPayHint, textAlign: TextAlign.center),
                SizedBox(height: s.lg),
                FilledButton(
                  key: const ValueKey('coin_open_payment'),
                  onPressed: _open,
                  child: Text(l.coinPayInstapay),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
