import 'dart:io';

const _siteRoot = 'https://mastercollection.github.io/ArknightsNexus/';

bool get canOpenSiteLinks => Platform.isWindows;

Uri siteRoot() => Uri.parse(_siteRoot);

Future<bool> openSiteLink(Uri uri) async {
  if (!Platform.isWindows) {
    return false;
  }
  // Explorer hands an http(s) URL to the default browser.
  await Process.run('explorer.exe', [uri.toString()]);
  return true;
}
