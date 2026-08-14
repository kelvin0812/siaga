// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Malay (`ms`).
class AppLocalizationsMs extends AppLocalizations {
  AppLocalizationsMs([String locale = 'ms']) : super(locale);

  @override
  String get appTitle => 'SIAGA';

  @override
  String get navMap => 'Peta';

  @override
  String get navMyRisk => 'Risiko Saya';

  @override
  String get navReport => 'Lapor';

  @override
  String get navSettings => 'Tetapan';

  @override
  String get riskNormal => 'Normal';

  @override
  String get riskWatch => 'Perhatian';

  @override
  String get riskWarning => 'Amaran';

  @override
  String get riskEvacuate => 'Berpindah';

  @override
  String get myRiskTitle => 'Tahap risiko untuk kawasan anda';

  @override
  String get myRiskNoCell => 'Menunggu lokasi...';

  @override
  String get sourceAttribution =>
      'Nasihat SIAGA (sokongan keputusan sahaja) — sahkan dengan NADMA / MetMalaysia / JPS.';

  @override
  String get nodeHistoryTitle => 'Sejarah paras air';

  @override
  String get nodeBattery => 'Bateri';

  @override
  String get nodeLastSeen => 'Kali terakhir dilihat';

  @override
  String get nodeStateLabel => 'Status';

  @override
  String get offlineBanner =>
      'Tiada sambungan — memaparkan data terkini yang diketahui';

  @override
  String get reportTitle => 'Laporkan bahaya';

  @override
  String get reportCategoryFlooding => 'Banjir';

  @override
  String get reportCategoryLandslide => 'Tanah runtuh / pergerakan cerun';

  @override
  String get reportCategoryOther => 'Lain-lain';

  @override
  String get reportNoteLabel => 'Catatan (pilihan)';

  @override
  String get reportAddPhoto => 'Tambah foto (pilihan)';

  @override
  String get reportSubmit => 'Hantar laporan';

  @override
  String get reportSubmitted => 'Laporan dihantar. Terima kasih.';

  @override
  String get reportFailed =>
      'Tidak dapat menghantar laporan. Cuba lagi apabila anda mempunyai sambungan.';

  @override
  String get settingsTitle => 'Tetapan';

  @override
  String get settingsLanguage => 'Bahasa';

  @override
  String get settingsLanguageSystem => 'Ikut bahasa peranti';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageMalay => 'Bahasa Malaysia';

  @override
  String get settingsDemoMode => 'Mod demo';

  @override
  String get settingsDemoModeDescription =>
      'Jalankan aplikasi menggunakan simulasi banjir untuk demonstrasi tanpa perkakasan sebenar.';

  @override
  String get evacuateHeadline => 'BERPINDAH SEKARANG';

  @override
  String get evacuateBody =>
      'Tinggalkan kawasan ini dengan segera dan ikut arahan rasmi.';

  @override
  String get evacuateAcknowledge => 'Saya faham';

  @override
  String get evacuateViewRoute => 'Lihat laluan pemindahan';

  @override
  String get assemblyPointsTitle => 'Tempat perhimpunan';

  @override
  String get permissionLocationRationale =>
      'SIAGA memerlukan lokasi anda untuk menentukan kawasan yang perlu dimaklumkan. Lokasi tepat anda tidak akan meninggalkan peranti ini.';

  @override
  String get permissionNotificationRationale =>
      'SIAGA memerlukan kebenaran notifikasi untuk menghantar amaran banjir dan tanah runtuh.';
}
