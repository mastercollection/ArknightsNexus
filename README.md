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
