/// Glass/dark design system ported from the Tauri app's UnoCSS shortcuts and
/// Element Plus theme layer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data_sources/region_code.dart';
import '../i18n/nexus_i18n.dart';
import 'nexus_controls.dart';
import 'nexus_surfaces.dart';

export 'nexus_controls.dart';
export 'nexus_feedback.dart';
export 'nexus_icons.dart';
export 'nexus_media.dart';
export 'nexus_overlays.dart';
export 'nexus_page.dart';
export 'nexus_scrollbar.dart';
export 'nexus_surfaces.dart';
export 'nexus_tokens.dart';

/// Region `el-select` from the home top bar (`w-24`).
class RegionSelect extends ConsumerWidget {
  const RegionSelect({this.width = 96, super.key});

  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NexusSelect<RegionCode>(
      width: width,
      value: ref.watch(regionProvider),
      options: [
        for (final region in regionOptions)
          NexusOption(region, regionLabels[region]!),
      ],
      onChanged: (region) {
        if (region != null) {
          ref.read(regionProvider.notifier).state = region;
        }
      },
    );
  }
}

/// Top-bar back button. Pops when possible, otherwise navigates to
/// [fallback] (Vue pages push a fixed parent route).
class NexusBackButton extends StatelessWidget {
  const NexusBackButton({
    this.fallback = '/',
    this.forceFallback = false,
    super.key,
  });

  final String fallback;

  /// Always go to [fallback] instead of popping (e.g. the operators list
  /// returns to home via `router.push('/')`).
  final bool forceFallback;

  @override
  Widget build(BuildContext context) {
    return NexusTopBarIcon(
      icon: Icons.arrow_back,
      onPressed: () {
        if (!forceFallback && context.canPop()) {
          context.pop();
        } else {
          context.go(fallback);
        }
      },
    );
  }
}
