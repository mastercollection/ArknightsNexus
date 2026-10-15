import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_sources/region_code.dart';
import 'nexus_messages.g.dart';
import 'nexus_messages_extra.dart';

/// Region selected in the top bar. Like the Tauri app's `useRegionPreference`,
/// it drives both the data region and the UI language, and is not persisted.
final regionProvider = StateProvider<RegionCode>((ref) => RegionCode.kr);

final i18nProvider = Provider<NexusI18n>((ref) {
  return NexusI18n(ref.watch(regionProvider));
});

const regionLabels = <RegionCode, String>{
  RegionCode.kr: 'KR',
  RegionCode.cn: 'CN',
  RegionCode.jp: 'JP',
  RegionCode.tw: 'TW',
  RegionCode.en: 'EN',
};

/// Display order of the region selector (matches the Tauri app).
const regionOptions = <RegionCode>[
  RegionCode.kr,
  RegionCode.cn,
  RegionCode.jp,
  RegionCode.tw,
  RegionCode.en,
];

const _fallbackLocale = 'en';

const _professionKeys = <String, String>{
  'Vanguard': 'vanguard',
  'Sniper': 'sniper',
  'Medic': 'medic',
  'Caster': 'caster',
  'Guard': 'guard',
  'Defender': 'defender',
  'Supporter': 'supporter',
  'Specialist': 'specialist',
};

const _skillRecoveryKeys = {
  'auto_recovery',
  'attack_recovery',
  'defense_recovery',
  'unknown_recovery',
};

const _skillActivationKeys = {
  'passive',
  'manual_trigger',
  'auto_trigger',
  'unknown_trigger',
};

const _statKeys = {
  'hp',
  'atk',
  'def',
  'magic_res',
  'cost',
  'block_cnt',
  'respawn_time',
  'attack_interval',
  'hp_recovery_per_sec',
};

final _placeholderPattern = RegExp(r'\{(\w+)\}');

/// Port of the vue-i18n setup in `src/i18n.ts`: dotted keys, `{name}`
/// interpolation, locale = region, fallback to `en`, then the key itself.
class NexusI18n {
  const NexusI18n(this.region);

  final RegionCode region;

  String get locale => region.value;

  static String? _lookup(String locale, String key) {
    final base = nexusMessages[locale]?[key];
    if (base != null) {
      return base;
    }
    for (final extra in nexusExtraMessages) {
      final value = extra[locale]?[key];
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  bool has(String key) {
    return _lookup(locale, key) != null ||
        _lookup(_fallbackLocale, key) != null;
  }

  String t(String key, [Map<String, Object?> params = const {}]) {
    final message =
        _lookup(locale, key) ?? _lookup(_fallbackLocale, key) ?? key;
    if (params.isEmpty) {
      return message;
    }
    return message.replaceAllMapped(_placeholderPattern, (match) {
      final name = match.group(1)!;
      return params.containsKey(name) ? '${params[name]}' : match.group(0)!;
    });
  }

  String secondsValue(Object value) =>
      t('stats.secondsValue', {'value': value});

  String profession(String profession) {
    final key = _professionKeys[profession];
    return key == null ? profession : t('profession.$key');
  }

  String skillRecovery(String recoveryType) {
    return _skillRecoveryKeys.contains(recoveryType)
        ? t('skill.recovery.$recoveryType')
        : recoveryType;
  }

  String skillActivation(String activationType) {
    return _skillActivationKeys.contains(activationType)
        ? t('skill.activation.$activationType')
        : activationType;
  }

  String statLabel(String statKey) {
    return _statKeys.contains(statKey) ? t('stats.$statKey') : statKey;
  }
}
