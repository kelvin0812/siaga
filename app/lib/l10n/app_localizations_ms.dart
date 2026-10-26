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
      'Disimulasikan untuk demonstrasi. Tahapnya mengikuti rig langsung.';

  @override
  String get mapLegendDemo => 'Nod demo (simulasi)';

  @override
  String get riskViewing => 'Data daripada';

  @override
  String get nodePickerTitle => 'Pilih nod';

  @override
  String get nodePickerSearch => 'Cari ikut nama';

  @override
  String get nodeGroupSensor => 'Nod sensor';

  @override
  String get nodeGroupDemo => 'Nod demo (simulasi)';

  @override
  String get nodeAutoPick => 'Paling dekat dengan saya (automatik)';

  @override
  String get nodeNoMatch => 'Tiada nod yang sepadan.';

  @override
  String get simNoSensors =>
      'Ini nod demo, jadi ia tiada sensor. Tahapnya mengikuti rig langsung.';

  @override
  String get simShowRig => 'Tunjuk rig langsung';

  @override
  String get statusNormalT => 'Selamat buat masa ini';

  @override
  String get statusNormalD => 'Air berada pada paras biasa.';

  @override
  String get statusWatchT => 'Pantau keadaan';

  @override
  String get statusWatchD =>
      'Bacaan mula berubah. Semak semula tidak lama lagi.';

  @override
  String get statusWarningT => 'Bersedia untuk berpindah';

  @override
  String get statusWarningD =>
      'Air meningkat menghampiri paras berbahaya. Ketahui jalan ke kawasan yang lebih tinggi.';

  @override
  String get statusEvacT => 'Berpindah ke kawasan tinggi sekarang';

  @override
  String get statusEvacD =>
      'Keadaan berbahaya. Ikut laluan ke tempat berkumpul terdekat.';

  @override
  String get statusOfflineT => 'Tiada bacaan langsung';

  @override
  String get statusWaitingT => 'Menunggu rig';

  @override
  String get statusWaitingD =>
      'Belum ada data. Pastikan rig dihidupkan dan dalam talian.';

  @override
  String get statusDemoT => 'Nod demo';

  @override
  String get openMapBtn => 'Buka peta';

  @override
  String get howTitle2 => 'Bagaimana ini ditentukan?';

  @override
  String get howBody =>
      'Empat sensor pada rig memberi data kepada model yang dilatih menggunakan larian ujian rig ini sendiri, dan paras air paling diutamakan. Siren pada rig menjalankan model yang sama, jadi ia menunjukkan tahap yang sama seperti skrin ini.';

  @override
  String get viewInRisk => 'Tunjuk dalam Risiko Saya';

  @override
  String statusOfflineD(String ago) {
    return 'Bacaan terakhir daripada rig ialah $ago. SIAGA tidak dapat memastikan keadaan sekarang.';
  }

  @override
  String get simRigOffline =>
      'Rig langsung di luar talian, jadi nod demo kekal pada Normal.';

  @override
  String get popToggle => 'Penduduk';

  @override
  String get popLegendTitle => 'Penduduk setiap km²';

  @override
  String get popHigh => 'Tinggi';

  @override
  String get popMedium => 'Sederhana';

  @override
  String get popLow => 'Rendah';

  @override
  String get popSource => 'Anggaran penduduk: Kontur, CC BY 4.0';

  @override
  String get popDensityHigh => 'Kepadatan tinggi';

  @override
  String get popDensityMedium => 'Kepadatan sederhana';

  @override
  String get popDensityLow => 'Kepadatan rendah';

  @override
  String get popDensitySparse => 'Jarang penduduk';

  @override
  String popAround(String count, String km) {
    return 'Anggaran $count penduduk dalam lingkungan $km km';
  }

  @override
  String get settingsSectionDemo => 'Demonstrasi';

  @override
  String get settingsSectionDiagnostics => 'Diagnostik';

  @override
  String get settingsDiagnosticsHint =>
      'Untuk pasukan: bacaan mentah rig dan semakan model.';

  @override
  String get simulatePhaseTitle => 'Simulasi fasa';

  @override
  String get simulatePhaseHint =>
      'Paksa seluruh aplikasi ke satu fasa untuk melatih amaran. Peta, Risiko Saya dan amaran turut mengikutinya.';

  @override
  String get simulateLive => 'Langsung';

  @override
  String simulatingNow(String phase) {
    return 'Mensimulasikan fasa $phase. Bacaan rig sebenar dijeda.';
  }

  @override
  String get rigStatusSimulated => 'Simulasi';

  @override
  String get settingsLanguageAuto => 'Auto';

  @override
  String get settingsAboutTagline =>
      'Amaran awal banjir kilat dan tanah runtuh.';

  @override
  String get settingsAboutCredits =>
      'Data peta © penyumbang OpenStreetMap. Imej © Esri. Penduduk: Kontur (CC BY 4.0).';

  @override
  String get reportSubtitle =>
      'Nampak sesuatu berhampiran sungai, parit atau cerun? Maklumkan pihak berkuasa dengan beberapa ketikan.';

  @override
  String get reportStepWhat => 'Apa yang anda lihat?';

  @override
  String get reportStepWhere => 'Di mana?';

  @override
  String get reportStepDetails => 'Ada apa-apa untuk ditambah?';

  @override
  String get reportPrivacy =>
      'Hanya kod kawasan tempat ini dihantar, tidak sekali-kali kedudukan tepat anda.';

  @override
  String get reportNotePlaceholder =>
      'cth. air melimpasi jalan berhampiran jambatan';

  @override
  String get reportCategoryLandslideShort => 'Tanah runtuh';

  @override
  String get merangName => 'Merang';

  @override
  String get merangTagline =>
      'Kawan sungai anda. Saya terangkan apa yang aplikasi tunjukkan.';

  @override
  String get merangAsk => 'Tanya Merang';

  @override
  String get merangAskHint => 'Kenapa tahap ini? Apa patut saya buat?';

  @override
  String get merangHi => 'Hai, saya Merang!';

  @override
  String get merangDisclaimer =>
      'Saya hanya menerangkan apa yang aplikasi sudah tunjukkan. Saya tidak memutuskan atau menghantar amaran. Semak NADMA, MetMalaysia dan JPS untuk amaran rasmi.';

  @override
  String merangQWhy(String phase) {
    return 'Mengapa tahapnya $phase?';
  }

  @override
  String get merangQNext => 'Apa yang patut saya buat?';

  @override
  String get merangQData => 'Dari mana data ini datang?';

  @override
  String get merangQHow => 'Bagaimana anda berfungsi?';

  @override
  String merangWhyLevel(String height) {
    return 'Air berada $height cm di atas paras normalnya.';
  }

  @override
  String get merangWhyLevelNormal => 'Air berada pada paras normal.';

  @override
  String merangRiseFast(String rate) {
    return 'Air sedang naik, kira-kira $rate cm setiap minit.';
  }

  @override
  String get merangRiseSlow => 'Air naik perlahan-lahan.';

  @override
  String get merangRiseSteady => 'Air stabil buat masa ini.';

  @override
  String merangFalling(String rate) {
    return 'Air sedang surut, kira-kira $rate cm setiap minit.';
  }

  @override
  String get merangWhyBands =>
      'Pada rig ujian kami, Perhatian bermula sekitar 0.8 cm, Amaran sekitar 2.2 cm dan Berpindah sekitar 3.6 cm di atas paras normal.';

  @override
  String get merangWhyOthers =>
      'Aliran, tanah dan kecondongan juga dikira, tetapi paras air paling penting.';

  @override
  String merangWhyNoRig(String node, String phase) {
    return '$node berada pada tahap $phase. Saya hanya ada ringkasannya di sini, bukan bacaan sensor mentah.';
  }

  @override
  String merangWhyStale(String ago) {
    return 'Rig tidak menghantar apa-apa selama $ago, jadi tiada bacaan baharu. Aplikasi menunjukkan Normal dan tidak mengeluarkan amaran daripada data lama.';
  }

  @override
  String get merangWhySimulated =>
      'Tahap ini ditetapkan secara manual di Tetapan untuk demonstrasi. Nombor ialah nilai biasa bagi tahap itu, bukan bacaan langsung.';

  @override
  String get merangWhyDemoNode =>
      'Ini nod demo. Tahapnya mengikut rig langsung.';

  @override
  String get merangNextNormal =>
      'Tiada apa-apa untuk dibuat sekarang. Biarkan notifikasi hidup, dan semak semula jika hujan lebat bermula.';

  @override
  String get merangNextWatch =>
      'Berwaspada. Pantau aplikasi dan cuaca, dan kumpulkan barang penting anda.';

  @override
  String get merangNextWarning =>
      'Bersedia untuk berpindah. Tahu laluan anda, cas telefon, dan buka peta untuk mencari tempat berkumpul terdekat.';

  @override
  String get merangNextEvacuate =>
      'Berpindah sekarang. Ikut laluan ke tempat berkumpul terdekat dan dengar arahan rasmi.';

  @override
  String get merangNextStale =>
      'Data ini sudah lama, jadi jangan bergantung padanya. Semak saluran rasmi.';

  @override
  String get merangNextOfficial =>
      'Sentiasa sahkan dengan NADMA, MetMalaysia atau JPS. SIAGA membantu anda membuat keputusan; ia bukan amaran rasmi.';

  @override
  String get merangDataRig =>
      'Nombor ini datang daripada rig ujian kami. Sensornya menghantar data kepada ESP32, yang menyimpan setiap bacaan ke jadual dalam talian kami (Supabase). Aplikasi menyemak baris baharu setiap 3 saat.';

  @override
  String merangDataAgo(String ago) {
    return 'Bacaan terakhir ialah $ago yang lalu.';
  }

  @override
  String get merangDataSim =>
      'Nod ini disimulasikan untuk demo, jadi tiada sensor di belakangnya.';

  @override
  String get merangDataOther =>
      'Bacaan ini datang daripada nod sensor kami, melalui bahagian belakang kami.';

  @override
  String get merangHow =>
      'Saya Merang. Saya membaca nombor yang sama seperti anda dan menukarnya kepada kata-kata mudah. Saya berjalan pada telefon anda, jadi saya berfungsi tanpa talian dan lokasi anda tidak pernah keluar. Sensor dan peraturan yang memutuskan amaran, bukan saya.';

  @override
  String get merangAiTag => 'Ditulis oleh AI (Gemini). Semak saluran rasmi.';

  @override
  String get merangInputHint => 'Tanya Merang tentang bacaan ini…';

  @override
  String get merangSend => 'Hantar';

  @override
  String get merangHello =>
      'Hai, saya Merang! Tekan satu soalan di bawah, atau taip soalan anda sendiri.';

  @override
  String get merangNoAi =>
      'Saya tidak dapat menghubungi otak AI saya sekarang, jadi saya hanya boleh menjawab soalan di bawah. Sila tekan salah satu.';

  @override
  String get merangTypedNote =>
      'Soalan yang ditaip dihantar kepada Google Gemini untuk dijawab. Sila jangan taip butiran peribadi.';

  @override
  String get merangQTips => 'Petua keselamatan';

  @override
  String get merangQWhere => 'Ke mana saya patut pergi?';

  @override
  String get merangQBring => 'Apa yang patut saya bawa?';

  @override
  String get merangQStuck => 'Bagaimana jika saya tidak boleh keluar?';

  @override
  String get merangTips1 =>
      'Kenali laluan ke tempat tinggi sebelum air naik. Buka tab Peta dan cari tempat berkumpul yang terdekat.';

  @override
  String get merangTips2 =>
      'Jangan berjalan, berenang atau memandu melalui air banjir. Air deras setinggi 15 cm pun boleh menjatuhkan anda.';

  @override
  String get merangTips3 =>
      'Jauhi tebing sungai, parit dan cerun curam. Selepas hujan lebat, rekahan baharu, pokok condong atau air keruh yang mengalir dari cerun boleh menandakan tanah runtuh.';

  @override
  String get merangTips4 =>
      'Jika air masuk ke rumah, matikan elektrik di suis utama dan jangan sentuh peralatan elektrik yang basah. Pastikan telefon dicas dan notifikasi dihidupkan.';

  @override
  String get merangWhere1 =>
      'Pergi ke tempat berkumpul yang paling dekat. Buka tab Peta dan ketik Lihat laluan pemindahan untuk melihat laluan terpendek dan masa berjalan kaki.';

  @override
  String get merangWhere2 =>
      'Laluan bermula dari kawasan anda, bukan kedudukan tepat anda. Tanpa isyarat, anda masih mendapat garis lurus, atau laluan yang anda simpan tadi.';

  @override
  String get merangBring1 =>
      'Hanya yang sempat anda ambil dalam seminit: telefon dan pengecas, kad pengenalan, ubat, sedikit air dan lampu suluh.';

  @override
  String get merangBring2 =>
      'Letakkan dokumen dalam beg kalis air jika ada. Pergi bersama keluarga dan jiran, dan jangan patah balik untuk mengambil barang.';

  @override
  String get merangStuck1 =>
      'Jangan berjalan, berenang atau memandu melalui air banjir. Naik ke tingkat paling tinggi bangunan yang kukuh, jauh dari sungai, parit dan cerun.';

  @override
  String get merangStuck2 =>
      'Hubungi 999 dan beritahu mereka di mana anda berada. Pastikan telefon anda dicas dan tunggu bantuan.';

  @override
  String get mapFaceNorth => 'Hadap utara';

  @override
  String get riskNoLive => 'TIADA DATA LANGSUNG';

  @override
  String riskLastKnown(String level) {
    return 'Terakhir diketahui: $level';
  }

  @override
  String get riskTrendsStale => 'Bacaan terakhir sebelum rig senyap';

  @override
  String get mapKey => 'Kunci peta';
}
