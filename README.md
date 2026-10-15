# ArknightsNexus

ArknightsNexus is an app that helps Arknights players with operator data, item
data and operator promotion planning. It is a Flutter app for Windows and
Android; layouts adapt to the window width (bottom tabs on phones, an icon
rail on wider windows, master-detail operators on PC).

## Layout

| Path | Contents |
| --- | --- |
| `lib/app/` | App root, router and the responsive shell (`shell.dart`) |
| `lib/ui/redesign/` | Design tokens and the shared widget kit of the current layout |
| `lib/ui/` | Older shared widgets (dialogs, messages, media) still used by screens |
| `lib/i18n/` | `nexus_messages.g.dart` (5 locales) plus per-area additions in `extra/`; the selected region is also the UI language |
| `lib/features/` | Screens: home, operators (list/detail), items (list/detail), plan (index/operator), settings |
| `lib/services/` | Region sync, data normalizers, cache-backed queries, plan costs, Penguin Stats, image cache, diagnostics |
| `lib/raw_models/`, `lib/domain/` | Upstream table models and the cached snapshot DTOs |
| `tool/` | `build_snapshots.dart`: builds the published region snapshots |
| `site/` | Static GitHub Pages site (homepage, privacy policy) |

## Develop

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

Release builds: `flutter build windows --release`, `flutter build apk --release`,
`flutter build appbundle --release`. Android release signing reads
`ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and
`ANDROID_KEY_PASSWORD`; without them the debug key is used. Tagging `v*` runs
`.github/workflows/release.yml`.

`lib/i18n/nexus_messages.g.dart` holds the original translations; do not edit
it by hand. Put new strings in the matching `lib/i18n/extra/<area>.dart` with
values for all five locales.

## Game data flow

The app needs one normalized `RegionSnapshot` per region (operators, items,
building formulas, terms, stage codes). It gets it in this order:

1. **Published snapshot (default).** `.github/workflows/pages.yml` runs
   `tool/build_snapshots.dart`, which fetches the raw tables and normalizes
   them with the app's own code (`lib/services/region_source.dart`), and
   publishes the result on GitHub Pages:
   `https://mastercollection.github.io/ArknightsNexus/data/manifest.json` plus
   `data/v{schemaVersion}/{region}/snapshot.json` (about 15 MB of JSON per
   region, about 2 MB as served gzipped). `PublishedSnapshotSyncService`
   reads the manifest, skips the download when the cached snapshot already
   has the published `VersionControl`, otherwise downloads the snapshot,
   checks its size and SHA-256, decodes it on a background isolate and
   derives the summary, status and terms files from it.
2. **Raw upstream tables (fallback).** When the manifest or snapshot cannot
   be fetched or verified, the region or this app's
   `RegionSnapshot.schemaVersion` is not published, or the published copy is
   older than the cached snapshot, the app logs the reason and falls back to
   `DartRegionSyncService`: about 80 MB of tables from
   `raw.githubusercontent.com/ArknightsAssets/ArknightsGamedata`, normalized
   on the device.

The freshness check runs once per region per app session; the manual sync
buttons use the same order. Pages can lag upstream by up to the hourly
publishing interval plus the build time.

Point the app at another data site (a fork or a local build) with
`--dart-define=NEXUS_DATA_BASE_URL=http://127.0.0.1:8765/data/`.

### Building snapshots locally

```sh
flutter pub get
dart run tool/build_snapshots.dart --out build/site/data --regions kr
# optional: --previous-manifest https://mastercollection.github.io/ArknightsNexus/data/manifest.json
#           --fingerprint <hash>   (copy unchanged regions from the published site)
```

The tool is pure Dart; nothing it imports may depend on Flutter. To check a
local build end to end, serve its parent directory (for example
`python -m http.server 8765 --bind 127.0.0.1 --directory build/site`) and run

```sh
flutter test test/integration/published_snapshot_roundtrip_test.dart --run-skipped   --dart-define=NEXUS_DATA_BASE_URL=http://127.0.0.1:8765/data/
```

which installs KR from that site and compares it with a raw sync.

### GitHub Pages

`site/` holds the static homepage (`index.html`) and privacy policy
(`privacy.html`); the workflow copies it next to `data/`. The workflow runs
hourly, on pushes to `main` that touch the generator inputs or `site/`, and
manually. The hourly run only builds when an upstream `data_version.txt`
differs from the published manifest or the generator inputs' fingerprint
changed; unchanged regions are copied from the published site after
checking their SHA-256, and a region that fails to build keeps its
published copy.

One-time setup by the repository owner: **Settings → Pages → Build and
deployment → Source: "GitHub Actions"**. Then run the "Pages" workflow once
from the Actions tab (or push to `main`).

## Compatibility with the earlier Tauri app

- Android uses the same application id (`com.nexus.arknights`), so a build
  signed with the same key updates the earlier app in place.
- On first launch, an existing Tauri `user/user_data.json` (schema 3) is
  imported once (Windows: `%APPDATA%\com.nexus.arknights`, Android: app data
  dir).
- Cached region snapshots carry a schema version; a mismatch triggers a full
  re-sync.
- Plan costs include module upgrade costs (the earlier app left them out).

## Disclaimer

ArknightsNexus is an unofficial fan-made project and is not affiliated with, endorsed by, or sponsored by Hypergryph Network Technology Co., Ltd., Studio Montagne, Yostar, or any other official rights holder.

Arknights and all related names, logos, characters, artwork, text, audio, and in-game assets are the property of their respective rights holders.

Any third-party copyrighted material present in this repository remains the property of its respective owner. If you are a rights holder and would like any material to be modified or removed, please open an issue or contact the project maintainer, and it will be addressed promptly.
