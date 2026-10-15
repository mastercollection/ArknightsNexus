import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_sources/region_code.dart';
import '../i18n/nexus_i18n.dart';
import 'router.dart';
import 'theme.dart';

class ArknightNexusApp extends ConsumerWidget {
  const ArknightNexusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'ArknightsNexus',
      theme: NexusTheme.dark(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => _GlobalBackHandler(
        onBack: () => ref.read(routerProvider).routerDelegate.popRoute(),
        child: child!,
      ),
      locale: _materialLocales[ref.watch(regionProvider)],
      supportedLocales: _materialLocales.values,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
    );
  }
}

/// Material/Cupertino locale for each region (the UI language follows the
/// selected region, as in the Tauri app).
const _materialLocales = <RegionCode, Locale>{
  RegionCode.kr: Locale('ko'),
  RegionCode.cn: Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
  RegionCode.jp: Locale('ja'),
  RegionCode.tw: Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  RegionCode.en: Locale('en'),
};

/// Desktop affordances for going back: the mouse "back" side button and the
/// Esc key. They run the same pop as Android's system back (dialogs first,
/// then the page stack, then the shell's section rule); unlike Android,
/// nothing happens when that reaches home, so the window never closes.
class _GlobalBackHandler extends StatelessWidget {
  const _GlobalBackHandler({required this.onBack, required this.child});

  final Future<bool> Function() onBack;
  final Widget child;

  void _back() {
    onBack();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        if (event.buttons == kBackMouseButton) {
          _back();
        }
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _back,
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}
