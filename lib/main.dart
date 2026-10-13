import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  runApp(const DrillMasterApp());
}

class DrillMasterApp extends StatelessWidget {
  const DrillMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aviation DrillTech CAD Studio',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F141C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFFFFB300),
          surface: Color(0xFF171E28),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF171E28),
          elevation: 0,
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DrillTechnicalDrawingScreen(),
    UnitConverterScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF171E28),
        indicatorColor: const Color(0xFF00E5FF).withOpacity(0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.architecture_outlined),
            selectedIcon: Icon(Icons.architecture, color: Color(0xFF00E5FF)),
            label: '1/4"-28 Havacilik Matkabi',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_outlined),
            selectedIcon: Icon(Icons.swap_horiz, color: Color(0xFF00E5FF)),
            label: 'Birim & Tel/Harf Tablosu',
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 1. 1/4"-28 THREADED SHANK TEKNIK RESIM & TAM PARAMETRIK SAP DUZENLEME EKRANI
// =============================================================================

class DrillTechnicalDrawingScreen extends StatefulWidget {
  const DrillTechnicalDrawingScreen({super.key});

  @override
  State<DrillTechnicalDrawingScreen> createState() =>
      _DrillTechnicalDrawingScreenState();
}

class _DrillTechnicalDrawingScreenState
    extends State<DrillTechnicalDrawingScreen>
    with SingleTickerProviderStateMixin {
  // ISO / DIN Takım ve Matkap Parametreleri (mm)
  double drillDiameter = 3.26; // d1: Matkap / Kesme Çapı (h9)
  double totalLength = 54.0; // l1: Tam Boy
  double fluteLength = 22.0; // l2: Kesme Boyu
  double reachLength = 28.0; // l3: Boyunlu / Kullanılabilir Boy (KIRMIZI VURGULU)
  double neckDiameter = 3.00; // d3: Boyun Çapı
  double shankDiameter = 6.35; // d2: Sap Çapı (h6)
  double pointAngle = 180.0; // Uç Açısı (Varsayılan: Düz Freze 180°, listeden değiştirilebilir)

  // Görünüm & Katalog Ayarları
  bool isCatalogWhiteMode = true; // Varsayılan: Katalog Beyazı
  String toolTipType = 'endmill'; // 'endmill' (Düz Freze) veya 'drill135', 'drill118', 'drill140', 'drill90', 'drill60'
  String dimensionDisplayMode = 'both'; // 'both', 'symbols', 'values'
  final TransformationController _transformController = TransformationController();

  // 3D Teknik Resim & Model Durumu
  bool is3DMode = false; // 2D ISO Çizim vs 3D CAD Modeli
  double rotX = 0.40; // 3D Pitch
  double rotY = -0.70; // 3D Yaw
  double rotZ = 0.0;
  double zoom3D = 1.0;
  bool isAutoRotating = false;
  bool is3DWireframe = false;
  String renderStyle3D = 'solid'; // 'solid' (Katı Model) veya 'wireframe' (Tel Kafes)
  late final AnimationController _autoRotateController;

  // Uç Açısı ve Geometri Listesi
  final List<Map<String, dynamic>> standardTipAngles = [
    {
      'id': 'endmill',
      'label': '⬛ Düz Freze Ucu (0° / 180° - End Mill)',
      'shortLabel': '⬛ Düz Freze',
      'angle': 180.0,
      'toolTipType': 'endmill',
      'desc': 'Düz tabanlı frezeleme, havşa yuvası düzeltme ve yüzey işleme.',
    },
    {
      'id': 'drill135',
      'label': '📐 135° Matkap Ucu (Havacılık / Split Point)',
      'shortLabel': '📐 135° Havacılık',
      'angle': 135.0,
      'toolTipType': 'drill135',
      'desc': 'NAS 907/965 standardı. Titanyum, Inconel ve paslanmaz çelik için kaymayı önleyen çapraz bileme (split point).',
    },
    {
      'id': 'drill118',
      'label': '📐 118° Standart Matkap (Genel Amaçlı)',
      'shortLabel': '📐 118° Standart',
      'angle': 118.0,
      'toolTipType': 'drill118',
      'desc': 'DIN 338 standardı. Yapı çelikleri, pirinç, yumuşak metaller ve plastik delme.',
    },
    {
      'id': 'drill140',
      'label': '📐 140° Yüksek Hız Karbür Matkap',
      'shortLabel': '📐 140° Karbür',
      'angle': 140.0,
      'toolTipType': 'drill140',
      'desc': 'DIN 6537 standardı. CNC rijit işleme, derin delikler ve yüksek kesme hızları.',
    },
    {
      'id': 'spot90',
      'label': '📐 90° Havşa ve Punta (Countersink / Spotting)',
      'shortLabel': '📐 90° Havşa',
      'angle': 90.0,
      'toolTipType': 'drill90',
      'desc': '90° perçin ve vida havşası açma, delik ağzı pahı kırma.',
    },
    {
      'id': 'center60',
      'label': '📐 60° Torna Punta / Merkezleme Matkabı',
      'shortLabel': '📐 60° Merkezleme',
      'angle': 60.0,
      'toolTipType': 'drill60',
      'desc': 'DIN 333 Tip A. Torna punta yuvası ve hassas eksen kılavuzlama.',
    },
  ];
  String selectedTipId = 'endmill';

  // Hammadde ve Sertlik Listesi
  final List<Map<String, dynamic>> toolMaterials = [
    {
      'id': 'm42',
      'name': 'HSS-Co %8 (Cobalt M42 / 1.3247)',
      'standard': 'NAS 907 Tip J / NAS 965 Tip D',
      'hardness': '67 - 69 HRC',
      'hardnessHv': '900 - 980 HV',
      'hardnessHra': '85.5 - 86.5 HRA',
      'temp': '650°C',
      'badge': 'Havacılık Standardı',
      'badgeColor': const Color(0xFF00E5FF),
      'app': 'Titanyum Ti-6Al-4V, Paslanmaz Çelik (316/321), Inconel 718',
    },
    {
      'id': 'm35',
      'name': 'HSS-Co %5 (Cobalt M35 / HSSE / 1.3243)',
      'standard': 'DIN 338 Co5 / DIN 1897',
      'hardness': '64 - 66 HRC',
      'hardnessHv': '800 - 870 HV',
      'hardnessHra': '83.5 - 85.0 HRA',
      'temp': '600°C',
      'badge': 'Aşınma Dirençli',
      'badgeColor': const Color(0xFFFFB300),
      'app': 'Yüksek mukavemetli çelikler, korozyon dayanımlı alaşımlar',
    },
    {
      'id': 'm2',
      'name': 'HSS (M2 / 1.3343 - Standart Yüksek Hız Çeliği)',
      'standard': 'DIN 338 Tip N / NAS 907 Tip A',
      'hardness': '62 - 64 HRC',
      'hardnessHv': '750 - 810 HV',
      'hardnessHra': '82.0 - 83.5 HRA',
      'temp': '550°C',
      'badge': 'Ekonomik / Standart',
      'badgeColor': Colors.grey,
      'app': 'Genel yapı çelikleri, dökme demir, pirinç, yumuşak metaller',
    },
    {
      'id': 'vhm',
      'name': 'VHM Solid Karbür (Mikro Taneli Tungsten Karbür)',
      'standard': 'DIN 6537 / ISO K10-K40',
      'hardness': '91 - 93 HRA (~74 HRC)',
      'hardnessHv': '1600 - 1850 HV',
      'hardnessHra': '91.5 - 93.0 HRA',
      'temp': '900°C',
      'badge': 'Ultra Sert / CNC',
      'badgeColor': const Color(0xFF76FF03),
      'app': 'Havacılık kompozitleri (CFRP), Karbon fiber, Titanyum ve CNC seri üretim',
    },
    {
      'id': 'pm_hss',
      'name': 'PM-HSS Toz Metalurjisi (ASP 2030 / ASP 2060)',
      'standard': 'ASTM A600 / Yüksek Tokluk',
      'hardness': '66 - 68 HRC',
      'hardnessHv': '880 - 950 HV',
      'hardnessHra': '85.0 - 86.0 HRA',
      'temp': '640°C',
      'badge': 'Kırılma Dirençli',
      'badgeColor': const Color(0xFFE040FB),
      'app': 'Kesintili kesme, derin delik ve darbe alan zorlu havacılık parçaları',
    },
  ];

  final List<Map<String, dynamic>> toolCoatings = [
    {
      'id': 'tialn',
      'name': 'TiAlN (Titanyum Alüminyum Nitrür - Havacılık)',
      'shortName': 'TiAlN',
      'color': const Color(0xFF3F4E5E),
      'hardness': '3300 HV',
      'temp': '800°C',
      'desc': 'Sert metaller, titanyum ve paslanmaz çelik için üstün ısı direnci.',
    },
    {
      'id': 'altin',
      'name': 'AlTiN (Alüminyum Titanyum Nitrür - Nano)',
      'shortName': 'AlTiN',
      'color': const Color(0xFF22262C),
      'hardness': '3600 HV',
      'temp': '900°C',
      'desc': 'Kuru işleme, nikel bazlı süperalaşımlar ve ekstrem aşınma dayanımı.',
    },
    {
      'id': 'tin',
      'name': 'TiN (Titanyum Nitrür - Altın Sarısı)',
      'shortName': 'TiN',
      'color': const Color(0xFFFFC107),
      'hardness': '2300 HV',
      'temp': '550°C',
      'desc': 'Sürtünmeyi azaltır, talaş yapışmasını önler, genel çelikler.',
    },
    {
      'id': 'black_oxide',
      'name': 'Siyah Oksit (Buhar Meneviş - Black Oxide)',
      'shortName': 'Siyah Oksit',
      'color': const Color(0xFF1E242B),
      'hardness': 'Ana Malzeme',
      'temp': '400°C',
      'desc': 'Soğutma sıvısı tutuşu mükemmel, gerilim giderme, kaynaklanmayı önler.',
    },
    {
      'id': 'bright',
      'name': 'Parlak / Kaplamasız (Bright Finish)',
      'shortName': 'Parlak Çelik',
      'color': const Color(0xFFB0BEC5),
      'hardness': 'Ana Malzeme',
      'temp': 'Standart',
      'desc': 'Alüminyum ve yumuşak metallerde talaş sarılmasını engeller.',
    },
  ];

  String selectedMaterialId = 'm42';
  String selectedCoatingId = 'tialn';

  // Sap (Shank) Parametreleri (1/4"-28 Vidalı Sap - NAS 965 Standardı)
  bool hasThreadedShank = true; // Varsayılan olarak vidalı sap açık
  double threadLength = 8.70; // Dişli Bölüm Boyu (mm) - Standart 1/4"-28 = 8.70 mm
  double threadDiameter = 6.35; // Diş Çapı (mm) - 1/4" = 6.35 mm
  double hexLength = 7.94; // Kalın Somun Kafa Boyu (mm) - 5/16" = 7.94 mm
  double hexWidth = 7.94; // Kalın Somun Kafa Çapı / Anahtar Ağzı (mm) - 5/16" = 7.94 mm

  String selectedModel = '#30 (Ø3.26mm / 0.1285")';

  // Matkap Gövdesi Controller'lar
  final _diamMmController = TextEditingController(text: '3.26');
  final _totalLenMmController = TextEditingController(text: '54.0');
  final _fluteLenMmController = TextEditingController(text: '22.0');
  final _reachLenMmController = TextEditingController(text: '28.0');
  final _neckDiamMmController = TextEditingController(text: '3.00');
  final _shankDiamMmController = TextEditingController(text: '6.35');

  final _diamInController = TextEditingController(text: '0.1285');
  final _totalLenInController = TextEditingController(text: '2.125');
  final _fluteLenInController = TextEditingController(text: '0.875');
  final _reachLenInController = TextEditingController(text: '1.102');

  // Sap Bölümü Controller'lar (Dişli Yer ve Kalın Yer)
  final _threadLenController = TextEditingController(text: '8.70');
  final _threadDiamController = TextEditingController(text: '6.35');
  final _hexLenController = TextEditingController(text: '7.94');
  final _hexWidthController = TextEditingController(text: '7.94');

  final List<Map<String, dynamic>> aviationPresets = [
    {
      'label': '#40 (Ø2.49mm / 0.0980")',
      'dMm': 2.49,
      'dIn': '0.0980',
      'lMm': 54.0,
      'lIn': '2.125',
      'fluteMm': 18.0,
      'fluteIn': '0.700',
      'reachMm': 24.0,
      'neckMm': 2.30,
      'shankMm': 6.35,
      'angle': 135.0,
    },
    {
      'label': '#30 (Ø3.26mm / 0.1285")',
      'dMm': 3.26,
      'dIn': '0.1285',
      'lMm': 54.0,
      'lIn': '2.125',
      'fluteMm': 22.0,
      'fluteIn': '0.875',
      'reachMm': 28.0,
      'neckMm': 3.00,
      'shankMm': 6.35,
      'angle': 135.0,
    },
    {
      'label': '#21 (Ø4.04mm / 0.1590")',
      'dMm': 4.04,
      'dIn': '0.1590',
      'lMm': 57.0,
      'lIn': '2.250',
      'fluteMm': 25.0,
      'fluteIn': '1.000',
      'reachMm': 31.0,
      'neckMm': 3.80,
      'shankMm': 6.35,
      'angle': 135.0,
    },
    {
      'label': '#10 (Ø4.92mm / 0.1935")',
      'dMm': 4.92,
      'dIn': '0.1935',
      'lMm': 63.5,
      'lIn': '2.500',
      'fluteMm': 28.0,
      'fluteIn': '1.125',
      'reachMm': 35.0,
      'neckMm': 4.60,
      'shankMm': 6.35,
      'angle': 135.0,
    },
    {
      'label': '1/4" (Ø6.35mm / 0.2500")',
      'dMm': 6.35,
      'dIn': '0.2500',
      'lMm': 70.0,
      'lIn': '2.750',
      'fluteMm': 32.0,
      'fluteIn': '1.250',
      'reachMm': 40.0,
      'neckMm': 5.80,
      'shankMm': 6.35,
      'angle': 135.0,
    },
  ];

  @override
  void initState() {
    super.initState();
    _autoRotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..addListener(() {
        if (isAutoRotating && is3DMode) {
          setState(() {
            rotY += 0.02;
          });
        }
      });
  }

  @override
  void dispose() {
    _autoRotateController.dispose();
    _diamMmController.dispose();
    _totalLenMmController.dispose();
    _fluteLenMmController.dispose();
    _reachLenMmController.dispose();
    _neckDiamMmController.dispose();
    _shankDiamMmController.dispose();

    _diamInController.dispose();
    _totalLenInController.dispose();
    _fluteLenInController.dispose();
    _reachLenInController.dispose();

    _threadLenController.dispose();
    _threadDiamController.dispose();
    _hexLenController.dispose();
    _hexWidthController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _applyTipAngle(Map<String, dynamic> item) {
    setState(() {
      selectedTipId = item['id'] as String;
      pointAngle = (item['angle'] as num).toDouble();
      toolTipType = item['toolTipType'] as String;
    });
  }

  void _reset3DView() {
    setState(() {
      rotX = 0.40;
      rotY = -0.70;
      rotZ = 0.0;
      zoom3D = 1.0;
    });
  }

  void _set3DCameraPreset(String preset) {
    setState(() {
      switch (preset) {
        case 'iso':
          rotX = 0.40;
          rotY = -0.70;
          rotZ = 0.0;
          break;
        case 'front':
          rotX = 0.0;
          rotY = 0.0;
          rotZ = 0.0;
          break;
        case 'top':
          rotX = math.pi / 2;
          rotY = 0.0;
          rotZ = 0.0;
          break;
        case 'tip':
          rotX = 0.0;
          rotY = -math.pi / 2;
          rotZ = 0.0;
          break;
        case 'shank':
          rotX = 0.0;
          rotY = math.pi / 2;
          rotZ = 0.0;
          break;
      }
    });
  }

  void _toggleAutoRotate() {
    setState(() {
      isAutoRotating = !isAutoRotating;
      if (isAutoRotating) {
        _autoRotateController.repeat();
      } else {
        _autoRotateController.stop();
      }
    });
  }

  void _zoomIn() {
    setState(() {
      if (is3DMode) {
        zoom3D = (zoom3D * 1.2).clamp(0.4, 4.0);
      } else {
        _transformController.value = _transformController.value.scaled(1.2, 1.2, 1.0);
      }
    });
  }

  void _zoomOut() {
    setState(() {
      if (is3DMode) {
        zoom3D = (zoom3D * 0.833).clamp(0.4, 4.0);
      } else {
        _transformController.value = _transformController.value.scaled(0.833, 0.833, 1.0);
      }
    });
  }

  void _resetZoom() {
    setState(() {
      if (is3DMode) {
        _reset3DView();
      } else {
        _transformController.value = Matrix4.identity();
      }
    });
  }

  void _applyPreset(Map<String, dynamic> item) {
    setState(() {
      selectedModel = item['label'];
      drillDiameter = item['dMm'];
      totalLength = item['lMm'];
      fluteLength = item['fluteMm'];
      pointAngle = item['angle'];
      reachLength = (item['reachMm'] as num?)?.toDouble() ?? (fluteLength + 6.0);
      neckDiameter = (item['neckMm'] as num?)?.toDouble() ?? (drillDiameter * 0.92);
      shankDiameter = (item['shankMm'] as num?)?.toDouble() ?? (hasThreadedShank ? 6.35 : (drillDiameter > 6.0 ? drillDiameter : 6.35));

      _diamMmController.text = drillDiameter.toStringAsFixed(2);
      _totalLenMmController.text = totalLength.toStringAsFixed(1);
      _fluteLenMmController.text = fluteLength.toStringAsFixed(1);
      _reachLenMmController.text = reachLength.toStringAsFixed(1);
      _neckDiamMmController.text = neckDiameter.toStringAsFixed(2);
      _shankDiamMmController.text = shankDiameter.toStringAsFixed(2);

      _diamInController.text = item['dIn'];
      _totalLenInController.text = item['lIn'];
      _fluteLenInController.text = item['fluteIn'];
      _reachLenInController.text = (reachLength / 25.4).toStringAsFixed(3);
    });
  }

  void _updateDrillFromMm() {
    setState(() {
      drillDiameter = double.tryParse(_diamMmController.text) ?? drillDiameter;
      totalLength = double.tryParse(_totalLenMmController.text) ?? totalLength;
      fluteLength = double.tryParse(_fluteLenMmController.text) ?? fluteLength;
      reachLength = double.tryParse(_reachLenMmController.text) ?? reachLength;
      neckDiameter = double.tryParse(_neckDiamMmController.text) ?? neckDiameter;
      shankDiameter = double.tryParse(_shankDiamMmController.text) ?? shankDiameter;

      _diamInController.text = (drillDiameter / 25.4).toStringAsFixed(4);
      _totalLenInController.text = (totalLength / 25.4).toStringAsFixed(3);
      _fluteLenInController.text = (fluteLength / 25.4).toStringAsFixed(3);
      _reachLenInController.text = (reachLength / 25.4).toStringAsFixed(3);
    });
  }

  void _updateDrillFromInch() {
    setState(() {
      final inD = double.tryParse(_diamInController.text);
      final inL = double.tryParse(_totalLenInController.text);
      final inF = double.tryParse(_fluteLenInController.text);
      final inR = double.tryParse(_reachLenInController.text);

      if (inD != null) drillDiameter = inD * 25.4;
      if (inL != null) totalLength = inL * 25.4;
      if (inF != null) fluteLength = inF * 25.4;
      if (inR != null) reachLength = inR * 25.4;

      _diamMmController.text = drillDiameter.toStringAsFixed(2);
      _totalLenMmController.text = totalLength.toStringAsFixed(1);
      _fluteLenMmController.text = fluteLength.toStringAsFixed(1);
      _reachLenMmController.text = reachLength.toStringAsFixed(1);
    });
  }

  void _updateShankParams() {
    setState(() {
      threadLength = double.tryParse(_threadLenController.text) ?? threadLength;
      threadDiameter = double.tryParse(_threadDiamController.text) ?? threadDiameter;
      hexLength = double.tryParse(_hexLenController.text) ?? hexLength;
      hexWidth = double.tryParse(_hexWidthController.text) ?? hexWidth;
    });
  }

  // Teknik Resmi Doğrudan Açma / Yazdırma Motoru
  Future<void> _openTechnicalDrawing() async {
    try {
      final pdfBytes = await _buildPdfDocument(PdfPageFormat.a4.landscape);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'ISO_Catalog_Drill_${drillDiameter.toStringAsFixed(2)}mm.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Oluşturma Hatası: $e')),
        );
      }
    }
  }

  Future<Uint8List> _buildPdfDocument(PdfPageFormat format) async {
    final doc = pw.Document();
    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(841.89, 595.28, marginAll: 20),
        build: (pw.Context context) {
          final pdfFont = font.getFont(context);
          final pdfFontBold = fontBold.getFont(context);

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. Antet Ust Bilgi (Engineering Catalog Header)
              pw.Container(
                width: 800,
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.black, width: 1.2),
                ),
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'TEKNIK IMALAT VE KATALOG RESMI (ISO 13399 / NAS 907)',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          hasThreadedShank
                              ? '1/4"-28 VIDALI SAP HAVACILIK MATKABI (AEROSPACE NAS 907 TYPE J / 53-2971)'
                              : (toolTipType == 'endmill'
                                  ? 'DUZ SILINDIRIK SAPLI FREZE / MATKAP (DIN 6527 / NAS 907)'
                                  : '135° SPLIT POINT HAVACILIK MATKABI (NAS 907 TYPE B/J)'),
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'KOD: ${hasThreadedShank ? "53-2971 (VIDALI)" : "NAS-907"} | d1: ${drillDiameter.toStringAsFixed(2)} mm (h9) | d2: ${shankDiameter.toStringAsFixed(2)} mm (h6)',
                          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text('TARIH: ${DateTime.now().toString().substring(0, 10)} | REV: ISO-06', style: const pw.TextStyle(fontSize: 7.5)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),

              // 2. CAD Cizim Kutusu (White Catalog Box)
              pw.Container(
                width: 800,
                height: 250,
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  border: pw.Border.all(color: PdfColors.black, width: 1.2),
                ),
                alignment: pw.Alignment.center,
                child: pw.CustomPaint(
                  size: const PdfPoint(760, 230),
                  painter: (PdfGraphics canvas, PdfPoint size) {
                    _drawAeroPdfDrill(canvas, size, pdfFont, pdfFontBold);
                  },
                ),
              ),
              pw.SizedBox(height: 6),

              // 3. Alt Tablo & Teknik Ozellikler (ISO 13399 Specs)
              pw.Container(
                width: 800,
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // 6 Kolonlu ISO Tablosu (l3 Kirmizi Vurgulu!)
                    pw.SizedBox(
                      width: 530,
                      child: pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey600),
                        columnWidths: const {
                          0: pw.FlexColumnWidth(1.1),
                          1: pw.FlexColumnWidth(1.1),
                          2: pw.FlexColumnWidth(1.0),
                          3: pw.FlexColumnWidth(1.1),
                          4: pw.FlexColumnWidth(1.3),
                          5: pw.FlexColumnWidth(1.1),
                        },
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('d1 (h9)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('d2 (h6)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('d3 (Boyun)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('l2 (Kesme)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('l3 (Kullanilabilir)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.red900))),
                              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('l1 (Tam Boy)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                            ],
                          ),
                          pw.TableRow(
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('${drillDiameter.toStringAsFixed(2)} mm\n[${(drillDiameter / 25.4).toStringAsFixed(4)}"]', style: const pw.TextStyle(fontSize: 7.5))),
                              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('${shankDiameter.toStringAsFixed(2)} mm\n[${(shankDiameter / 25.4).toStringAsFixed(3)}"]', style: const pw.TextStyle(fontSize: 7.5))),
                              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('${neckDiameter.toStringAsFixed(2)} mm', style: const pw.TextStyle(fontSize: 7.5))),
                              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('${fluteLength.toStringAsFixed(1)} mm\n[${(fluteLength / 25.4).toStringAsFixed(3)}"]', style: const pw.TextStyle(fontSize: 7.5))),
                              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('${reachLength.toStringAsFixed(1)} mm\n[${(reachLength / 25.4).toStringAsFixed(3)}"]', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.red900))),
                              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('${totalLength.toStringAsFixed(1)} mm\n[${(totalLength / 25.4).toStringAsFixed(3)}"]', style: const pw.TextStyle(fontSize: 7.5))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(
                      width: 260,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(4),
                        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey600)),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Standart: ${hasThreadedShank ? "NAS 965 Tip B/D (1/4\"-28)" : "DIN 6527 / ISO 13399"}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            pw.Text('Hammadde: ${toolMaterials.firstWhere((m) => m['id'] == selectedMaterialId)['name']}', style: const pw.TextStyle(fontSize: 7.5)),
                            pw.Text('Sertlik: ${toolMaterials.firstWhere((m) => m['id'] == selectedMaterialId)['hardness']}', style: const pw.TextStyle(fontSize: 7.5)),
                            pw.Text('Kaplama: ${toolCoatings.firstWhere((c) => c['id'] == selectedCoatingId)['name']}', style: const pw.TextStyle(fontSize: 7.5)),
                            pw.Text('Uç Geometrisi: ${standardTipAngles.firstWhere((t) => t['id'] == selectedTipId)['shortLabel']} ($pointAngle°)', style: const pw.TextStyle(fontSize: 7.5)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  void _drawAeroPdfDrill(PdfGraphics canvas, PdfPoint size, PdfFont pdfFont, PdfFont pdfFontBold) {
    final originY = size.y * 0.44;
    const double tipX = 80.0;
    final double drawWidth = size.x - 160.0;
    final double scaleX = drawWidth / totalLength;

    final double d1Px = (drillDiameter * 6.5).clamp(22.0, 48.0);
    final double halfD1 = d1Px / 2;
    final double d2Px = (shankDiameter * 6.5).clamp(22.0, 52.0);
    final double halfD2 = d2Px / 2;
    final double d3Px = (neckDiameter * 6.5).clamp(16.0, 42.0);
    final double halfD3 = d3Px / 2;
    final double maxHalfH = math.max(halfD1, math.max(halfD2, halfD3));

    final double pointLenPx = (toolTipType == 'endmill')
        ? 0.0
        : (halfD1 / math.tan((pointAngle / 2) * math.pi / 180)).clamp(4.0, 18.0);

    final double fluteStartX = tipX + pointLenPx;
    final double fluteEndX = tipX + (fluteLength * scaleX);
    final double reachEndX = tipX + (reachLength * scaleX);
    final double shankEndX = tipX + (totalLength * scaleX);

    // 1. Tool Shading / Fill
    canvas.setColor(PdfColors.grey100);
    canvas.drawRect(fluteStartX, originY - halfD1, fluteEndX - fluteStartX, d1Px);
    canvas.drawRect(fluteEndX, originY - halfD3, reachEndX - fluteEndX, d3Px);
    canvas.drawRect(reachEndX, originY - halfD2, shankEndX - reachEndX, d2Px);
    canvas.fillPath();

    // 2. Tool Outlines (Solid Black)
    canvas.setColor(PdfColors.black);
    canvas.setLineWidth(1.3);

    // Top & Bottom Flute Contour
    canvas.moveTo(fluteStartX, originY - halfD1); canvas.lineTo(fluteEndX, originY - halfD1);
    canvas.moveTo(fluteStartX, originY + halfD1); canvas.lineTo(fluteEndX, originY + halfD1);

    // Tip Contour
    if (toolTipType == 'endmill') {
      canvas.moveTo(tipX, originY - halfD1 + 2);
      canvas.lineTo(tipX + 2, originY - halfD1);
      canvas.moveTo(tipX, originY + halfD1 - 2);
      canvas.lineTo(tipX + 2, originY + halfD1);
      canvas.moveTo(tipX, originY - halfD1 + 2);
      canvas.lineTo(tipX, originY + halfD1 - 2);
    } else {
      canvas.moveTo(fluteStartX, originY - halfD1);
      canvas.lineTo(tipX, originY);
      canvas.lineTo(fluteStartX, originY + halfD1);
    }
    canvas.strokePath();

    // Helical Flutes (3 sweeps with double margin lines)
    final fluteBodyLen = fluteEndX - fluteStartX;
    final waveStep = fluteBodyLen / 3.0;
    canvas.setColor(PdfColors.black);
    canvas.setLineWidth(1.1);

    for (int i = 0; i < 3; i++) {
      final wx = fluteStartX + i * waveStep;
      canvas.moveTo(wx, originY - halfD1);
      canvas.curveTo(wx + waveStep * 0.45, originY - halfD1 * 0.3, wx + waveStep * 0.55, originY + halfD1 * 0.3, wx + waveStep, originY + halfD1);
      canvas.strokePath();

      // Parallel margin line
      canvas.setColor(PdfColors.grey600);
      canvas.setLineWidth(0.8);
      canvas.moveTo(wx + 2.5, originY - halfD1);
      canvas.curveTo(wx + waveStep * 0.45 + 2.5, originY - halfD1 * 0.3, wx + waveStep * 0.55 + 2.5, originY + halfD1 * 0.3, wx + waveStep + 2.5, originY + halfD1);
      canvas.strokePath();
      canvas.setColor(PdfColors.black);
      canvas.setLineWidth(1.1);
    }

    // Flute Runout Fillet to Neck
    canvas.moveTo(fluteEndX, originY - halfD1);
    canvas.curveTo(fluteEndX + 3, originY - halfD3, fluteEndX + 4, originY - halfD3, fluteEndX + 6, originY - halfD3);
    canvas.moveTo(fluteEndX, originY + halfD1);
    canvas.curveTo(fluteEndX + 3, originY + halfD3, fluteEndX + 4, originY + halfD3, fluteEndX + 6, originY + halfD3);
    canvas.strokePath();

    // Neck Body Lines
    canvas.moveTo(fluteEndX + 6, originY - halfD3); canvas.lineTo(reachEndX - 3, originY - halfD3);
    canvas.moveTo(fluteEndX + 6, originY + halfD3); canvas.lineTo(reachEndX - 3, originY + halfD3);

    // Neck to Shank Step-up Fillet
    canvas.curveTo(reachEndX - 1, originY - halfD2, reachEndX, originY - halfD2, reachEndX + 2, originY - halfD2);
    canvas.moveTo(reachEndX - 3, originY + halfD3);
    canvas.curveTo(reachEndX - 1, originY + halfD2, reachEndX, originY + halfD2, reachEndX + 2, originY + halfD2);
    canvas.strokePath();

    // Shank Body Lines & Chamfer / Threaded Hex System
    if (!hasThreadedShank) {
      canvas.moveTo(reachEndX + 2, originY - halfD2); canvas.lineTo(shankEndX - 4, originY - halfD2);
      canvas.moveTo(reachEndX + 2, originY + halfD2); canvas.lineTo(shankEndX - 4, originY + halfD2);

      // 45° Chamfer at rear end
      canvas.moveTo(shankEndX - 4, originY - halfD2);
      canvas.lineTo(shankEndX, originY - halfD2 + 4);
      canvas.lineTo(shankEndX, originY + halfD2 - 4);
      canvas.lineTo(shankEndX - 4, originY + halfD2);
      canvas.strokePath();
    } else {
      final double thLenPx = (threadLength * scaleX).clamp(24.0, 70.0);
      final double thHPx = (threadDiameter * 6.5).clamp(20.0, 52.0);
      final double halfThH = thHPx / 2;

      final double hxLenPx = (hexLength * scaleX).clamp(24.0, 70.0);
      final double hxHPx = (hexWidth * 6.5).clamp(24.0, 58.0);
      final double halfHxH = hxHPx / 2;
      final double threadEndX = shankEndX;
      final double threadStartX = threadEndX - thLenPx;
      final double hexEndX = threadStartX;
      final double hexStartX = hexEndX - hxLenPx;
      final double bodyEndX = hexStartX - 6.0;

      // Gövde
      canvas.moveTo(reachEndX + 2, originY - halfD2); canvas.lineTo(bodyEndX, originY - halfD2);
      canvas.moveTo(reachEndX + 2, originY + halfD2); canvas.lineTo(bodyEndX, originY + halfD2);
      // Konik omuz
      canvas.moveTo(bodyEndX, originY - halfD2); canvas.lineTo(hexStartX, originY - halfHxH);
      canvas.moveTo(bodyEndX, originY + halfD2); canvas.lineTo(hexStartX, originY + halfHxH);
      canvas.strokePath();

      // 6-Gen Kafa
      _drawPdfHexHead(canvas, hexStartX, hexEndX, originY, halfHxH);

      // Diş dış hatları & uç pahı
      canvas.setColor(PdfColors.black);
      canvas.setLineWidth(1.5);
      canvas.moveTo(threadStartX, originY - halfThH); canvas.lineTo(threadEndX - 3, originY - halfThH);
      canvas.moveTo(threadStartX, originY + halfThH); canvas.lineTo(threadEndX - 3, originY + halfThH);
      canvas.lineTo(threadEndX, originY + halfThH - 3);
      canvas.lineTo(threadEndX, originY - halfThH + 3);
      canvas.lineTo(threadEndX - 3, originY - halfThH);
      canvas.strokePath();

      // Diş Çizgileri
      canvas.setColor(PdfColors.amber800);
      canvas.setLineWidth(1.2);
      for (double tx = threadStartX + 3; tx < threadEndX - 3; tx += 3.5) {
        canvas.moveTo(tx, originY - halfThH);
        canvas.lineTo(tx + 2, originY + halfThH);
        canvas.strokePath();
      }
    }

    // 3. Centerline (Thin Dash-Dot)
    canvas.setColor(PdfColors.grey500);
    canvas.setLineWidth(0.7);
    _drawPdfDashDotLine(canvas, tipX - 35, originY, shankEndX + 35, originY);

    // 4. Dashed Projection Lines (Grey)
    canvas.setColor(PdfColors.grey500);
    canvas.setLineWidth(0.7);

    // d1 h9 horizontal dashed projections (Left)
    _drawPdfDashedLine(canvas, tipX, originY - halfD1, tipX - 35, originY - halfD1);
    _drawPdfDashedLine(canvas, tipX, originY + halfD1, tipX - 35, originY + halfD1);

    // d2 h6 horizontal dashed projections (Right)
    _drawPdfDashedLine(canvas, shankEndX, originY - halfD2, shankEndX + 35, originY - halfD2);
    _drawPdfDashedLine(canvas, shankEndX, originY + halfD2, shankEndX + 35, originY + halfD2);

    // l2 vertical dashed projections
    final dimY1 = originY + maxHalfH + 18;
    _drawPdfDashedLine(canvas, tipX, originY + halfD1, tipX, dimY1 + 5);
    _drawPdfDashedLine(canvas, fluteEndX, originY + halfD1, fluteEndX, dimY1 + 5);

    // l1 vertical dashed projections
    final dimY3 = originY + maxHalfH + 62;
    _drawPdfDashedLine(canvas, tipX, dimY1 + 5, tipX, dimY3 + 6);
    _drawPdfDashedLine(canvas, shankEndX, originY + halfD2, shankEndX, dimY3 + 6);

    // 5. RED DASHED PROJECTIONS FOR l3!
    canvas.setColor(PdfColors.red);
    canvas.setLineWidth(0.9);
    final dimY2 = originY + maxHalfH + 40;
    _drawPdfDashedLine(canvas, tipX, dimY1 + 5, tipX, dimY2 + 5);
    _drawPdfDashedLine(canvas, reachEndX, originY + halfD2, reachEndX, dimY2 + 5);

    // 6. Dimension Lines & Arrows
    // d1 h9 Dimension
    canvas.setColor(PdfColors.black);
    canvas.setLineWidth(0.9);
    canvas.moveTo(tipX - 25, originY - halfD1); canvas.lineTo(tipX - 25, originY + halfD1); canvas.strokePath();
    _drawPdfArrow(canvas, tipX - 25, originY - halfD1, 0, 1, PdfColors.black);
    _drawPdfArrow(canvas, tipX - 25, originY + halfD1, 0, -1, PdfColors.black);
    canvas.drawString(pdfFont, 8, 'd1 h9', tipX - 48, originY - 3);

    // d2 h6 Dimension
    canvas.moveTo(shankEndX + 25, originY - halfD2); canvas.lineTo(shankEndX + 25, originY + halfD2); canvas.strokePath();
    _drawPdfArrow(canvas, shankEndX + 25, originY - halfD2, 0, 1, PdfColors.black);
    _drawPdfArrow(canvas, shankEndX + 25, originY + halfD2, 0, -1, PdfColors.black);
    canvas.drawString(pdfFont, 8, 'd2 h6', shankEndX + 29, originY - 3);

    // d3 Neck Pointer (Top)
    final neckMidX = (fluteEndX + reachEndX) / 2;
    canvas.moveTo(neckMidX, originY - halfD3); canvas.lineTo(neckMidX, originY - halfD3 - 26); canvas.strokePath();
    _drawPdfArrow(canvas, neckMidX, originY - halfD3, 0, 1, PdfColors.black);
    canvas.drawString(pdfFont, 8, 'd3', neckMidX - 4, originY - halfD3 - 34);

    // l2 Dimension
    canvas.moveTo(tipX, dimY1); canvas.lineTo(fluteEndX, dimY1); canvas.strokePath();
    _drawPdfArrow(canvas, tipX, dimY1, 1, 0, PdfColors.black);
    _drawPdfArrow(canvas, fluteEndX, dimY1, -1, 0, PdfColors.black);
    canvas.drawString(pdfFont, 8, 'l2', (tipX + fluteEndX) / 2 - 4, dimY1 - 8);

    // l3 DIMENSION (RED!)
    canvas.setColor(PdfColors.red);
    canvas.setLineWidth(1.0);
    canvas.moveTo(tipX, dimY2); canvas.lineTo(reachEndX, dimY2); canvas.strokePath();
    _drawPdfArrow(canvas, tipX, dimY2, 1, 0, PdfColors.red);
    _drawPdfArrow(canvas, reachEndX, dimY2, -1, 0, PdfColors.red);
    canvas.drawString(pdfFontBold, 8.5, 'l3', (tipX + reachEndX) / 2 - 4, dimY2 - 8);

    // l1 Dimension
    canvas.setColor(PdfColors.black);
    canvas.setLineWidth(0.9);
    canvas.moveTo(tipX, dimY3); canvas.lineTo(shankEndX, dimY3); canvas.strokePath();
    _drawPdfArrow(canvas, tipX, dimY3, 1, 0, PdfColors.black);
    _drawPdfArrow(canvas, shankEndX, dimY3, -1, 0, PdfColors.black);
    canvas.drawString(pdfFont, 8, 'l1', (tipX + shankEndX) / 2 - 4, dimY3 - 8);
  }

  void _drawPdfDashedLine(PdfGraphics canvas, double x1, double y1, double x2, double y2, {double dash = 4.0, double gap = 3.0}) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist == 0) return;
    final uX = dx / dist;
    final uY = dy / dist;
    double d = 0;
    while (d < dist) {
      final curDash = math.min(dash, dist - d);
      canvas.moveTo(x1 + uX * d, y1 + uY * d);
      canvas.lineTo(x1 + uX * (d + curDash), y1 + uY * (d + curDash));
      canvas.strokePath();
      d += dash + gap;
    }
  }

  void _drawPdfDashDotLine(PdfGraphics canvas, double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist == 0) return;
    final uX = dx / dist;
    final uY = dy / dist;
    double d = 0;
    const longDash = 14.0;
    const gap = 3.5;
    const dot = 2.0;

    while (d < dist) {
      final curL = math.min(longDash, dist - d);
      canvas.moveTo(x1 + uX * d, y1 + uY * d);
      canvas.lineTo(x1 + uX * (d + curL), y1 + uY * (d + curL));
      canvas.strokePath();
      d += longDash + gap;

      if (d < dist) {
        canvas.moveTo(x1 + uX * d, y1 + uY * d);
        canvas.lineTo(x1 + uX * (d + dot), y1 + uY * (d + dot));
        canvas.strokePath();
        d += dot + gap;
      }
    }
  }

  void _drawPdfArrow(PdfGraphics canvas, double tipX, double tipY, double dirX, double dirY, PdfColor color, {double size = 5.0, double width = 2.2}) {
    final normX = -dirY;
    final normY = dirX;
    final p1X = tipX - dirX * size + normX * width;
    final p1Y = tipY - dirY * size + normY * width;
    final p2X = tipX - dirX * size - normX * width;
    final p2Y = tipY - dirY * size - normY * width;
    canvas.setColor(color);
    canvas.moveTo(tipX, tipY);
    canvas.lineTo(p1X, p1Y);
    canvas.lineTo(p2X, p2Y);
    canvas.closePath();
    canvas.fillPath();
  }

  void _drawPdfHexHead(
    PdfGraphics canvas,
    double hexStartX,
    double hexEndX,
    double originY,
    double halfHexH,
  ) {
    final double facetSplit = halfHexH * 0.52;

    // Yüzey dolguları (3 görünür yüzey tonu)
    canvas.setFillColor(PdfColors.grey200);
    canvas.drawRect(hexStartX, originY - halfHexH, hexEndX - hexStartX, halfHexH - facetSplit);
    canvas.fillPath();

    canvas.setFillColor(PdfColors.grey100);
    canvas.drawRect(hexStartX, originY - facetSplit, hexEndX - hexStartX, facetSplit * 2);
    canvas.fillPath();

    canvas.setFillColor(PdfColors.grey200);
    canvas.drawRect(hexStartX, originY + facetSplit, hexEndX - hexStartX, halfHexH - facetSplit);
    canvas.fillPath();

    // Dış çevre konturu
    canvas.setColor(PdfColors.black);
    canvas.setLineWidth(1.6);
    canvas.drawRect(hexStartX, originY - halfHexH, hexEndX - hexStartX, halfHexH * 2);
    canvas.strokePath();

    // Yüzey ayrım çizgileri (Crease lines)
    canvas.setColor(PdfColors.grey700);
    canvas.setLineWidth(1.0);
    canvas.moveTo(hexStartX, originY - facetSplit);
    canvas.lineTo(hexEndX, originY - facetSplit);
    canvas.moveTo(hexStartX, originY + facetSplit);
    canvas.lineTo(hexEndX, originY + facetSplit);
    canvas.strokePath();

    // Köşe pahları (Chamfer lines)
    canvas.setColor(PdfColors.grey600);
    canvas.setLineWidth(0.8);
    canvas.moveTo(hexStartX, originY - halfHexH + 2.5); canvas.lineTo(hexStartX + 2.5, originY - halfHexH);
    canvas.moveTo(hexEndX - 2.5, originY - halfHexH); canvas.lineTo(hexEndX, originY - halfHexH + 2.5);
    canvas.moveTo(hexStartX, originY + halfHexH - 2.5); canvas.lineTo(hexStartX + 2.5, originY + halfHexH);
    canvas.moveTo(hexEndX - 2.5, originY + halfHexH); canvas.lineTo(hexEndX, originY + halfHexH - 2.5);
    canvas.strokePath();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flight_takeoff, color: Color(0xFF00E5FF), size: 18),
            SizedBox(width: 6),
            Text('AIRCRAFT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 15)),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.print, size: 13),
            label: const Text('Teknik Resim & Yazdır', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
            onPressed: _openTechnicalDrawing,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Havacılık Standart Presetleri
            Card(
              color: const Color(0xFF171E28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF232E3E)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.precision_manufacturing, color: Color(0xFFFFB300), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Standart 1/4"-28 Vidalı Sap Matkap Ölçüleri (53-2971):',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: aviationPresets.map((preset) {
                        final isSelected = selectedModel == preset['label'];
                        return ChoiceChip(
                          label: Text(preset['label']),
                          selected: isSelected,
                          selectedColor: const Color(0xFF00E5FF).withOpacity(0.25),
                          backgroundColor: const Color(0xFF0F141C),
                          labelStyle: TextStyle(
                            color: isSelected ? const Color(0xFF00E5FF) : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFF232E3E),
                          ),
                          onSelected: (selected) {
                            if (selected) _applyPreset(preset);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // CAD Önizleme & Katalog Görüntüleme Kartı (ISO / DIN Standardı)
            Card(
              elevation: 6,
              color: const Color(0xFF141A24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF232E3E), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Kart Başlığı, Tip Etiketi ve 2D/3D Görünüm Seçici
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(is3DMode ? Icons.view_in_ar : Icons.architecture, color: const Color(0xFF00E5FF), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              is3DMode ? '3D İNTERAKTİF CAD MODELİ' : 'TEKNİK KATALOG ÇİZİMİ (2D)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        // 2D / 3D Görünüm Modu Değiştirici
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F141C),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF232E3E)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => setState(() => is3DMode = false),
                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: !is3DMode ? const Color(0xFF00E5FF).withOpacity(0.2) : Colors.transparent,
                                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.architecture, size: 14, color: !is3DMode ? const Color(0xFF00E5FF) : Colors.grey),
                                      const SizedBox(width: 4),
                                      Text('2D ISO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: !is3DMode ? const Color(0xFF00E5FF) : Colors.grey)),
                                    ],
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => setState(() => is3DMode = true),
                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: is3DMode ? const Color(0xFFFFB300).withOpacity(0.25) : Colors.transparent,
                                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.view_in_ar, size: 14, color: is3DMode ? const Color(0xFFFFB300) : Colors.grey),
                                      const SizedBox(width: 4),
                                      Text('3D CAD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: is3DMode ? const Color(0xFFFFB300) : Colors.grey)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // İnteraktif Çizim Araç Çubuğu (Toolbar)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: is3DMode
                            ? [
                                // 3D Toolbar Kontrolleri
                                ActionChip(
                                  avatar: const Icon(Icons.crop_rotate, size: 15, color: Color(0xFF00E5FF)),
                                  label: const Text('İzometrik', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  backgroundColor: const Color(0xFF0F141C),
                                  side: const BorderSide(color: Color(0xFF232E3E)),
                                  onPressed: () => _set3DCameraPreset('iso'),
                                ),
                                const SizedBox(width: 6),
                                ActionChip(
                                  avatar: const Icon(Icons.border_right, size: 15, color: Color(0xFF00E5FF)),
                                  label: const Text('Ön / Yan', style: TextStyle(fontSize: 11)),
                                  backgroundColor: const Color(0xFF0F141C),
                                  side: const BorderSide(color: Color(0xFF232E3E)),
                                  onPressed: () => _set3DCameraPreset('front'),
                                ),
                                const SizedBox(width: 6),
                                ActionChip(
                                  avatar: const Icon(Icons.border_top, size: 15, color: Color(0xFF00E5FF)),
                                  label: const Text('Üst Görünüm', style: TextStyle(fontSize: 11)),
                                  backgroundColor: const Color(0xFF0F141C),
                                  side: const BorderSide(color: Color(0xFF232E3E)),
                                  onPressed: () => _set3DCameraPreset('top'),
                                ),
                                const SizedBox(width: 6),
                                ActionChip(
                                  avatar: const Icon(Icons.adjust, size: 15, color: Color(0xFF00E5FF)),
                                  label: const Text('Uç / Ağız', style: TextStyle(fontSize: 11)),
                                  backgroundColor: const Color(0xFF0F141C),
                                  side: const BorderSide(color: Color(0xFF232E3E)),
                                  onPressed: () => _set3DCameraPreset('tip'),
                                ),
                                const SizedBox(width: 6),
                                ActionChip(
                                  avatar: const Icon(Icons.hexagon, size: 15, color: Color(0xFF00E5FF)),
                                  label: const Text('Vidalı Sap', style: TextStyle(fontSize: 11)),
                                  backgroundColor: const Color(0xFF0F141C),
                                  side: const BorderSide(color: Color(0xFF232E3E)),
                                  onPressed: () => _set3DCameraPreset('shank'),
                                ),
                                const SizedBox(width: 8),
                                FilterChip(
                                  avatar: Icon(
                                    isAutoRotating ? Icons.stop_circle : Icons.play_circle,
                                    size: 16,
                                    color: isAutoRotating ? const Color(0xFFFF5252) : const Color(0xFFFFB300),
                                  ),
                                  label: Text(
                                    isAutoRotating ? 'Durdur' : '360° Döndür',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  selected: isAutoRotating,
                                  selectedColor: const Color(0xFFFFB300).withOpacity(0.2),
                                  backgroundColor: const Color(0xFF0F141C),
                                  side: const BorderSide(color: Color(0xFF232E3E)),
                                  onSelected: (_) => _toggleAutoRotate(),
                                ),
                                const SizedBox(width: 8),
                                ActionChip(
                                  avatar: Icon(
                                    is3DWireframe ? Icons.grid_3x3 : Icons.wb_shade,
                                    size: 16,
                                    color: const Color(0xFF00E5FF),
                                  ),
                                  label: Text(
                                    is3DWireframe ? 'Tel Kafes' : 'Katı Metalik',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  backgroundColor: const Color(0xFF0F141C),
                                  side: const BorderSide(color: Color(0xFF232E3E)),
                                  onPressed: () => setState(() => is3DWireframe = !is3DWireframe),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.zoom_in, size: 20),
                                  tooltip: 'Yakınlaştır',
                                  onPressed: _zoomIn,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.zoom_out, size: 20),
                                  tooltip: 'Uzaklaştır',
                                  onPressed: _zoomOut,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 20),
                                  tooltip: 'Sıfırla',
                                  onPressed: _resetZoom,
                                ),
                              ]
                            : [
                                // 2D Toolbar Kontrolleri
                                ActionChip(
                                  avatar: Icon(
                                    isCatalogWhiteMode ? Icons.light_mode : Icons.dark_mode,
                                    size: 16,
                                    color: isCatalogWhiteMode ? const Color(0xFFFFB300) : const Color(0xFF00E5FF),
                                  ),
                                  label: Text(
                                    isCatalogWhiteMode ? 'Beyaz Katalog' : 'Karanlık CAD',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  backgroundColor: isCatalogWhiteMode ? Colors.white.withOpacity(0.12) : const Color(0xFF0F141C),
                                  side: BorderSide(color: isCatalogWhiteMode ? const Color(0xFFFFB300) : const Color(0xFF232E3E)),
                                  onPressed: () => setState(() => isCatalogWhiteMode = !isCatalogWhiteMode),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('d1, l1... (ISO)', style: TextStyle(fontSize: 11)),
                                  selected: dimensionDisplayMode == 'symbols',
                                  selectedColor: const Color(0xFFFFB300).withOpacity(0.25),
                                  onSelected: (val) => setState(() => dimensionDisplayMode = 'symbols'),
                                ),
                                const SizedBox(width: 6),
                                ChoiceChip(
                                  label: const Text('Birlikte', style: TextStyle(fontSize: 11)),
                                  selected: dimensionDisplayMode == 'both',
                                  selectedColor: const Color(0xFFFFB300).withOpacity(0.25),
                                  onSelected: (val) => setState(() => dimensionDisplayMode = 'both'),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.zoom_in, size: 20),
                                  tooltip: 'Yakınlaştır',
                                  onPressed: _zoomIn,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.zoom_out, size: 20),
                                  tooltip: 'Uzaklaştır',
                                  onPressed: _zoomOut,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.fit_screen, size: 20),
                                  tooltip: 'Görünümü Sıfırla',
                                  onPressed: _resetZoom,
                                ),
                              ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Canvas Alanı (2D InteractiveViewer veya 3D GestureDetector)
                    Container(
                      height: 330,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: is3DMode
                            ? const Color(0xFF0A0F17)
                            : (isCatalogWhiteMode ? Colors.white : const Color(0xFF080D14)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (!is3DMode && isCatalogWhiteMode)
                              ? const Color(0xFFD0D7DE)
                              : const Color(0xFF1D2838),
                          width: 1.5,
                        ),
                        boxShadow: (!is3DMode && isCatalogWhiteMode)
                            ? [
                                BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4)),
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: is3DMode
                            ? GestureDetector(
                                onPanUpdate: (details) {
                                  if (isAutoRotating) {
                                    _toggleAutoRotate();
                                  }
                                  setState(() {
                                    rotY += details.delta.dx * 0.012;
                                    rotX = (rotX - details.delta.dy * 0.012).clamp(-math.pi * 0.48, math.pi * 0.48);
                                  });
                                },
                                onDoubleTap: _reset3DView,
                                child: Stack(
                                  children: [
                                    CustomPaint(
                                      size: Size.infinite,
                                      painter: Tool3DModelPainter(
                                        rotX: rotX,
                                        rotY: rotY,
                                        rotZ: rotZ,
                                        zoom: zoom3D,
                                        isWireframe: is3DWireframe,
                                        toolTipType: toolTipType,
                                        pointAngle: pointAngle,
                                        drillDiameter: drillDiameter,
                                        totalLength: totalLength,
                                        fluteLength: fluteLength,
                                        reachLength: reachLength,
                                        neckDiameter: neckDiameter,
                                        shankDiameter: shankDiameter,
                                        hasThreadedShank: hasThreadedShank,
                                        threadLength: threadLength,
                                        threadDiameter: threadDiameter,
                                        hexLength: hexLength,
                                        hexWidth: hexWidth,
                                        coatingColor: toolCoatings.firstWhere((c) => c['id'] == selectedCoatingId)['color'] as Color,
                                      ),
                                    ),
                                    Positioned(
                                      top: 10,
                                      left: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.65),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.white12),
                                        ),
                                        child: Text(
                                          'Açı: X:${(rotX * 180 / math.pi).toStringAsFixed(0)}°  Y:${(rotY * 180 / math.pi).toStringAsFixed(0)}°  |  Zoom: ${(zoom3D * 100).toStringAsFixed(0)}%',
                                          style: const TextStyle(fontSize: 10, color: Colors.white70, fontFamily: 'monospace'),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 10,
                                      left: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.65),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.white12),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.touch_app, size: 12, color: Color(0xFF00E5FF)),
                                            SizedBox(width: 4),
                                            Text(
                                              'Parmağınızla / fareyle 360° serbestçe döndürün',
                                              style: TextStyle(fontSize: 10, color: Colors.white70),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : InteractiveViewer(
                                transformationController: _transformController,
                                minScale: 0.5,
                                maxScale: 4.0,
                                child: CustomPaint(
                                  size: Size.infinite,
                                  painter: IndustrialCatalogDrillPainter(
                                    isCatalogWhiteMode: isCatalogWhiteMode,
                                    toolTipType: toolTipType,
                                    dimensionDisplayMode: dimensionDisplayMode,
                                    hasThreadedShank: hasThreadedShank,
                                    drillDiameter: drillDiameter,
                                    totalLength: totalLength,
                                    fluteLength: fluteLength,
                                    reachLength: reachLength,
                                    neckDiameter: neckDiameter,
                                    shankDiameter: shankDiameter,
                                    pointAngle: pointAngle,
                                    threadLength: threadLength,
                                    hexLength: hexLength,
                                    threadDiameter: threadDiameter,
                                    hexWidth: hexWidth,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Alt Hızlı Ölçü Çipleri (l3 Kırmızı Vurgulu!)
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildParamChip('d1 (h9)', 'Ø ${drillDiameter.toStringAsFixed(2)} mm', const Color(0xFF00E5FF)),
                        _buildParamChip('d2 (h6)', 'Ø ${shankDiameter.toStringAsFixed(2)} mm', const Color(0xFF00E5FF)),
                        _buildParamChip('d3 (Boyun)', 'Ø ${neckDiameter.toStringAsFixed(2)} mm', Colors.grey),
                        _buildParamChip('l2 (Kesme)', '${fluteLength.toStringAsFixed(1)} mm', Colors.white70),
                        _buildParamChip('l3 (Kullanılabilir)', '${reachLength.toStringAsFixed(1)} mm', const Color(0xFFE53935), isHighlight: true),
                        _buildParamChip('l1 (Tam Boy)', '${totalLength.toStringAsFixed(1)} mm', const Color(0xFFFFB300)),
                        if (hasThreadedShank) ...[
                          _buildParamChip('⬡ Somun (Kafa)', 'SW ${hexWidth.toStringAsFixed(2)} mm', const Color(0xFFFFB300)),
                          _buildParamChip('🔩 Vida (Diş)', '1/4"-28 (Ø${threadDiameter.toStringAsFixed(2)})', const Color(0xFFFFB300)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // KART 1: TAKIM GEOMETRİSİ VE UÇ AÇISI LİSTESİ (DÜZ FREZE & MATKAP AÇILARI)
            Card(
              color: const Color(0xFF171E28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF232E3E)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.architecture, color: Color(0xFF00E5FF), size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Takım Geometrisi ve Uç Açısı Listesi:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                          ),
                          child: Text(
                            '${pointAngle.toStringAsFixed(0)}° Açı',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: standardTipAngles.map((tip) {
                        final isSelected = selectedTipId == tip['id'];
                        return ChoiceChip(
                          label: Text(tip['label']),
                          selected: isSelected,
                          selectedColor: const Color(0xFF00E5FF).withOpacity(0.25),
                          backgroundColor: const Color(0xFF0F141C),
                          labelStyle: TextStyle(
                            color: isSelected ? const Color(0xFF00E5FF) : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 11.5,
                          ),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFF232E3E),
                          ),
                          onSelected: (selected) {
                            if (selected) _applyTipAngle(tip);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F141C),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF232E3E)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: Color(0xFF00E5FF)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              standardTipAngles.firstWhere((t) => t['id'] == selectedTipId)['desc'],
                              style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // KART 2: HAMMADDE, SERTLİK VE KAPLAMA TÜRLERİ
            Card(
              color: const Color(0xFF171E28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF232E3E)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.shield, color: Color(0xFFFFB300), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Matkap Hammadde, Sertlik ve Kaplama Türleri:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Hammadde Seçimi
                    const Text('Kesici Takım Hammaddesi:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: toolMaterials.map((mat) {
                        final isSelected = selectedMaterialId == mat['id'];
                        return ChoiceChip(
                          label: Text(mat['name'].toString().split('(').first.trim()),
                          selected: isSelected,
                          selectedColor: const Color(0xFFFFB300).withOpacity(0.25),
                          backgroundColor: const Color(0xFF0F141C),
                          labelStyle: TextStyle(
                            color: isSelected ? const Color(0xFFFFB300) : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 11.5,
                          ),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFFFFB300) : const Color(0xFF232E3E),
                          ),
                          onSelected: (selected) {
                            if (selected) setState(() => selectedMaterialId = mat['id']);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Sertlik Değerleri Kutucukları (Rockwell HRC, Vickers HV, Maks Sıcaklık)
                    Builder(builder: (context) {
                      final currentMat = toolMaterials.firstWhere((m) => m['id'] == selectedMaterialId);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F141C),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF232E3E)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Rockwell Sertlik', style: TextStyle(fontSize: 9.5, color: Colors.grey)),
                                      const SizedBox(height: 2),
                                      Text(currentMat['hardness'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFFB300))),
                                      Text(currentMat['hardnessHra'] ?? '', style: const TextStyle(fontSize: 9, color: Colors.white54)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F141C),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF232E3E)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Vickers Sertlik', style: TextStyle(fontSize: 9.5, color: Colors.grey)),
                                      const SizedBox(height: 2),
                                      Text(currentMat['hardnessHv'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))),
                                      const Text('HV 0.5 Yük', style: TextStyle(fontSize: 9, color: Colors.white54)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F141C),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF232E3E)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Termal Direnç', style: TextStyle(fontSize: 9.5, color: Colors.grey)),
                                      const SizedBox(height: 2),
                                      Text(currentMat['temp'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFF5252))),
                                      const Text('Kızıl Sertlik', style: TextStyle(fontSize: 9, color: Colors.white54)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F141C),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF232E3E)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.flight_takeoff, size: 14, color: Color(0xFF00E5FF)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Önerilen Havacılık Alaşımları: ${currentMat['app']}',
                                    style: const TextStyle(fontSize: 10.5, color: Colors.white70),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 12),

                    // Kaplama Türü Seçimi
                    const Text('Yüzey Kaplama Türü (PVD):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: toolCoatings.map((coating) {
                        final isSelected = selectedCoatingId == coating['id'];
                        final Color cColor = coating['color'] as Color;
                        return ChoiceChip(
                          avatar: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: cColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white54, width: 0.8),
                            ),
                          ),
                          label: Text(coating['shortName']),
                          selected: isSelected,
                          selectedColor: const Color(0xFF00E5FF).withOpacity(0.25),
                          backgroundColor: const Color(0xFF0F141C),
                          labelStyle: TextStyle(
                            color: isSelected ? const Color(0xFF00E5FF) : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 11,
                          ),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFF232E3E),
                          ),
                          onSelected: (selected) {
                            if (selected) setState(() => selectedCoatingId = coating['id']);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 1. KISIM: VİDALI SAP (STANDART NAS 965 - AÇMA / KAPAMA SİSTEMLİ)
            Card(
              color: const Color(0xFF171E28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: hasThreadedShank ? const Color(0xFFFFB300) : const Color(0xFF232E3E),
                  width: 1.2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.build_circle,
                              color: hasThreadedShank ? const Color(0xFFFFB300) : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Vidalı Sap',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              hasThreadedShank ? 'Açık' : 'Kapalı',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: hasThreadedShank ? const Color(0xFFFFB300) : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Switch(
                              value: hasThreadedShank,
                              activeColor: const Color(0xFFFFB300),
                              onChanged: (val) => setState(() => hasThreadedShank = val),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (hasThreadedShank) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInputField(
                              label: 'Vida Boyu',
                              controller: _threadLenController,
                              suffix: 'mm',
                              onChanged: (v) => _updateShankParams(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInputField(
                              label: 'Vida Çapı',
                              controller: _threadDiamController,
                              suffix: 'mm',
                              onChanged: (v) => _updateShankParams(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInputField(
                              label: 'Somun Boyu',
                              controller: _hexLenController,
                              suffix: 'mm',
                              onChanged: (v) => _updateShankParams(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInputField(
                              label: 'Somun Çapı',
                              controller: _hexWidthController,
                              suffix: 'mm',
                              onChanged: (v) => _updateShankParams(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F141C),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF232E3E)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, size: 14, color: Color(0xFFFFB300)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Standart NAS 965: Gövde ➔ Konik Omuz ➔ 6-Gen Kafa ➔ 1/4"-28 Vidalı Uç',
                                style: TextStyle(fontSize: 11, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. KISIM: TAKIM VE GÖVDE PARAMETRELERİ (ISO 13399 ÖLÇÜLERİ)
            Card(
              color: const Color(0xFF171E28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF232E3E)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Takım ve Gövde Parametreleri (ISO 13399 Ölçüleri)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Metrik Satırı 1 (d1, l2, l3, l1)
                    const Text('Metrik Ölçüler (mm):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            label: 'Kesme Çapı (d1)',
                            controller: _diamMmController,
                            suffix: 'mm',
                            onChanged: (v) => _updateDrillFromMm(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildInputField(
                            label: 'Kesme Boyu (l2)',
                            controller: _fluteLenMmController,
                            suffix: 'mm',
                            onChanged: (v) => _updateDrillFromMm(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildInputField(
                            label: 'Kullanılabilir (l3)',
                            controller: _reachLenMmController,
                            suffix: 'mm',
                            labelColor: const Color(0xFFFF5252),
                            onChanged: (v) => _updateDrillFromMm(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildInputField(
                            label: 'Tam Boy (l1)',
                            controller: _totalLenMmController,
                            suffix: 'mm',
                            onChanged: (v) => _updateDrillFromMm(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Metrik Satırı 2 (d3, d2)
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            label: 'Boyun Çapı (d3)',
                            controller: _neckDiamMmController,
                            suffix: 'mm',
                            onChanged: (v) => _updateDrillFromMm(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInputField(
                            label: 'Sap Çapı (d2 - h6)',
                            controller: _shankDiamMmController,
                            suffix: 'mm',
                            onChanged: (v) => _updateDrillFromMm(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // İnç Satırı
                    const Text('İnç Ölçüleri (inch / "):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFFB300))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            label: 'd1 (İnç)',
                            controller: _diamInController,
                            suffix: '"',
                            onChanged: (v) => _updateDrillFromInch(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildInputField(
                            label: 'l2 (İnç)',
                            controller: _fluteLenInController,
                            suffix: '"',
                            onChanged: (v) => _updateDrillFromInch(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildInputField(
                            label: 'l3 (İnç)',
                            controller: _reachLenInController,
                            suffix: '"',
                            labelColor: const Color(0xFFFFB300),
                            onChanged: (v) => _updateDrillFromInch(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildInputField(
                            label: 'l1 (İnç)',
                            controller: _totalLenInController,
                            suffix: '"',
                            onChanged: (v) => _updateDrillFromInch(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Büyük Teknik Resim Aç / Yazdır Butonu (Kompakt ve Şık)
            ElevatedButton.icon(
              onPressed: _openTechnicalDrawing,
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
              label: const Text(
                'Teknik Resmi Görüntüle & Yazdır (A4 PDF)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParamChip(String label, String value, Color color, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isHighlight ? const Color(0xFFE53935).withOpacity(0.18) : const Color(0xFF0F141C),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isHighlight ? const Color(0xFFE53935) : color.withOpacity(0.4),
          width: isHighlight ? 1.4 : 1.0,
        ),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isHighlight ? const Color(0xFFFF5252) : color,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                color: isHighlight ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String suffix,
    required ValueChanged<String> onChanged,
    Color? labelColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: labelColor ?? Colors.grey, fontWeight: labelColor != null ? FontWeight.bold : FontWeight.normal)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onChanged,
          decoration: InputDecoration(
            suffixText: suffix,
            filled: true,
            fillColor: const Color(0xFF0F141C),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF232E3E)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF00E5FF)),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// ENDÜSTRİYEL ISO / DIN TEKNİK KATALOG ÇİZİCİSİ (IndustrialCatalogDrillPainter)
// =============================================================================

class IndustrialCatalogDrillPainter extends CustomPainter {
  final bool isCatalogWhiteMode;
  final String toolTipType; // 'drill135', 'endmill', 'drill118'
  final String dimensionDisplayMode; // 'both', 'symbols', 'values'
  final bool hasThreadedShank;
  final double drillDiameter;
  final double totalLength;
  final double fluteLength;
  final double reachLength;
  final double neckDiameter;
  final double shankDiameter;
  final double pointAngle;
  final double threadLength;
  final double hexLength;
  final double threadDiameter;
  final double hexWidth;

  const IndustrialCatalogDrillPainter({
    required this.isCatalogWhiteMode,
    required this.toolTipType,
    required this.dimensionDisplayMode,
    required this.hasThreadedShank,
    required this.drillDiameter,
    required this.totalLength,
    required this.fluteLength,
    required this.reachLength,
    required this.neckDiameter,
    required this.shankDiameter,
    required this.pointAngle,
    required this.threadLength,
    required this.hexLength,
    required this.threadDiameter,
    required this.hexWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Arka Plan & Teknik Izgara
    if (isCatalogWhiteMode) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.white);
      final gridPaint = Paint()..color = const Color(0xFFF1F3F5)..strokeWidth = 0.5;
      for (double x = 0; x < size.width; x += 15) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (double y = 0; y < size.height; y += 15) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    } else {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF080D14));
      final gridMinor = Paint()..color = const Color(0xFF101926)..strokeWidth = 0.5;
      final gridMajor = Paint()..color = const Color(0xFF182436)..strokeWidth = 1.0;
      for (double i = 0; i < size.width; i += 10) {
        canvas.drawLine(Offset(i, 0), Offset(i, size.height), (i % 50 == 0) ? gridMajor : gridMinor);
      }
      for (double j = 0; j < size.height; j += 20) {
        canvas.drawLine(Offset(0, j), Offset(size.width, j), (j % 60 == 0) ? gridMajor : gridMinor);
      }
    }

    const double startX = 85.0;
    final double centerY = size.height * 0.36;
    final double maxDrawWidth = size.width - 170.0;
    final double scaleX = maxDrawWidth / totalLength;

    final double d1Px = (drillDiameter * 7.0).clamp(24.0, 52.0);
    final double halfD1 = d1Px / 2;
    final double d2Px = (shankDiameter * 7.0).clamp(24.0, 56.0);
    final double halfD2 = d2Px / 2;
    final double d3Px = (neckDiameter * 7.0).clamp(18.0, 44.0);
    final double halfD3 = d3Px / 2;
    final double maxHalfH = math.max(halfD1, math.max(halfD2, halfD3));

    final double pointLenPx = (toolTipType == 'endmill')
        ? 0.0
        : (halfD1 / math.tan((pointAngle / 2) * math.pi / 180)).clamp(4.0, 20.0);

    const double tipX = startX;
    final double fluteStartX = tipX + pointLenPx;
    final double fluteEndX = tipX + (fluteLength * scaleX);
    final double reachEndX = tipX + (reachLength * scaleX);
    final double shankEndX = tipX + (totalLength * scaleX);

    // Renk Tanımları
    final Color strokeCol = isCatalogWhiteMode ? const Color(0xFF1A1A1A) : const Color(0xFFE2E8F0);
    final Color dimCol = isCatalogWhiteMode ? const Color(0xFF212529) : const Color(0xFFFFB300);
    final Color projCol = isCatalogWhiteMode ? const Color(0xFF868E96) : const Color(0xFF4A5D75);
    const Color redHighlightCol = Color(0xFFE53935);

    final contourPaint = Paint()
      ..color = strokeCol
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isCatalogWhiteMode
            ? [const Color(0xFFF8F9FA), const Color(0xFFE9ECEF), const Color(0xFFDEE2E6), const Color(0xFFF8F9FA)]
            : [const Color(0xFF334252), const Color(0xFF1B232C), const Color(0xFF11171E), const Color(0xFF334252)],
      ).createShader(Rect.fromLTWH(tipX, centerY - maxHalfH, shankEndX - tipX, maxHalfH * 2));

    // 2. Takım Dolguları
    canvas.drawRect(Rect.fromLTWH(fluteStartX, centerY - halfD1, fluteEndX - fluteStartX, d1Px), fillPaint);
    canvas.drawRect(Rect.fromLTWH(fluteEndX, centerY - halfD3, reachEndX - fluteEndX, d3Px), fillPaint);
    canvas.drawRect(Rect.fromLTWH(reachEndX, centerY - halfD2, shankEndX - reachEndX, d2Px), fillPaint);

    if (toolTipType != 'endmill') {
      final tipPath = Path()
        ..moveTo(fluteStartX, centerY - halfD1)
        ..lineTo(tipX, centerY)
        ..lineTo(fluteStartX, centerY + halfD1)
        ..close();
      canvas.drawPath(tipPath, fillPaint);
      canvas.drawPath(tipPath, contourPaint);
    }

    // 3. Takım Dış Hatları ve Çizgileri
    canvas.drawLine(Offset(fluteStartX, centerY - halfD1), Offset(fluteEndX, centerY - halfD1), contourPaint);
    canvas.drawLine(Offset(fluteStartX, centerY + halfD1), Offset(fluteEndX, centerY + halfD1), contourPaint);

    // Uç yüzeyi
    if (toolTipType == 'endmill') {
      canvas.drawLine(Offset(tipX, centerY - halfD1 + 2), Offset(tipX + 2, centerY - halfD1), contourPaint);
      canvas.drawLine(Offset(tipX, centerY - halfD1 + 2), Offset(tipX, centerY + halfD1 - 2), contourPaint);
      canvas.drawLine(Offset(tipX, centerY + halfD1 - 2), Offset(tipX + 2, centerY + halfD1), contourPaint);
      // Uç gash çizgileri
      canvas.drawLine(Offset(tipX + 4, centerY - halfD1 * 0.4), Offset(tipX, centerY), Paint()..color = strokeCol..strokeWidth = 1.2);
      canvas.drawLine(Offset(tipX + 4, centerY + halfD1 * 0.4), Offset(tipX, centerY), Paint()..color = strokeCol..strokeWidth = 1.2);
    }

    // Helis Kanalları (3 dalga, çift hatlı marj)
    final fluteBodyLen = fluteEndX - fluteStartX;
    final waveStep = fluteBodyLen / 3.0;

    final helixLinePaint = Paint()..color = strokeCol..strokeWidth = 1.4..style = PaintingStyle.stroke;
    final marginPaint = Paint()
      ..color = isCatalogWhiteMode ? const Color(0xFF6C757D) : const Color(0xFF00E5FF).withOpacity(0.6)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 3; i++) {
      final double wx = fluteStartX + i * waveStep;
      final path = Path()
        ..moveTo(wx, centerY - halfD1)
        ..cubicTo(wx + waveStep * 0.45, centerY - halfD1 * 0.3, wx + waveStep * 0.55, centerY + halfD1 * 0.3, wx + waveStep, centerY + halfD1);
      canvas.drawPath(path, helixLinePaint);

      final marginPath = Path()
        ..moveTo(wx + 3.0, centerY - halfD1)
        ..cubicTo(wx + waveStep * 0.45 + 3.0, centerY - halfD1 * 0.3, wx + waveStep * 0.55 + 3.0, centerY + halfD1 * 0.3, wx + waveStep + 3.0, centerY + halfD1);
      canvas.drawPath(marginPath, marginPaint);
    }

    // Helis Çıkış Kavis Geçişi (Fillet)
    final runoutTop = Path()
      ..moveTo(fluteEndX, centerY - halfD1)
      ..cubicTo(fluteEndX + 3, centerY - halfD3, fluteEndX + 4, centerY - halfD3, fluteEndX + 6, centerY - halfD3);
    canvas.drawPath(runoutTop, contourPaint);

    final runoutBottom = Path()
      ..moveTo(fluteEndX, centerY + halfD1)
      ..cubicTo(fluteEndX + 3, centerY + halfD3, fluteEndX + 4, centerY + halfD3, fluteEndX + 6, centerY + halfD3);
    canvas.drawPath(runoutBottom, contourPaint);

    // Boyun Hatları
    canvas.drawLine(Offset(fluteEndX + 6, centerY - halfD3), Offset(reachEndX - 3, centerY - halfD3), contourPaint);
    canvas.drawLine(Offset(fluteEndX + 6, centerY + halfD3), Offset(reachEndX - 3, centerY + halfD3), contourPaint);

    // Boyundan Sapa Geçiş Kavisi
    final stepUpTop = Path()
      ..moveTo(reachEndX - 3, centerY - halfD3)
      ..cubicTo(reachEndX - 1, centerY - halfD2, reachEndX, centerY - halfD2, reachEndX + 3, centerY - halfD2);
    canvas.drawPath(stepUpTop, contourPaint);

    final stepUpBottom = Path()
      ..moveTo(reachEndX - 3, centerY + halfD3)
      ..cubicTo(reachEndX - 1, centerY + halfD2, reachEndX, centerY + halfD2, reachEndX + 3, centerY + halfD2);
    canvas.drawPath(stepUpBottom, contourPaint);

    if (!hasThreadedShank) {
      // Sap Hatları ve Arka 45° Pah
      canvas.drawLine(Offset(reachEndX + 3, centerY - halfD2), Offset(shankEndX - 4, centerY - halfD2), contourPaint);
      canvas.drawLine(Offset(reachEndX + 3, centerY + halfD2), Offset(shankEndX - 4, centerY + halfD2), contourPaint);

      final chamferPath = Path()
        ..moveTo(shankEndX - 4, centerY - halfD2)
        ..lineTo(shankEndX, centerY - halfD2 + 4)
        ..lineTo(shankEndX, centerY + halfD2 - 4)
        ..lineTo(shankEndX - 4, centerY + halfD2);
      canvas.drawPath(chamferPath, contourPaint);
    } else {
      // VİDALI SAP VE 6-GEN SOMUN KAFA
      final double thLenPx = (threadLength * scaleX).clamp(24.0, 70.0);
      final double thHPx = (threadDiameter * 7.0).clamp(20.0, 52.0);
      final double halfThH = thHPx / 2;

      final double hxLenPx = (hexLength * scaleX).clamp(24.0, 70.0);
      final double hxHPx = (hexWidth * 7.0).clamp(24.0, 60.0);
      final double halfHxH = hxHPx / 2;

      // Standart NAS 965: Gövde -> Konik Omuz -> 6-Gen Somun Kafa -> 1/4"-28 Vida (Uçta)
      final double threadEndX = shankEndX;
      final double threadStartX = threadEndX - thLenPx;
      final double hexEndX = threadStartX;
      final double hexStartX = hexEndX - hxLenPx;
      final double bodyEndX = hexStartX - 6.0;

      // Silindirik Gövde Hatları
      canvas.drawLine(Offset(reachEndX + 3, centerY - halfD2), Offset(bodyEndX, centerY - halfD2), contourPaint);
      canvas.drawLine(Offset(reachEndX + 3, centerY + halfD2), Offset(bodyEndX, centerY + halfD2), contourPaint);

      // Gövdeden 6-Gen Kafaya Konik Omuz (Taper Transition)
      canvas.drawLine(Offset(bodyEndX, centerY - halfD2), Offset(hexStartX, centerY - halfHxH), contourPaint);
      canvas.drawLine(Offset(bodyEndX, centerY + halfD2), Offset(hexStartX, centerY + halfHxH), contourPaint);

      // 6-Gen Somun Kafa
      _drawHexHead(canvas, hexStartX, hexEndX, centerY, halfHxH, contourPaint, isCatalogWhiteMode);

      // Vidalı Kısım Dış Çizgileri
      canvas.drawLine(Offset(threadStartX, centerY - halfThH), Offset(threadEndX - 3, centerY - halfThH), contourPaint);
      canvas.drawLine(Offset(threadStartX, centerY + halfThH), Offset(threadEndX - 3, centerY + halfThH), contourPaint);

      // Uç Pahı
      final tipChamfer = Path()
        ..moveTo(threadEndX - 3, centerY - halfThH)
        ..lineTo(threadEndX, centerY - halfThH + 3)
        ..lineTo(threadEndX, centerY + halfThH - 3)
        ..lineTo(threadEndX - 3, centerY + halfThH);
      canvas.drawPath(tipChamfer, contourPaint);

      // Vida Diş Çizgileri
      final threadLinePaint = Paint()
        ..color = isCatalogWhiteMode ? const Color(0xFFD97706) : const Color(0xFFFFB300)
        ..strokeWidth = 1.6;
      for (double tx = threadStartX + 3; tx < threadEndX - 3; tx += 4.0) {
        canvas.drawLine(Offset(tx, centerY - halfThH), Offset(tx + 2.5, centerY + halfThH), threadLinePaint);
      }
    }

    // 4. Eksen Çizgisi (Noktalı Çizgi)
    _drawDashDotLine(
      canvas,
      Offset(tipX - 35, centerY),
      Offset(shankEndX + 35, centerY),
      isCatalogWhiteMode ? const Color(0xFF868E96) : const Color(0xFFFF5252),
    );

    // 5. Kesikli Bağlama (Projeksiyon) Çizgileri
    final projPaint = Paint()..color = projCol..strokeWidth = 1.0;

    // d1 h9 yatay kesikli uzantılar (Sol)
    _drawDashedLine(canvas, Offset(tipX, centerY - halfD1), Offset(tipX - 35, centerY - halfD1), projPaint);
    _drawDashedLine(canvas, Offset(tipX, centerY + halfD1), Offset(tipX - 35, centerY + halfD1), projPaint);

    // d2 h6 yatay kesikli uzantılar (Sağ)
    _drawDashedLine(canvas, Offset(shankEndX, centerY - halfD2), Offset(shankEndX + 35, centerY - halfD2), projPaint);
    _drawDashedLine(canvas, Offset(shankEndX, centerY + halfD2), Offset(shankEndX + 35, centerY + halfD2), projPaint);

    // l2 dikey kesikli uzantılar
    final double dimY1 = centerY + maxHalfH + 20;
    _drawDashedLine(canvas, Offset(tipX, centerY + halfD1), Offset(tipX, dimY1 + 5), projPaint);
    _drawDashedLine(canvas, Offset(fluteEndX, centerY + halfD1), Offset(fluteEndX, dimY1 + 5), projPaint);

    // l1 dikey kesikli uzantılar
    final double dimY3 = centerY + maxHalfH + 72;
    _drawDashedLine(canvas, Offset(tipX, dimY1 + 5), Offset(tipX, dimY3 + 6), projPaint);
    _drawDashedLine(canvas, Offset(shankEndX, centerY + halfD2), Offset(shankEndX, dimY3 + 6), projPaint);

    // 6. l3 İÇİN KIRMIZI KESİKLİ UZANTILAR!
    final redProjPaint = Paint()..color = redHighlightCol..strokeWidth = 1.2;
    final double dimY2 = centerY + maxHalfH + 46;
    _drawDashedLine(canvas, Offset(tipX, dimY1 + 5), Offset(tipX, dimY2 + 5), redProjPaint);
    _drawDashedLine(canvas, Offset(reachEndX, centerY + halfD2), Offset(reachEndX, dimY2 + 5), redProjPaint);

    // 7. Ölçü Çizgileri ve Oklar
    // d1 h9
    _drawVerticalDim(
      canvas,
      tipX - 25,
      centerY - halfD1,
      centerY + halfD1,
      _formatLabel('d1 h9', 'Ø ${drillDiameter.toStringAsFixed(2)}'),
      dimCol,
      isLeft: true,
    );

    // d2 h6
    _drawVerticalDim(
      canvas,
      shankEndX + 25,
      centerY - halfD2,
      centerY + halfD2,
      _formatLabel('d2 h6', 'Ø ${shankDiameter.toStringAsFixed(2)}'),
      dimCol,
      isLeft: false,
    );

    // d3 Boyun Gösterge Oku (Üst)
    final double neckMidX = (fluteEndX + reachEndX) / 2;
    canvas.drawLine(Offset(neckMidX, centerY - halfD3), Offset(neckMidX, centerY - halfD3 - 26), Paint()..color = dimCol..strokeWidth = 1.1);
    _drawArrowHead(canvas, Offset(neckMidX, centerY - halfD3), const Offset(0, 1), dimCol);
    _drawText(canvas, _formatLabel('d3', 'Ø ${neckDiameter.toStringAsFixed(1)}'), Offset(neckMidX, centerY - halfD3 - 34), dimCol, isCentered: true);

    // l2 Ölçüsü
    _drawHorizontalDim(canvas, dimY1, tipX, fluteEndX, _formatLabel('l2', '${fluteLength.toStringAsFixed(1)} mm'), dimCol);

    // l3 ÖLÇÜSÜ (KIRMIZI VURGULU!)
    _drawHorizontalDim(canvas, dimY2, tipX, reachEndX, _formatLabel('l3', '${reachLength.toStringAsFixed(1)} mm'), redHighlightCol, isBold: true);

    // l1 Ölçüsü
    _drawHorizontalDim(canvas, dimY3, tipX, shankEndX, _formatLabel('l1', '${totalLength.toStringAsFixed(1)} mm'), dimCol);
  }

  String _formatLabel(String symbol, String val) {
    if (dimensionDisplayMode == 'symbols') return symbol;
    if (dimensionDisplayMode == 'values') return val;
    return '$symbol ($val)';
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint, {double dash = 4.0, double gap = 3.0}) {
    final dist = (p2 - p1).distance;
    if (dist == 0) return;
    final dir = (p2 - p1) / dist;
    double d = 0;
    while (d < dist) {
      final len = math.min(dash, dist - d);
      canvas.drawLine(p1 + dir * d, p1 + dir * (d + len), paint);
      d += dash + gap;
    }
  }

  void _drawDashDotLine(Canvas canvas, Offset p1, Offset p2, Color color) {
    final paint = Paint()..color = color..strokeWidth = 0.9;
    final dist = (p2 - p1).distance;
    if (dist == 0) return;
    final dir = (p2 - p1) / dist;
    double d = 0;
    const longDash = 14.0;
    const gap = 3.5;
    const dot = 2.0;

    while (d < dist) {
      final curL = math.min(longDash, dist - d);
      canvas.drawLine(p1 + dir * d, p1 + dir * (d + curL), paint);
      d += longDash + gap;

      if (d < dist) {
        final dotPos = p1 + dir * d;
        canvas.drawCircle(dotPos, 0.7, paint);
        d += dot + gap;
      }
    }
  }

  void _drawArrowHead(Canvas canvas, Offset tip, Offset dir, Color color, {double size = 5.0, double width = 2.2}) {
    final norm = Offset(-dir.dy, dir.dx);
    final p1 = tip - dir * size + norm * width;
    final p2 = tip - dir * size - norm * width;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }

  void _drawHorizontalDim(Canvas canvas, double y, double x1, double x2, String text, Color color, {bool isBold = false}) {
    final linePaint = Paint()..color = color..strokeWidth = isBold ? 1.2 : 0.9;
    canvas.drawLine(Offset(x1, y), Offset(x2, y), linePaint);
    _drawArrowHead(canvas, Offset(x1, y), const Offset(1, 0), color);
    _drawArrowHead(canvas, Offset(x2, y), const Offset(-1, 0), color);
    _drawText(canvas, text, Offset((x1 + x2) / 2, y - 9), color, isCentered: true, isBold: isBold);
  }

  void _drawVerticalDim(Canvas canvas, double x, double y1, double y2, String text, Color color, {bool isLeft = true, bool isBold = false}) {
    final linePaint = Paint()..color = color..strokeWidth = isBold ? 1.2 : 0.9;
    canvas.drawLine(Offset(x, y1), Offset(x, y2), linePaint);
    _drawArrowHead(canvas, Offset(x, y1), const Offset(0, 1), color);
    _drawArrowHead(canvas, Offset(x, y2), const Offset(0, -1), color);
    _drawText(canvas, text, Offset(isLeft ? x - 6 : x + 6, (y1 + y2) / 2), color, isCentered: false, isLeft: isLeft, isBold: isBold);
  }

  void _drawText(Canvas canvas, String text, Offset pos, Color color, {bool isCentered = true, bool isLeft = false, bool isBold = false}) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: isBold ? 11 : 9.5,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: isCentered ? TextAlign.center : (isLeft ? TextAlign.right : TextAlign.left),
    )..layout();

    final Offset drawOffset = isCentered
        ? Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2)
        : (isLeft
            ? Offset(pos.dx - textPainter.width, pos.dy - textPainter.height / 2)
            : Offset(pos.dx, pos.dy - textPainter.height / 2));

    // Arka plan kutusu (metnin çizgileri örtmesi için)
    final bgRect = Rect.fromLTWH(drawOffset.dx - 2, drawOffset.dy - 1, textPainter.width + 4, textPainter.height + 2);
    canvas.drawRect(bgRect, Paint()..color = isCatalogWhiteMode ? Colors.white : const Color(0xFF080D14));

    textPainter.paint(canvas, drawOffset);
  }

  void _drawHexHead(
    Canvas canvas,
    double hexStartX,
    double hexEndX,
    double centerY,
    double halfHexH,
    Paint contourPaint,
    bool isWhiteMode,
  ) {
    final double facetSplit = halfHexH * 0.52;

    // Yüzey dolguları (3 görünür yüzey tonu)
    final faceFillCenter = Paint()
      ..style = PaintingStyle.fill
      ..color = isWhiteMode ? const Color(0xFFF1F3F5) : const Color(0xFF2C3947);
    final faceFillSides = Paint()
      ..style = PaintingStyle.fill
      ..color = isWhiteMode ? const Color(0xFFE2E6EA) : const Color(0xFF1D2631);

    // Üst yüzey
    canvas.drawRect(
      Rect.fromLTRB(hexStartX, centerY - halfHexH, hexEndX, centerY - facetSplit),
      faceFillSides,
    );
    // Orta yüzey
    canvas.drawRect(
      Rect.fromLTRB(hexStartX, centerY - facetSplit, hexEndX, centerY + facetSplit),
      faceFillCenter,
    );
    // Alt yüzey
    canvas.drawRect(
      Rect.fromLTRB(hexStartX, centerY + facetSplit, hexEndX, centerY + halfHexH),
      faceFillSides,
    );

    // Dış çevre konturu
    canvas.drawRect(
      Rect.fromLTRB(hexStartX, centerY - halfHexH, hexEndX, centerY + halfHexH),
      contourPaint,
    );

    // Yüzey ayrım çizgileri (Crease lines)
    final creasePaint = Paint()
      ..color = isWhiteMode ? const Color(0xFF495057) : const Color(0xFF00E5FF).withOpacity(0.7)
      ..strokeWidth = 1.3;
    canvas.drawLine(Offset(hexStartX, centerY - facetSplit), Offset(hexEndX, centerY - facetSplit), creasePaint);
    canvas.drawLine(Offset(hexStartX, centerY + facetSplit), Offset(hexEndX, centerY + facetSplit), creasePaint);

    // Köşe pahları (Chamfer lines)
    final chamferPaint = Paint()
      ..color = isWhiteMode ? const Color(0xFF6C757D) : const Color(0xFF90CAF9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(hexStartX, centerY - halfHexH + 3), Offset(hexStartX + 3, centerY - halfHexH), chamferPaint);
    canvas.drawLine(Offset(hexEndX - 3, centerY - halfHexH), Offset(hexEndX, centerY - halfHexH + 3), chamferPaint);
    canvas.drawLine(Offset(hexStartX, centerY + halfHexH - 3), Offset(hexStartX + 3, centerY + halfHexH), chamferPaint);
    canvas.drawLine(Offset(hexEndX - 3, centerY + halfHexH), Offset(hexEndX, centerY + halfHexH - 3), chamferPaint);
  }

  @override
  bool shouldRepaint(covariant IndustrialCatalogDrillPainter oldDelegate) {
    return oldDelegate.isCatalogWhiteMode != isCatalogWhiteMode ||
        oldDelegate.toolTipType != toolTipType ||
        oldDelegate.dimensionDisplayMode != dimensionDisplayMode ||
        oldDelegate.hasThreadedShank != hasThreadedShank ||
        oldDelegate.drillDiameter != drillDiameter ||
        oldDelegate.totalLength != totalLength ||
        oldDelegate.fluteLength != fluteLength ||
        oldDelegate.reachLength != reachLength ||
        oldDelegate.neckDiameter != neckDiameter ||
        oldDelegate.shankDiameter != shankDiameter ||
        oldDelegate.pointAngle != pointAngle ||
        oldDelegate.threadLength != threadLength ||
        oldDelegate.hexLength != hexLength ||
        oldDelegate.threadDiameter != threadDiameter ||
        oldDelegate.hexWidth != hexWidth;
  }
}

// =============================================================================
// 3D İNTERAKTİF TEKNİK CAD MODELİ ÇİZİCİSİ (Tool3DModelPainter)
// =============================================================================

class Tool3DModelPainter extends CustomPainter {
  final double rotX;
  final double rotY;
  final double rotZ;
  final double zoom;
  final bool isWireframe;
  final String toolTipType;
  final double pointAngle;
  final double drillDiameter;
  final double totalLength;
  final double fluteLength;
  final double reachLength;
  final double neckDiameter;
  final double shankDiameter;
  final bool hasThreadedShank;
  final double threadLength;
  final double threadDiameter;
  final double hexLength;
  final double hexWidth;
  final Color coatingColor;

  Tool3DModelPainter({
    required this.rotX,
    required this.rotY,
    required this.rotZ,
    required this.zoom,
    required this.isWireframe,
    required this.toolTipType,
    required this.pointAngle,
    required this.drillDiameter,
    required this.totalLength,
    required this.fluteLength,
    required this.reachLength,
    required this.neckDiameter,
    required this.shankDiameter,
    required this.hasThreadedShank,
    required this.threadLength,
    required this.threadDiameter,
    required this.hexLength,
    required this.hexWidth,
    required this.coatingColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Teknik CAD Izgara & Arka Plan
    final bgPaint = Paint()..color = const Color(0xFF090E17);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final gridPaintMinor = Paint()
      ..color = const Color(0xFF131D2A)
      ..strokeWidth = 0.6;
    final gridPaintMajor = Paint()
      ..color = const Color(0xFF1C2C3F)
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += 15) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), (x % 60 == 0) ? gridPaintMajor : gridPaintMinor);
    }
    for (double y = 0; y < size.height; y += 15) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), (y % 60 == 0) ? gridPaintMajor : gridPaintMinor);
    }

    // 2. 3D Geometri Üretimi
    final List<_Face3D> rawFaces = [];

    // Boyut oranlamaları (3D modelin koordinat birimleri: mm)
    final double r1 = drillDiameter / 2;
    final double r2 = shankDiameter / 2;
    final double r3 = neckDiameter / 2;
    final double tipX = -totalLength / 2;
    final double shankX = totalLength / 2;

    // Matkap veya Düz Freze Ucu
    final bool isEndMill = (toolTipType == 'endmill' || pointAngle >= 175.0);
    final double pointLen = isEndMill
        ? 0.0
        : (r1 / math.tan((pointAngle / 2) * math.pi / 180)).clamp(1.2, r1 * 1.6);

    const int radialSegments = 16;
    const double angleStep = 2 * math.pi / radialSegments;

    // A. Uç (Tip) Modeli
    final double fluteStartX = tipX + pointLen;
    if (isEndMill) {
      // Düz Freze: Düz ön ayna yüzeyi (End-Mill Face)
      final List<_Vec3> diskVertices = [];
      for (int i = 0; i < radialSegments; i++) {
        final double theta = i * angleStep;
        diskVertices.add(_Vec3(fluteStartX, r1 * math.cos(theta), r1 * math.sin(theta)));
      }
      rawFaces.add(_Face3D(
        vertices: diskVertices,
        color: coatingColor.withOpacity(0.95),
      ));
      // Kesici ağız gash çizgileri
      for (int i = 0; i < 4; i++) {
        final double th = i * (math.pi / 2);
        rawFaces.add(_Face3D(
          vertices: [
            _Vec3(fluteStartX - 0.2, 0, 0),
            _Vec3(fluteStartX - 0.2, r1 * math.cos(th), r1 * math.sin(th)),
          ],
          color: Colors.white,
          isEdgeOnly: true,
        ));
      }
    } else {
      // Matkap Ucu: Konik Uç ve Split Point Yüzeyleri
      final _Vec3 apex = _Vec3(tipX, 0, 0);
      for (int i = 0; i < radialSegments; i++) {
        final double th1 = i * angleStep;
        final double th2 = (i + 1) * angleStep;
        final v1 = _Vec3(fluteStartX, r1 * math.cos(th1), r1 * math.sin(th1));
        final v2 = _Vec3(fluteStartX, r1 * math.cos(th2), r1 * math.sin(th2));

        // Split point bileme yüzeyi ayrımı
        final bool isPrimaryRelief = (i >= 2 && i <= 5) || (i >= 10 && i <= 13);
        final Color tipFacetCol = isPrimaryRelief
            ? coatingColor.withOpacity(0.95)
            : Color.lerp(coatingColor, Colors.white, 0.2)!.withOpacity(0.95);

        rawFaces.add(_Face3D(
          vertices: [apex, v1, v2],
          color: tipFacetCol,
        ));
      }
    }

    // B. Helis Kanallı Gövde (Fluted Cutting Body)
    final double fluteEndX = tipX + fluteLength;
    const int fluteSlices = 14;
    final double sliceStep = (fluteEndX - fluteStartX) / fluteSlices;

    for (int s = 0; s < fluteSlices; s++) {
      final double x0 = fluteStartX + s * sliceStep;
      final double x1 = x0 + sliceStep;

      final double twist0 = ((x0 - fluteStartX) / fluteLength) * 2.2 * math.pi;
      final double twist1 = ((x1 - fluteStartX) / fluteLength) * 2.2 * math.pi;

      for (int i = 0; i < radialSegments; i++) {
        final double th0A = i * angleStep + twist0;
        final double th0B = (i + 1) * angleStep + twist0;
        final double th1A = i * angleStep + twist1;
        final double th1B = (i + 1) * angleStep + twist1;

        // Helis derinliği (İki talaş kanalı oyuntusu)
        final double depthFactor0A = (math.sin(2 * (i * angleStep)).abs() > 0.55) ? 0.76 : 1.0;
        final double depthFactor0B = (math.sin(2 * ((i + 1) * angleStep)).abs() > 0.55) ? 0.76 : 1.0;
        final double depthFactor1A = (math.sin(2 * (i * angleStep)).abs() > 0.55) ? 0.76 : 1.0;
        final double depthFactor1B = (math.sin(2 * ((i + 1) * angleStep)).abs() > 0.55) ? 0.76 : 1.0;

        final v0A = _Vec3(x0, r1 * depthFactor0A * math.cos(th0A), r1 * depthFactor0A * math.sin(th0A));
        final v0B = _Vec3(x0, r1 * depthFactor0B * math.cos(th0B), r1 * depthFactor0B * math.sin(th0B));
        final v1B = _Vec3(x1, r1 * depthFactor1B * math.cos(th1B), r1 * depthFactor1B * math.sin(th1B));
        final v1A = _Vec3(x1, r1 * depthFactor1A * math.cos(th1A), r1 * depthFactor1A * math.sin(th1A));

        final bool isFluteGroove = (depthFactor0A < 0.9);
        final Color quadColor = isFluteGroove
            ? const Color(0xFF1E2833)
            : coatingColor;

        rawFaces.add(_Face3D(
          vertices: [v0A, v0B, v1B, v1A],
          color: quadColor,
        ));
      }
    }

    // C. Boyun (Neck - d3)
    final double reachEndX = tipX + reachLength;
    if (reachLength > fluteLength + 1.0) {
      // Helisten boyuna geçiş koniği
      final double transitionLen = math.min(3.0, (reachEndX - fluteEndX) * 0.3);
      final double neckStartX = fluteEndX + transitionLen;
      final double neckEndX = reachEndX - transitionLen;

      // Koni 1
      _addCylinderRing(rawFaces, fluteEndX, neckStartX, r1, r3, radialSegments, const Color(0xFF334252));
      // Boyun silindiri
      _addCylinderRing(rawFaces, neckStartX, neckEndX, r3, r3, radialSegments, const Color(0xFF2C3947));
      // Koni 2 (Boyundan Sapa geçiş)
      _addCylinderRing(rawFaces, neckEndX, reachEndX, r3, r2, radialSegments, const Color(0xFF334252));
    }

    // D. Sap (Shank)
    if (!hasThreadedShank) {
      // Düz Silindirik Sap
      final double chamferStart = shankX - 2.0;
      _addCylinderRing(rawFaces, reachEndX, chamferStart, r2, r2, radialSegments, const Color(0xFF475569));
      // Pah ve arka kapak
      _addCylinderRing(rawFaces, chamferStart, shankX, r2, r2 * 0.7, radialSegments, const Color(0xFF3B4856));
      final List<_Vec3> endCap = [];
      for (int i = 0; i < radialSegments; i++) {
        final double theta = i * angleStep;
        endCap.add(_Vec3(shankX, r2 * 0.7 * math.cos(theta), r2 * 0.7 * math.sin(theta)));
      }
      rawFaces.add(_Face3D(vertices: endCap, color: const Color(0xFF2C3947)));
    } else {
      // STANDART NAS 965: Gövde -> Konik Geçiş -> 6-Gen Somun Kafa -> 1/4"-28 Vida (Uçta)
      final double threadEndX = shankX;
      final double threadStartX = threadEndX - threadLength;
      final double hexEndX = threadStartX;
      final double hexStartX = hexEndX - hexLength;
      final double bodyEndX = hexStartX - 2.5;

      // Gövde Silindiri
      _addCylinderRing(rawFaces, reachEndX, bodyEndX, r2, r2, radialSegments, const Color(0xFF475569));
      // Konik Omuz (Gövdeden 6-Gen Somuna)
      final double hexRadius = (hexWidth / 2) / math.cos(math.pi / 6);
      _addCylinderRing(rawFaces, bodyEndX, hexStartX, r2, hexRadius * 0.95, radialSegments, const Color(0xFF334252));

      // 6-Gen Somun Kafa (Hexagonal Prism - 6 Düz Yüzey)
      const int hexSides = 6;
      const double hexAngleStep = 2 * math.pi / hexSides;
      for (int i = 0; i < hexSides; i++) {
        final double th1 = i * hexAngleStep;
        final double th2 = (i + 1) * hexAngleStep;
        final v1 = _Vec3(hexStartX, hexRadius * math.cos(th1), hexRadius * math.sin(th1));
        final v2 = _Vec3(hexStartX, hexRadius * math.cos(th2), hexRadius * math.sin(th2));
        final v3 = _Vec3(hexEndX, hexRadius * math.cos(th2), hexRadius * math.sin(th2));
        final v4 = _Vec3(hexEndX, hexRadius * math.cos(th1), hexRadius * math.sin(th1));

        final Color hexFaceColor = (i % 2 == 0)
            ? const Color(0xFFCBD5E1)
            : const Color(0xFF94A3B8);

        rawFaces.add(_Face3D(
          vertices: [v1, v2, v3, v4],
          color: hexFaceColor,
        ));
      }

      // Vidalı Kısım (1/4"-28 Vida Dişli Silindir)
      final double rThread = threadDiameter / 2;
      const int threadRings = 9;
      final double ringStep = threadLength / threadRings;

      for (int t = 0; t < threadRings; t++) {
        final double tx0 = threadStartX + t * ringStep;
        final double tx1 = tx0 + ringStep * 0.6;
        final double tx2 = tx0 + ringStep;

        final double rPeak = rThread * 1.04;
        final double rRoot = rThread * 0.88;

        _addCylinderRing(rawFaces, tx0, tx1, rRoot, rPeak, radialSegments, const Color(0xFFFFB300));
        _addCylinderRing(rawFaces, tx1, tx2, rPeak, rRoot, radialSegments, const Color(0xFFD97706));
      }

      // Vida Uç Pahı & Ön Kapak
      final double tipChamferStartX = threadEndX - 1.2;
      _addCylinderRing(rawFaces, tipChamferStartX, threadEndX, rThread, rThread * 0.65, radialSegments, const Color(0xFF94A3B8));
      final List<_Vec3> threadEndCap = [];
      for (int i = 0; i < radialSegments; i++) {
        final double theta = i * angleStep;
        threadEndCap.add(_Vec3(threadEndX, rThread * 0.65 * math.cos(theta), rThread * 0.65 * math.sin(theta)));
      }
      rawFaces.add(_Face3D(vertices: threadEndCap, color: const Color(0xFF475569)));
    }

    // 3. 3D Döndürme & Projeksiyon
    final double maxDim = math.max(totalLength, math.max(drillDiameter, hexWidth) * 3);
    final double scale = (size.width * 0.72) / maxDim;
    const double cameraDist = 450.0;

    // Tüm yüzeylerin köşe noktalarını döndür
    final List<_Face3D> rotatedFaces = rawFaces.map((face) {
      final List<_Vec3> rotVertices = face.vertices.map((v) {
        return v.rotateX(rotX).rotateY(rotY).rotateZ(rotZ);
      }).toList();
      return _Face3D(
        vertices: rotVertices,
        color: face.color,
        isEdgeOnly: face.isEdgeOnly,
      );
    }).toList();

    // 4. Painter's Algorithm: Derinliğe Göre Sıralama (Z derinliği en uzaktan en yakına)
    rotatedFaces.sort((a, b) => a.averageZ.compareTo(b.averageZ));

    // 5. Işık ve Çizim
    final _Vec3 lightDir = const _Vec3(0.55, -0.75, -0.65).normalized;
    const _Vec3 eyeDir = _Vec3(0, 0, -1);

    final edgePaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final solidEdgePaint = Paint()
      ..color = Colors.black.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    for (final face in rotatedFaces) {
      if (face.vertices.length < 2) continue;

      // 3D noktaları 2D ekrana projekte et
      final List<Offset> projectedPoints = face.vertices.map((v) {
        final double f = cameraDist / (cameraDist - v.z);
        final double px = size.width / 2 + v.x * scale * zoom * f;
        final double py = size.height / 2 + v.y * scale * zoom * f;
        return Offset(px, py);
      }).toList();

      if (face.isEdgeOnly || face.vertices.length == 2) {
        canvas.drawLine(projectedPoints[0], projectedPoints[1], edgePaint);
        continue;
      }

      final path = Path()..moveTo(projectedPoints[0].dx, projectedPoints[0].dy);
      for (int i = 1; i < projectedPoints.length; i++) {
        path.lineTo(projectedPoints[i].dx, projectedPoints[i].dy);
      }
      path.close();

      if (isWireframe) {
        // Tel Kafes Görünümü
        canvas.drawPath(path, edgePaint);
      } else {
        // Katı Model: Phong / Gouraud Aydınlatmalı Metalik Yüzey
        final normal = face.normal;
        final double diff = math.max(0.0, -normal.dot(lightDir));
        const double ambient = 0.32;

        // Speküler Parlama
        final double nDotL = normal.dot(lightDir);
        final _Vec3 r = (lightDir - normal * (2 * nDotL)).normalized;
        final double spec = math.pow(math.max(0.0, -r.dot(eyeDir)), 14) * 0.45;

        final double brightness = (ambient + diff * 0.60 + spec).clamp(0.18, 1.4);

        Color litColor = _shadeColor(face.color, brightness);
        if (spec > 0.18) {
          litColor = Color.lerp(litColor, Colors.white, (spec - 0.18) * 0.75)!;
        }

        final fillPaint = Paint()
          ..color = litColor
          ..style = PaintingStyle.fill;

        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, solidEdgePaint);
      }
    }

    // 6. Eksen Çizgisi (Merkez Noktalı Eksen)
    final _Vec3 axisStart = const _Vec3(-100, 0, 0).rotateX(rotX).rotateY(rotY).rotateZ(rotZ);
    final _Vec3 axisEnd = const _Vec3(100, 0, 0).rotateX(rotX).rotateY(rotY).rotateZ(rotZ);
    final double fStart = cameraDist / (cameraDist - axisStart.z);
    final double fEnd = cameraDist / (cameraDist - axisEnd.z);
    final pAxis1 = Offset(size.width / 2 + axisStart.x * scale * zoom * fStart, size.height / 2 + axisStart.y * scale * zoom * fStart);
    final pAxis2 = Offset(size.width / 2 + axisEnd.x * scale * zoom * fEnd, size.height / 2 + axisEnd.y * scale * zoom * fEnd);

    final axisPaint = Paint()
      ..color = const Color(0xFFFF5252).withOpacity(0.4)
      ..strokeWidth = 1.0;
    canvas.drawLine(pAxis1, pAxis2, axisPaint);

    // 7. 3D Koordinat Tripod (Sol Alt Köşe)
    _drawCoordinateTripod(canvas, Offset(46, size.height - 46));
  }

  void _addCylinderRing(
    List<_Face3D> faces,
    double x0,
    double x1,
    double r0,
    double r1,
    int segments,
    Color color,
  ) {
    final double angleStep = 2 * math.pi / segments;
    for (int i = 0; i < segments; i++) {
      final double th1 = i * angleStep;
      final double th2 = (i + 1) * angleStep;

      final v0A = _Vec3(x0, r0 * math.cos(th1), r0 * math.sin(th1));
      final v0B = _Vec3(x0, r0 * math.cos(th2), r0 * math.sin(th2));
      final v1B = _Vec3(x1, r1 * math.cos(th2), r1 * math.sin(th2));
      final v1A = _Vec3(x1, r1 * math.cos(th1), r1 * math.sin(th1));

      faces.add(_Face3D(
        vertices: [v0A, v0B, v1B, v1A],
        color: color,
      ));
    }
  }

  Color _shadeColor(Color col, double factor) {
    final int r = (col.red * factor).clamp(0, 255).toInt();
    final int g = (col.green * factor).clamp(0, 255).toInt();
    final int b = (col.blue * factor).clamp(0, 255).toInt();
    return Color.fromARGB(col.alpha, r, g, b);
  }

  void _drawCoordinateTripod(Canvas canvas, Offset origin) {
    const double len = 26.0;
    final _Vec3 vx = const _Vec3(len, 0, 0).rotateX(rotX).rotateY(rotY).rotateZ(rotZ);
    final _Vec3 vy = const _Vec3(0, len, 0).rotateX(rotX).rotateY(rotY).rotateZ(rotZ);
    final _Vec3 vz = const _Vec3(0, 0, len).rotateX(rotX).rotateY(rotY).rotateZ(rotZ);

    // X: Kırmızı (Takım Ekseni)
    final pX = Offset(origin.dx + vx.x, origin.dy + vx.y);
    canvas.drawLine(origin, pX, Paint()..color = const Color(0xFFFF5252)..strokeWidth = 2.0);
    _drawText(canvas, 'X', pX, const Color(0xFFFF5252));

    // Y: Yeşil (Dikey)
    final pY = Offset(origin.dx + vy.x, origin.dy + vy.y);
    canvas.drawLine(origin, pY, Paint()..color = const Color(0xFF69F0AE)..strokeWidth = 2.0);
    _drawText(canvas, 'Y', pY, const Color(0xFF69F0AE));

    // Z: Mavi (Derinlik)
    final pZ = Offset(origin.dx + vz.x, origin.dy + vz.y);
    canvas.drawLine(origin, pZ, Paint()..color = const Color(0xFF40C4FF)..strokeWidth = 2.0);
    _drawText(canvas, 'Z', pZ, const Color(0xFF40C4FF));
  }

  void _drawText(Canvas canvas, String text, Offset pos, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pos.dx + 2, pos.dy - 6));
  }

  @override
  bool shouldRepaint(covariant Tool3DModelPainter oldDelegate) {
    return oldDelegate.rotX != rotX ||
        oldDelegate.rotY != rotY ||
        oldDelegate.rotZ != rotZ ||
        oldDelegate.zoom != zoom ||
        oldDelegate.isWireframe != isWireframe ||
        oldDelegate.toolTipType != toolTipType ||
        oldDelegate.pointAngle != pointAngle ||
        oldDelegate.drillDiameter != drillDiameter ||
        oldDelegate.totalLength != totalLength ||
        oldDelegate.fluteLength != fluteLength ||
        oldDelegate.reachLength != reachLength ||
        oldDelegate.neckDiameter != neckDiameter ||
        oldDelegate.shankDiameter != shankDiameter ||
        oldDelegate.hasThreadedShank != hasThreadedShank ||
        oldDelegate.threadLength != threadLength ||
        oldDelegate.threadDiameter != threadDiameter ||
        oldDelegate.hexLength != hexLength ||
        oldDelegate.hexWidth != hexWidth ||
        oldDelegate.coatingColor != coatingColor;
  }
}

// 3D Vektör Sınıfı
class _Vec3 {
  final double x, y, z;
  const _Vec3(this.x, this.y, this.z);

  _Vec3 operator +(_Vec3 o) => _Vec3(x + o.x, y + o.y, z + o.z);
  _Vec3 operator -(_Vec3 o) => _Vec3(x - o.x, y - o.y, z - o.z);
  _Vec3 operator *(double s) => _Vec3(x * s, y * s, z * s);

  double dot(_Vec3 o) => x * o.x + y * o.y + z * o.z;
  _Vec3 cross(_Vec3 o) => _Vec3(
        y * o.z - z * o.y,
        z * o.x - x * o.z,
        x * o.y - y * o.x,
      );

  double get length => math.sqrt(x * x + y * y + z * z);
  _Vec3 get normalized {
    final l = length;
    return l == 0 ? const _Vec3(0, 0, 0) : _Vec3(x / l, y / l, z / l);
  }

  _Vec3 rotateX(double a) {
    final cosA = math.cos(a), sinA = math.sin(a);
    return _Vec3(x, y * cosA - z * sinA, y * sinA + z * cosA);
  }

  _Vec3 rotateY(double a) {
    final cosA = math.cos(a), sinA = math.sin(a);
    return _Vec3(x * cosA + z * sinA, y, -x * sinA + z * cosA);
  }

  _Vec3 rotateZ(double a) {
    final cosA = math.cos(a), sinA = math.sin(a);
    return _Vec3(x * cosA - y * sinA, x * sinA + y * cosA, z);
  }
}

// 3D Yüzey Çokgeni Sınıfı
class _Face3D {
  final List<_Vec3> vertices;
  final Color color;
  final bool isEdgeOnly;
  final double averageZ;
  final _Vec3 normal;

  _Face3D({
    required this.vertices,
    required this.color,
    this.isEdgeOnly = false,
  })  : averageZ = vertices.fold<double>(0.0, (sum, v) => sum + v.z) / (vertices.isEmpty ? 1 : vertices.length),
        normal = _calcNormal(vertices);

  static _Vec3 _calcNormal(List<_Vec3> v) {
    if (v.length < 3) return const _Vec3(0, 0, 1);
    final ab = v[1] - v[0];
    final ac = v[2] - v[0];
    return ab.cross(ac).normalized;
  }
}

// ==========================================
// 2. INCH - MM VE TEL/HARF OLCU TABLOLARI
// ==========================================

class UnitConverterScreen extends StatefulWidget {
  const UnitConverterScreen({super.key});

  @override
  State<UnitConverterScreen> createState() => _UnitConverterScreenState();
}

class _UnitConverterScreenState extends State<UnitConverterScreen> {
  final _inchController = TextEditingController();
  final _mmController = TextEditingController();

  final List<String> standardFractions = [
    '1/16', '1/8', '3/16', '1/4', '5/16', '3/8', '7/16', '1/2',
    '9/16', '5/8', '11/16', '3/4', '13/16', '7/8', '15/16', '1'
  ];

  @override
  void dispose() {
    _inchController.dispose();
    _mmController.dispose();
    super.dispose();
  }

  void _convertFromInch(String value) {
    if (value.isEmpty) {
      _mmController.clear();
      return;
    }
    double? inches;
    if (value.contains('/')) {
      final parts = value.split('/');
      if (parts.length == 2) {
        final num = double.tryParse(parts[0].trim());
        final den = double.tryParse(parts[1].trim());
        if (num != null && den != null && den != 0) {
          inches = num / den;
        }
      }
    } else {
      inches = double.tryParse(value);
    }

    if (inches != null) {
      final mm = inches * 25.4;
      _mmController.text = mm.toStringAsFixed(3);
    }
  }

  void _convertFromMm(String value) {
    if (value.isEmpty) {
      _inchController.clear();
      return;
    }
    final mm = double.tryParse(value);
    if (mm != null) {
      final inches = mm / 25.4;
      _inchController.text = inches.toStringAsFixed(4);
    }
  }

  void _applyFraction(String fraction) {
    _inchController.text = fraction;
    _convertFromInch(fraction);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hassas Ölçü & Havacılık Tel/Numara Tablosu'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: const Color(0xFF171E28),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _inchController,
                      keyboardType: TextInputType.text,
                      onChanged: _convertFromInch,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'İnç (in / " veya 1/4 kesir)',
                        suffixText: 'inch',
                        filled: true,
                        fillColor: const Color(0xFF0F141C),
                        prefixIcon: const Icon(Icons.straighten, color: Color(0xFF00E5FF)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Icon(Icons.swap_vert, color: Colors.grey, size: 28),
                    ),
                    TextField(
                      controller: _mmController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: _convertFromMm,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Milimetre (mm)',
                        suffixText: 'mm',
                        filled: true,
                        fillColor: const Color(0xFF0F141C),
                        prefixIcon: const Icon(Icons.tune, color: Color(0xFFFFB300)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Standart Kesirli İnç Ölçüleri:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: standardFractions.map((fraction) {
                return ActionChip(
                  label: Text('$fraction"'),
                  backgroundColor: const Color(0xFF171E28),
                  side: const BorderSide(color: Color(0xFF232E3E)),
                  onPressed: () => _applyFraction(fraction),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Havacılık Numaralı Matkap Çapları Tablosu (Wire Gauge)
            Card(
              color: const Color(0xFF171E28),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.flight, color: Color(0xFF00E5FF)),
                        SizedBox(width: 8),
                        Text(
                          'Havacılıkta Kullanılan Standart Matkap Boyutları',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Table(
                      border: TableBorder.all(color: const Color(0xFF232E3E)),
                      children: const [
                        TableRow(
                          decoration: BoxDecoration(color: Color(0xFF0F141C)),
                          children: [
                            Padding(padding: EdgeInsets.all(8.0), child: Text('Tel No / Ölçü', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('Ondalık İnç', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('Milimetre (mm)', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('Standart Perçin', style: TextStyle(color: Color(0xFFFFB300), fontWeight: FontWeight.bold))),
                          ],
                        ),
                        TableRow(
                          decoration: BoxDecoration(color: Color(0xFF1B2A38)),
                          children: [
                            Padding(padding: EdgeInsets.all(8.0), child: Text('#40', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber))),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('0.0980"')),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('2.49 mm')),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('3/32" Perçin')),
                        ]),
                        TableRow(
                          decoration: BoxDecoration(color: Color(0xFF1B2A38)),
                          children: [
                            Padding(padding: EdgeInsets.all(8.0), child: Text('#30', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber))),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('0.1285"')),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('3.26 mm')),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('1/8" Perçin')),
                        ]),
                        TableRow(
                          decoration: BoxDecoration(color: Color(0xFF1B2A38)),
                          children: [
                            Padding(padding: EdgeInsets.all(8.0), child: Text('#21', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber))),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('0.1590"')),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('4.04 mm')),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('5/32" Perçin')),
                        ]),
                        TableRow(
                          decoration: BoxDecoration(color: Color(0xFF1B2A38)),
                          children: [
                            Padding(padding: EdgeInsets.all(8.0), child: Text('#10', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber))),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('0.1935"')),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('4.92 mm')),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('3/16" Perçin')),
                        ]),
                        TableRow(children: [
                          Padding(padding: EdgeInsets.all(8.0), child: Text('1/4"', style: TextStyle(fontWeight: FontWeight.bold))),
                          Padding(padding: EdgeInsets.all(8.0), child: Text('0.2500"')),
                          Padding(padding: EdgeInsets.all(8.0), child: Text('6.35 mm')),
                          Padding(padding: EdgeInsets.all(8.0), child: Text('1/4" Civata/Perçin')),
                        ]),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
