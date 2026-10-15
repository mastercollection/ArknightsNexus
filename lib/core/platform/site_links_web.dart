import 'package:web/web.dart' as web;

bool get canOpenSiteLinks => true;

Uri siteRoot() => Uri.parse(web.document.baseURI);

Future<bool> openSiteLink(Uri uri) async {
  web.window.open(uri.toString(), '_blank');
  return true;
}
