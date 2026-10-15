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
      tableUris[fileName] = _rawUri(region, fileName);
    }

    return SourceDescriptor(
      region: region,
      repositoryUri: Uri.parse(repository),
      branch: defaultBranch,
      dataVersionUri: _rawUri(region, ArknightsDataSource.dataVersionFile),
      tableUris: Map.unmodifiable(tableUris),
    );
  }

  Uri tableUri(String fileName) {
    return tableUris[fileName] ?? _rawUri(region, fileName);
  }

  static Uri _rawUri(RegionCode region, String fileName) {
    return Uri.parse(
      '$rawRepository/refs/heads/$defaultBranch/'
      '${region.value}/gamedata/excel/$fileName',
    );
  }
}
