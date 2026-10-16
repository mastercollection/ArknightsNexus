import 'package:arknight_nexus/app/app.dart';
import 'package:arknight_nexus/app/page_transitions.dart';
import 'package:arknight_nexus/app/providers.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/operator.dart';
import 'package:arknight_nexus/domain/sync_status.dart';
import 'package:arknight_nexus/features/home/home_screen.dart';
import 'package:arknight_nexus/features/operators/operators_screen.dart';
import 'package:arknight_nexus/features/settings/settings_screen.dart';
import 'package:arknight_nexus/services/operator_service.dart';
import 'package:arknight_nexus/services/region_sync_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        operatorServiceProvider.overrideWithValue(_EmptyOperatorService()),
        regionSyncServiceProvider.overrideWithValue(_NoopRegionSyncService()),
      ],
      child: const ArknightNexusApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Opacity of the route-level fade around [page], or null when the page is
/// not inside one.
double? _routeFadeOpacity(WidgetTester tester, Finder page) {
  final fades = find.ancestor(of: page, matching: find.byType(FadeTransition));
  if (fades.evaluate().isEmpty) {
    return null;
  }
  return tester.widget<FadeTransition>(fades.first).opacity.value;
}

void main() {
  test('pushes fade on desktop and keep the platform transition on mobile', () {
    expect(pushTransitionFor(TargetPlatform.windows), NexusPageTransition.fade);
    expect(pushTransitionFor(TargetPlatform.linux), NexusPageTransition.fade);
    expect(pushTransitionFor(TargetPlatform.macOS), NexusPageTransition.fade);
    expect(
      pushTransitionFor(TargetPlatform.android),
      NexusPageTransition.platform,
    );
    expect(pushTransitionFor(TargetPlatform.iOS), NexusPageTransition.platform);
  });

  testWidgets('rail section switches do not animate', (tester) async {
    await _pumpApp(tester);
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('rail-settings')));
    await tester.pump();

    // One frame: the new section is fully shown and the old one is gone.
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(_routeFadeOpacity(tester, find.byType(SettingsScreen)), isNull);

    await tester.tap(find.byKey(const Key('rail-home')));
    await tester.pump();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
  });

  testWidgets('a rail tap pops a pushed page without animating', (
    tester,
  ) async {
    await _pumpApp(tester);
    // The home search pushes the operators list.
    await tester.tap(find.byKey(const Key('home-search-button')));
    await tester.pumpAndSettle();
    expect(find.byType(OperatorsScreen), findsOneWidget);

    // Home is underneath, so going home pops the operators page.
    await tester.tap(find.byKey(const Key('rail-home')));
    await tester.pump();
    expect(find.byType(OperatorsScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('pushes and pops fade quickly on desktop', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await _pumpApp(tester);

      await tester.tap(find.byKey(const Key('home-search-button')));
      await tester.pump();
      await tester.pump(nexusFadeDuration ~/ 2);
      // Mid-fade: the operators page is partly transparent over home.
      final opacity = _routeFadeOpacity(
        tester,
        find.byType(OperatorsScreen),
      );
      expect(opacity, isNotNull);
      expect(opacity, greaterThan(0));
      expect(opacity, lessThan(1));
      expect(find.byType(HomeScreen), findsOneWidget);

      await tester.pump(nexusFadeDuration);
      await tester.pump();
      expect(find.byType(HomeScreen), findsNothing);
      expect(_routeFadeOpacity(tester, find.byType(OperatorsScreen)), 1);

      // Esc pops back with the same fade.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(nexusFadeDuration ~/ 2);
      expect(find.byType(OperatorsScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(OperatorsScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

class _NoopRegionSyncService implements RegionSyncService {
  @override
  Future<SyncResult> ensureRegionFresh(RegionCode region) async {
    return const SyncResult(
      region: RegionCode.kr,
      sourceRevision: 'test',
      sourceVersion: 'test',
      updatedAt: '2026-05-17T00:00:00Z',
      operatorCount: 0,
      status: 'ready',
    );
  }

  @override
  Future<RegionSyncStatus?> getRegionSyncStatus(RegionCode region) async {
    return null;
  }

  @override
  Future<Map<String, String>> getRegionStageCodes(RegionCode region) async {
    return const {};
  }

  @override
  Future<Map<String, String>> getRegionTerms(RegionCode region) async {
    return const {};
  }

  @override
  Stream<SyncStatus> syncRegion(RegionCode region) async* {}
}

class _EmptyOperatorService implements OperatorService {
  @override
  Future<OperatorDetail?> getOperatorDetail(
    RegionCode region,
    String operatorId,
  ) async {
    return null;
  }

  @override
  Future<List<OperatorSummary>> listOperators(OperatorQuery query) async {
    return const [];
  }
}
