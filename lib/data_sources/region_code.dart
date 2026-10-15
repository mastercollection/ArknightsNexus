import 'source_descriptor.dart';

enum RegionCode {
  cn('cn'),
  kr('kr'),
  jp('jp'),
  tw('tw'),
  en('en');

  const RegionCode(this.value);

  final String value;

  static RegionCode parse(String value) {
    final normalized = value.trim().toLowerCase();
    for (final code in RegionCode.values) {
      if (code.value == normalized) {
        return code;
      }
    }

    throw FormatException('Unsupported region code: $value');
  }

  static RegionCode fromJson(Object? value) {
    if (value is! String) {
      throw FormatException('Unsupported region code: $value');
    }

    return parse(value);
  }

  SourceDescriptor get descriptor => SourceDescriptor.forRegion(this);

  String toJson() => value;
}
