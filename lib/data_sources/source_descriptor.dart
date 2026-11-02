import 'arknights_data_source.dart';
import 'region_code.dart';

class SourceDescriptor {
  const SourceDescriptor({
    required this.region,
    required this.repositoryUri,
    required this.branch,
    required this.dataVersionUri,
    required this.tableUris,
  });

  static const repository =
      'https://github.com/ArknightsAssets/ArknightsGamedata';
  static const rawRepository =
      'https://raw.githubusercontent.com/ArknightsAssets/ArknightsGamedata';
  static const defaultBranch = 'master';

  final RegionCode region;
  final Uri repositoryUri;
  final String branch;
  final Uri dataVersionUri;
  final Map<String, Uri> tableUris;

  factory SourceDescriptor.forRegion(RegionCode region) {
    final tableUris = <String, Uri>{};
    for (final fileName in ArknightsDataSource.requiredTableFiles) {
      tableUris[fileName] =
          _rawUri(region, ArknightsDataSource.tablePath(fileName));
    }

    return SourceDescriptor(
      region: region,
      repositoryUri: Uri.parse(repository),
      branch: defaultBranch,
      dataVersionUri: _rawUri(
        region,
        ArknightsDataSource.tablePath(ArknightsDataSource.dataVersionFile),
      ),
      tableUris: Map.unmodifiable(tableUris),
    );
  }

  Uri tableUri(String fileName) {
    return tableUris[fileName] ??
        _rawUri(region, ArknightsDataSource.tablePath(fileName));
  }

  /// The level file of a stage's `levelId` (`Obt/Main/level_main_01-07`):
  /// the upstream folders are lower case while the ids are not.
  Uri levelUri(String levelId) {
    return _rawUri(region, 'levels/${levelId.toLowerCase()}.json');
  }

  /// [path] under the region's `gamedata/`.
  static Uri _rawUri(RegionCode region, String path) {
    return Uri.parse(
      '$rawRepository/refs/heads/$defaultBranch/'
      '${region.value}/gamedata/$path',
    );
  }
}
