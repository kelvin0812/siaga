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
  String get nodeNoReadings => 'Belum ada bacaan';

  @override
  String get nodeGpsLabel => 'Lokasi GPS';

  @override
  String get demoReadoutTitle => 'Bacaan sensor langsung (demo)';

  @override
  String get demoWaterLevel => 'Kedalaman air';

  @override
  String get demoWaterPressure => 'Tekanan air';

  @override
  String get demoSoilMoisture => 'Kelembapan tanah';

  @override
  String get demoSoilInertia => 'Inersia tanah (IMU)';

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
  String get settingsDemoTriggerLabel => 'Lompat ke status';

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

  @override
  String get myLocationTitle => 'Lokasi saya';

  @override
  String get myLocationRiskLabel => 'Risiko di kawasan anda';

  @override
  String get myLocationCellLabel => 'Kod kawasan';

  @override
  String get myLocationUpdatedLabel => 'Kemas kini terakhir';

  @override
  String get myLocationPrivacyNote =>
      'Ini hanya dipaparkan kepada anda — lokasi tepat anda tidak pernah dihantar ke mana-mana.';

  @override
  String get myLocationTapHint => 'Ketik untuk lihat status kawasan anda';

  @override
  String get reportCategoryLabel => 'Kategori';

  @override
  String get reportWhereLabel => 'Di mana anda perasan perkara ini? (pilihan)';

  @override
  String get reportWherePrefix => 'Lokasi';

  @override
  String get reportWhereHint => 'cth. berhampiran jambatan, belakang pasar';

  @override
  String get reportSectionDetails => 'Butiran';

  @override
  String get settingsNotifications => 'Notifikasi';

  @override
  String get settingsNotificationsEnabled => 'Diaktifkan';

  @override
  String get settingsNotificationsDisabled => 'Dilumpuhkan';

  @override
  String get settingsNotificationsUnknown => 'Belum diminta';

  @override
  String get settingsNotificationsDescription =>
      'Amaran banjir dan tanah runtuh untuk kawasan anda.';

  @override
  String get settingsNotificationsEnable => 'Aktifkan';

  @override
  String get settingsAbout => 'Tentang';

  @override
  String get settingsAboutVersion => 'SIAGA v1.0.0';

  @override
  String get mapSearchHint => 'Cari nod atau titik perhimpunan';

  @override
  String get mapSearchNoResults => 'Tiada padanan';

  @override
  String get mapLockNode => 'Kunci sebagai kawasan saya';

  @override
  String get mapUnlockNode => 'Buka kunci';

  @override
  String get mapLockedHint => 'Risiko Saya akan mengikut nod ini';

  @override
  String get riskSelectorLabel => 'Memaparkan';

  @override
  String get riskSelectorAuto => 'Automatik (terdekat dengan saya)';

  @override
  String get reportLocationLabel => 'Lokasi';

  @override
  String get reportLocationCurrent => 'Lokasi semasa saya';

  @override
  String get reportPhotoRemove => 'Buang foto';

  @override
  String get reportPhotoUploading => 'Memuat naik foto…';

  @override
  String get reportPhotoUploadFailed =>
      'Muat naik foto gagal. Cuba lagi atau buang foto.';

  @override
  String get benchSensorTitle => 'Rig Sensor Bangku (Langsung)';

  @override
  String get benchSensorDescription =>
      'Bacaan langsung daripada rig ujian ESP32/Pico melalui Supabase — berasingan daripada nod sungai yang dipantau di atas.';

  @override
  String get benchSensorWaiting => 'Menunggu bacaan...';

  @override
  String get benchSensorError => 'Tidak dapat menghubungi Supabase.';

  @override
  String get benchSensorUpdated => 'Dikemas kini';

  @override
  String get benchEvalTitle => 'Penilaian Model Risiko (Data Bangku)';

  @override
  String get benchEvalDescription =>
      'Menjalankan bacaan sensor sebenar rig bangku melalui model terlatih sebenar. Isikan apa yang rig tidak dapat kesan, kemudian jalankan — ini adalah inferens langsung terhadap model sebenar, bukan latihan semula.';

  @override
  String get benchEvalRainLabel => 'Hujan simulasi, sejam lepas (mm)';

  @override
  String get benchEvalHeightLabel => 'Ganti paras air';

  @override
  String get benchEvalSoilLabel => 'Ganti kelembapan tanah';

  @override
  String get benchEvalRunButton => 'Jalankan penilaian';

  @override
  String get benchEvalRunning => 'Menjalankan…';

  @override
  String get benchEvalErrorMsg =>
      'Tidak dapat menjalankan penilaian. Semak sambungan anda dan cuba lagi.';

  @override
  String get benchEvalResultTitle => 'Keputusan';

  @override
  String get benchEvalProbabilityLabel => 'Kebarangkalian Tier 2';

  @override
  String get benchEvalCorroborationLabel => 'Saluran pengesahan';

  @override
  String get benchEvalReadingUsedLabel => 'Bacaan yang dihantar ke model';

  @override
  String get benchEvalStubWarning =>
      'Ini dijalankan pada model ganti heuristik, bukan model terlatih sebenar — pelayan bahagian belakang tidak dapat memuatkannya kali ini. Nombor di atas hanya untuk ilustrasi.';

  @override
  String get rigModeTitle => 'Rig Langsung (Model Fasa)';

  @override
  String get rigModeDescription =>
      'Menjalankan seluruh aplikasi daripada sensor sebenar rig ujian. Model fasa membaca paras air, aliran, tanah dan kecondongan, lalu menunjukkan Normal, Perhatian, Amaran atau Berpindah.';

  @override
  String get rigWaiting => 'Menunggu bacaan daripada rig...';

  @override
  String get rigOffline => 'Tiada data terkini daripada rig';

  @override
  String get rigPhaseLabel => 'Fasa';

  @override
  String get rigReadoutTitle => 'Bacaan rig langsung';

  @override
  String get rigMetricLevel => 'Paras air';

  @override
  String get rigMetricLevelCaption => 'Atas paras sungai biasa';

  @override
  String get rigMetricFlow => 'Aliran air';

  @override
  String get rigMetricFlowCaption => 'Denyut sensor setiap 3 s';

  @override
  String get rigUnitPulses => 'denyut';

  @override
  String get rigMetricSoil => 'Kelembapan tanah';

  @override
  String get rigMetricSoilCaption => 'Isyarat sensor tanah';

  @override
  String get rigMetricTilt => 'Kecondongan cerun';

  @override
  String get rigMetricTiltCaption => 'Anjakan dari kedudukan asal';

  @override
  String get rigLastKnown => 'Terakhir diketahui';

  @override
  String get rigStatusLive => 'Langsung';

  @override
  String get rigStatusOffline => 'Rig di luar talian';

  @override
  String get rigLastData => 'data terakhir';

  @override
  String get riskScoreLabel => 'Skor risiko';

  @override
  String get riskSummaryTitle => 'Maksud keadaan ini';

  @override
  String get riskSummaryNormal => 'Paras air biasa. Tiada tindakan diperlukan.';

  @override
  String get riskSummaryWatch =>
      'Keadaan sedang berubah. Berwaspada dan terus semak skrin ini.';

  @override
  String get riskSummaryWarning =>
      'Bahaya semakin meningkat. Bersedia untuk berpindah ke kawasan yang lebih tinggi.';

  @override
  String get riskSummaryEvacuate =>
      'Keadaan berbahaya. Berpindah ke kawasan yang lebih tinggi sekarang.';

  @override
  String get riskSummaryOffline =>
      'Rig tidak menghantar data, jadi tiada penilaian langsung buat masa ini.';

  @override
  String get riskTrendsTitle => 'Trend';

  @override
  String get riskTrendsSubtitle =>
      '10 minit terakhir daripada rig, dikemas kini secara langsung';

  @override
  String get trendRisk => 'Tahap risiko';

  @override
  String get trendRiskHelp =>
      'Keputusan model dari semasa ke semasa. Lebih tinggi bermakna lebih bahaya.';

  @override
  String get trendLevelHelp =>
      'Air yang meningkat ialah tanda amaran paling kuat.';

  @override
  String get trendFlowHelp => 'Lonjakan mengejut bermakna air mengalir laju.';

  @override
  String get trendSoilHelp =>
      'Menunjukkan jumlah air yang telah diserap tanah.';

  @override
  String get trendTiltHelp =>
      'Pergerakan di sini mungkin bermakna cerun sedang bergerak.';

  @override
  String get trendNoData => 'Menunggu bacaan untuk melukis carta ini';

  @override
  String get trendNow => 'kini';

  @override
  String get howTitle => 'Bagaimana SIAGA membuat keputusan';

  @override
  String get howStep1 =>
      'Sensor pada rig mengukur paras air, aliran, kelembapan tanah dan kecondongan setiap 3 saat.';

  @override
  String get howStep2 =>
      'Model pembelajaran mesin, dilatih menggunakan rekod larian rig ini sendiri, membaca empat isyarat itu. Paras air paling diutamakan.';

  @override
  String get howStep3 =>
      'Ia memilih satu daripada empat tahap: Normal, Perhatian, Amaran atau Berpindah. Siren pada rig menjalankan model yang sama, jadi ia dan aplikasi ini mengikut bacaan yang sama.';

  @override
  String get mapLegendNode => 'Nod sensor';

  @override
  String get mapLegendAssembly => 'Tempat berkumpul';

  @override
  String get mapLegendYou => 'Anda';

  @override
  String get routeShortest => 'Laluan terpendek';

  @override
  String get routeByRoad => 'melalui jalan';

  @override
  String get routeStraight => 'Garis lurus, luar talian';

  @override
  String get routeSaved => 'Laluan tersimpan';

  @override
  String get routeWalk => 'berjalan kaki';

  @override
  String get routeCalculating => 'Mencari laluan terpendek...';

  @override
  String get routeAreaNote =>
      'Laluan bermula dari kawasan anda. Kedudukan tepat anda tidak pernah dihantar.';

  @override
  String get routeHere => 'Tunjuk laluan ke sini';

  @override
  String get routeNearest => 'Kembali ke laluan terpendek';

  @override
  String get nodeKindSensor => 'Nod sensor';

  @override
  String get nodeKindAssembly => 'Tempat berkumpul';

  @override
  String get mapAway => 'jarak garis lurus';

  @override
  String get placeDetails => 'Butiran dan trend';

  @override
  String get nodeKindDemo => 'Nod demo';

  @override
  String get nodeSimulatedNote =>
      'Disimulasikan untuk demonstrasi. Tahapnya mengikuti rig langsung, jadi anda boleh melihat amaran merebak di kawasan ini.';

  @override
  String get mapLegendDemo => 'Nod demo (simulasi)';
}
