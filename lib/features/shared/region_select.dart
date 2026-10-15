import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data_sources/region_code.dart';
import '../../i18n/nexus_i18n.dart';
import '../../ui/redesign/rd_widgets.dart';

/// Region options with their native language name, as the canvas lists them
/// ("KR · 한국어"). The names are endonyms, so they do not follow the locale.
const regionLanguageLabels = <RegionCode, String>{
  RegionCode.kr: 'KR · 한국어',
  RegionCode.cn: 'CN · 简体中文',
  RegionCode.jp: 'JP · 日本語',
  RegionCode.tw: 'TW · 繁體中文',
  RegionCode.en: 'EN · English',
};

/// Region select of the redesign: the data region, which also sets the UI
/// language (`useRegionPreference`). Not persisted, like the Tauri app.
class RdRegionSelect extends ConsumerWidget {
  const RdRegionSelect({
    required this.semanticLabel,
    this.codesOnly = false,
    this.height = 40,
    this.fontSize = 14,
    super.key = const Key('region-select'),
  });

  final String semanticLabel;

  /// Shows "KR" instead of "KR · 한국어" in the closed select (the mobile
  /// header); the menu always lists the language names.
  final bool codesOnly;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RdSelect<RegionCode>(
      label: semanticLabel,
      value: ref.watch(regionProvider),
      height: height,
      fontSize: fontSize,
      shrinkWrap: codesOnly,
      options: [
        for (final option in regionOptions)
          RdSelectOption(
            option,
            regionLanguageLabels[option]!,
            shortLabel: codesOnly ? regionLabels[option] : null,
          ),
      ],
      onChanged: (next) => ref.read(regionProvider.notifier).state = next,
    );
  }
}
