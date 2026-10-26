import 'install_service.dart';

InstallService createPlatformInstallService() => _NoInstall();

class _NoInstall extends InstallService {
  @override
  bool get supported => false;
  @override
  bool get installed => false;
  @override
  bool get canPrompt => false;
  @override
  bool get isIos => false;
  @override
  Future<void> prompt() async {}
}
