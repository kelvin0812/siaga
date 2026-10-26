import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'install_service.dart';

InstallService createPlatformInstallService() => _WebInstall();

/// Talks to the small helpers in web/index.html, which hold on to the browser's install prompt.
class _WebInstall extends InstallService {
  _WebInstall() {
    globalContext['siagaOnInstallChange'] = (() => notifyListeners()).toJS;
  }

  bool _ask(String helper) {
    try {
      if (!globalContext.has(helper)) return false;
      return globalContext.callMethod<JSBoolean>(helper.toJS).toDart;
    } catch (_) {
      return false;
    }
  }

  @override
  bool get supported => true;
  @override
  bool get installed => _ask('siagaIsInstalled');
  @override
  bool get canPrompt => _ask('siagaCanInstall');
  @override
  bool get isIos => _ask('siagaIsIos');

  @override
  Future<void> prompt() async {
    if (!canPrompt) return;
    try {
      await globalContext.callMethod<JSPromise<JSAny?>>('siagaInstall'.toJS).toDart;
    } catch (_) {
      // the person closed the dialog, or the browser refused: nothing to do
    }
    notifyListeners();
  }

  @override
  void dispose() {
    globalContext['siagaOnInstallChange'] = null;
    super.dispose();
  }
}
