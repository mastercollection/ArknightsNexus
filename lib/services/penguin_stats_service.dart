import 'dart:convert';

import '../core/errors/app_failure.dart';
import '../core/http/http_client.dart';
import '../domain/penguin_matrix.dart';

abstract interface class PenguinStatsService {
  /// Fetches the drop matrix for [itemId] from the given [server], sorted by
  /// drop rate. Returns an empty list for a blank item id.
  Future<List<PenguinMatrixEntry>> getItemMatrix(
    String itemId, {
    PenguinServer server,
  });
}

/// Dart port of the Tauri `getPenguinItemMatrix` flow. Queries the Penguin
/// Stats matrix endpoint, filters to usable rows, derives the drop rate, sorts,
/// and caches results per server/item.
class DartPenguinStatsService implements PenguinStatsService {
  DartPenguinStatsService({required NexusHttpClient httpClient})
      : _httpClient = httpClient;

  static const String _endpoint =
      'https://penguin-stats.io/PenguinStats/api/v2/result/matrix';

  final NexusHttpClient _httpClient;
  final Map<String, List<PenguinMatrixEntry>> _cache = {};

  @override
  Future<List<PenguinMatrixEntry>> getItemMatrix(
    String itemId, {
    PenguinServer server = PenguinServer.cn,
  }) async {
    final normalizedItemId = itemId.trim();
    if (normalizedItemId.isEmpty) {
      return const [];
    }

    final cacheKey = '${server.value}:$normalizedItemId';
    final cached = _cache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final uri = Uri.parse(_endpoint).replace(
      queryParameters: {
        'itemFilter': normalizedItemId,
        'server': server.value,
      },
    );

    final String body;
    try {
      body = await _httpClient.getText(uri);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw NetworkFailure('Penguin Stats request failed: $error');
    }

    final dynamic payload = jsonDecode(body);
    final List<dynamic> matrix;
    if (payload is List) {
      matrix = payload;
    } else if (payload is Map && payload['matrix'] is List) {
      matrix = payload['matrix'] as List<dynamic>;
    } else {
      matrix = const [];
    }

    final result = <PenguinMatrixEntry>[];
    for (final dynamic raw in matrix) {
      if (raw is! Map) {
        continue;
      }
      final entryItemId = raw['itemId'] as String?;
      final quantity = (raw['quantity'] as num?)?.toInt() ?? 0;
      final times = (raw['times'] as num?)?.toInt() ?? 0;
      if (entryItemId != normalizedItemId || times <= 0 || quantity <= 0) {
        continue;
      }
      result.add(
        PenguinMatrixEntry(
          stageId: raw['stageId'] as String? ?? '',
          itemId: entryItemId!,
          quantity: quantity,
          times: times,
          dropRate: quantity / times,
          start: (raw['start'] as num?)?.toInt(),
          end: (raw['end'] as num?)?.toInt(),
        ),
      );
    }

    result.sort((left, right) {
      final byRate = right.dropRate.compareTo(left.dropRate);
      if (byRate != 0) {
        return byRate;
      }
      final byTimes = right.times.compareTo(left.times);
      if (byTimes != 0) {
        return byTimes;
      }
      return left.stageId.compareTo(right.stageId);
    });

    _cache[cacheKey] = result;
    return result;
  }
}
