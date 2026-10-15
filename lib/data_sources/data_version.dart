import '../core/errors/app_failure.dart';

class DataVersion {
  const DataVersion({
    required this.versionControl,
    this.stream,
    this.changeValue,
    this.changeDate,
  });

  final String versionControl;
  final String? stream;
  final String? changeValue;
  final String? changeDate;

  static DataVersion parse(String text) {
    String? stream;
    String? changeValue;
    String? changeDate;
    String? versionControl;

    for (final rawLine in text.split('\n')) {
      final line = rawLine.replaceFirst('\uFEFF', '').trim();
      if (line.isEmpty) {
        continue;
      }

      if (line.startsWith('Stream:')) {
        final value = line.substring('Stream:'.length).trim();
        if (value.isNotEmpty) {
          stream = value;
        }
        continue;
      }

      if (line.startsWith('Change:')) {
        final value = line.substring('Change:'.length).trim();
        if (value.isEmpty) {
          continue;
        }

        final match = RegExp(
          r'^(.+?)\s+on\s+(.+)$',
          caseSensitive: false,
        ).firstMatch(value);
        if (match == null) {
          throw ParseFailure(
            'Expected Change:<value> on <date>, got `$value`',
            source: 'Change',
          );
        }

        final parsedValue = match.group(1)?.trim();
        final parsedDate = match.group(2)?.trim();
        if (parsedValue != null && parsedValue.isNotEmpty) {
          changeValue = parsedValue;
        }
        if (parsedDate != null && parsedDate.isNotEmpty) {
          changeDate = parsedDate;
        }
        continue;
      }

      if (line.startsWith('VersionControl:')) {
        versionControl = line.substring('VersionControl:'.length).trim();
      }
    }

    final requiredVersion = versionControl;
    if (requiredVersion == null) {
      throw const ParseFailure(
        'Missing VersionControl field',
        source: 'VersionControl',
      );
    }
    if (requiredVersion.isEmpty) {
      throw const ParseFailure(
        'Empty VersionControl field',
        source: 'VersionControl',
      );
    }

    return DataVersion(
      stream: stream,
      changeValue: changeValue,
      changeDate: changeDate,
      versionControl: requiredVersion,
    );
  }

  factory DataVersion.fromJson(Map<String, Object?> json) {
    final versionControl = json['versionControl'];
    if (versionControl is! String || versionControl.trim().isEmpty) {
      throw const ParseFailure(
        'DataVersion JSON requires a non-empty versionControl',
        source: 'versionControl',
      );
    }

    return DataVersion(
      stream: _readNullableString(json, 'stream'),
      changeValue: _readNullableString(json, 'changeValue'),
      changeDate: _readNullableString(json, 'changeDate'),
      versionControl: versionControl,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'stream': stream,
      'changeValue': changeValue,
      'changeDate': changeDate,
      'versionControl': versionControl,
    };
  }

  static String? _readNullableString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }

    throw ParseFailure(
      'Expected `$key` to be a string or null',
      source: key,
    );
  }
}
