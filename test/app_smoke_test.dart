import 'package:arknight_nexus/app/app.dart';
import 'package:arknight_nexus/app/providers.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/operator.dart';
import 'package:arknight_nexus/domain/sync_status.dart';
import 'package:arknight_nexus/services/operator_service.dart';
import 'package:arknight_nexus/services/region_sync_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts on the Korean home hub', (tester) async {
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

    // The default 800x600 view is the medium layout: icon rail + the home
    // page, whose data card carries the region select (the brand lives in
    // the PC sidebar and the phone header).
    expect(find.text('KR · 한국어'), findsOneWidget);
    for (final section in ['home', 'operators', 'plan', 'items', 'settings']) {
      expect(find.byKey(Key('rail-$section')), findsOneWidget);
    }
    expect(find.byKey(const Key('home-search-field')), findsOneWidget);
    expect(find.byKey(const Key('home-sync-button')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('home-rights-notice')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('비공식 팬 앱'), findsOneWidget);
  });

  testWidgets('navigates from dashboard to operators', (tester) async {
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

    await tester.tap(find.byKey(const Key('home-search-button')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.byKey(const Key('home-search-field')), findsNothing);
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
