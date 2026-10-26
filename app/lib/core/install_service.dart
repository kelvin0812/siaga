import 'package:flutter/foundation.dart';
import 'install_platform_stub.dart' if (dart.library.js_interop) 'install_platform_web.dart';

/// Putting SIAGA on the home screen. In a browser that offers it, one tap shows the browser's own install dialog; where it
/// does not (iPhone Safari, an in-app browser), the app shows the steps instead. Off the web there is nothing to install.
abstract class InstallService extends ChangeNotifier {
  /// Only the web version can be installed this way.
  bool get supported;

  /// Already running from the home screen.
  bool get installed;

  /// The browser is ready to show its install dialog right now.
  bool get canPrompt;

  /// iPhone or iPad, where the way to install is Share, then Add to Home Screen.
  bool get isIos;

  /// Shows the browser's install dialog. Does nothing when [canPrompt] is false.
  Future<void> prompt();
}

InstallService createInstallService() => createPlatformInstallService();
