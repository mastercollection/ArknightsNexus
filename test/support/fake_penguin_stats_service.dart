import 'package:arknight_nexus/domain/penguin_matrix.dart';
import 'package:arknight_nexus/services/penguin_stats_service.dart';

/// Configurable [PenguinStatsService] fake for widget tests. Returns the
/// registered entries for an item id without touching the network.
class FakePenguinStatsService implements PenguinStatsService {
  FakePenguinStatsService([Map<String, List<PenguinMatrixEntry>>? byItemId])
      : _byItemId = byItemId ?? const {};

  final Map<String, List<PenguinMatrixEntry>> _byItemId;
  final requestedServers = <PenguinServer>[];

  @override
  Future<List<PenguinMatrixEntry>> getItemMatrix(
    String itemId, {
    PenguinServer server = PenguinServer.cn,
  }) async {
    requestedServers.add(server);
    return _byItemId[itemId.trim()] ?? const [];
  }
}
