import 'site_links_web.dart' if (dart.library.io) 'site_links_io.dart' as impl;

/// Pages of the project site (GitHub Pages), which also hosts the web build.
abstract final class SiteLinks {
  static const aboutPage = 'about.html';
  static const privacyPage = 'privacy.html';

  /// Whether [open] can show a page on this platform (the web build and
  /// Windows; Android would need a browser-intent plugin).
  static bool get canOpen => impl.canOpenSiteLinks;

  /// The absolute URL of a site [page]. The web build resolves it next to
  /// the app itself, so a fork or a local server links its own pages.
  static Uri uriOf(String page) => impl.siteRoot().resolve(page);

  /// Opens [page] in the browser. Returns false when the platform cannot.
  static Future<bool> open(String page) => impl.openSiteLink(uriOf(page));
}
