import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
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
  bool show3DDimensions = true; // 3D Yüzen CAD Ölçülendirme Çizgileri & Etiketleri
  String renderStyle3D = 'solid'; // 'solid' (Katı Model) veya 'wireframe' (Tel Kafes)
  double _baseZoom = 1.0;
  Offset _lastFocalPoint = Offset.zero;
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
  int fluteCount = 2; // 2: 2 Ağızlı (Standart Helis), 3: 3 Ağızlı (Rijit / Havacılık)

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
    FocusManager.instance.primaryFocus?.unfocus();
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
    FocusManager.instance.primaryFocus?.unfocus();
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

  // ===========================================================================
  // 3D TEKNİK RESİM GÖRÜNTÜLEME VE YAZDIRMA MOTORU (A4 LANDSCAPE CAD BLUEPRINT)
  // ===========================================================================

  Future<void> _open3DTechnicalDrawing() async {
    try {
      final pdfBytes = await _build3DPdfDocument(PdfPageFormat.a4.landscape);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: '3D_CAD_Blueprint_Drill_${drillDiameter.toStringAsFixed(2)}mm_Z$fluteCount.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('3D PDF Oluşturma Hatası: $e')),
        );
      }
    }
  }

  Future<Uint8List> _build3DPdfDocument(PdfPageFormat format) async {
    final doc = pw.Document();
    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(841.89, 595.28, marginAll: 0),
        build: (pw.Context context) {
          final pdfFont = font.getFont(context);
          final pdfFontBold = fontBold.getFont(context);

          return pw.CustomPaint(
            size: const PdfPoint(841.89, 595.28),
            painter: (PdfGraphics canvas, PdfPoint size) {
              _drawCompleteEngineeringBlueprintPdf(canvas, size, pdfFont, pdfFontBold);
            },
          );
        },
      ),
    );

    return doc.save();
  }

  // ===========================================================================
  // DIN EN ISO 2768 / NAS 965 TAM MÜHENDİSLİK TEKNİK RESİM ÇİZİM MOTORU (PDF)
  // ===========================================================================

  void _drawCompleteEngineeringBlueprintPdf(
    PdfGraphics canvas,
    PdfPoint size,
    PdfFont pdfFont,
    PdfFont pdfFontBold,
  ) {
    double py(double yFromTop) => size.y - yFromTop;

    // 1. Sayfa Beyaz Zemin (Drafting Paper White)
    canvas.setFillColor(PdfColors.white);
    canvas.drawRect(0, 0, size.x, size.y);
    canvas.fillPath();

    // 2. Çift Kenarlık (Dual Border) ve 4 Merkezleme İşareti (Centering Marks)
    _drawPdfBlueprintBorders(canvas, size, py);

    // 3. Ana Boyuna 2D Kesici Takım Görünüşü (Merkez-Sol & Üst)
    _drawPdfMainToolView(canvas, size, py, pdfFont, pdfFontBold);

    // 4. Kesici Uç Alın Görünüşü (Sağ Üst, 4:1)
    _drawPdfAxialView(canvas, size, py, pdfFont, pdfFontBold);

    // 5. Detay C: DIN 509 Boşaltma Kanalı (Sağ Orta, 4:1)
    _drawPdfDetailC(canvas, size, py, pdfFont, pdfFontBold);

    // 6. Kesit A-A: Boyuna Kesit ve 45° Tarama Çizgileri (Sol Alt, 1:1)
    _drawPdfSectionA(canvas, size, py, pdfFont, pdfFontBold);

    // 7. 3D İzometrik Shaded CAD Modeli Bölgesi (Orta Alt)
    _drawPdf3DModelZone(canvas, size, py, pdfFont, pdfFontBold);

    // 8. Genel İmalat Notları ve Genel Yüzey Pürüzlülüğü Sembolü (Antet Üstü)
    _drawPdfGeneralNotesAndRoughness(canvas, size, py, pdfFont, pdfFontBold);

    // 9. DIN / ISO Mühendislik Anteti (Sağ Alt Köşe)
    _drawPdfTitleBlock(canvas, size, py, pdfFont, pdfFontBold);
  }

  void _drawPdfBlueprintBorders(PdfGraphics canvas, PdfPoint size, double Function(double) py) {
    // Dış İnce Çerçeve (0.7 pt)
    canvas.setColor(PdfColors.black);
    canvas.setLineWidth(0.7);
    canvas.drawRect(14, py(581.28), 813.89, 567.28);
    canvas.strokePath();

    // İç Kalın Çerçeve (1.6 pt)
    canvas.setColor(PdfColors.black);
    canvas.setLineWidth(1.6);
    canvas.drawRect(24, py(571.28), 793.89, 547.28);
    canvas.strokePath();

    // 4 Kenar Merkezleme Çeltikleri (Centering Marks)
    canvas.setLineWidth(1.1);
    // Üst Merkez
    canvas.moveTo(420.94, py(14)); canvas.lineTo(420.94, py(24));
    // Alt Merkez
    canvas.moveTo(420.94, py(581.28)); canvas.lineTo(420.94, py(571.28));
    // Sol Merkez
    canvas.moveTo(14, py(297.64)); canvas.lineTo(24, py(297.64));
    // Sağ Merkez
    canvas.moveTo(827.89, py(297.64)); canvas.lineTo(817.89, py(297.64));
    canvas.strokePath();
  }

  void _drawPdfInspectionBalloon(PdfGraphics canvas, double cx, double cyPdf, int number, PdfFont pdfFontBold) {
    const double r = 6.5;
    canvas.setFillColor(PdfColors.white);
    canvas.drawEllipse(cx, cyPdf, r, r);
    canvas.fillPath();
    canvas.setColor(const PdfColor(0.16, 0.47, 1.0)); // Standart Mavi Balon (#2979FF)
    canvas.setLineWidth(0.85);
    canvas.drawEllipse(cx, cyPdf, r, r);
    canvas.strokePath();
    final String s = '$number';
    final double xOff = (number >= 10) ? 3.8 : 2.2;
    canvas.setFillColor(const PdfColor(0.16, 0.47, 1.0));
    canvas.drawString(pdfFontBold, 6.5, s, cx - xOff, cyPdf - 2.2);
  }

  void _drawPdfChainLine(PdfGraphics canvas, double x1, double y1Pdf, double x2, double y2Pdf, {PdfColor? color, double width = 0.5}) {
    canvas.setColor(color ?? PdfColors.grey700);
    canvas.setLineWidth(width);
    final double dx = x2 - x1;
    final double dy = y2Pdf - y1Pdf;
    final double len = math.sqrt(dx * dx + dy * dy);
    if (len < 1.0) return;
    final double ux = dx / len;
    final double uy = dy / len;
    double dist = 0.0;
    while (dist < len) {
      final double seg1 = math.min(12.0, len - dist);
      canvas.moveTo(x1 + ux * dist, y1Pdf + uy * dist);
      canvas.lineTo(x1 + ux * (dist + seg1), y1Pdf + uy * (dist + seg1));
      canvas.strokePath();
      dist += seg1 + 3.0;
      if (dist >= len) break;
      final double seg2 = math.min(2.0, len - dist);
      canvas.moveTo(x1 + ux * dist, y1Pdf + uy * dist);
      canvas.lineTo(x1 + ux * (dist + seg2), y1Pdf + uy * (dist + seg2));
      canvas.strokePath();
      dist += seg2 + 3.0;
    }
  }

  void _drawPdfGdtFrame(PdfGraphics canvas, double x, double yPdf, String symbol, String tol, String datum, PdfFont pdfFont, PdfFont pdfFontBold) {
    canvas.setColor(PdfColors.black);
    canvas.setLineWidth(0.7);
    canvas.drawRect(x, yPdf - 11, 42, 11);
    canvas.strokePath();
    canvas.moveTo(x + 12, yPdf - 11); canvas.lineTo(x + 12, yPdf);
    canvas.moveTo(x + 30, yPdf - 11); canvas.lineTo(x + 30, yPdf);
    canvas.strokePath();
    canvas.drawString(pdfFontBold, 7, symbol, x + 3, yPdf - 8.5);
    canvas.drawString(pdfFont, 6.5, tol, x + 14, yPdf - 8.5);
    canvas.drawString(pdfFontBold, 7, datum, x + 33, yPdf - 8.5);
  }

  void _drawPdfDatumMarker(PdfGraphics canvas, double x, double yPdf, String label, PdfFont pdfFontBold) {
    canvas.setColor(PdfColors.black);
    canvas.setLineWidth(0.7);
    canvas.drawRect(x - 5.5, yPdf - 5.5, 11, 11);
    canvas.strokePath();
    canvas.drawString(pdfFontBold, 7, label, x - 2.8, yPdf - 2.8);
  }

  void _drawPdfSurfaceFinish(PdfGraphics canvas, double x, double yPdf, String raVal, PdfFont pdfFont) {
    canvas.setColor(PdfColors.black);
    canvas.setLineWidth(0.7);
    canvas.moveTo(x - 3, yPdf - 6);
    canvas.lineTo(x, yPdf);
    canvas.lineTo(x + 5, yPdf - 11);
    canvas.lineTo(x + 16, yPdf - 11);
    canvas.strokePath();
    canvas.drawString(pdfFont, 6.0, raVal, x + 5.5, yPdf - 10.0);
  }

  void _drawPdfMainToolView(
    PdfGraphics canvas,
    PdfPoint size,
    double Function(double) py,
    PdfFont pdfFont,
    PdfFont pdfFontBold,
  ) {
    const double cyTop = 150.0;
    final double cyPdf = py(cyTop);

    // 1. Eksen Çizgisi (Centerline - · - · -)
    _drawPdfChainLine(canvas, 42, cyPdf, 525, cyPdf);

    final bool isEndMill = (toolTipType == 'endmill' || pointAngle >= 175.0);
    const double xTip = 80.0;
    const double r1 = 18.0;
    const double r3 = 14.5;
    const double r2 = 18.0;
    final double lPt = isEndMill ? 3.0 : (r1 / math.tan((pointAngle / 2) * math.pi / 180)).clamp(6.0, 18.0);
    final double xFluteStart = xTip + lPt;
    const double xFluteEnd = 220.0;
    const double xNeckEnd = 295.0;
    const double xShankEnd = 375.0;
    const double xHexEnd = 410.0;
    const double xThreadEnd = 475.0;

    // 2. Takım Geometrisi Gövdesi (Solid Outline)
    canvas.setColor(PdfColors.black);
    canvas.setLineWidth(1.2);

    if (isEndMill) {
      // Düz Freze Alın ve 45° Köşe Pahları
      canvas.moveTo(xTip, py(cyTop - 15)); canvas.lineTo(xTip, py(cyTop + 15));
      canvas.moveTo(xTip, py(cyTop - 15)); canvas.lineTo(xTip + 3, py(cyTop - r1));
      canvas.moveTo(xTip, py(cyTop + 15)); canvas.lineTo(xTip + 3, py(cyTop + r1));
      // Alın Merkez Çanak Eğrisi (Dish)
      canvas.moveTo(xTip, py(cyTop - 4)); canvas.lineTo(xTip + 1.5, py(cyTop)); canvas.lineTo(xTip, py(cyTop + 4));
    } else {
      // Matkap Uç Konisi (135° veya 118°)
      canvas.moveTo(xTip, cyPdf); canvas.lineTo(xFluteStart, py(cyTop - r1));
      canvas.moveTo(xTip, cyPdf); canvas.lineTo(xFluteStart, py(cyTop + r1));
      // Öz Kenar (Chisel)
      canvas.moveTo(xTip, py(cyTop - 2)); canvas.lineTo(xTip, py(cyTop + 2));
    }

    // Helis Gövde Dış Kenarları (Flute land lines)
    canvas.moveTo(xFluteStart, py(cyTop - r1)); canvas.lineTo(xFluteEnd, py(cyTop - r1));
    canvas.moveTo(xFluteStart, py(cyTop + r1)); canvas.lineTo(xFluteEnd, py(cyTop + r1));
    canvas.strokePath();

    // Helis Zırh ve Kanal Eğrileri (Helical lands)
    canvas.setColor(PdfColors.grey800);
    canvas.setLineWidth(0.8);
    // Zırh Payı (Margin line)
    canvas.moveTo(xFluteStart, py(cyTop - r1 + 1.6)); canvas.lineTo(xFluteEnd, py(cyTop - r1 + 1.6));
    canvas.moveTo(xFluteStart, py(cyTop + r1 - 1.6)); canvas.lineTo(xFluteEnd, py(cyTop + r1 - 1.6));
    canvas.strokePath();

    // Helis Dalgaları (Spiral flute curves)
    for (int k = 0; k < 4; k++) {
      final double sx = xFluteStart + 12 + k * 28;
      canvas.moveTo(sx, py(cyTop - r1));
      canvas.curveTo(sx + 8, py(cyTop - 6), sx + 12, py(cyTop + 6), sx + 20, py(cyTop + r1));
      canvas.strokePath();
    }

    // Boyun Boşaltması (Neck Transition d3)
    canvas.setColor(PdfColors.black);
    canvas.setLineWidth(1.2);
    // Üst Boyun ve Radyüsler
    canvas.moveTo(xFluteEnd, py(cyTop - r1));
    canvas.curveTo(xFluteEnd + 5, py(cyTop - r3), xFluteEnd + 6, py(cyTop - r3), xFluteEnd + 10, py(cyTop - r3));
    canvas.lineTo(xNeckEnd - 10, py(cyTop - r3));
    canvas.curveTo(xNeckEnd - 6, py(cyTop - r3), xNeckEnd - 5, py(cyTop - r2), xNeckEnd, py(cyTop - r2));

    // Alt Boyun ve Radyüsler
    canvas.moveTo(xFluteEnd, py(cyTop + r1));
    canvas.curveTo(xFluteEnd + 5, py(cyTop + r3), xFluteEnd + 6, py(cyTop + r3), xFluteEnd + 10, py(cyTop + r3));
    canvas.lineTo(xNeckEnd - 10, py(cyTop + r3));
    canvas.curveTo(xNeckEnd - 6, py(cyTop + r3), xNeckEnd - 5, py(cyTop + r2), xNeckEnd, py(cyTop + r2));
    canvas.strokePath();

    // Silindirik Sap Gövdesi (Straight Shank d2)
    canvas.moveTo(xNeckEnd, py(cyTop - r2)); canvas.lineTo(xShankEnd, py(cyTop - r2));
    canvas.moveTo(xNeckEnd, py(cyTop + r2)); canvas.lineTo(xShankEnd, py(cyTop + r2));
    canvas.strokePath();

    if (hasThreadedShank) {
      // Altıköşe Somun Kafa (Hex Collar NAS 965)
      const double rHex = 22.0;
      canvas.setLineWidth(1.3);
      // Düz Alın Faturası (Washer collar face - sapa 90° dik!)
      canvas.moveTo(xShankEnd, py(cyTop - rHex)); canvas.lineTo(xShankEnd, py(cyTop + rHex));
      canvas.moveTo(xShankEnd, py(cyTop - rHex)); canvas.lineTo(xHexEnd, py(cyTop - rHex));
      canvas.moveTo(xShankEnd, py(cyTop + rHex)); canvas.lineTo(xHexEnd, py(cyTop + rHex));
      canvas.moveTo(xHexEnd, py(cyTop - rHex)); canvas.lineTo(xHexEnd, py(cyTop + rHex));
      canvas.strokePath();

      // Somun Faset Çizgileri ve 30° Köşe Pahları
      canvas.setLineWidth(0.7);
      canvas.moveTo(xShankEnd, py(cyTop - 11.5)); canvas.lineTo(xHexEnd, py(cyTop - 11.5));
      canvas.moveTo(xShankEnd, py(cyTop + 11.5)); canvas.lineTo(xHexEnd, py(cyTop + 11.5));
      canvas.strokePath();

      // Boşaltma Kanalı (Detail C: DIN 509 Undercut)
      const double xUndercut = 417.0;
      canvas.setLineWidth(1.1);
      canvas.moveTo(xHexEnd, py(cyTop - 14)); canvas.lineTo(xUndercut, py(cyTop - 14));
      canvas.moveTo(xHexEnd, py(cyTop + 14)); canvas.lineTo(xUndercut, py(cyTop + 14));
      canvas.strokePath();

      // Vidalı Sap Bölümü (1/4"-28 UNF Thread)
      const double rThCrest = 17.0;
      const double rThRoot = 14.5;
      canvas.setLineWidth(1.2);
      // Diş Üstü Çizgileri
      canvas.moveTo(xUndercut, py(cyTop - rThCrest)); canvas.lineTo(xThreadEnd - 3, py(cyTop - rThCrest));
      canvas.moveTo(xUndercut, py(cyTop + rThCrest)); canvas.lineTo(xThreadEnd - 3, py(cyTop + rThCrest));
      // 45° Uç Pahı ve Alın
      canvas.lineTo(xThreadEnd, py(cyTop + rThCrest - 3));
      canvas.lineTo(xThreadEnd, py(cyTop - rThCrest + 3));
      canvas.lineTo(xThreadEnd - 3, py(cyTop - rThCrest));
      canvas.strokePath();

      // Diş Dibi Kesik Çizgileri (Root lines)
      canvas.setColor(PdfColors.grey700);
      canvas.setLineWidth(0.6);
      canvas.moveTo(xUndercut, py(cyTop - rThRoot)); canvas.lineTo(xThreadEnd - 3, py(cyTop - rThRoot));
      canvas.moveTo(xUndercut, py(cyTop + rThRoot)); canvas.lineTo(xThreadEnd - 3, py(cyTop + rThRoot));
      canvas.strokePath();

      // Diş Sırtı Çizgileri (Thread ridges every 3.2 pt)
      for (double tx = xUndercut + 2.5; tx < xThreadEnd - 3; tx += 3.2) {
        canvas.moveTo(tx, py(cyTop - rThCrest));
        canvas.lineTo(tx + 1.2, py(cyTop + rThCrest));
        canvas.strokePath();
      }
    } else {
      // Düz Silindirik Sap Sonu ve 45° Pah
      canvas.setLineWidth(1.2);
      canvas.moveTo(xShankEnd, py(cyTop - r2)); canvas.lineTo(xThreadEnd - 3, py(cyTop - r2));
      canvas.moveTo(xShankEnd, py(cyTop + r2)); canvas.lineTo(xThreadEnd - 3, py(cyTop + r2));
      canvas.lineTo(xThreadEnd, py(cyTop + r2 - 3));
      canvas.lineTo(xThreadEnd, py(cyTop - r2 + 3));
      canvas.lineTo(xThreadEnd - 3, py(cyTop - r2));
      canvas.strokePath();
    }

    // =========================================================================
    // 3. ÖLÇÜLENDİRME ÇİZGİLERİ VE DENETİM BALONLARI (INSPECTION BALLOONS 1-10)
    // =========================================================================

    canvas.setColor(PdfColors.black);
    canvas.setLineWidth(0.6);

    // --- (1) Takım Çapı d1 (h9) ---
    canvas.moveTo(xTip, py(cyTop - r1)); canvas.lineTo(52, py(cyTop - r1));
    canvas.moveTo(xTip, py(cyTop + r1)); canvas.lineTo(52, py(cyTop + r1));
    canvas.moveTo(56, py(cyTop - r1)); canvas.lineTo(56, py(cyTop + r1));
    canvas.strokePath();
    _drawPdfArrow(canvas, 56, py(cyTop - r1), 0, -1, PdfColors.black, size: 4);
    _drawPdfArrow(canvas, 56, py(cyTop + r1), 0, 1, PdfColors.black, size: 4);
    canvas.drawString(pdfFontBold, 7.5, 'd1 = ${drillDiameter.toStringAsFixed(2)} h9', 32, py(cyTop - 2));
    _drawPdfInspectionBalloon(canvas, 38, py(cyTop - 14), 1, pdfFontBold);

    // --- (2) Kesme Boyu l2 (±0.1) ---
    canvas.moveTo(xTip, py(cyTop - r1)); canvas.lineTo(xTip, py(85));
    canvas.moveTo(xFluteEnd, py(cyTop - r1)); canvas.lineTo(xFluteEnd, py(85));
    canvas.moveTo(xTip, py(89)); canvas.lineTo(xFluteEnd, py(89));
    canvas.strokePath();
    _drawPdfArrow(canvas, xTip, py(89), -1, 0, PdfColors.black, size: 4);
    _drawPdfArrow(canvas, xFluteEnd, py(89), 1, 0, PdfColors.black, size: 4);
    canvas.drawString(pdfFontBold, 7.5, 'l2 = ${fluteLength.toStringAsFixed(1)} +/-0.1', 125, py(84));
    _drawPdfInspectionBalloon(canvas, 150, py(72), 2, pdfFontBold);

    // --- (3) Kullanılabilir Derinlik / Reach Boyu l3 (±0.2) ---
    canvas.moveTo(xNeckEnd, py(cyTop - r3)); canvas.lineTo(xNeckEnd, py(68));
    canvas.moveTo(xTip, py(85)); canvas.lineTo(xTip, py(68));
    canvas.moveTo(xTip, py(72)); canvas.lineTo(xNeckEnd, py(72));
    canvas.strokePath();
    _drawPdfArrow(canvas, xTip, py(72), -1, 0, PdfColors.black, size: 4);
    _drawPdfArrow(canvas, xNeckEnd, py(72), 1, 0, PdfColors.black, size: 4);
    canvas.drawString(pdfFontBold, 7.5, 'l3 = ${reachLength.toStringAsFixed(1)} +/-0.2', 170, py(67));
    _drawPdfInspectionBalloon(canvas, 205, py(56), 3, pdfFontBold);

    // --- (4) Boyun Çapı d3 (±0.1) ---
    const double xDimNeck = 258.0;
    canvas.moveTo(xDimNeck, py(cyTop - r3)); canvas.lineTo(xDimNeck, py(cyTop + r3));
    canvas.strokePath();
    _drawPdfArrow(canvas, xDimNeck, py(cyTop - r3), 0, -1, PdfColors.black, size: 4);
    _drawPdfArrow(canvas, xDimNeck, py(cyTop + r3), 0, 1, PdfColors.black, size: 4);
    canvas.drawString(pdfFont, 7.0, 'd3 = ${neckDiameter.toStringAsFixed(2)}', xDimNeck - 18, py(cyTop - 2));
    _drawPdfInspectionBalloon(canvas, xDimNeck, py(118), 4, pdfFontBold);

    // --- (5) Sap Çapı d2 (h6) ---
    const double xDimShank = 338.0;
    canvas.moveTo(xDimShank, py(cyTop - r2)); canvas.lineTo(xDimShank, py(cyTop + r2));
    canvas.strokePath();
    _drawPdfArrow(canvas, xDimShank, py(cyTop - r2), 0, -1, PdfColors.black, size: 4);
    _drawPdfArrow(canvas, xDimShank, py(cyTop + r2), 0, 1, PdfColors.black, size: 4);
    canvas.drawString(pdfFontBold, 7.5, 'd2 = ${shankDiameter.toStringAsFixed(2)} h6', xDimShank - 22, py(cyTop - 2));
    _drawPdfInspectionBalloon(canvas, xDimShank, py(118), 5, pdfFontBold);

    // --- (6) Toplam Boy l1 (±0.2) ---
    canvas.moveTo(xTip, py(cyTop + r1)); canvas.lineTo(xTip, py(218));
    canvas.moveTo(xThreadEnd, py(cyTop + 14)); canvas.lineTo(xThreadEnd, py(218));
    canvas.moveTo(xTip, py(214)); canvas.lineTo(xThreadEnd, py(214));
    canvas.strokePath();
    _drawPdfArrow(canvas, xTip, py(214), -1, 0, PdfColors.black, size: 4);
    _drawPdfArrow(canvas, xThreadEnd, py(214), 1, 0, PdfColors.black, size: 4);
    canvas.drawString(pdfFontBold, 8.0, 'l1 = ${totalLength.toStringAsFixed(1)} +/-0.2 (TAM BOY)', 230, py(208));
    _drawPdfInspectionBalloon(canvas, 275, py(228), 6, pdfFontBold);

    // --- (7) Vidalı Sap Bağlantı Çağrısı (NAS 965 Tip D) ---
    if (hasThreadedShank) {
      canvas.moveTo(445, py(cyTop - 17)); canvas.lineTo(465, py(105)); canvas.lineTo(515, py(105));
      canvas.strokePath();
      _drawPdfArrow(canvas, 445, py(cyTop - 17), -1, 1, PdfColors.black, size: 3.5);
      canvas.drawString(pdfFontBold, 7.0, '1/4"-28 UNF-2A Dis', 466, py(100));
      _drawPdfInspectionBalloon(canvas, 525, py(105), 7, pdfFontBold);

      // --- (8) Altıköşe Somun Kafa (5/16" SW) ---
      canvas.moveTo(392, py(cyTop - 22)); canvas.lineTo(405, py(95)); canvas.lineTo(440, py(95));
      canvas.strokePath();
      _drawPdfArrow(canvas, 392, py(cyTop - 22), -1, 1, PdfColors.black, size: 3.5);
      canvas.drawString(pdfFontBold, 7.0, '5/16" SW Somun Kafa', 406, py(90));
      _drawPdfInspectionBalloon(canvas, 450, py(95), 8, pdfFontBold);
    } else {
      canvas.moveTo(470, py(cyTop - r2)); canvas.lineTo(485, py(105)); canvas.lineTo(525, py(105));
      canvas.strokePath();
      _drawPdfArrow(canvas, 470, py(cyTop - r2), -1, 1, PdfColors.black, size: 3.5);
      canvas.drawString(pdfFontBold, 7.0, 'DIN 6527 1x45 Pah', 486, py(100));
      _drawPdfInspectionBalloon(canvas, 535, py(105), 7, pdfFontBold);
    }

    // --- (9) Uç Açısı Çağrısı (Point Angle) ---
    canvas.moveTo(xTip + 2, py(cyTop - 6)); canvas.lineTo(60, py(115)); canvas.lineTo(42, py(115));
    canvas.strokePath();
    _drawPdfArrow(canvas, xTip + 2, py(cyTop - 6), 1, -1, PdfColors.black, size: 3.5);
    canvas.drawString(pdfFontBold, 7.0, isEndMill ? '180 Alin' : '${pointAngle.toStringAsFixed(0)} Uc Acisi', 28, py(110));
    _drawPdfInspectionBalloon(canvas, 68, py(115), 9, pdfFontBold);

    // --- (10) Boyun Geçiş Radyüsü (R 1.5) ---
    canvas.moveTo(222, py(cyTop + r1 - 2)); canvas.lineTo(210, py(180)); canvas.lineTo(190, py(180));
    canvas.strokePath();
    _drawPdfArrow(canvas, 222, py(cyTop + r1 - 2), 1, 1, PdfColors.black, size: 3.5);
    canvas.drawString(pdfFont, 7.0, 'R 1.5', 192, py(176));
    _drawPdfInspectionBalloon(canvas, 180, py(180), 10, pdfFontBold);

    // =========================================================================
    // 4. GD&T GEOMETRİK TOLERANS, DATUM VE YÜZEY KALİTESİ SEMBOLLERİ
    // =========================================================================

    // GD&T Dairesel Salgı Toleransı [ ↗ | 0,02 | B ]
    _drawPdfGdtFrame(canvas, 125, py(100), '^', '0,02', 'B', pdfFont, pdfFontBold);
    canvas.moveTo(146, py(111)); canvas.lineTo(152, py(cyTop - r1));
    canvas.strokePath();
    _drawPdfArrow(canvas, 152, py(cyTop - r1), 1, 1, PdfColors.black, size: 4);

    // Datum B İşareti (Sap Çapı Üzerinde [-B-])
    _drawPdfDatumMarker(canvas, xDimShank, py(178), 'B', pdfFontBold);
    canvas.moveTo(xDimShank, py(cyTop + r2)); canvas.lineTo(xDimShank, py(172.5));
    canvas.strokePath();

    // Yüzey Pürüzlülüğü (Ra 0.8 Kesici Helis, Ra 1.6 Taşlanmış Sap)
    _drawPdfSurfaceFinish(canvas, 185, py(cyTop - r1), 'Ra 0.8', pdfFont);
    _drawPdfSurfaceFinish(canvas, 355, py(cyTop - r2), 'Ra 1.6', pdfFont);

    // Kesit Düzlemi A-A Göstergesi (Cutting Plane Line)
    const double xSec = 145.0;
    canvas.setColor(PdfColors.black);
    canvas.setLineWidth(1.8);
    // Üst Segment
    canvas.moveTo(xSec, py(112)); canvas.lineTo(xSec, py(126)); canvas.strokePath();
    _drawPdfArrow(canvas, xSec - 6, py(119), -1, 0, PdfColors.black, size: 5);
    canvas.drawString(pdfFontBold, 9.0, 'A', xSec + 4, py(114));

    // Alt Segment
    canvas.moveTo(xSec, py(174)); canvas.lineTo(xSec, py(188)); canvas.strokePath();
    _drawPdfArrow(canvas, xSec - 6, py(181), -1, 0, PdfColors.black, size: 5);
    canvas.drawString(pdfFontBold, 9.0, 'A', xSec + 4, py(186));

    // Detay C Çemberi (Boşaltma Kanalı Etrafında)
    if (hasThreadedShank) {
      canvas.setColor(PdfColors.black);
      canvas.setLineWidth(0.6);
      canvas.drawEllipse(413.5, cyPdf, 8.5, 8.5);
      canvas.strokePath();
      canvas.moveTo(421, py(cyTop - 6)); canvas.lineTo(435, py(130)); canvas.lineTo(448, py(130));
      canvas.strokePath();
      canvas.drawString(pdfFontBold, 8.0, 'C', 451, py(126));
    }
  }

  void _drawPdfAxialView(
    PdfGraphics canvas,
    PdfPoint size,
    double Function(double) py,
    PdfFont pdfFont,
    PdfFont pdfFontBold,
  ) {
    const double cx = 695.0;
    const double cyTop = 110.0;
    final double cyPdf = py(cyTop);
    const double rAx = 38.0;

    // Başlık ve Notlar
    canvas.drawString(pdfFontBold, 8.0, 'KESICI UC ALIN GORUNUSU ( 4 : 1 )', cx - 75, py(34));
    canvas.drawString(pdfFont, 6.5, '2 PLACES THIS VIEW', cx - 28, py(168));

    // Eksen Çizgileri (+ - · - ·)
    _drawPdfChainLine(canvas, cx - rAx - 10, cyPdf, cx + rAx + 10, cyPdf);
    _drawPdfChainLine(canvas, cx, py(cyTop - rAx - 10), cx, py(cyTop + rAx + 10));

    // Dış Çap Çemberi
    canvas.setColor(PdfColors.black);
    canvas.setLineWidth(1.4);
    canvas.drawEllipse(cx, cyPdf, rAx, rAx);
    canvas.strokePath();

    if (toolTipType == 'endmill') {
      // Düz Freze Uç Alın Geometrisi
      canvas.setLineWidth(1.1);
      canvas.drawEllipse(cx, cyPdf, 7.0, 7.0); canvas.strokePath(); // Alın Çanağı
      canvas.drawEllipse(cx, cyPdf, rAx - 3.5, rAx - 3.5); canvas.strokePath(); // Köşe Pah Hattı
      // Z-Ağızlı Radyal Kesici Bıçaklar
      for (int k = 0; k < fluteCount; k++) {
        final double th = k * (2 * math.pi / fluteCount);
        canvas.moveTo(cx, cyPdf);
        canvas.lineTo(cx + rAx * math.cos(th), cyPdf + rAx * math.sin(th));
        canvas.strokePath();
      }
    } else if (fluteCount == 2) {
      // 135° Split Point Matkap Uç Alın Geometrisi (Chisel + Çapraz Bileme)
      const double chiselAngle = 135.0 * math.pi / 180.0;
      const double halfWeb = 4.2;
      final double c1x = cx - halfWeb * math.cos(chiselAngle);
      final double c1y = cyPdf - halfWeb * math.sin(chiselAngle);
      final double c2x = cx + halfWeb * math.cos(chiselAngle);
      final double c2y = cyPdf + halfWeb * math.sin(chiselAngle);

      canvas.setLineWidth(2.2);
      canvas.moveTo(c1x, c1y); canvas.lineTo(c2x, c2y); canvas.strokePath();

      canvas.setLineWidth(1.3);
      canvas.moveTo(c1x, c1y); canvas.lineTo(cx - rAx * 0.95, cyPdf - 3); canvas.strokePath();
      canvas.moveTo(c2x, c2y); canvas.lineTo(cx + rAx * 0.95, cyPdf + 3); canvas.strokePath();

      // Helis Boşaltma Yayları (Thinning notches)
      canvas.setLineWidth(0.7);
      canvas.curveTo(c1x - 8, c1y + 6, c1x - 14, c1y + 12, cx - 18, cyPdf + 22); canvas.strokePath();
      canvas.curveTo(c2x + 8, c2y - 6, c2x + 14, c2y - 12, cx + 18, cyPdf - 22); canvas.strokePath();
    } else {
      // 3 Ağızlı Piramit Helis Alın
      canvas.setLineWidth(1.3);
      for (int k = 0; k < 3; k++) {
        final double th = k * (2 * math.pi / 3);
        canvas.moveTo(cx, cyPdf);
        canvas.lineTo(cx + rAx * 0.95 * math.cos(th), cyPdf + rAx * 0.95 * math.sin(th));
        canvas.strokePath();
      }
      canvas.drawEllipse(cx, cyPdf, 3.5, 3.5); canvas.strokePath();
    }

    // Çap Ölçülendirmesi (Ø d1) ve Denetim Balonu (11)
    const double diagX = rAx * 0.707;
    const double diagY = rAx * 0.707;
    canvas.setColor(PdfColors.black);
    canvas.setLineWidth(0.6);
    canvas.moveTo(cx - diagX, cyPdf - diagY); canvas.lineTo(cx + diagX, cyPdf + diagY);
    canvas.strokePath();
    _drawPdfArrow(canvas, cx - diagX, cyPdf - diagY, -1, -1, PdfColors.black, size: 4);
    _drawPdfArrow(canvas, cx + diagX, cyPdf + diagY, 1, 1, PdfColors.black, size: 4);
    canvas.drawString(pdfFontBold, 7.5, 'd1 = ${drillDiameter.toStringAsFixed(2)}', cx + diagX + 4, cyPdf + diagY + 4);
    _drawPdfInspectionBalloon(canvas, cx + diagX + 38, cyPdf + diagY + 6, 11, pdfFontBold);
  }

  void _drawPdfDetailC(
    PdfGraphics canvas,
    PdfPoint size,
    double Function(double) py,
    PdfFont pdfFont,
    PdfFont pdfFontBold,
  ) {
    const double bx = 695.0;
    const double byTop = 245.0;
    final double byPdf = py(byTop);

    canvas.drawString(pdfFontBold, 8.0, 'C ( 4 : 1 )', bx - 35, py(192));
    canvas.drawString(pdfFont, 6.5, 'E 0,4x0,2 DIN 509', bx - 35, py(200));
    _drawPdfInspectionBalloon(canvas, bx + 42, py(196), 12, pdfFontBold);

    // Boşaltma Kanalı Büyütülmüş Kesiti (Detail C Undercut Profile)
    canvas.setColor(PdfColors.black);
    canvas.setLineWidth(1.1);
    // Sol Fatura Duvarı
    canvas.moveTo(bx - 25, byPdf + 18); canvas.lineTo(bx - 12, byPdf + 18);
    canvas.lineTo(bx - 12, byPdf - 4);
    // R0.4 Kavisli Taban
    canvas.curveTo(bx - 12, byPdf - 10, bx - 6, byPdf - 10, bx - 4, byPdf - 10);
    // 15° Eğimli Çıkış Hattı
    canvas.lineTo(bx + 14, byPdf - 5);
    canvas.lineTo(bx + 26, byPdf - 5);
    canvas.strokePath();

    // Boyut Okları ve Yazılar (2 mm genişlik, 0.2 mm derinlik, 15°, R0.4)
    canvas.setColor(PdfColors.grey800);
    canvas.setLineWidth(0.6);
    // Genişlik 2
    canvas.moveTo(bx - 12, byPdf + 22); canvas.lineTo(bx + 14, byPdf + 22); canvas.strokePath();
    _drawPdfArrow(canvas, bx - 12, byPdf + 22, -1, 0, PdfColors.grey800, size: 3);
    _drawPdfArrow(canvas, bx + 14, byPdf + 22, 1, 0, PdfColors.grey800, size: 3);
    canvas.drawString(pdfFontBold, 6.5, '2', bx - 1, byPdf + 24);

    // Derinlik 0.2
    canvas.moveTo(bx + 22, byPdf - 10); canvas.lineTo(bx + 22, byPdf - 5); canvas.strokePath();
    _drawPdfArrow(canvas, bx + 22, byPdf - 10, 0, -1, PdfColors.grey800, size: 2.8);
    _drawPdfArrow(canvas, bx + 22, byPdf - 5, 0, 1, PdfColors.grey800, size: 2.8);
    canvas.drawString(pdfFont, 6.0, '0,2', bx + 25, byPdf - 9);

    // Açı 15°
    canvas.drawString(pdfFont, 6.0, '15 deg', bx + 20, byPdf + 2);
    // Radyüs R0.4
    canvas.drawString(pdfFont, 6.0, 'R0,4', bx - 10, byPdf - 17);
  }

  void _drawPdfSectionA(
    PdfGraphics canvas,
    PdfPoint size,
    double Function(double) py,
    PdfFont pdfFont,
    PdfFont pdfFontBold,
  ) {
    const double cyTop = 445.0;
    final double cyPdf = py(cyTop);

    canvas.drawString(pdfFontBold, 8.5, 'A - A  ( 1 : 1 )', 40, py(325));

    // Eksen Çizgisi
    _drawPdfChainLine(canvas, 38, cyPdf, 248, cyPdf);

    const double x0 = 48.0;
    const double xEnd = 235.0;
    const double rExt = 18.0;
    final double webCore = (drillDiameter * 0.22).clamp(1.2, 5.0);
    final double rWeb = webCore * 2.8;

    // Kesit Gövde Dış Sınırları
    canvas.setColor(PdfColors.black);
    canvas.setLineWidth(1.1);
    canvas.moveTo(x0, py(cyTop - rExt)); canvas.lineTo(xEnd, py(cyTop - rExt));
    canvas.lineTo(xEnd, py(cyTop + rExt)); canvas.lineTo(x0, py(cyTop + rExt));
    canvas.lineTo(x0, py(cyTop - rExt));
    canvas.strokePath();

    // 45° Standart Metal Tarama Çizgileri (Hatching - Tarama)
    canvas.setColor(const PdfColor(0.5, 0.55, 0.65));
    canvas.setLineWidth(0.45);
    for (double hx = x0 - rExt; hx < xEnd + rExt; hx += 3.8) {
      final double px1 = hx.clamp(x0, xEnd);
      final double py1 = (cyTop - rExt + (px1 - hx)).clamp(cyTop - rExt, cyTop + rExt);
      final double px2 = (hx + rExt * 2).clamp(x0, xEnd);
      final double py2 = (cyTop - rExt + (px2 - hx)).clamp(cyTop - rExt, cyTop + rExt);
      if ((px2 - px1).abs() > 1.0) {
        canvas.moveTo(px1, py(py1));
        canvas.lineTo(px2, py(py2));
        canvas.strokePath();
      }
    }

    // İç Çekirdek Öz Kalınlığı Kanalı (Web Thickness b)
    canvas.setColor(PdfColors.black);
    canvas.setLineWidth(1.0);
    canvas.moveTo(x0, py(cyTop - rWeb)); canvas.lineTo(xEnd - 40, py(cyTop - rWeb));
    canvas.moveTo(x0, py(cyTop + rWeb)); canvas.lineTo(xEnd - 40, py(cyTop + rWeb));
    canvas.strokePath();

    // Kesit Ölçülendirmeleri ve Denetim Balonları (13, 14, 15)
    canvas.setLineWidth(0.6);
    // (13) Öz Kalınlığı b
    canvas.moveTo(85, py(cyTop - rWeb)); canvas.lineTo(85, py(cyTop + rWeb)); canvas.strokePath();
    _drawPdfArrow(canvas, 85, py(cyTop - rWeb), 0, -1, PdfColors.black, size: 3.5);
    _drawPdfArrow(canvas, 85, py(cyTop + rWeb), 0, 1, PdfColors.black, size: 3.5);
    canvas.drawString(pdfFontBold, 6.5, 'b = ${webCore.toStringAsFixed(2)}', 90, py(cyTop - 2));
    _drawPdfInspectionBalloon(canvas, 120, py(cyTop - 22), 13, pdfFontBold);

    // (14) Helis Kanal Derinliği
    canvas.drawString(pdfFont, 6.5, 'Kanal = ${((drillDiameter - webCore) / 2).toStringAsFixed(2)}', 135, py(cyTop + 24));
    _drawPdfInspectionBalloon(canvas, 182, py(cyTop + 24), 14, pdfFontBold);

    // (15) Uç Pahı 0.5x45°
    canvas.drawString(pdfFont, 6.5, '0,5x45', 215, py(cyTop + 24));
    _drawPdfInspectionBalloon(canvas, 245, py(cyTop + 24), 15, pdfFontBold);
  }

  void _drawPdf3DModelZone(
    PdfGraphics canvas,
    PdfPoint size,
    double Function(double) py,
    PdfFont pdfFont,
    PdfFont pdfFontBold,
  ) {
    const double bx = 265.0;
    const double byTop = 310.0;
    const double bw = 245.0;
    const double bh = 255.0;

    // 3D Alanı Dış Çerçevesi (Subtle border)
    canvas.setColor(const PdfColor(0.85, 0.88, 0.92));
    canvas.setLineWidth(0.8);
    canvas.drawRect(bx, py(byTop + bh), bw, bh);
    canvas.strokePath();

    // Üst Rozet / Başlık
    canvas.setFillColor(const PdfColor(0.94, 0.96, 0.98));
    canvas.drawRect(bx, py(byTop + 18), bw, 18);
    canvas.fillPath();
    canvas.setColor(PdfColors.blue900);
    canvas.drawString(pdfFontBold, 7.5, '3D IZOMETRIK CAD MODELI (ISO 13399)', bx + 10, py(byTop + 12));

    // 3D Gölgeli Modeli Çizdir (No dimensions, clean rendering in box)
    _draw3DIsoPdfDrill(
      canvas,
      size,
      pdfFont,
      pdfFontBold,
      customCx: bx + bw / 2,
      customCy: py(byTop + bh / 2 + 10),
      customW: bw - 15,
      customH: bh - 40,
      showDimensions: false,
    );
  }

  void _drawPdfGeneralNotesAndRoughness(
    PdfGraphics canvas,
    PdfPoint size,
    double Function(double) py,
    PdfFont pdfFont,
    PdfFont pdfFontBold,
  ) {
    const double nx = 525.0;
    const double nyTop = 318.0;

    // Genel İmalat Notları (Technical Notes DIN ISO 2768)
    canvas.setFillColor(PdfColors.black);
    canvas.drawString(pdfFontBold, 7.5, 'GENEL IMALAT VE HAVACILIK NOTLARI:', nx, py(nyTop));
    canvas.drawString(pdfFont, 6.8, '1. General tolerance DIN ISO 2768 -medium.', nx, py(nyTop + 13));
    canvas.drawString(pdfFont, 6.8, '2. Deburr and break sharp edges 0,1...0,3 mm.', nx, py(nyTop + 24));
    canvas.drawString(pdfFont, 6.8, '3. Scratches and dents are not acceptable.', nx, py(nyTop + 35));
    canvas.drawString(pdfFont, 6.8, '4. Havacilik Standardi: NAS 907 / NAS 965 Tip D - ISO 13399', nx, py(nyTop + 46));
    canvas.drawString(pdfFont, 6.8, '5. Malzeme: Solid Carbide (Mikro-tane Karbur VHM, 92 HRA)', nx, py(nyTop + 57));
    canvas.drawString(pdfFont, 6.8, '6. Yuzey: ${toolCoatings.firstWhere((c) => c['id'] == selectedCoatingId)['name']} (${toolCoatings.firstWhere((c) => c['id'] == selectedCoatingId)['hardness']})', nx, py(nyTop + 68));

    // Genel Yüzey Pürüzlülüğü Sembolü (ISO 1302: 3,2 / \ ( \/ ) )
    const double rx = 765.0;
    const double ryTop = 350.0;
    canvas.setColor(PdfColors.black);
    canvas.setLineWidth(0.8);
    // Kök İşareti / Çentik
    canvas.moveTo(rx, py(ryTop + 10));
    canvas.lineTo(rx + 4, py(ryTop + 20));
    canvas.lineTo(rx + 11, py(ryTop));
    canvas.lineTo(rx + 24, py(ryTop));
    canvas.strokePath();
    // 3,2 Değeri
    canvas.drawString(pdfFontBold, 7.5, '3,2', rx + 10, py(ryTop - 2));
    // Parantez İçinde ( \/ ) Sembolü
    canvas.drawString(pdfFont, 8.0, '( \\/ )', rx + 27, py(ryTop + 6));
  }

  void _drawPdfTitleBlock(
    PdfGraphics canvas,
    PdfPoint size,
    double Function(double) py,
    PdfFont pdfFont,
    PdfFont pdfFontBold,
  ) {
    const double tx = 520.0;
    const double tyTop = 428.0;
    const double tw = 297.89;
    const double th = 143.28;

    // Dış Çerçeve
    canvas.setColor(PdfColors.black);
    canvas.setLineWidth(1.3);
    canvas.drawRect(tx, py(tyTop + th), tw, th);
    canvas.strokePath();

    // Yatay Ara Çizgiler
    canvas.setLineWidth(0.7);
    canvas.moveTo(tx, py(tyTop + 24)); canvas.lineTo(tx + tw, py(tyTop + 24));
    canvas.moveTo(tx, py(tyTop + 54)); canvas.lineTo(tx + tw, py(tyTop + 54));
    canvas.moveTo(tx, py(tyTop + 84)); canvas.lineTo(tx + tw, py(tyTop + 84));
    canvas.moveTo(tx, py(tyTop + 114)); canvas.lineTo(tx + tw, py(tyTop + 114));
    canvas.strokePath();

    // Dikey Ara Çizgiler
    canvas.moveTo(tx + 145, py(tyTop)); canvas.lineTo(tx + 145, py(tyTop + th));
    canvas.moveTo(tx + 60, py(tyTop + 24)); canvas.lineTo(tx + 60, py(tyTop + 84));
    canvas.moveTo(tx + 225, py(tyTop)); canvas.lineTo(tx + 225, py(tyTop + 24));
    canvas.strokePath();

    // --- Satır 1: Tolerans, Ağırlık, Format ---
    canvas.drawString(pdfFont, 6.5, 'Tolerans: DIN ISO 2768-m', tx + 8, py(tyTop + 15));
    canvas.drawString(pdfFont, 6.5, 'Gewicht: ~38g', tx + 152, py(tyTop + 15));
    canvas.drawString(pdfFontBold, 7.5, 'Format: A4', tx + 233, py(tyTop + 15));

    // --- Satır 2: Çizen (Draw) & Ölçek ---
    canvas.drawString(pdfFontBold, 6.8, 'Draw', tx + 8, py(tyTop + 42));
    canvas.drawString(pdfFont, 6.5, DateTime.now().toString().substring(0, 10), tx + 66, py(tyTop + 37));
    canvas.drawString(pdfFontBold, 7.0, 'H.CANLI', tx + 66, py(tyTop + 47));
    canvas.drawString(pdfFont, 6.5, 'Scale: 1:1 / 4:1', tx + 152, py(tyTop + 38));
    canvas.drawString(pdfFont, 6.5, 'Proj: 1. ACI (ISO)', tx + 152, py(tyTop + 48));

    // --- Satır 3: Kontrol (Check) & Çizim No ---
    canvas.drawString(pdfFontBold, 6.8, 'Check', tx + 8, py(tyTop + 72));
    canvas.drawString(pdfFont, 6.5, DateTime.now().toString().substring(0, 10), tx + 66, py(tyTop + 67));
    canvas.drawString(pdfFontBold, 7.0, 'QC-PASS', tx + 66, py(tyTop + 77));
    canvas.drawString(pdfFontBold, 7.5, 'DWG NO: 53-2971-Z$fluteCount', tx + 152, py(tyTop + 72));

    // --- Satır 4: Malzeme & Parça Adı ---
    canvas.drawString(pdfFontBold, 6.5, 'Material:', tx + 8, py(tyTop + 97));
    canvas.drawString(pdfFont, 6.5, 'Solid Carbide (VHM)', tx + 8, py(tyTop + 107));
    canvas.drawString(pdfFontBold, 9.0, 'AERO-TOOL-53-2971-Z$fluteCount', tx + 152, py(tyTop + 102));

    // --- Satır 5: Kaplama & Takım Tanımı ---
    canvas.drawString(pdfFontBold, 6.5, 'Finish:', tx + 8, py(tyTop + 127));
    canvas.drawString(pdfFont, 6.5, toolCoatings.firstWhere((c) => c['id'] == selectedCoatingId)['name'].toString().split(' ')[0], tx + 8, py(tyTop + 137));
    canvas.drawString(pdfFontBold, 7.5, 'HAVACILIK MATKAP / FREZE TAKIMI', tx + 152, py(tyTop + 127));
    canvas.drawString(pdfFont, 6.5, 'NAS 965 TIP D / DIN 6527 (ISO 13399)', tx + 152, py(tyTop + 137));
  }

  void _draw3DIsoPdfDrill(
    PdfGraphics canvas,
    PdfPoint size,
    PdfFont pdfFont,
    PdfFont pdfFontBold, {
    double? customCx,
    double? customCy,
    double? customW,
    double? customH,
    bool showDimensions = true,
  }) {
    // 1. Isometric Background Grid (Subtle CAD lines)
    if (customCx != null && customCy != null && customW != null && customH != null) {
      final double bx = customCx - customW / 2;
      final double by = customCy - customH / 2;
      canvas.setColor(const PdfColor(0.94, 0.96, 0.98));
      canvas.setLineWidth(0.4);
      for (double x = -customW; x < customW * 2; x += 18) {
        final gx1 = (bx + x).clamp(bx, bx + customW);
        final gx2 = (bx + x + customH * 0.577).clamp(bx, bx + customW);
        canvas.moveTo(gx1, by);
        canvas.lineTo(gx2, by + customH);
        canvas.strokePath();
      }
    } else {
      canvas.setColor(const PdfColor(0.93, 0.95, 0.98));
      canvas.setLineWidth(0.4);
      for (double x = -size.x; x < size.x * 2; x += 22) {
        canvas.moveTo(x, 0);
        canvas.lineTo(x + size.y * 0.577, size.y);
        canvas.strokePath();
        canvas.moveTo(x, size.y);
        canvas.lineTo(x + size.y * 0.577, 0);
        canvas.strokePath();
      }
    }

    // 2. 3D Model Geometry Generation
    final List<_Face3D> rawFaces = [];
    final double r1 = drillDiameter / 2;
    final double r2 = shankDiameter / 2;
    final double r3 = neckDiameter / 2;
    final double tipX = -totalLength / 2;
    final double shankX = totalLength / 2;
    final bool isEndMill = (toolTipType == 'endmill' || pointAngle >= 175.0);
    final double endMillFaceLen = isEndMill ? (r1 * 0.22).clamp(0.5, 1.2) : 0.0;
    final double pointLen = isEndMill
        ? endMillFaceLen
        : (r1 / math.tan((pointAngle / 2) * math.pi / 180)).clamp(1.2, r1 * 1.6);
    final double fluteStartX = tipX + pointLen;
    final double fluteEndX = tipX + fluteLength;
    final double reachEndX = tipX + reachLength;

    const int radialSegments = 32;
    const double angleStep = 2 * math.pi / radialSegments;
    final Color coatingCol = toolCoatings.firstWhere((c) => c['id'] == selectedCoatingId)['color'] as Color;

    // Tip Geometry (Düz Freze / Parmak Freze Ucu vs Matkap Ucu)
    if (isEndMill) {
      final int flutes = fluteCount;
      final int segmentsPerFlute = radialSegments ~/ flutes;
      final _Vec3 centerDish = _Vec3(tipX + 0.35, 0, 0);

      // Z-Ağızlı Alın Kesici Fasetleri (Primary Relief, Secondary Relief, Gash)
      for (int k = 0; k < flutes; k++) {
        final double baseAngle = k * (2 * math.pi / flutes);

        for (int j = 0; j < segmentsPerFlute; j++) {
          final double thA = baseAngle + j * angleStep;
          final double thB = baseAngle + (j + 1) * angleStep;
          final double tMid = (j + 0.5) / segmentsPerFlute;

          double xEdgeA = tipX;
          double xEdgeB = tipX;
          Color facetColor;

          if (tMid < 0.40) {
            xEdgeA = tipX + (tMid * 0.4) * endMillFaceLen;
            xEdgeB = tipX + ((j + 1) / segmentsPerFlute * 0.4) * endMillFaceLen;
            facetColor = Color.lerp(coatingCol, Colors.white, 0.45)!;
          } else if (tMid < 0.75) {
            final double dt = (tMid - 0.40) / 0.35;
            xEdgeA = tipX + (0.4 + dt * 0.4) * endMillFaceLen;
            xEdgeB = tipX + (0.4 + dt * 0.4) * endMillFaceLen;
            facetColor = Color.lerp(coatingCol, const Color(0xFFFFB300), 0.35)!;
          } else {
            xEdgeA = tipX + endMillFaceLen;
            xEdgeB = tipX + endMillFaceLen;
            facetColor = const Color(0xFF1E293B);
          }

          final double rA = (tMid > 0.75) ? r1 * 0.65 : r1 * 0.92;
          final double rB = ((j + 1) / segmentsPerFlute > 0.75) ? r1 * 0.65 : r1 * 0.92;

          final vA = _Vec3(xEdgeA, rA * math.cos(thA), rA * math.sin(thA));
          final vB = _Vec3(xEdgeB, rB * math.cos(thB), rB * math.sin(thB));

          rawFaces.add(_Face3D(vertices: [centerDish, vB, vA], color: facetColor));
        }
      }

      // 45° Köşe Koruma Pahı (Corner Chamfer)
      for (int i = 0; i < radialSegments; i++) {
        final double th1 = i * angleStep;
        final double th2 = (i + 1) * angleStep;
        final v1 = _Vec3(tipX, r1 * 0.92 * math.cos(th1), r1 * 0.92 * math.sin(th1));
        final v2 = _Vec3(tipX, r1 * 0.92 * math.cos(th2), r1 * 0.92 * math.sin(th2));
        final v3 = _Vec3(fluteStartX, r1 * math.cos(th2), r1 * math.sin(th2));
        final v4 = _Vec3(fluteStartX, r1 * math.cos(th1), r1 * math.sin(th1));
        rawFaces.add(_Face3D(vertices: [v1, v4, v3, v2], color: Color.lerp(coatingCol, Colors.white, 0.3)!));
      }
    } else {
      final int flutes = fluteCount;
      final int segmentsPerFlute = radialSegments ~/ flutes;
      if (flutes == 2) {
        final double halfWeb = (r1 * 0.08).clamp(0.2, 0.6);
        const double chiselAngle = 135.0 * math.pi / 180.0;
        final _Vec3 c1 = _Vec3(tipX, -halfWeb * math.cos(chiselAngle), -halfWeb * math.sin(chiselAngle));
        final _Vec3 c2 = _Vec3(tipX, halfWeb * math.cos(chiselAngle), halfWeb * math.sin(chiselAngle));

        for (int k = 0; k < 2; k++) {
          final double baseAngle = k * math.pi;
          final _Vec3 lipOrigin = (k == 0) ? c1 : c2;
          for (int j = 0; j < segmentsPerFlute; j++) {
            final double thA = baseAngle + j * angleStep;
            final double thB = baseAngle + (j + 1) * angleStep;
            final double tMid = (j + 0.5) / segmentsPerFlute;
            final double rBaseA = _calcFluteRadiusMath(thA, r1, 0.58, 2);
            final double rBaseB = _calcFluteRadiusMath(thB, r1, 0.58, 2);
            final double drop = (tMid < 0.45) ? (pointLen * 0.3) * (tMid / 0.45) : pointLen * 0.6;
            final Color col = (tMid < 0.45)
                ? Color.lerp(coatingCol, Colors.white, 0.45)!
                : (tMid < 0.7 ? const Color(0xFFFFB300) : const Color(0xFF1E293B));
            final double xBase = fluteStartX - (pointLen * 0.20) + (drop * 0.5);
            final vA = _Vec3(xBase, rBaseA * math.cos(thA), rBaseA * math.sin(thA));
            final vB = _Vec3(xBase, rBaseB * math.cos(thB), rBaseB * math.sin(thB));
            rawFaces.add(_Face3D(vertices: [lipOrigin, vA, vB], color: col));
          }
        }
      } else {
        final _Vec3 apex = _Vec3(tipX, 0, 0);
        for (int k = 0; k < 3; k++) {
          final double baseAngle = k * (2 * math.pi / 3);
          for (int j = 0; j < segmentsPerFlute; j++) {
            final double thA = baseAngle + j * angleStep;
            final double thB = baseAngle + (j + 1) * angleStep;
            final double tMid = (j + 0.5) / segmentsPerFlute;
            final double rBaseA = _calcFluteRadiusMath(thA, r1, 0.58, 3);
            final double rBaseB = _calcFluteRadiusMath(thB, r1, 0.58, 3);
            final double drop = (tMid < 0.45) ? (pointLen * 0.3) * (tMid / 0.45) : pointLen * 0.6;
            final Color col = (tMid < 0.45)
                ? Color.lerp(coatingCol, Colors.white, 0.45)!
                : (tMid < 0.7 ? const Color(0xFFFFB300) : const Color(0xFF1E293B));
            final double xBase = fluteStartX - (pointLen * 0.20) + (drop * 0.5);
            final vA = _Vec3(xBase, rBaseA * math.cos(thA), rBaseA * math.sin(thA));
            final vB = _Vec3(xBase, rBaseB * math.cos(thB), rBaseB * math.sin(thB));
            rawFaces.add(_Face3D(vertices: [apex, vA, vB], color: col));
          }
        }
      }
    }

    // Helical Flutes
    const int fluteSlices = 24;
    final double sliceStep = (fluteEndX - fluteStartX) / fluteSlices;
    final double flutePitch = 2 * math.pi / fluteCount;
    for (int s = 0; s < fluteSlices; s++) {
      final double x0 = fluteStartX + s * sliceStep;
      final double x1 = x0 + sliceStep;
      final double twist0 = ((x0 - fluteStartX) / fluteLength) * 2.2 * math.pi;
      final double twist1 = ((x1 - fluteStartX) / fluteLength) * 2.2 * math.pi;
      final double webRatio0 = (0.58 + 0.10 * (s / fluteSlices));
      final double webRatio1 = (0.58 + 0.10 * ((s + 1) / fluteSlices));

      for (int i = 0; i < radialSegments; i++) {
        final double angleA = i * angleStep;
        final double angleB = (i + 1) * angleStep;
        final double r0A = _calcFluteRadiusMath(angleA, r1, webRatio0, fluteCount);
        final double r0B = _calcFluteRadiusMath(angleB, r1, webRatio0, fluteCount);
        final double r1A = _calcFluteRadiusMath(angleA, r1, webRatio1, fluteCount);
        final double r1B = _calcFluteRadiusMath(angleB, r1, webRatio1, fluteCount);
        final double th0A = angleA + twist0;
        final double th0B = angleB + twist0;
        final double th1A = angleA + twist1;
        final double th1B = angleB + twist1;
        final v0A = _Vec3(x0, r0A * math.cos(th0A), r0A * math.sin(th0A));
        final v0B = _Vec3(x0, r0B * math.cos(th0B), r0B * math.sin(th0B));
        final v1B = _Vec3(x1, r1B * math.cos(th1B), r1B * math.sin(th1B));
        final v1A = _Vec3(x1, r1A * math.cos(th1A), r1A * math.sin(th1A));

        double phi = angleA % flutePitch;
        if (phi < 0) phi += flutePitch;
        final double t = phi / flutePitch;
        Color quadColor = (t < 0.15)
            ? Color.lerp(coatingCol, Colors.white, 0.45)!
            : (t < 0.48 ? coatingCol : (t < 0.85 ? const Color(0xFF1E293B) : Color.lerp(coatingCol, Colors.white, 0.2)!));

        rawFaces.add(_Face3D(vertices: [v0A, v0B, v1B, v1A], color: quadColor));
      }
    }

    // Neck & Fillets
    if (reachLength > fluteLength + 1.0) {
      final double blendLen = math.min(2.5, (reachEndX - fluteEndX) * 0.25);
      final double neckStartX = fluteEndX + blendLen;
      final double neckMidEndX = reachEndX - blendLen;
      _addSmoothFilletMath(rawFaces, fluteEndX, neckStartX, r1, r3, radialSegments, 3, const Color(0xFF334155));
      _addCylinderRingMath(rawFaces, neckStartX, neckMidEndX, r3, r3, radialSegments, const Color(0xFF1E293B));
      _addSmoothFilletMath(rawFaces, neckMidEndX, reachEndX, r3, r2, radialSegments, 3, const Color(0xFF334155));
    }

    // Shank (Threaded vs Cylindrical)
    if (!hasThreadedShank) {
      final double chamferStart = shankX - 2.0;
      _addCylinderRingMath(rawFaces, reachEndX, chamferStart, r2, r2, radialSegments, const Color(0xFF475569));
      _addCylinderRingMath(rawFaces, chamferStart, shankX, r2, r2 * 0.72, radialSegments, const Color(0xFF334155));
    } else {
      final double threadEndX = shankX;
      final double threadStartX = threadEndX - threadLength;
      final double hexEndX = threadStartX;
      final double hexStartX = hexEndX - hexLength;
      final double hexRadius = (hexWidth / 2) / math.cos(math.pi / 6);

      // Silindirik Sap: Sapa tamamen düz devam eder (Omuzda ovallik/şişkinlik yok, tam silindirik)
      _addCylinderRingMath(rawFaces, reachEndX, hexStartX, r2, r2, radialSegments, const Color(0xFF475569));

      // Somun Ön Alın / Washer Face Omuzu (r2'den hexRadius'a düz fatura yüzeyi)
      if (hexRadius * 0.95 > r2) {
        const int hexSides = 6;
        const double hexAngleStep = 2 * math.pi / hexSides;
        for (int i = 0; i < hexSides; i++) {
          final double th1 = i * hexAngleStep;
          final double th2 = (i + 1) * hexAngleStep;
          final w1 = _Vec3(hexStartX, r2 * math.cos(th1), r2 * math.sin(th1));
          final w2 = _Vec3(hexStartX, r2 * math.cos(th2), r2 * math.sin(th2));
          final w3 = _Vec3(hexStartX, hexRadius * 0.95 * math.cos(th2), hexRadius * 0.95 * math.sin(th2));
          final w4 = _Vec3(hexStartX, hexRadius * 0.95 * math.cos(th1), hexRadius * 0.95 * math.sin(th1));
          rawFaces.add(_Face3D(vertices: [w1, w2, w3, w4], color: const Color(0xFF64748B)));
        }
      }

      // Hex Collar
      const int hexSides = 6;
      const double hexAngleStep = 2 * math.pi / hexSides;
      for (int i = 0; i < hexSides; i++) {
        final double th1 = i * hexAngleStep;
        final double th2 = (i + 1) * hexAngleStep;
        final v1 = _Vec3(hexStartX, hexRadius * math.cos(th1), hexRadius * math.sin(th1));
        final v2 = _Vec3(hexStartX, hexRadius * math.cos(th2), hexRadius * math.sin(th2));
        final v3 = _Vec3(hexEndX, hexRadius * math.cos(th2), hexRadius * math.sin(th2));
        final v4 = _Vec3(hexEndX, hexRadius * math.cos(th1), hexRadius * math.sin(th1));
        final col = (i % 2 == 0) ? const Color(0xFFCBD5E1) : const Color(0xFF94A3B8);
        rawFaces.add(_Face3D(vertices: [v1, v2, v3, v4], color: col));
      }

      // Thread Rings
      final double rThreadMajor = threadDiameter / 2;
      final double rThreadMinor = rThreadMajor * 0.86;
      const int threadRings = 9;
      final double ringStep = threadLength / threadRings;
      for (int t = 0; t < threadRings; t++) {
        final double tx0 = threadStartX + t * ringStep;
        final double tx1 = tx0 + ringStep * 0.5;
        final double tx2 = tx0 + ringStep;
        _addCylinderRingMath(rawFaces, tx0, tx1, rThreadMinor, rThreadMajor, radialSegments, const Color(0xFFFFB300));
        _addCylinderRingMath(rawFaces, tx1, tx2, rThreadMajor, rThreadMinor, radialSegments, const Color(0xFFD97706));
      }
    }

    // 3. Isometric Rotation & Perspective Projection
    const double pdfRotX = -0.42;
    const double pdfRotY = 0.58;
    const double pdfRotZ = 0.0;
    final double maxDim = math.max(totalLength, math.max(drillDiameter, hexWidth) * 3);
    final double scale = (customW != null) ? (customW * 0.68) / maxDim : (size.x * 0.56) / maxDim;
    final double cx = customCx ?? (size.x * 0.48);
    final double cy = customCy ?? (size.y * 0.50);

    final rotatedFaces = rawFaces.map((f) {
      return _Face3D(
        vertices: f.vertices.map((v) => v.rotateX(pdfRotX).rotateY(pdfRotY).rotateZ(pdfRotZ)).toList(),
        color: f.color,
      );
    }).toList();

    rotatedFaces.sort((a, b) => a.averageZ.compareTo(b.averageZ));

    // Shading with Key and Fill Light
    final keyDir = const _Vec3(0.55, -0.75, -0.65).normalized;
    final fillDir = const _Vec3(-0.65, 0.40, -0.35).normalized;

    for (final face in rotatedFaces) {
      if (face.vertices.length < 3) continue;
      final normal = face.normal;
      final double diff1 = math.max(0.0, -normal.dot(keyDir));
      final double diff2 = math.max(0.0, -normal.dot(fillDir));
      final double bright = (0.35 + diff1 * 0.48 + diff2 * 0.20).clamp(0.20, 1.0);

      final r = ((face.color.red * bright).clamp(0, 255)).toInt() / 255.0;
      final g = ((face.color.green * bright).clamp(0, 255)).toInt() / 255.0;
      final b = ((face.color.blue * bright).clamp(0, 255)).toInt() / 255.0;

      canvas.setFillColor(PdfColor(r, g, b));
      final v0 = face.vertices[0];
      canvas.moveTo(cx + v0.x * scale, cy + v0.y * scale);
      for (int i = 1; i < face.vertices.length; i++) {
        final v = face.vertices[i];
        canvas.lineTo(cx + v.x * scale, cy + v.y * scale);
      }
      canvas.closePath();
      canvas.fillPath();

      // Precision CAD Edge Definition
      canvas.setColor(PdfColor(r * 0.65, g * 0.65, b * 0.65));
      canvas.setLineWidth(0.3);
      canvas.moveTo(cx + v0.x * scale, cy + v0.y * scale);
      for (int i = 1; i < face.vertices.length; i++) {
        final v = face.vertices[i];
        canvas.lineTo(cx + v.x * scale, cy + v.y * scale);
      }
      canvas.closePath();
      canvas.strokePath();
    }

    Offset projectPdf(_Vec3 v) {
      final rotV = v.rotateX(pdfRotX).rotateY(pdfRotY).rotateZ(pdfRotZ);
      return Offset(cx + rotV.x * scale, cy + rotV.y * scale);
    }

    // 4. ISO 3D Leader Dimension Lines in PDF
    if (showDimensions) {
      // d1 Leader
      final pTipTop = projectPdf(_Vec3(fluteStartX + fluteLength * 0.25, r1, 0));
      final pTipLead = projectPdf(_Vec3(fluteStartX + fluteLength * 0.25, r1 + 18, 0));
      canvas.setColor(PdfColors.black);
      canvas.setLineWidth(0.8);
      canvas.moveTo(pTipTop.dx, pTipTop.dy);
      canvas.lineTo(pTipLead.dx, pTipLead.dy);
      canvas.lineTo(pTipLead.dx + 25, pTipLead.dy);
      canvas.strokePath();
      _drawPdfArrow(canvas, pTipTop.dx, pTipTop.dy, (pTipTop.dx - pTipLead.dx), (pTipTop.dy - pTipLead.dy), PdfColors.black, size: 4.5);
      canvas.drawString(pdfFontBold, 7.5, 'd1 = Ø${drillDiameter.toStringAsFixed(2)} mm (h9)', pTipLead.dx + 2, pTipLead.dy + 3);

      // l2 Flute Length
      final pL2_0 = projectPdf(_Vec3(fluteStartX, -(r1 + 12), 0));
      final pL2_1 = projectPdf(_Vec3(fluteEndX, -(r1 + 12), 0));
      canvas.setColor(PdfColors.black);
      canvas.setLineWidth(0.8);
      canvas.moveTo(pL2_0.dx, pL2_0.dy); canvas.lineTo(pL2_1.dx, pL2_1.dy); canvas.strokePath();
      _drawPdfArrow(canvas, pL2_0.dx, pL2_0.dy, (pL2_1.dx - pL2_0.dx), (pL2_1.dy - pL2_0.dy), PdfColors.black, size: 4);
      _drawPdfArrow(canvas, pL2_1.dx, pL2_1.dy, (pL2_0.dx - pL2_1.dx), (pL2_0.dy - pL2_1.dy), PdfColors.black, size: 4);
      canvas.drawString(pdfFont, 7.5, 'l2 = ${fluteLength.toStringAsFixed(1)} mm', (pL2_0.dx + pL2_1.dx) / 2 - 18, pL2_0.dy - 10);

      // l3 Usable Reach Length (RED HIGHLIGHT)
      final pL3_0 = projectPdf(_Vec3(fluteStartX, -(r1 + 22), 0));
      final pL3_1 = projectPdf(_Vec3(reachEndX, -(r1 + 22), 0));
      canvas.setColor(PdfColors.red900);
      canvas.setLineWidth(1.0);
      canvas.moveTo(pL3_0.dx, pL3_0.dy); canvas.lineTo(pL3_1.dx, pL3_1.dy); canvas.strokePath();
      _drawPdfArrow(canvas, pL3_0.dx, pL3_0.dy, (pL3_1.dx - pL3_0.dx), (pL3_0.dy - pL3_1.dy), PdfColors.red900, size: 4);
      _drawPdfArrow(canvas, pL3_1.dx, pL3_1.dy, (pL3_0.dx - pL3_1.dx), (pL3_0.dy - pL3_1.dy), PdfColors.red900, size: 4);
      canvas.drawString(pdfFontBold, 7.5, 'l3 = ${reachLength.toStringAsFixed(1)} mm [Kullanilabilir]', (pL3_0.dx + pL3_1.dx) / 2 - 25, pL3_0.dy - 10);

      // l1 Total Length
      final pL1_0 = projectPdf(_Vec3(tipX, -(r1 + 34), 0));
      final pL1_1 = projectPdf(_Vec3(shankX, -(r1 + 34), 0));
      canvas.setColor(PdfColors.black);
      canvas.setLineWidth(0.9);
      canvas.moveTo(pL1_0.dx, pL1_0.dy); canvas.lineTo(pL1_1.dx, pL1_1.dy); canvas.strokePath();
      _drawPdfArrow(canvas, pL1_0.dx, pL1_0.dy, (pL1_1.dx - pL1_0.dx), (pL1_1.dy - pL1_0.dy), PdfColors.black, size: 4);
      _drawPdfArrow(canvas, pL1_1.dx, pL1_1.dy, (pL1_0.dx - pL1_1.dx), (pL1_0.dy - pL1_1.dy), PdfColors.black, size: 4);
      canvas.drawString(pdfFontBold, 8, 'l1 = ${totalLength.toStringAsFixed(1)} mm (Tam Boy)', (pL1_0.dx + pL1_1.dx) / 2 - 25, pL1_0.dy - 10);

      // Thread & Hex callout
      if (hasThreadedShank) {
        final pThreadLead0 = projectPdf(_Vec3(shankX - threadLength * 0.4, r2 + 4, 0));
        final pThreadLead1 = projectPdf(_Vec3(shankX - threadLength * 0.4, r2 + 20, 0));
        canvas.setColor(PdfColors.amber900);
        canvas.setLineWidth(0.8);
        canvas.moveTo(pThreadLead0.dx, pThreadLead0.dy);
        canvas.lineTo(pThreadLead1.dx, pThreadLead1.dy);
        canvas.lineTo(pThreadLead1.dx + 25, pThreadLead1.dy);
        canvas.strokePath();
        _drawPdfArrow(canvas, pThreadLead0.dx, pThreadLead0.dy, (pThreadLead0.dx - pThreadLead1.dx), (pThreadLead0.dy - pThreadLead1.dy), PdfColors.amber900, size: 4);
        canvas.drawString(pdfFontBold, 7, '1/4"-28 UNF-2A Dis', pThreadLead1.dx + 2, pThreadLead1.dy + 3);

        final pHexLead0 = projectPdf(_Vec3(shankX - threadLength - hexLength * 0.5, r2 + 4, 0));
        final pHexLead1 = projectPdf(_Vec3(shankX - threadLength - hexLength * 0.5, r2 + 24, 0));
        canvas.setColor(PdfColors.grey800);
        canvas.setLineWidth(0.8);
        canvas.moveTo(pHexLead0.dx, pHexLead0.dy);
        canvas.lineTo(pHexLead1.dx, pHexLead1.dy);
        canvas.lineTo(pHexLead1.dx - 25, pHexLead1.dy);
        canvas.strokePath();
        _drawPdfArrow(canvas, pHexLead0.dx, pHexLead0.dy, (pHexLead0.dx - pHexLead1.dx), (pHexLead0.dy - pHexLead1.dy), PdfColors.grey800, size: 4);
        canvas.drawString(pdfFontBold, 7, '5/16" SW Somun Kafa', pHexLead1.dx - 80, pHexLead1.dy + 3);
      }
    }

    // 5. Isometric Coordinate Tripod in Corner
    const double axLen = 18.0;
    final pOrigin = (customCx != null && customCy != null)
        ? Offset(customCx - (customW ?? 200) * 0.42, customCy - (customH ?? 150) * 0.38)
        : const Offset(35, 35);
    final pAxX = projectPdf(const _Vec3(axLen, 0, 0)) - Offset(cx, cy) + pOrigin;
    final pAxY = projectPdf(const _Vec3(0, axLen, 0)) - Offset(cx, cy) + pOrigin;
    final pAxZ = projectPdf(const _Vec3(0, 0, axLen)) - Offset(cx, cy) + pOrigin;

    canvas.setColor(PdfColors.red); canvas.setLineWidth(1.1);
    canvas.moveTo(pOrigin.dx, pOrigin.dy); canvas.lineTo(pAxX.dx, pAxX.dy); canvas.strokePath();
    canvas.drawString(pdfFontBold, 6.0, 'X', pAxX.dx + 2, pAxX.dy - 2);

    canvas.setColor(PdfColors.green); canvas.setLineWidth(1.1);
    canvas.moveTo(pOrigin.dx, pOrigin.dy); canvas.lineTo(pAxY.dx, pAxY.dy); canvas.strokePath();
    canvas.drawString(pdfFontBold, 6.0, 'Y', pAxY.dx + 2, pAxY.dy - 2);

    canvas.setColor(PdfColors.blue); canvas.setLineWidth(1.1);
    canvas.moveTo(pOrigin.dx, pOrigin.dy); canvas.lineTo(pAxZ.dx, pAxZ.dy); canvas.strokePath();
    canvas.drawString(pdfFontBold, 6.0, 'Z', pAxZ.dx + 2, pAxZ.dy - 2);
  }

  // ===========================================================================
  // 3D TEKNİK RESİM ETKİLEŞİMLİ ÖNİZLEME MODAL PENCERESİ (IN-APP CAD BLUEPRINT)
  // ===========================================================================

  void _show3DDrawingPreviewModal() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          backgroundColor: const Color(0xFF090D14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
          ),
          child: Container(
            width: 1200,
            constraints: const BoxConstraints(maxHeight: 880),
            child: Column(
              children: [
                // Top CAD Header Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF111823),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                    border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.architecture, color: Color(0xFF00E5FF), size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '3D TEKNİK RESİM',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text('A4 PDF Olarak Yazdır / Kaydet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB300),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 3,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _open3DTechnicalDrawing();
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        tooltip: 'Kapat',
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // Blueprint Workbench Viewport (Interactive Pan & Zoom)
                Expanded(
                  child: Container(
                    color: const Color(0xFF0C1017),
                    child: InteractiveViewer(
                      minScale: 0.45,
                      maxScale: 3.5,
                      boundaryMargin: const EdgeInsets.all(120),
                      child: Center(
                        child: Container(
                          width: 842,
                          height: 595,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.65),
                                blurRadius: 28,
                                spreadRadius: 4,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: CustomPaint(
                            size: const Size(842, 595),
                            painter: _EngineeringBlueprintPainter(
                              drillDiameter: drillDiameter,
                              shankDiameter: shankDiameter,
                              neckDiameter: neckDiameter,
                              fluteLength: fluteLength,
                              reachLength: reachLength,
                              totalLength: totalLength,
                              pointAngle: pointAngle,
                              fluteCount: fluteCount,
                              toolTipType: toolTipType,
                              hasThreadedShank: hasThreadedShank,
                              threadLength: threadLength,
                              threadDiameter: threadDiameter,
                              hexLength: hexLength,
                              hexWidth: hexWidth,
                              materialName: toolMaterials.firstWhere((m) => m['id'] == selectedMaterialId)['name'] as String,
                              materialHardness: toolMaterials.firstWhere((m) => m['id'] == selectedMaterialId)['hardness'] as String,
                              coatingName: toolCoatings.firstWhere((c) => c['id'] == selectedCoatingId)['name'] as String,
                              coatingColor: toolCoatings.firstWhere((c) => c['id'] == selectedCoatingId)['color'] as Color,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Status Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF111823),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                    border: Border(top: BorderSide(color: Color(0xFF1E293B))),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app, size: 14, color: Colors.white54),
                      const SizedBox(width: 6),
                      const Text(
                        'İpucu: Çizimi incelemek için fare tekerleğiyle yakınlaştırıp (zoom) kaydırabilirsiniz (pan).',
                        style: TextStyle(fontSize: 11, color: Colors.white60),
                      ),
                      const Spacer(),
                      _buildBlueprintBadge('15 DENETİM BALONU', const Color(0xFF2979FF)),
                      const SizedBox(width: 8),
                      _buildBlueprintBadge('DIN ISO 2768-m', Colors.white70),
                      const SizedBox(width: 8),
                      _buildBlueprintBadge(hasThreadedShank ? 'NAS 965 TIP D' : 'DIN 6527', const Color(0xFFFFB300)),
                      const SizedBox(width: 8),
                      _buildBlueprintBadge('Z = $fluteCount KESİCİ AĞIZ', const Color(0xFF00E5FF)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBlueprintBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4), width: 1.0),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  static double _calcFluteRadiusMath(double angle, double r1, double webRatio, int flutes) {
    final double pitch = 2 * math.pi / flutes;
    double phi = angle % pitch;
    if (phi < 0) phi += pitch;
    final double t = phi / pitch;

    if (t < 0.14) {
      return r1;
    } else if (t < 0.45) {
      final double smooth = (t - 0.14) / 0.31;
      return r1 * (1.0 - 0.065 * (smooth * smooth));
    } else if (t < 0.88) {
      final double uGullet = (t - 0.45) / 0.43;
      final double dip = math.sin(uGullet * math.pi);
      return r1 * (1.0 - (1.0 - webRatio) * dip);
    } else {
      final double uRake = (t - 0.88) / 0.12;
      return r1 * (webRatio + (1.0 - webRatio) * (uRake * uRake));
    }
  }

  static void _addCylinderRingMath(
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
      faces.add(_Face3D(vertices: [v0A, v0B, v1B, v1A], color: color));
    }
  }

  static void _addSmoothFilletMath(
    List<_Face3D> faces,
    double xStart,
    double xEnd,
    double rStart,
    double rEnd,
    int segments,
    int steps,
    Color color,
  ) {
    final double dx = (xEnd - xStart) / steps;
    for (int s = 0; s < steps; s++) {
      final double x0 = xStart + s * dx;
      final double x1 = x0 + dx;
      final double t0 = s / steps;
      final double t1 = (s + 1) / steps;
      final double s0 = (1 - math.cos(t0 * math.pi)) / 2;
      final double s1 = (1 - math.cos(t1 * math.pi)) / 2;
      final double r0 = rStart + (rEnd - rStart) * s0;
      final double r1 = rStart + (rEnd - rStart) * s1;
      _addCylinderRingMath(faces, x0, x1, r0, r1, segments, color);
    }
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
                            pw.Text('Kesici Ağız: Z = $fluteCount (${fluteCount == 2 ? "2 Ağızlı Helis" : "3 Ağızlı Helis"})', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
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
    final double len = math.sqrt(dirX * dirX + dirY * dirY);
    if (len < 0.001) return;
    final double ux = dirX / len;
    final double uy = dirY / len;
    final double normX = -uy;
    final double normY = ux;
    final double p1X = tipX - ux * size + normX * width;
    final double p1Y = tipY - uy * size + normY * width;
    final double p2X = tipX - ux * size - normX * width;
    final double p2Y = tipY - uy * size - normY * width;
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
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.view_in_ar, size: 14),
            label: const Text('3D Teknik Resim & Yazdır', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
            onPressed: _show3DDrawingPreviewModal,
          ),
          const SizedBox(width: 6),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.architecture, size: 13),
            label: const Text('2D İmalat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
            onPressed: _openTechnicalDrawing,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                                FilterChip(
                                  avatar: const Icon(Icons.straighten, size: 15, color: Color(0xFF00E5FF)),
                                  label: const Text('3D Ölçüler', style: TextStyle(fontSize: 11)),
                                  selected: show3DDimensions,
                                  selectedColor: const Color(0xFF00E5FF).withOpacity(0.2),
                                  backgroundColor: const Color(0xFF0F141C),
                                  side: const BorderSide(color: Color(0xFF232E3E)),
                                  onSelected: (val) => setState(() => show3DDimensions = val),
                                ),
                                const SizedBox(width: 8),
                                ActionChip(
                                  avatar: const Icon(Icons.picture_as_pdf, size: 15, color: Color(0xFFFFB300)),
                                  label: const Text('3D Çizim & Yazdır', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  backgroundColor: const Color(0xFF0F141C),
                                  side: const BorderSide(color: Color(0xFFFFB300)),
                                  onPressed: _show3DDrawingPreviewModal,
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
                            ? Listener(
                                onPointerSignal: (pointerSignal) {
                                  if (pointerSignal is PointerScrollEvent) {
                                    setState(() {
                                      if (pointerSignal.scrollDelta.dy < 0) {
                                        zoom3D = (zoom3D * 1.10).clamp(0.35, 5.0);
                                      } else {
                                        zoom3D = (zoom3D * 0.91).clamp(0.35, 5.0);
                                      }
                                    });
                                  }
                                },
                                child: GestureDetector(
                                  onScaleStart: (details) {
                                    FocusManager.instance.primaryFocus?.unfocus();
                                    _baseZoom = zoom3D;
                                    _lastFocalPoint = details.focalPoint;
                                    if (isAutoRotating) _toggleAutoRotate();
                                  },
                                  onScaleUpdate: (details) {
                                    setState(() {
                                      if (details.pointerCount > 1) {
                                        zoom3D = (_baseZoom * details.scale).clamp(0.35, 5.0);
                                      } else {
                                        final delta = details.focalPoint - _lastFocalPoint;
                                        rotY += delta.dx * 0.012;
                                        rotX = (rotX - delta.dy * 0.012).clamp(-math.pi * 0.48, math.pi * 0.48);
                                      }
                                      _lastFocalPoint = details.focalPoint;
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
                                        fluteCount: fluteCount,
                                        show3DDimensions: show3DDimensions,
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
                                          'Z=$fluteCount Ağızlı  |  Açı: X:${(rotX * 180 / math.pi).toStringAsFixed(0)}°  Y:${(rotY * 180 / math.pi).toStringAsFixed(0)}°  |  Zoom: ${(zoom3D * 100).toStringAsFixed(0)}%',
                                          style: const TextStyle(fontSize: 10, color: Colors.white70, fontFamily: 'monospace'),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 10,
                                      right: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00E5FF).withOpacity(0.18),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.auto_awesome, size: 12, color: Color(0xFF00E5FF)),
                                            SizedBox(width: 4),
                                            Text('ULTRA-HD 48-MESH PBR CAD', style: TextStyle(fontSize: 9.5, color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
                                          ],
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
                                    fluteCount: fluteCount,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Alt Hızlı Ölçü Kartları (Eşit Genişlik ve Yükseklikte Düzenli Parametre Tablosu)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final double availWidth = constraints.maxWidth;
                        int cols = 4;
                        if (availWidth < 460) {
                          cols = 2;
                        } else if (availWidth < 720) {
                          cols = 3;
                        } else if (availWidth < 1000) {
                          cols = 4;
                        } else {
                          cols = hasThreadedShank ? 5 : 4;
                        }
                        const double gap = 8.0;
                        final double itemWidth = ((availWidth - (cols - 1) * gap) / cols).floorToDouble();

                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          alignment: WrapAlignment.start,
                          children: [
                            _buildEqualParamCard('Ağız Sayısı', 'Z = $fluteCount (${fluteCount == 2 ? "2 Ağızlı" : "3 Ağızlı"})', const Color(0xFF00E5FF), width: itemWidth),
                            _buildEqualParamCard('d1 (h9) Çap', 'Ø ${drillDiameter.toStringAsFixed(2)} mm', const Color(0xFF00E5FF), width: itemWidth),
                            _buildEqualParamCard('d2 (h6) Sap', 'Ø ${shankDiameter.toStringAsFixed(2)} mm', const Color(0xFF00E5FF), width: itemWidth),
                            _buildEqualParamCard('d3 (Boyun)', 'Ø ${neckDiameter.toStringAsFixed(2)} mm', Colors.grey, width: itemWidth),
                            _buildEqualParamCard('l2 (Kesme)', '${fluteLength.toStringAsFixed(1)} mm', Colors.white70, width: itemWidth),
                            _buildEqualParamCard('l3 (Kullanılabilir)', '${reachLength.toStringAsFixed(1)} mm', const Color(0xFFE53935), isHighlight: true, width: itemWidth),
                            _buildEqualParamCard('l1 (Tam Boy)', '${totalLength.toStringAsFixed(1)} mm', const Color(0xFFFFB300), width: itemWidth),
                            if (hasThreadedShank) ...[
                              _buildEqualParamCard('⬡ Somun (Kafa)', 'SW ${hexWidth.toStringAsFixed(2)} mm', const Color(0xFFFFB300), width: itemWidth),
                              _buildEqualParamCard('🔩 Vida (Diş)', '1/4"-28 UNF', const Color(0xFFFFB300), width: itemWidth),
                            ],
                          ],
                        );
                      },
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
                    const SizedBox(height: 14),

                    // KESİCİ AĞIZ SAYISI (2 AĞIZLI / 3 AĞIZLI KESİCİ)
                    Row(
                      children: [
                        const Icon(Icons.filter_2, color: Color(0xFF00E5FF), size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Matkap Kesici Ağız Sayısı:',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB300).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.3)),
                          ),
                          child: Text(
                            'Z = $fluteCount Ağızlı',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFFB300)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => fluteCount = 2),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: fluteCount == 2 ? const Color(0xFF00E5FF).withOpacity(0.14) : const Color(0xFF0F141C),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: fluteCount == 2 ? const Color(0xFF00E5FF) : const Color(0xFF232E3E),
                                  width: fluteCount == 2 ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Radio<int>(
                                    value: 2,
                                    groupValue: fluteCount,
                                    activeColor: const Color(0xFF00E5FF),
                                    onChanged: (val) {
                                      if (val != null) setState(() => fluteCount = val);
                                    },
                                  ),
                                  const SizedBox(width: 2),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('2 Ağızlı Kesici', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                        SizedBox(height: 2),
                                        Text('Standart Helis & Geniş Talaş', style: TextStyle(fontSize: 10, color: Colors.white60)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => fluteCount = 3),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: fluteCount == 3 ? const Color(0xFFFFB300).withOpacity(0.14) : const Color(0xFF0F141C),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: fluteCount == 3 ? const Color(0xFFFFB300) : const Color(0xFF232E3E),
                                  width: fluteCount == 3 ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Radio<int>(
                                    value: 3,
                                    groupValue: fluteCount,
                                    activeColor: const Color(0xFFFFB300),
                                    onChanged: (val) {
                                      if (val != null) setState(() => fluteCount = val);
                                    },
                                  ),
                                  const SizedBox(width: 2),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('3 Ağızlı Kesici', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                        SizedBox(height: 2),
                                        Text('Yüksek Rijitlik & Çapaksız Delik', style: TextStyle(fontSize: 10, color: Colors.white60)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F141C),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF232E3E)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            fluteCount == 2 ? Icons.check_circle_outline : Icons.star_border,
                            size: 14,
                            color: fluteCount == 2 ? const Color(0xFF00E5FF) : const Color(0xFFFFB300),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              fluteCount == 2
                                  ? '2 Ağızlı Kesici (Z=2): Genel delme ve derin deliklerde maksimum talaş tahliyesi sağlar.'
                                  : '3 Ağızlı Kesici (Z=3): Havacılık sac ve titanyum perçin deliklerinde titreşimi önler, hassas dairesellik sağlar.',
                              style: const TextStyle(fontSize: 10.5, color: Colors.white70),
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
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInputField(
                              label: 'Somun Boyu (Kafa)',
                              controller: _hexLenController,
                              suffix: 'mm',
                              onChanged: (v) => _updateShankParams(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInputField(
                              label: 'Somun Çapı (SW)',
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

                    // Metrik Ölçüler (İkişer İkişer Alt Alta)
                    const Text('Metrik Ölçüler (mm):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))),
                    const SizedBox(height: 8),
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInputField(
                            label: 'Kesme Boyu (l2)',
                            controller: _fluteLenMmController,
                            suffix: 'mm',
                            onChanged: (v) => _updateDrillFromMm(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            label: 'Kullanılabilir Boy (l3)',
                            controller: _reachLenMmController,
                            suffix: 'mm',
                            labelColor: const Color(0xFFFF5252),
                            onChanged: (v) => _updateDrillFromMm(),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                    const SizedBox(height: 16),

                    // İnç Ölçüleri (İkişer İkişer Alt Alta)
                    const Text('İnç Ölçüleri (inch / "):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFFB300))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            label: 'Kesme Çapı - d1 (İnç)',
                            controller: _diamInController,
                            suffix: '"',
                            onChanged: (v) => _updateDrillFromInch(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInputField(
                            label: 'Kesme Boyu - l2 (İnç)',
                            controller: _fluteLenInController,
                            suffix: '"',
                            onChanged: (v) => _updateDrillFromInch(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            label: 'Kullanılabilir Boy - l3 (İnç)',
                            controller: _reachLenInController,
                            suffix: '"',
                            labelColor: const Color(0xFFFFB300),
                            onChanged: (v) => _updateDrillFromInch(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInputField(
                            label: 'Tam Boy - l1 (İnç)',
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

            // Dual Teknik Resim Butonları: 3D CAD & 2D İmalat Resmi
            Row(
              children: [
                Expanded(
                  flex: 6,
                  child: ElevatedButton.icon(
                    onPressed: _show3DDrawingPreviewModal,
                    icon: const Icon(Icons.view_in_ar, size: 20),
                    label: const Text(
                      '3D Teknik Resmi Görüntüle & Yazdır (A4 CAD)',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB300),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: ElevatedButton.icon(
                    onPressed: _openTechnicalDrawing,
                    icon: const Icon(Icons.architecture, size: 18),
                    label: const Text(
                      '2D İmalat Resmi',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: const Color(0xFF00E5FF),
                      side: const BorderSide(color: Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildEqualParamCard(String label, String value, Color color, {bool isHighlight = false, required double width}) {
    return Container(
      width: width,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isHighlight
            ? const Color(0xFFE53935).withOpacity(0.18)
            : const Color(0xFF111823),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlight ? const Color(0xFFE53935) : color.withOpacity(0.45),
          width: isHighlight ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: isHighlight ? const Color(0xFFFF5252) : color,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
              color: isHighlight ? Colors.white : Colors.white,
              fontFamily: 'monospace',
            ),
          ),
        ],
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
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            suffixText: suffix,
            suffixIcon: IconButton(
              icon: const Icon(Icons.check_circle_outline, size: 15, color: Color(0xFF00E5FF)),
              tooltip: 'Klavyeyi Kapat',
              onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
            ),
            filled: true,
            fillColor: const Color(0xFF0F141C),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
  final int fluteCount;

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
    this.fluteCount = 2,
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

    // Helis Kanalları (fluteCount: 2 ise 3 dalga, 3 ise 4 dalga)
    final fluteBodyLen = fluteEndX - fluteStartX;
    final int waveCount = (fluteCount == 3) ? 4 : 3;
    final waveStep = fluteBodyLen / waveCount;

    final helixLinePaint = Paint()..color = strokeCol..strokeWidth = 1.4..style = PaintingStyle.stroke;
    final marginPaint = Paint()
      ..color = isCatalogWhiteMode ? const Color(0xFF6C757D) : const Color(0xFF00E5FF).withOpacity(0.6)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < waveCount; i++) {
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

    // Kesici Ağız Sayısı Belirteci (Z=2 veya Z=3)
    _drawText(
      canvas,
      'Z=$fluteCount (${fluteCount == 2 ? "2 Ağızlı" : "3 Ağızlı"})',
      Offset((fluteStartX + fluteEndX) / 2, centerY - halfD1 - 9),
      isCatalogWhiteMode ? const Color(0xFF0D6EFD) : const Color(0xFF00E5FF),
      isCentered: true,
      isBold: true,
    );

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
        oldDelegate.hexWidth != hexWidth ||
        oldDelegate.fluteCount != fluteCount;
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
  final int fluteCount;
  final bool show3DDimensions;

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
    this.fluteCount = 2,
    this.show3DDimensions = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Teknik CAD Izgara & Arka Plan
    final bgPaint = Paint()..color = const Color(0xFF070B12);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final gridPaintMinor = Paint()
      ..color = const Color(0xFF0F1824)
      ..strokeWidth = 0.5;
    final gridPaintMajor = Paint()
      ..color = const Color(0xFF162334)
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += 15) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), (x % 60 == 0) ? gridPaintMajor : gridPaintMinor);
    }
    for (double y = 0; y < size.height; y += 15) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), (y % 60 == 0) ? gridPaintMajor : gridPaintMinor);
    }

    // 2. 3D Geometri Üretimi (Ultra-HD 48-Segments Mesh)
    final List<_Face3D> rawFaces = [];

    final double r1 = drillDiameter / 2;
    final double r2 = shankDiameter / 2;
    final double r3 = neckDiameter / 2;
    final double tipX = -totalLength / 2;
    final double shankX = totalLength / 2;

    final bool isEndMill = (toolTipType == 'endmill' || pointAngle >= 175.0);
    final double endMillFaceLen = isEndMill ? (r1 * 0.22).clamp(0.5, 1.2) : 0.0;
    final double pointLen = isEndMill
        ? endMillFaceLen
        : (r1 / math.tan((pointAngle / 2) * math.pi / 180)).clamp(1.2, r1 * 1.6);

    const int radialSegments = 48; // 48: 2, 3, 4, 6, 8, 12, 16, 24 ile tam bölünen pürüzsüz silindirik çözünürlük
    const double angleStep = 2 * math.pi / radialSegments;

    // A. Uç (Tip) Modeli
    final double fluteStartX = tipX + pointLen;
    if (isEndMill) {
      // Düz Freze: Gerçekçi Z-Ağızlı Alın Kesici Geometri, Çanak Eğimi (Dish Recess), Fasetler ve Köşe Pahı
      final int flutes = fluteCount;
      final int segmentsPerFlute = radialSegments ~/ flutes;
      final _Vec3 centerDish = _Vec3(tipX + 0.35, 0, 0);

      // Z Kesici Ağız Alın Fasetleri (Primary Relief, Secondary Relief, Gash)
      for (int k = 0; k < flutes; k++) {
        final double baseAngle = k * (2 * math.pi / flutes);

        for (int j = 0; j < segmentsPerFlute; j++) {
          final double thA = baseAngle + j * angleStep;
          final double thB = baseAngle + (j + 1) * angleStep;
          final double tMid = (j + 0.5) / segmentsPerFlute;

          double xEdgeA = tipX;
          double xEdgeB = tipX;
          Color facetColor;

          if (tMid < 0.40) {
            // 1. Birincil Alın Serbestlik Yüzeyi (Primary Face Relief)
            xEdgeA = tipX + (tMid * 0.4) * endMillFaceLen;
            xEdgeB = tipX + ((j + 1) / segmentsPerFlute * 0.4) * endMillFaceLen;
            facetColor = Color.lerp(coatingColor, Colors.white, 0.45)!;
          } else if (tMid < 0.75) {
            // 2. İkincil Alın Serbestlik Faseti (Secondary Face Relief)
            final double dt = (tMid - 0.40) / 0.35;
            xEdgeA = tipX + (0.4 + dt * 0.4) * endMillFaceLen;
            xEdgeB = tipX + (0.4 + dt * 0.4) * endMillFaceLen;
            facetColor = Color.lerp(coatingColor, const Color(0xFFFFB300), 0.35)!;
          } else {
            // 3. Alın Talaş Boşluğu (End Gash Pocket)
            xEdgeA = tipX + endMillFaceLen;
            xEdgeB = tipX + endMillFaceLen;
            facetColor = const Color(0xFF141C24);
          }

          final double rA = (tMid > 0.75) ? r1 * 0.65 : r1 * 0.92;
          final double rB = ((j + 1) / segmentsPerFlute > 0.75) ? r1 * 0.65 : r1 * 0.92;

          final vA = _Vec3(xEdgeA, rA * math.cos(thA), rA * math.sin(thA));
          final vB = _Vec3(xEdgeB, rB * math.cos(thB), rB * math.sin(thB));

          rawFaces.add(_Face3D(vertices: [centerDish, vB, vA], color: facetColor));
        }

        // Kesici Kenar Çizgisi (Her Ağız İçin Parlak Camgöbeği Lip Line)
        final double lipAngle = baseAngle;
        final _Vec3 lipOuter = _Vec3(tipX, r1 * 0.92 * math.cos(lipAngle), r1 * 0.92 * math.sin(lipAngle));
        final _Vec3 lipMid = _Vec3(tipX + 0.15, (r1 * 0.5) * math.cos(lipAngle), (r1 * 0.5) * math.sin(lipAngle));
        rawFaces.add(_Face3D(
          vertices: [centerDish, lipMid, lipOuter],
          color: const Color(0xFF00E5FF),
          isEdgeOnly: true,
        ));
      }

      // 45° Alın Köşe Koruma Pahı (Corner Chamfer 45°)
      for (int i = 0; i < radialSegments; i++) {
        final double th1 = i * angleStep;
        final double th2 = (i + 1) * angleStep;
        final v1 = _Vec3(tipX, r1 * 0.92 * math.cos(th1), r1 * 0.92 * math.sin(th1));
        final v2 = _Vec3(tipX, r1 * 0.92 * math.cos(th2), r1 * 0.92 * math.sin(th2));
        final v3 = _Vec3(fluteStartX, r1 * math.cos(th2), r1 * math.sin(th2));
        final v4 = _Vec3(fluteStartX, r1 * math.cos(th1), r1 * math.sin(th1));
        rawFaces.add(_Face3D(vertices: [v1, v4, v3, v2], color: Color.lerp(coatingColor, Colors.white, 0.30)!));
      }
    } else {
      // GERÇEKÇİ MATKAP UCU: 2 AĞIZLI (Z=2) VEYA 3 AĞIZLI (Z=3) BİLEME VE KESİCİ AĞIZ MODELİ
      final int flutes = fluteCount;
      final int segmentsPerFlute = radialSegments ~/ flutes;

      if (flutes == 2) {
        // ==========================================
        // 2 AĞIZLI MATKAP UCU (Z = 2)
        // 2 Adet 180° Karşılıklı Kesici Ağız, Öz Kenar (Chisel Edge) ve Havacılık Split Point Fasetleri
        // ==========================================
        final double halfWeb = (r1 * 0.08).clamp(0.2, 0.6);
        const double chiselAngle = 135.0 * math.pi / 180.0;
        final _Vec3 c1 = _Vec3(tipX, -halfWeb * math.cos(chiselAngle), -halfWeb * math.sin(chiselAngle));
        final _Vec3 c2 = _Vec3(tipX, halfWeb * math.cos(chiselAngle), halfWeb * math.sin(chiselAngle));

        for (int k = 0; k < 2; k++) {
          final double baseAngle = k * math.pi;
          final _Vec3 lipOrigin = (k == 0) ? c1 : c2;

          for (int j = 0; j < segmentsPerFlute; j++) {
            final double thA = baseAngle + j * angleStep;
            final double thB = baseAngle + (j + 1) * angleStep;
            final double tA = j / segmentsPerFlute;
            final double tB = (j + 1) / segmentsPerFlute;
            final double tMid = (tA + tB) / 2;

            final double rBaseA = _calcFluteRadius(thA, r1, 0.58, 2);
            final double rBaseB = _calcFluteRadius(thB, r1, 0.58, 2);

            double dropA = 0.0;
            double dropB = 0.0;
            Color facetColor;

            if (tMid < 0.42) {
              // 1. Birincil Bileme Serbestlik Yüzeyi (Primary Lip Relief Facet)
              dropA = (pointLen * 0.32) * (tA / 0.42);
              dropB = (pointLen * 0.32) * (tB / 0.42);
              facetColor = Color.lerp(coatingColor, Colors.white, 0.42)!;
            } else if (tMid < 0.68) {
              // 2. İkincil Serbestlik / Split Point Yüzeyi (Secondary Relief Facet)
              final double dtA = (tA - 0.42) / 0.26;
              final double dtB = (tB - 0.42) / 0.26;
              dropA = (pointLen * 0.32) + (pointLen * 0.38) * dtA.clamp(0.0, 1.0);
              dropB = (pointLen * 0.32) + (pointLen * 0.38) * dtB.clamp(0.0, 1.0);
              facetColor = Color.lerp(coatingColor, const Color(0xFFFFB300), 0.35)!;
            } else {
              // 3. Talaş Kanalı Çıkışı (Flute Rake Gullet)
              dropA = pointLen * 0.68;
              dropB = pointLen * 0.68;
              facetColor = const Color(0xFF141C24);
            }

            final double xBaseA = fluteStartX - (pointLen * 0.20) + (dropA * 0.5);
            final double xBaseB = fluteStartX - (pointLen * 0.20) + (dropB * 0.5);

            final vA = _Vec3(xBaseA, rBaseA * math.cos(thA), rBaseA * math.sin(thA));
            final vB = _Vec3(xBaseB, rBaseB * math.cos(thB), rBaseB * math.sin(thB));

            rawFaces.add(_Face3D(
              vertices: [lipOrigin, vA, vB],
              color: facetColor,
            ));
          }

          // 2 Ağızlı Matkap Kesici Kenarları (Cutting Lips - Parlak Mavi/Camgöbeği)
          final double lipAngle = baseAngle;
          final _Vec3 lipOuter = _Vec3(fluteStartX, r1 * math.cos(lipAngle), r1 * math.sin(lipAngle));
          final _Vec3 lipMid = _Vec3(tipX + pointLen * 0.45, (r1 * 0.5) * math.cos(lipAngle), (r1 * 0.5) * math.sin(lipAngle));
          rawFaces.add(_Face3D(
            vertices: [lipOrigin, lipMid, lipOuter],
            color: const Color(0xFF00E5FF),
            isEdgeOnly: true,
          ));
        }

        // Merkez Öz Kenar (Chisel Edge - Parlak Altın Sarısı)
        rawFaces.add(_Face3D(
          vertices: [c1, c2],
          color: const Color(0xFFFFB300),
          isEdgeOnly: true,
        ));
      } else {
        // ==========================================
        // 3 AĞIZLI MATKAP UCU (Z = 3)
        // 3 Adet 120° Aralıklı Kesici Ağız, Piramit Merkez Uç ve 3-Helis Serbestlik Fasetleri
        // ==========================================
        final _Vec3 apex = _Vec3(tipX, 0, 0);

        for (int k = 0; k < 3; k++) {
          final double baseAngle = k * (2 * math.pi / 3);

          for (int j = 0; j < segmentsPerFlute; j++) {
            final double thA = baseAngle + j * angleStep;
            final double thB = baseAngle + (j + 1) * angleStep;
            final double tA = j / segmentsPerFlute;
            final double tB = (j + 1) / segmentsPerFlute;
            final double tMid = (tA + tB) / 2;

            final double rBaseA = _calcFluteRadius(thA, r1, 0.58, 3);
            final double rBaseB = _calcFluteRadius(thB, r1, 0.58, 3);

            double dropA = 0.0;
            double dropB = 0.0;
            Color facetColor;

            if (tMid < 0.42) {
              // 1. Birincil Bileme Serbestlik Yüzeyi (Primary Lip Relief Facet)
              dropA = (pointLen * 0.32) * (tA / 0.42);
              dropB = (pointLen * 0.32) * (tB / 0.42);
              facetColor = Color.lerp(coatingColor, Colors.white, 0.42)!;
            } else if (tMid < 0.68) {
              // 2. İkincil Serbestlik Faseti (Secondary Relief Facet)
              final double dtA = (tA - 0.42) / 0.26;
              final double dtB = (tB - 0.42) / 0.26;
              dropA = (pointLen * 0.32) + (pointLen * 0.38) * dtA.clamp(0.0, 1.0);
              dropB = (pointLen * 0.32) + (pointLen * 0.38) * dtB.clamp(0.0, 1.0);
              facetColor = Color.lerp(coatingColor, const Color(0xFFFFB300), 0.35)!;
            } else {
              // 3. Talaş Kanalı Çıkışı (Flute Rake Gullet)
              dropA = pointLen * 0.68;
              dropB = pointLen * 0.68;
              facetColor = const Color(0xFF141C24);
            }

            final double xBaseA = fluteStartX - (pointLen * 0.20) + (dropA * 0.5);
            final double xBaseB = fluteStartX - (pointLen * 0.20) + (dropB * 0.5);

            final vA = _Vec3(xBaseA, rBaseA * math.cos(thA), rBaseA * math.sin(thA));
            final vB = _Vec3(xBaseB, rBaseB * math.cos(thB), rBaseB * math.sin(thB));

            rawFaces.add(_Face3D(
              vertices: [apex, vA, vB],
              color: facetColor,
            ));
          }

          // 3 Ağızlı Matkap Kesici Kenarları (3 Adet 120° Kesici Ağız - Parlak Mavi/Camgöbeği)
          final double lipAngle = baseAngle;
          final _Vec3 lipOuter = _Vec3(fluteStartX, r1 * math.cos(lipAngle), r1 * math.sin(lipAngle));
          final _Vec3 lipMid = _Vec3(tipX + pointLen * 0.45, (r1 * 0.5) * math.cos(lipAngle), (r1 * 0.5) * math.sin(lipAngle));
          rawFaces.add(_Face3D(
            vertices: [apex, lipMid, lipOuter],
            color: const Color(0xFF00E5FF),
            isEdgeOnly: true,
          ));
        }
      }
    }

    // B. Yüksek Hassasiyetli Helis Kanallı Gövde (Twist Drill Flutes & Margins - Z=2 / Z=3)
    final double fluteEndX = tipX + fluteLength;
    const int fluteSlices = 42; // 42 Dilim: Pürüzsüz sürekli helis kanalı
    final double sliceStep = (fluteEndX - fluteStartX) / fluteSlices;
    final double flutePitch = 2 * math.pi / fluteCount;

    for (int s = 0; s < fluteSlices; s++) {
      final double x0 = fluteStartX + s * sliceStep;
      final double x1 = x0 + sliceStep;

      final double twist0 = ((x0 - fluteStartX) / fluteLength) * 2.2 * math.pi;
      final double twist1 = ((x1 - fluteStartX) / fluteLength) * 2.2 * math.pi;

      // Gerçekçi matkap öz konikliği (Web Taper): Uçta ince öz (%54), dipte rijit öz (%72)
      final double webRatio0 = (0.54 + 0.18 * (s / fluteSlices));
      final double webRatio1 = (0.54 + 0.18 * ((s + 1) / fluteSlices));

      for (int i = 0; i < radialSegments; i++) {
        final double angleA = i * angleStep;
        final double angleB = (i + 1) * angleStep;

        final double r0A = _calcFluteRadius(angleA, r1, webRatio0, fluteCount);
        final double r0B = _calcFluteRadius(angleB, r1, webRatio0, fluteCount);
        final double r1A = _calcFluteRadius(angleA, r1, webRatio1, fluteCount);
        final double r1B = _calcFluteRadius(angleB, r1, webRatio1, fluteCount);

        final double th0A = angleA + twist0;
        final double th0B = angleB + twist0;
        final double th1A = angleA + twist1;
        final double th1B = angleB + twist1;

        final v0A = _Vec3(x0, r0A * math.cos(th0A), r0A * math.sin(th0A));
        final v0B = _Vec3(x0, r0B * math.cos(th0B), r0B * math.sin(th0B));
        final v1B = _Vec3(x1, r1B * math.cos(th1B), r1B * math.sin(th1B));
        final v1A = _Vec3(x1, r1A * math.cos(th1A), r1A * math.sin(th1A));

        // Yüzey tipi: Talaş kanalı içi, Taşlanmış parlak marj şeridi, Sırt boşluğu
        double phi = angleA % flutePitch;
        if (phi < 0) phi += flutePitch;
        final double t = phi / flutePitch;

        Color quadColor;
        if (t < 0.14) {
          // Parlak Taşlanmış Marj Şeridi (Land Margin at cutting lip)
          quadColor = Color.lerp(coatingColor, Colors.white, 0.50)!;
        } else if (t < 0.45) {
          // Sırt Boşluğu (Heel Clearance)
          quadColor = coatingColor;
        } else if (t < 0.88) {
          // Talaş Kanalı Çukuru (Dark chip trough)
          quadColor = const Color(0xFF141C24);
        } else {
          // Talaş Yüzeyi / Rake Face (Leading up to next cutting edge)
          quadColor = Color.lerp(coatingColor, Colors.white, 0.22)!;
        }

        rawFaces.add(_Face3D(
          vertices: [v0A, v0B, v1B, v1A],
          color: quadColor,
        ));
      }
    }

    // C. Pürüzsüz Boyun Geçişi (Smooth Fillet Neck - d3)
    final double reachEndX = tipX + reachLength;
    if (reachLength > fluteLength + 1.0) {
      final double blendLen = math.min(2.5, (reachEndX - fluteEndX) * 0.25);
      final double neckStartX = fluteEndX + blendLen;
      final double neckMidEndX = reachEndX - blendLen;

      // Kavisli Geçiş 1 (Gövdeden Boyuna 5-kademeli pürüzsüz S-geçişi)
      _addSmoothFillet(rawFaces, fluteEndX, neckStartX, r1, r3, radialSegments, 5, const Color(0xFF2C3947));
      // Boyun Silindiri
      _addCylinderRing(rawFaces, neckStartX, neckMidEndX, r3, r3, radialSegments, const Color(0xFF25303D));
      // Kavisli Geçiş 2 (Boyundan Sapa 5-kademeli pürüzsüz S-geçişi)
      _addSmoothFillet(rawFaces, neckMidEndX, reachEndX, r3, r2, radialSegments, 5, const Color(0xFF2C3947));
    }

    // D. Sap (Shank)
    if (!hasThreadedShank) {
      // Düz Silindirik Sap
      final double chamferStart = shankX - 2.0;
      _addCylinderRing(rawFaces, reachEndX, chamferStart, r2, r2, radialSegments, const Color(0xFF4A5A6D));
      // 45° Pah
      _addCylinderRing(rawFaces, chamferStart, shankX, r2, r2 * 0.72, radialSegments, const Color(0xFF384655));
      // Arka Kapak
      final List<_Vec3> endCap = [];
      for (int i = 0; i < radialSegments; i++) {
        final double theta = i * angleStep;
        endCap.add(_Vec3(shankX, r2 * 0.72 * math.cos(theta), r2 * 0.72 * math.sin(theta)));
      }
      rawFaces.add(_Face3D(vertices: endCap, color: const Color(0xFF222B35)));
    } else {
      // STANDART NAS 965: Gövde -> Düz Silindirik Sap -> 6-Gen Somun Kafa (Pahlı) -> 1/4"-28 Vida (Uçta)
      final double threadEndX = shankX;
      final double threadStartX = threadEndX - threadLength;
      final double hexEndX = threadStartX;
      final double hexStartX = hexEndX - hexLength;
      final double hexRadius = (hexWidth / 2) / math.cos(math.pi / 6);

      // Gövde Silindiri: Sapa tamamen düz ve pürüzsüz devam eder (Omuzda ovallik/şişkinlik yok, tam silindirik)
      _addCylinderRing(rawFaces, reachEndX, hexStartX, r2, r2, radialSegments, const Color(0xFF475569));

      // 6-Gen Somun Kafa (Havacılık 5/16" SW, 30° Ön ve Arka Pahlı / Double Chamfered Washer Face)
      const int hexSides = 6;
      const double hexAngleStep = 2 * math.pi / hexSides;
      final double hexChamferLen = math.min(1.2, hexLength * 0.18);

      // Somun Ön Alın / Washer Face Omuzu (r2'den hexRadius * 0.91'e düz fatura yüzeyi)
      if (hexRadius * 0.91 > r2) {
        for (int i = 0; i < hexSides; i++) {
          final double th1 = i * hexAngleStep;
          final double th2 = (i + 1) * hexAngleStep;
          final w1 = _Vec3(hexStartX, r2 * math.cos(th1), r2 * math.sin(th1));
          final w2 = _Vec3(hexStartX, r2 * math.cos(th2), r2 * math.sin(th2));
          final w3 = _Vec3(hexStartX, hexRadius * 0.91 * math.cos(th2), hexRadius * 0.91 * math.sin(th2));
          final w4 = _Vec3(hexStartX, hexRadius * 0.91 * math.cos(th1), hexRadius * 0.91 * math.sin(th1));
          rawFaces.add(_Face3D(
            vertices: [w1, w2, w3, w4],
            color: const Color(0xFF64748B),
          ));
        }
      }

      for (int i = 0; i < hexSides; i++) {
        final double th1 = i * hexAngleStep;
        final double th2 = (i + 1) * hexAngleStep;

        final v1 = _Vec3(hexStartX + hexChamferLen, hexRadius * math.cos(th1), hexRadius * math.sin(th1));
        final v2 = _Vec3(hexStartX + hexChamferLen, hexRadius * math.cos(th2), hexRadius * math.sin(th2));
        final v3 = _Vec3(hexEndX - hexChamferLen, hexRadius * math.cos(th2), hexRadius * math.sin(th2));
        final v4 = _Vec3(hexEndX - hexChamferLen, hexRadius * math.cos(th1), hexRadius * math.sin(th1));

        final Color hexFaceColor = (i % 2 == 0)
            ? const Color(0xFFD8E2EC)
            : const Color(0xFF9EAFBF);

        // Ana düz yüzey
        rawFaces.add(_Face3D(
          vertices: [v1, v2, v3, v4],
          color: hexFaceColor,
        ));

        // Ön Pah (Washer Face Chamfer)
        final v01 = _Vec3(hexStartX, hexRadius * 0.91 * math.cos(th1), hexRadius * 0.91 * math.sin(th1));
        final v02 = _Vec3(hexStartX, hexRadius * 0.91 * math.cos(th2), hexRadius * 0.91 * math.sin(th2));
        rawFaces.add(_Face3D(
          vertices: [v01, v02, v2, v1],
          color: Color.lerp(hexFaceColor, Colors.white, 0.2)!,
        ));

        // Arka Pah
        final v03 = _Vec3(hexEndX, hexRadius * 0.91 * math.cos(th2), hexRadius * 0.91 * math.sin(th2));
        final v04 = _Vec3(hexEndX, hexRadius * 0.91 * math.cos(th1), hexRadius * 0.91 * math.sin(th1));
        rawFaces.add(_Face3D(
          vertices: [v4, v3, v03, v04],
          color: Color.lerp(hexFaceColor, Colors.black, 0.15)!,
        ));
      }

      // 1/4"-28 UNF Vida Dişleri (Gerçek 60° V-Profili Diş Hatları)
      final double rThreadMajor = threadDiameter / 2;
      final double rThreadMinor = rThreadMajor * 0.86;
      const int threadRings = 11;
      final double ringStep = threadLength / threadRings;

      for (int t = 0; t < threadRings; t++) {
        final double tx0 = threadStartX + t * ringStep;
        final double tx1 = tx0 + ringStep * 0.50;
        final double tx2 = tx0 + ringStep;

        // Diş Tepe Eğimi (Lead Flank)
        _addCylinderRing(rawFaces, tx0, tx1, rThreadMinor, rThreadMajor, radialSegments, const Color(0xFFFFB300));
        // Diş Taban Eğimi (Trailing Flank)
        _addCylinderRing(rawFaces, tx1, tx2, rThreadMajor, rThreadMinor, radialSegments, const Color(0xFFC67D00));
      }

      // Vida Uç Pahı & Ön Kılavuz Burun (Dog Point Chamfer 45°)
      final double tipChamferStartX = threadEndX - 1.4;
      _addCylinderRing(rawFaces, tipChamferStartX, threadEndX, rThreadMajor, rThreadMinor * 0.75, radialSegments, const Color(0xFF94A3B8));
      final List<_Vec3> threadEndCap = [];
      for (int i = 0; i < radialSegments; i++) {
        final double theta = i * angleStep;
        threadEndCap.add(_Vec3(threadEndX, rThreadMinor * 0.75 * math.cos(theta), rThreadMinor * 0.75 * math.sin(theta)));
      }
      rawFaces.add(_Face3D(vertices: threadEndCap, color: const Color(0xFF475569)));
    }

    // 3. 3D Döndürme & Kamera Projeksiyonu
    final double maxDim = math.max(totalLength, math.max(drillDiameter, hexWidth) * 3);
    final double scale = (size.width * 0.72) / maxDim;
    const double cameraDist = 480.0;

    // Yüzeylerin köşe noktalarını 3D uzayda döndür
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

    // 4. Painter's Algorithm: Derinliğe Göre Sıralama
    rotatedFaces.sort((a, b) => a.averageZ.compareTo(b.averageZ));

    // 5. Zemin Temas Gölgesi (Ambient Occlusion Drop Shadow)
    if (!isWireframe) {
      _drawGroundContactShadow(canvas, size, scale, cameraDist);
    }

    // 6. Stüdyo 3-Noktalı Aydınlatma ve Yüzey Çizimi
    final _Vec3 keyLightDir = const _Vec3(0.55, -0.75, -0.65).normalized;
    final _Vec3 fillLightDir = const _Vec3(-0.65, 0.40, -0.35).normalized;
    final _Vec3 rimLightDir = const _Vec3(0.0, -0.85, 0.70).normalized;
    const _Vec3 eyeDir = _Vec3(0, 0, -1);

    final edgePaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final solidEdgePaint = Paint()
      ..color = Colors.black.withOpacity(0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (final face in rotatedFaces) {
      if (face.vertices.length < 2) continue;

      final List<Offset> projectedPoints = face.vertices.map((v) {
        final double f = cameraDist / (cameraDist - v.z);
        final double px = size.width / 2 + v.x * scale * zoom * f;
        final double py = size.height / 2 + v.y * scale * zoom * f;
        return Offset(px, py);
      }).toList();

      if (face.isEdgeOnly || face.vertices.length == 2) {
        final linePaint = Paint()
          ..color = face.color
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round;
        for (int i = 0; i < projectedPoints.length - 1; i++) {
          canvas.drawLine(projectedPoints[i], projectedPoints[i + 1], linePaint);
        }
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
        // PBR Metalik Aydınlatma Hesaplaması
        final normal = face.normal;

        // 1. Ana Işık (Key) Diffuse
        final double keyDiff = math.max(0.0, -normal.dot(keyLightDir));
        // 2. Dolgu Işık (Fill) Diffuse
        final double fillDiff = math.max(0.0, -normal.dot(fillLightDir));
        // 3. Arka Silüet Işık (Rim)
        final double rimFactor = math.max(0.0, normal.dot(rimLightDir));

        const double ambient = 0.28;

        // Blinn-Phong Speküler Parlama (Ultra-HD Anisotropic Sheen)
        final _Vec3 halfVector = (keyLightDir * -1.0 + eyeDir * -1.0).normalized;
        final double nDotH = math.max(0.0, normal.dot(halfVector));
        final double spec = math.pow(nDotH, 32) * 0.65;

        // Fresnel Kenar Işıması (Grazing Rim Angle)
        final double nDotV = math.max(0.0, -normal.dot(eyeDir));
        final double fresnel = math.pow(1.0 - nDotV, 3.5) * 0.42;

        final double brightness = (ambient + keyDiff * 0.58 + fillDiff * 0.20 + rimFactor * 0.22 + spec).clamp(0.18, 1.55);

        Color litColor = _shadeColor(face.color, brightness);
        if (spec > 0.12 || fresnel > 0.18) {
          final double highHighlight = (spec * 0.75 + fresnel * 0.55).clamp(0.0, 1.0);
          litColor = Color.lerp(litColor, Colors.white, highHighlight * 0.70)!;
        }

        final fillPaint = Paint()
          ..color = litColor
          ..style = PaintingStyle.fill;

        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, solidEdgePaint);
      }
    }

    // 7. Eksen Çizgisi (Merkez Noktalı Eksen)
    final _Vec3 axisStart = const _Vec3(-100, 0, 0).rotateX(rotX).rotateY(rotY).rotateZ(rotZ);
    final _Vec3 axisEnd = const _Vec3(100, 0, 0).rotateX(rotX).rotateY(rotY).rotateZ(rotZ);
    final double fStart = cameraDist / (cameraDist - axisStart.z);
    final double fEnd = cameraDist / (cameraDist - axisEnd.z);
    final pAxis1 = Offset(size.width / 2 + axisStart.x * scale * zoom * fStart, size.height / 2 + axisStart.y * scale * zoom * fStart);
    final pAxis2 = Offset(size.width / 2 + axisEnd.x * scale * zoom * fEnd, size.height / 2 + axisEnd.y * scale * zoom * fEnd);

    final axisPaint = Paint()
      ..color = const Color(0xFFFF5252).withOpacity(0.35)
      ..strokeWidth = 0.9;
    canvas.drawLine(pAxis1, pAxis2, axisPaint);

    // 8. 3D Yüzen CAD Ölçülendirme Çizgileri & Etiketleri (Floating 3D Dimensions)
    if (show3DDimensions) {
      _draw3DFloatingDimensions(canvas, size, scale, cameraDist, tipX, shankX, fluteStartX, fluteEndX, reachEndX, r1, r2);
    }

    // 9. 3D Koordinat Tripod (Sol Alt Köşe)
    _drawCoordinateTripod(canvas, Offset(46, size.height - 46));
  }

  double _calcFluteRadius(double angle, double r1, double webRatio, int flutes) {
    final double pitch = 2 * math.pi / flutes;
    double phi = angle % pitch;
    if (phi < 0) phi += pitch;
    final double t = phi / pitch;

    if (t < 0.14) {
      // 1. Kesici Ağız ve Taşlanmış Marj Şeridi (Land margin at cutting edge)
      return r1;
    } else if (t < 0.45) {
      // 2. Sırt Boşluğu (Heel clearance behind cutting edge)
      final double smooth = (t - 0.14) / 0.31;
      return r1 * (1.0 - 0.065 * (smooth * smooth));
    } else if (t < 0.88) {
      // 3. Talaş Kanalı Çukuru (Deep chip flute trough)
      final double uGullet = (t - 0.45) / 0.43;
      final double dip = math.sin(uGullet * math.pi);
      return r1 * (1.0 - (1.0 - webRatio) * dip);
    } else {
      // 4. Talaş Yüzeyi (Rake face climbing back up to next cutting lip)
      final double uRake = (t - 0.88) / 0.12;
      return r1 * (webRatio + (1.0 - webRatio) * (uRake * uRake));
    }
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

  void _addSmoothFillet(
    List<_Face3D> faces,
    double xStart,
    double xEnd,
    double rStart,
    double rEnd,
    int segments,
    int steps,
    Color color,
  ) {
    final double dx = (xEnd - xStart) / steps;
    for (int s = 0; s < steps; s++) {
      final double x0 = xStart + s * dx;
      final double x1 = x0 + dx;
      final double t0 = s / steps;
      final double t1 = (s + 1) / steps;
      // Sinüzoidal S-eğrisi yumuşatma
      final double s0 = (1 - math.cos(t0 * math.pi)) / 2;
      final double s1 = (1 - math.cos(t1 * math.pi)) / 2;
      final double r0 = rStart + (rEnd - rStart) * s0;
      final double r1 = rStart + (rEnd - rStart) * s1;
      _addCylinderRing(faces, x0, x1, r0, r1, segments, color);
    }
  }

  void _drawGroundContactShadow(Canvas canvas, Size size, double scale, double cameraDist) {
    const double groundY = 28.0;
    final _Vec3 center3D = const _Vec3(0, groundY, 0).rotateX(rotX).rotateY(rotY).rotateZ(rotZ);
    final double f = cameraDist / (cameraDist - center3D.z);
    final double cx = size.width / 2 + center3D.x * scale * zoom * f;
    final double cy = size.height / 2 + center3D.y * scale * zoom * f;

    final double shadowWidth = (totalLength * 0.95 * scale * zoom * f).clamp(40.0, size.width * 0.85);
    final double shadowHeight = (drillDiameter * 3.5 * scale * zoom * f).clamp(10.0, 45.0);

    final shadowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withOpacity(0.45),
          Colors.black.withOpacity(0.18),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: shadowWidth, height: shadowHeight));

    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: shadowWidth, height: shadowHeight), shadowPaint);
  }

  Color _shadeColor(Color col, double factor) {
    final int r = (col.red * factor).clamp(0, 255).toInt();
    final int g = (col.green * factor).clamp(0, 255).toInt();
    final int b = (col.blue * factor).clamp(0, 255).toInt();
    return Color.fromARGB(col.alpha, r, g, b);
  }

  void _drawCoordinateTripod(Canvas canvas, Offset origin) {
    const double len = 28.0;
    final _Vec3 vx = const _Vec3(len, 0, 0).rotateX(rotX).rotateY(rotY).rotateZ(rotZ);
    final _Vec3 vy = const _Vec3(0, len, 0).rotateX(rotX).rotateY(rotY).rotateZ(rotZ);
    final _Vec3 vz = const _Vec3(0, 0, len).rotateX(rotX).rotateY(rotY).rotateZ(rotZ);

    // X: Kırmızı (Takım Ekseni)
    final pX = Offset(origin.dx + vx.x, origin.dy + vx.y);
    canvas.drawLine(origin, pX, Paint()..color = const Color(0xFFFF5252)..strokeWidth = 2.2);
    _drawText(canvas, 'X', pX, const Color(0xFFFF5252));

    // Y: Yeşil (Dikey)
    final pY = Offset(origin.dx + vy.x, origin.dy + vy.y);
    canvas.drawLine(origin, pY, Paint()..color = const Color(0xFF69F0AE)..strokeWidth = 2.2);
    _drawText(canvas, 'Y', pY, const Color(0xFF69F0AE));

    // Z: Mavi (Derinlik)
    final pZ = Offset(origin.dx + vz.x, origin.dy + vz.y);
    canvas.drawLine(origin, pZ, Paint()..color = const Color(0xFF40C4FF)..strokeWidth = 2.2);
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

  void _draw3DFloatingDimensions(
    Canvas canvas,
    Size size,
    double scale,
    double cameraDist,
    double tipX,
    double shankX,
    double fluteStartX,
    double fluteEndX,
    double reachEndX,
    double r1,
    double r2,
  ) {
    Offset project(_Vec3 v) {
      final rotV = v.rotateX(rotX).rotateY(rotY).rotateZ(rotZ);
      final double f = cameraDist / (cameraDist - rotV.z);
      return Offset(
        size.width / 2 + rotV.x * scale * zoom * f,
        size.height / 2 + rotV.y * scale * zoom * f,
      );
    }

    final dimPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.85)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final redDimPaint = Paint()
      ..color = const Color(0xFFFF5252).withOpacity(0.95)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final dashedPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // 1. d1 (Çap)
    final double d1X = tipX + fluteLength * 0.35;
    final pTop = project(_Vec3(d1X, r1, 0));
    final pBot = project(_Vec3(d1X, -r1, 0));
    final pLead = project(_Vec3(d1X, r1 * 1.8 + 6, 0));

    canvas.drawLine(pTop, pBot, dimPaint);
    canvas.drawLine(pTop, pLead, dashedPaint);
    _drawCanvasArrow(canvas, pTop, pBot, const Color(0xFF00E5FF));
    _drawCanvasArrow(canvas, pBot, pTop, const Color(0xFF00E5FF));
    _drawFloatingBadge(
      canvas,
      'Ø${drillDiameter.toStringAsFixed(2)} mm (h9)',
      pLead,
      const Color(0xFF00E5FF),
      Colors.black,
    );

    // 2. l2 (Kesme Boyu)
    final double l2Offset = r1 * 1.6 + 7;
    final pFlute0 = project(_Vec3(fluteStartX, 0, 0));
    final pFlute1 = project(_Vec3(fluteEndX, 0, 0));
    final pFluteDim0 = project(_Vec3(fluteStartX, l2Offset, 0));
    final pFluteDim1 = project(_Vec3(fluteEndX, l2Offset, 0));

    canvas.drawLine(pFlute0, pFluteDim0, dashedPaint);
    canvas.drawLine(pFlute1, pFluteDim1, dashedPaint);
    canvas.drawLine(pFluteDim0, pFluteDim1, dimPaint);
    _drawCanvasArrow(canvas, pFluteDim1, pFluteDim0, const Color(0xFF00E5FF));
    _drawCanvasArrow(canvas, pFluteDim0, pFluteDim1, const Color(0xFF00E5FF));
    final pFluteMid = Offset((pFluteDim0.dx + pFluteDim1.dx) / 2, (pFluteDim0.dy + pFluteDim1.dy) / 2 - 10);
    _drawFloatingBadge(
      canvas,
      'l2 = ${fluteLength.toStringAsFixed(1)} mm',
      pFluteMid,
      const Color(0xFF1E293B),
      const Color(0xFF00E5FF),
      borderColor: const Color(0xFF00E5FF),
    );

    // 3. l3 (Kullanılabilir Boy - RED HIGHLIGHT)
    final double l3Offset = r1 * 2.4 + 14;
    final pReachEnd = project(_Vec3(reachEndX, 0, 0));
    final pReachDim0 = project(_Vec3(fluteStartX, l3Offset, 0));
    final pReachDim1 = project(_Vec3(reachEndX, l3Offset, 0));

    canvas.drawLine(pFluteDim0, pReachDim0, dashedPaint);
    canvas.drawLine(pReachEnd, pReachDim1, dashedPaint);
    canvas.drawLine(pReachDim0, pReachDim1, redDimPaint);
    _drawCanvasArrow(canvas, pReachDim1, pReachDim0, const Color(0xFFFF5252));
    _drawCanvasArrow(canvas, pReachDim0, pReachDim1, const Color(0xFFFF5252));
    final pReachMid = Offset((pReachDim0.dx + pReachDim1.dx) / 2, (pReachDim0.dy + pReachDim1.dy) / 2 - 10);
    _drawFloatingBadge(
      canvas,
      'l3 = ${reachLength.toStringAsFixed(1)} mm [Kullanılabilir]',
      pReachMid,
      const Color(0xFF3B0000),
      const Color(0xFFFF5252),
      borderColor: const Color(0xFFFF5252),
    );

    // 4. l1 (Tam Boy)
    final double l1Offset = -(r1 * 1.8 + 12);
    final pTip = project(_Vec3(tipX, 0, 0));
    final pShank = project(_Vec3(shankX, 0, 0));
    final pTotDim0 = project(_Vec3(tipX, l1Offset, 0));
    final pTotDim1 = project(_Vec3(shankX, l1Offset, 0));

    canvas.drawLine(pTip, pTotDim0, dashedPaint);
    canvas.drawLine(pShank, pTotDim1, dashedPaint);
    canvas.drawLine(pTotDim0, pTotDim1, dimPaint);
    _drawCanvasArrow(canvas, pTotDim1, pTotDim0, const Color(0xFF00E5FF));
    _drawCanvasArrow(canvas, pTotDim0, pTotDim1, const Color(0xFF00E5FF));
    final pTotMid = Offset((pTotDim0.dx + pTotDim1.dx) / 2, (pTotDim0.dy + pTotDim1.dy) / 2 + 10);
    _drawFloatingBadge(
      canvas,
      'l1 = ${totalLength.toStringAsFixed(1)} mm',
      pTotMid,
      const Color(0xFF1E293B),
      Colors.white,
      borderColor: Colors.white24,
    );

    // 5. Vidalı Sap / Somun Çağrıları
    if (hasThreadedShank) {
      final double threadMidX = shankX - threadLength * 0.5;
      final pThreadPos = project(_Vec3(threadMidX, -(r1 * 1.5 + 8), 0));
      _drawFloatingBadge(
        canvas,
        '1/4"-28 UNF-2A',
        pThreadPos,
        const Color(0xFFFFB300),
        Colors.black,
      );

      final double hexMidX = shankX - threadLength - hexLength * 0.5;
      final pHexPos = project(_Vec3(hexMidX, r1 * 1.6 + 8, 0));
      _drawFloatingBadge(
        canvas,
        '5/16" HEX (SW 7.94)',
        pHexPos,
        const Color(0xFF475569),
        Colors.white,
      );
    }
  }

  void _drawFloatingBadge(
    Canvas canvas,
    String text,
    Offset center,
    Color bgColor,
    Color textColor, {
    Color? borderColor,
  }) {
    final span = TextSpan(
      text: text,
      style: TextStyle(
        color: textColor,
        fontSize: 9.5,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
      ),
    );
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
    const padH = 6.0;
    const padV = 3.0;
    final rect = Rect.fromCenter(
      center: center,
      width: tp.width + padH * 2,
      height: tp.height + padV * 2,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));

    final bgP = Paint()..color = bgColor;
    canvas.drawRRect(rrect, bgP);

    if (borderColor != null) {
      final borderP = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(rrect, borderP);
    }

    tp.paint(canvas, Offset(rect.left + padH, rect.top + padV));
  }

  void _drawCanvasArrow(Canvas canvas, Offset from, Offset to, Color color) {
    final double dx = to.dx - from.dx;
    final double dy = to.dy - from.dy;
    final double len = math.sqrt(dx * dx + dy * dy);
    if (len < 1.0) return;
    final double ux = dx / len;
    final double uy = dy / len;
    const double arrowLen = 6.0;
    const double arrowW = 3.0;

    final p1 = Offset(to.dx - ux * arrowLen - uy * arrowW, to.dy - uy * arrowLen + ux * arrowW);
    final p2 = Offset(to.dx - ux * arrowLen + uy * arrowW, to.dy - uy * arrowLen - ux * arrowW);

    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant Tool3DModelPainter oldDelegate) {
    return oldDelegate.rotX != rotX ||
        oldDelegate.rotY != rotY ||
        oldDelegate.rotZ != rotZ ||
        oldDelegate.zoom != zoom ||
        oldDelegate.isWireframe != isWireframe ||
        oldDelegate.show3DDimensions != show3DDimensions ||
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
        oldDelegate.coatingColor != coatingColor ||
        oldDelegate.fluteCount != fluteCount;
  }
}

// =============================================================================
// MODAL DETAY GÖRÜNÜM ÇİZİCİSİ (Detail A & Detail B 2D Painter)
// =============================================================================

// =============================================================================
// DIN EN ISO 2768 / NAS 965 MÜHENDİSLİK TEKNİK RESİM ÇİZİCİSİ (FLUTTER CANVAS)
// =============================================================================

class _EngineeringBlueprintPainter extends CustomPainter {
  final double drillDiameter;
  final double shankDiameter;
  final double neckDiameter;
  final double fluteLength;
  final double reachLength;
  final double totalLength;
  final double pointAngle;
  final int fluteCount;
  final String toolTipType;
  final bool hasThreadedShank;
  final double threadLength;
  final double threadDiameter;
  final double hexLength;
  final double hexWidth;
  final String materialName;
  final String materialHardness;
  final String coatingName;
  final Color coatingColor;

  _EngineeringBlueprintPainter({
    required this.drillDiameter,
    required this.shankDiameter,
    required this.neckDiameter,
    required this.fluteLength,
    required this.reachLength,
    required this.totalLength,
    required this.pointAngle,
    required this.fluteCount,
    required this.toolTipType,
    required this.hasThreadedShank,
    required this.threadLength,
    required this.threadDiameter,
    required this.hexLength,
    required this.hexWidth,
    required this.materialName,
    required this.materialHardness,
    required this.coatingName,
    required this.coatingColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Çift Kenarlık (Dual Border) ve 4 Merkezleme Çeltiği
    _drawCanvasBlueprintBorders(canvas, size);

    // 2. Ana 2D Boyuna Kesici Takım Görünüşü (Merkez-Sol & Üst)
    _drawCanvasMainToolView(canvas, size);

    // 3. Kesici Uç Alın Görünüşü (Sağ Üst, 4:1)
    _drawCanvasAxialView(canvas, size);

    // 4. Detay C: DIN 509 Boşaltma Kanalı (Sağ Orta, 4:1)
    _drawCanvasDetailC(canvas, size);

    // 5. Kesit A-A: Boyuna Kesit ve 45° Tarama Çizgileri (Sol Alt, 1:1)
    _drawCanvasSectionA(canvas, size);

    // 6. 3D İzometrik Shaded CAD Modeli Bölgesi (Orta Alt)
    _drawCanvas3DModelZone(canvas, size);

    // 7. Genel İmalat Notları ve Genel Yüzey Pürüzlülüğü Sembolü (Antet Üstü)
    _drawCanvasGeneralNotesAndRoughness(canvas, size);

    // 8. DIN / ISO Mühendislik Anteti (Sağ Alt Köşe)
    _drawCanvasTitleBlock(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _EngineeringBlueprintPainter oldDelegate) => true;

  // ---------------------------------------------------------------------------
  // YARDIMCI ÇİZİM FONKSİYONLARI (CANVAS)
  // ---------------------------------------------------------------------------

  void _drawCanvasText(
    Canvas canvas,
    String text,
    Offset offset, {
    double fontSize = 8.0,
    FontWeight fontWeight = FontWeight.normal,
    Color color = Colors.black,
    TextAlign align = TextAlign.left,
    double? maxWidth,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: maxWidth ?? double.infinity);
    tp.paint(canvas, offset);
  }

  void _drawCanvasInspectionBalloon(Canvas canvas, Offset center, int number) {
    const double r = 7.0;
    final bgP = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawCircle(center, r, bgP);
    final borderP = Paint()
      ..color = const Color(0xFF2979FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, r, borderP);
    final double xOff = (number >= 10) ? 4.5 : 2.5;
    _drawCanvasText(
      canvas,
      '$number',
      Offset(center.dx - xOff, center.dy - 4.5),
      fontSize: 7.5,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF2979FF),
    );
  }

  void _drawCanvasArrow(Canvas canvas, Offset tip, Offset dir, Color color, {double size = 4.5, double width = 2.0}) {
    final double len = dir.distance;
    if (len < 0.001) return;
    final Offset u = dir / len;
    final Offset norm = Offset(-u.dy, u.dx);
    final Offset p1 = tip - u * size + norm * width;
    final Offset p2 = tip - u * size - norm * width;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }

  void _drawCanvasChainLine(Canvas canvas, Offset p1, Offset p2, {Color color = const Color(0xFF616161), double width = 0.6}) {
    final paint = Paint()..color = color..strokeWidth = width..style = PaintingStyle.stroke;
    final double dx = p2.dx - p1.dx;
    final double dy = p2.dy - p1.dy;
    final double len = math.sqrt(dx * dx + dy * dy);
    if (len < 1.0) return;
    final double ux = dx / len;
    final double uy = dy / len;
    double dist = 0.0;
    while (dist < len) {
      final double seg1 = math.min(12.0, len - dist);
      canvas.drawLine(Offset(p1.dx + ux * dist, p1.dy + uy * dist), Offset(p1.dx + ux * (dist + seg1), p1.dy + uy * (dist + seg1)), paint);
      dist += seg1 + 3.0;
      if (dist >= len) break;
      final double seg2 = math.min(2.0, len - dist);
      canvas.drawLine(Offset(p1.dx + ux * dist, p1.dy + uy * dist), Offset(p1.dx + ux * (dist + seg2), p1.dy + uy * (dist + seg2)), paint);
      dist += seg2 + 3.0;
    }
  }

  void _drawCanvasGdtFrame(Canvas canvas, Offset pos, String symbol, String tol, String datum) {
    final p = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 0.8;
    canvas.drawRect(Rect.fromLTWH(pos.dx, pos.dy, 44, 12), p);
    canvas.drawLine(Offset(pos.dx + 13, pos.dy), Offset(pos.dx + 13, pos.dy + 12), p);
    canvas.drawLine(Offset(pos.dx + 31, pos.dy), Offset(pos.dx + 31, pos.dy + 12), p);
    _drawCanvasText(canvas, symbol, Offset(pos.dx + 3, pos.dy + 2), fontSize: 7.5, fontWeight: FontWeight.bold);
    _drawCanvasText(canvas, tol, Offset(pos.dx + 15, pos.dy + 2), fontSize: 7.0);
    _drawCanvasText(canvas, datum, Offset(pos.dx + 34, pos.dy + 2), fontSize: 7.5, fontWeight: FontWeight.bold);
  }

  void _drawCanvasDatumMarker(Canvas canvas, Offset pos, String label) {
    final p = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 0.8;
    canvas.drawRect(Rect.fromLTWH(pos.dx - 6, pos.dy - 6, 12, 12), p);
    _drawCanvasText(canvas, label, Offset(pos.dx - 3, pos.dy - 4.5), fontSize: 7.5, fontWeight: FontWeight.bold);
  }

  void _drawCanvasSurfaceFinish(Canvas canvas, Offset pos, String raVal) {
    final p = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 0.8;
    final path = Path()
      ..moveTo(pos.dx - 3, pos.dy - 6)
      ..lineTo(pos.dx, pos.dy)
      ..lineTo(pos.dx + 5, pos.dy - 11)
      ..lineTo(pos.dx + 17, pos.dy - 11);
    canvas.drawPath(path, p);
    _drawCanvasText(canvas, raVal, Offset(pos.dx + 6, pos.dy - 11), fontSize: 6.5);
  }

  void _drawCanvasBlueprintBorders(Canvas canvas, Size size) {
    final thinP = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 0.8;
    canvas.drawRect(const Rect.fromLTWH(14, 14, 814, 567), thinP);

    final boldP = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.8;
    canvas.drawRect(const Rect.fromLTWH(24, 24, 794, 547), boldP);

    final tickP = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.2;
    // 4 Kenar Merkezleme Çeltikleri
    canvas.drawLine(const Offset(421, 14), const Offset(421, 24), tickP);
    canvas.drawLine(const Offset(421, 581), const Offset(421, 571), tickP);
    canvas.drawLine(const Offset(14, 297.5), const Offset(24, 297.5), tickP);
    canvas.drawLine(const Offset(828, 297.5), const Offset(818, 297.5), tickP);
  }

  void _drawCanvasMainToolView(Canvas canvas, Size size) {
    const double cy = 150.0;

    // 1. Eksen Çizgisi
    _drawCanvasChainLine(canvas, const Offset(42, cy), const Offset(525, cy));

    final bool isEndMill = (toolTipType == 'endmill' || pointAngle >= 175.0);
    const double xTip = 80.0;
    const double r1 = 18.0;
    const double r3 = 14.5;
    const double r2 = 18.0;
    final double lPt = isEndMill ? 3.0 : (r1 / math.tan((pointAngle / 2) * math.pi / 180)).clamp(6.0, 18.0);
    final double xFluteStart = xTip + lPt;
    const double xFluteEnd = 220.0;
    const double xNeckEnd = 295.0;
    const double xShankEnd = 375.0;
    const double xHexEnd = 410.0;
    const double xThreadEnd = 475.0;

    final bodyP = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.3;

    if (isEndMill) {
      canvas.drawLine(const Offset(xTip, cy - 15), const Offset(xTip, cy + 15), bodyP);
      canvas.drawLine(const Offset(xTip, cy - 15), const Offset(xTip + 3, cy - r1), bodyP);
      canvas.drawLine(const Offset(xTip, cy + 15), const Offset(xTip + 3, cy + r1), bodyP);
      final dishPath = Path()
        ..moveTo(xTip, cy - 4)
        ..lineTo(xTip + 1.5, cy)
        ..lineTo(xTip, cy + 4);
      canvas.drawPath(dishPath, bodyP);
    } else {
      canvas.drawLine(const Offset(xTip, cy), Offset(xFluteStart, cy - r1), bodyP);
      canvas.drawLine(const Offset(xTip, cy), Offset(xFluteStart, cy + r1), bodyP);
      canvas.drawLine(const Offset(xTip, cy - 2), const Offset(xTip, cy + 2), bodyP);
    }

    // Helis Gövde Dış Kenarları
    canvas.drawLine(Offset(xFluteStart, cy - r1), const Offset(xFluteEnd, cy - r1), bodyP);
    canvas.drawLine(Offset(xFluteStart, cy + r1), const Offset(xFluteEnd, cy + r1), bodyP);

    // Zırh Payı Çizgileri
    final marginP = Paint()..color = const Color(0xFF424242)..style = PaintingStyle.stroke..strokeWidth = 0.8;
    canvas.drawLine(Offset(xFluteStart, cy - r1 + 1.6), const Offset(xFluteEnd, cy - r1 + 1.6), marginP);
    canvas.drawLine(Offset(xFluteStart, cy + r1 - 1.6), const Offset(xFluteEnd, cy + r1 - 1.6), marginP);

    // Helis Dalgaları (Spiral Flute Lands)
    final fluteWaveP = Paint()..color = const Color(0xFF212121)..style = PaintingStyle.stroke..strokeWidth = 0.9;
    for (int k = 0; k < 4; k++) {
      final double sx = xFluteStart + 12 + k * 28;
      final wavePath = Path()
        ..moveTo(sx, cy - r1)
        ..cubicTo(sx + 8, cy - 6, sx + 12, cy + 6, sx + 20, cy + r1);
      canvas.drawPath(wavePath, fluteWaveP);
    }

    // Boyun Boşaltması (Neck Transition d3)
    final neckPathTop = Path()
      ..moveTo(xFluteEnd, cy - r1)
      ..cubicTo(xFluteEnd + 5, cy - r3, xFluteEnd + 6, cy - r3, xFluteEnd + 10, cy - r3)
      ..lineTo(xNeckEnd - 10, cy - r3)
      ..cubicTo(xNeckEnd - 6, cy - r3, xNeckEnd - 5, cy - r2, xNeckEnd, cy - r2);
    canvas.drawPath(neckPathTop, bodyP);

    final neckPathBottom = Path()
      ..moveTo(xFluteEnd, cy + r1)
      ..cubicTo(xFluteEnd + 5, cy + r3, xFluteEnd + 6, cy + r3, xFluteEnd + 10, cy + r3)
      ..lineTo(xNeckEnd - 10, cy + r3)
      ..cubicTo(xNeckEnd - 6, cy + r3, xNeckEnd - 5, cy + r2, xNeckEnd, cy + r2);
    canvas.drawPath(neckPathBottom, bodyP);

    // Silindirik Sap Gövdesi
    canvas.drawLine(const Offset(xNeckEnd, cy - r2), const Offset(xShankEnd, cy - r2), bodyP);
    canvas.drawLine(const Offset(xNeckEnd, cy + r2), const Offset(xShankEnd, cy + r2), bodyP);

    if (hasThreadedShank) {
      // Somun Kafa (Hex Collar)
      const double rHex = 22.0;
      final hexCollarP = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.3;
      // Düz Alın Faturası (Washer collar face - sapa 90° dik)
      canvas.drawLine(const Offset(xShankEnd, cy - rHex), const Offset(xShankEnd, cy + rHex), hexCollarP);
      canvas.drawLine(const Offset(xShankEnd, cy - rHex), const Offset(xHexEnd, cy - rHex), hexCollarP);
      canvas.drawLine(const Offset(xShankEnd, cy + rHex), const Offset(xHexEnd, cy + rHex), hexCollarP);
      canvas.drawLine(const Offset(xHexEnd, cy - rHex), const Offset(xHexEnd, cy + rHex), hexCollarP);

      // Faset çizgileri
      final facetP = Paint()..color = const Color(0xFF616161)..style = PaintingStyle.stroke..strokeWidth = 0.8;
      canvas.drawLine(const Offset(xShankEnd, cy - 11.5), const Offset(xHexEnd, cy - 11.5), facetP);
      canvas.drawLine(const Offset(xShankEnd, cy + 11.5), const Offset(xHexEnd, cy + 11.5), facetP);

      // Boşaltma Kanalı (Detail C: Undercut)
      const double xUndercut = 417.0;
      canvas.drawLine(const Offset(xHexEnd, cy - 14), const Offset(xUndercut, cy - 14), bodyP);
      canvas.drawLine(const Offset(xHexEnd, cy + 14), const Offset(xUndercut, cy + 14), bodyP);

      // Vidalı Sap Bölümü
      const double rThCrest = 17.0;
      const double rThRoot = 14.5;
      canvas.drawLine(const Offset(xUndercut, cy - rThCrest), const Offset(xThreadEnd - 3, cy - rThCrest), bodyP);
      canvas.drawLine(const Offset(xUndercut, cy + rThCrest), const Offset(xThreadEnd - 3, cy + rThCrest), bodyP);
      canvas.drawLine(const Offset(xThreadEnd - 3, cy + rThCrest), const Offset(xThreadEnd, cy + rThCrest - 3), bodyP);
      canvas.drawLine(const Offset(xThreadEnd, cy + rThCrest - 3), const Offset(xThreadEnd, cy - rThCrest + 3), bodyP);
      canvas.drawLine(const Offset(xThreadEnd, cy - rThCrest + 3), const Offset(xThreadEnd - 3, cy - rThCrest), bodyP);

      // Diş Dibi Kesik Çizgileri
      final rootP = Paint()..color = const Color(0xFF616161)..style = PaintingStyle.stroke..strokeWidth = 0.7;
      canvas.drawLine(const Offset(xUndercut, cy - rThRoot), const Offset(xThreadEnd - 3, cy - rThRoot), rootP);
      canvas.drawLine(const Offset(xUndercut, cy + rThRoot), const Offset(xThreadEnd - 3, cy + rThRoot), rootP);

      // Diş sırt çizgileri
      for (double tx = xUndercut + 2.5; tx < xThreadEnd - 3; tx += 3.2) {
        canvas.drawLine(Offset(tx, cy - rThCrest), Offset(tx + 1.2, cy + rThCrest), rootP);
      }
    } else {
      // Düz Sap ve Pah
      canvas.drawLine(const Offset(xShankEnd, cy - r2), const Offset(xThreadEnd - 3, cy - r2), bodyP);
      canvas.drawLine(const Offset(xShankEnd, cy + r2), const Offset(xThreadEnd - 3, cy + r2), bodyP);
      canvas.drawLine(const Offset(xThreadEnd - 3, cy + r2), const Offset(xThreadEnd, cy + r2 - 3), bodyP);
      canvas.drawLine(const Offset(xThreadEnd, cy + r2 - 3), const Offset(xThreadEnd, cy - r2 + 3), bodyP);
      canvas.drawLine(const Offset(xThreadEnd, cy - r2 + 3), const Offset(xThreadEnd - 3, cy - r2), bodyP);
    }

    // =========================================================================
    // ÖLÇÜLER VE DENETİM BALONLARI (1 - 10)
    // =========================================================================
    final dimP = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 0.7;

    // (1) d1 (h9)
    canvas.drawLine(const Offset(xTip, cy - r1), const Offset(52, cy - r1), dimP);
    canvas.drawLine(const Offset(xTip, cy + r1), const Offset(52, cy + r1), dimP);
    canvas.drawLine(const Offset(56, cy - r1), const Offset(56, cy + r1), dimP);
    _drawCanvasArrow(canvas, const Offset(56, cy - r1), const Offset(0, -1), Colors.black);
    _drawCanvasArrow(canvas, const Offset(56, cy + r1), const Offset(0, 1), Colors.black);
    _drawCanvasText(canvas, 'd1 = ${drillDiameter.toStringAsFixed(2)} h9', const Offset(32, cy - 2), fontSize: 7.5, fontWeight: FontWeight.bold);
    _drawCanvasInspectionBalloon(canvas, const Offset(38, cy - 14), 1);

    // (2) l2 (±0.1)
    canvas.drawLine(const Offset(xTip, cy - r1), const Offset(xTip, 85), dimP);
    canvas.drawLine(const Offset(xFluteEnd, cy - r1), const Offset(xFluteEnd, 85), dimP);
    canvas.drawLine(const Offset(xTip, 89), const Offset(xFluteEnd, 89), dimP);
    _drawCanvasArrow(canvas, const Offset(xTip, 89), const Offset(-1, 0), Colors.black);
    _drawCanvasArrow(canvas, const Offset(xFluteEnd, 89), const Offset(1, 0), Colors.black);
    _drawCanvasText(canvas, 'l2 = ${fluteLength.toStringAsFixed(1)} +/-0.1', const Offset(125, 80), fontSize: 7.5, fontWeight: FontWeight.bold);
    _drawCanvasInspectionBalloon(canvas, const Offset(150, 72), 2);

    // (3) l3 (±0.2)
    canvas.drawLine(const Offset(xNeckEnd, cy - r3), const Offset(xNeckEnd, 68), dimP);
    canvas.drawLine(const Offset(xTip, 85), const Offset(xTip, 68), dimP);
    canvas.drawLine(const Offset(xTip, 72), const Offset(xNeckEnd, 72), dimP);
    _drawCanvasArrow(canvas, const Offset(xTip, 72), const Offset(-1, 0), Colors.black);
    _drawCanvasArrow(canvas, const Offset(xNeckEnd, 72), const Offset(1, 0), Colors.black);
    _drawCanvasText(canvas, 'l3 = ${reachLength.toStringAsFixed(1)} +/-0.2', const Offset(170, 63), fontSize: 7.5, fontWeight: FontWeight.bold);
    _drawCanvasInspectionBalloon(canvas, const Offset(205, 56), 3);

    // (4) d3 (±0.1)
    const double xDimNeck = 258.0;
    canvas.drawLine(const Offset(xDimNeck, cy - r3), const Offset(xDimNeck, cy + r3), dimP);
    _drawCanvasArrow(canvas, const Offset(xDimNeck, cy - r3), const Offset(0, -1), Colors.black);
    _drawCanvasArrow(canvas, const Offset(xDimNeck, cy + r3), const Offset(0, 1), Colors.black);
    _drawCanvasText(canvas, 'd3 = ${neckDiameter.toStringAsFixed(2)}', const Offset(xDimNeck - 18, cy - 2), fontSize: 7.0);
    _drawCanvasInspectionBalloon(canvas, const Offset(xDimNeck, 118), 4);

    // (5) d2 (h6)
    const double xDimShank = 338.0;
    canvas.drawLine(const Offset(xDimShank, cy - r2), const Offset(xDimShank, cy + r2), dimP);
    _drawCanvasArrow(canvas, const Offset(xDimShank, cy - r2), const Offset(0, -1), Colors.black);
    _drawCanvasArrow(canvas, const Offset(xDimShank, cy + r2), const Offset(0, 1), Colors.black);
    _drawCanvasText(canvas, 'd2 = ${shankDiameter.toStringAsFixed(2)} h6', const Offset(xDimShank - 22, cy - 2), fontSize: 7.5, fontWeight: FontWeight.bold);
    _drawCanvasInspectionBalloon(canvas, const Offset(xDimShank, 118), 5);

    // (6) l1 (±0.2)
    canvas.drawLine(const Offset(xTip, cy + r1), const Offset(xTip, 218), dimP);
    canvas.drawLine(const Offset(xThreadEnd, cy + 14), const Offset(xThreadEnd, 218), dimP);
    canvas.drawLine(const Offset(xTip, 214), const Offset(xThreadEnd, 214), dimP);
    _drawCanvasArrow(canvas, const Offset(xTip, 214), const Offset(-1, 0), Colors.black);
    _drawCanvasArrow(canvas, const Offset(xThreadEnd, 214), const Offset(1, 0), Colors.black);
    _drawCanvasText(canvas, 'l1 = ${totalLength.toStringAsFixed(1)} +/-0.2 (TAM BOY)', const Offset(230, 205), fontSize: 8.0, fontWeight: FontWeight.bold);
    _drawCanvasInspectionBalloon(canvas, const Offset(275, 228), 6);

    // (7) Vidalı Sap Çağrısı
    if (hasThreadedShank) {
      canvas.drawLine(const Offset(445, cy - 17), const Offset(465, 105), dimP);
      canvas.drawLine(const Offset(465, 105), const Offset(515, 105), dimP);
      _drawCanvasArrow(canvas, const Offset(445, cy - 17), const Offset(-1, 1), Colors.black, size: 3.5);
      _drawCanvasText(canvas, '1/4"-28 UNF-2A Diş', const Offset(466, 96), fontSize: 7.0, fontWeight: FontWeight.bold);
      _drawCanvasInspectionBalloon(canvas, const Offset(525, 105), 7);

      // (8) Altıköşe Somun Kafa
      canvas.drawLine(const Offset(392, cy - 22), const Offset(405, 95), dimP);
      canvas.drawLine(const Offset(405, 95), const Offset(440, 95), dimP);
      _drawCanvasArrow(canvas, const Offset(392, cy - 22), const Offset(-1, 1), Colors.black, size: 3.5);
      _drawCanvasText(canvas, '5/16" SW Somun', const Offset(406, 86), fontSize: 7.0, fontWeight: FontWeight.bold);
      _drawCanvasInspectionBalloon(canvas, const Offset(450, 95), 8);
    } else {
      canvas.drawLine(const Offset(470, cy - r2), const Offset(485, 105), dimP);
      canvas.drawLine(const Offset(485, 105), const Offset(525, 105), dimP);
      _drawCanvasArrow(canvas, const Offset(470, cy - r2), const Offset(-1, 1), Colors.black, size: 3.5);
      _drawCanvasText(canvas, 'DIN 6527 1x45° Pah', const Offset(486, 96), fontSize: 7.0, fontWeight: FontWeight.bold);
      _drawCanvasInspectionBalloon(canvas, const Offset(535, 105), 7);
    }

    // (9) Uç Açısı
    canvas.drawLine(const Offset(xTip + 2, cy - 6), const Offset(60, 115), dimP);
    canvas.drawLine(const Offset(60, 115), const Offset(42, 115), dimP);
    _drawCanvasArrow(canvas, const Offset(xTip + 2, cy - 6), const Offset(1, -1), Colors.black, size: 3.5);
    _drawCanvasText(canvas, isEndMill ? '180° Alın' : '${pointAngle.toStringAsFixed(0)}° Uç Açısı', const Offset(28, 106), fontSize: 7.0, fontWeight: FontWeight.bold);
    _drawCanvasInspectionBalloon(canvas, const Offset(68, 115), 9);

    // (10) Boyun Radyüsü R1.5
    canvas.drawLine(const Offset(222, cy + r1 - 2), const Offset(210, 180), dimP);
    canvas.drawLine(const Offset(210, 180), const Offset(190, 180), dimP);
    _drawCanvasArrow(canvas, const Offset(222, cy + r1 - 2), const Offset(1, 1), Colors.black, size: 3.5);
    _drawCanvasText(canvas, 'R 1.5', const Offset(192, 172), fontSize: 7.0);
    _drawCanvasInspectionBalloon(canvas, const Offset(180, 180), 10);

    // GD&T Dairesel Salgı Toleransı [ ↗ | 0,02 | B ]
    _drawCanvasGdtFrame(canvas, const Offset(125, 100), '^', '0,02', 'B');
    canvas.drawLine(const Offset(146, 112), const Offset(152, 132), dimP);
    _drawCanvasArrow(canvas, const Offset(152, 132), const Offset(1, 1), Colors.black, size: 4);

    // Datum B İşareti [-B-]
    _drawCanvasDatumMarker(canvas, const Offset(xDimShank, 178), 'B');
    canvas.drawLine(const Offset(338, 168), const Offset(338, 172), dimP);

    // Yüzey Pürüzlülüğü
    _drawCanvasSurfaceFinish(canvas, const Offset(185, 132), 'Ra 0.8');
    _drawCanvasSurfaceFinish(canvas, const Offset(355, 132), 'Ra 1.6');

    // Kesit Düzlemi A-A Göstergesi
    const double xSec = 145.0;
    final secP = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.8;
    canvas.drawLine(const Offset(xSec, 112), const Offset(xSec, 126), secP);
    _drawCanvasArrow(canvas, const Offset(xSec - 6, 119), const Offset(-1, 0), Colors.black, size: 5);
    _drawCanvasText(canvas, 'A', const Offset(xSec + 4, 112), fontSize: 9.0, fontWeight: FontWeight.bold);

    canvas.drawLine(const Offset(xSec, 174), const Offset(xSec, 188), secP);
    _drawCanvasArrow(canvas, const Offset(xSec - 6, 181), const Offset(-1, 0), Colors.black, size: 5);
    _drawCanvasText(canvas, 'A', const Offset(xSec + 4, 178), fontSize: 9.0, fontWeight: FontWeight.bold);

    // Detay C Çemberi
    if (hasThreadedShank) {
      final circleP = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 0.7;
      canvas.drawCircle(const Offset(413.5, cy), 8.5, circleP);
      canvas.drawLine(const Offset(421, cy - 6), const Offset(435, 130), dimP);
      canvas.drawLine(const Offset(435, 130), const Offset(448, 130), dimP);
      _drawCanvasText(canvas, 'C', const Offset(451, 124), fontSize: 8.5, fontWeight: FontWeight.bold);
    }
  }

  void _drawCanvasAxialView(Canvas canvas, Size size) {
    const double cx = 695.0;
    const double cy = 110.0;
    const double rAx = 38.0;

    _drawCanvasText(canvas, 'KESİCİ UÇ ALIN GÖRÜNÜŞÜ ( 4 : 1 )', const Offset(cx - 75, 34), fontSize: 8.0, fontWeight: FontWeight.bold);
    _drawCanvasText(canvas, '2 PLACES THIS VIEW', const Offset(cx - 28, 168), fontSize: 6.5, color: const Color(0xFF616161));

    // Eksen Çizgileri
    _drawCanvasChainLine(canvas, const Offset(cx - rAx - 10, cy), const Offset(cx + rAx + 10, cy));
    _drawCanvasChainLine(canvas, const Offset(cx, cy - rAx - 10), const Offset(cx, cy + rAx + 10));

    // Dış Çap Çemberi
    final outerP = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.4;
    canvas.drawCircle(const Offset(cx, cy), rAx, outerP);

    if (toolTipType == 'endmill') {
      final innerP = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.1;
      canvas.drawCircle(const Offset(cx, cy), 7.0, innerP);
      canvas.drawCircle(const Offset(cx, cy), rAx - 3.5, innerP);
      for (int k = 0; k < fluteCount; k++) {
        final double th = k * (2 * math.pi / fluteCount);
        canvas.drawLine(const Offset(cx, cy), Offset(cx + rAx * math.cos(th), cy + rAx * math.sin(th)), innerP);
      }
    } else if (fluteCount == 2) {
      const double chiselAngle = 135.0 * math.pi / 180.0;
      const double halfWeb = 4.2;
      final double c1x = cx - halfWeb * math.cos(chiselAngle);
      final double c1y = cy - halfWeb * math.sin(chiselAngle);
      final double c2x = cx + halfWeb * math.cos(chiselAngle);
      final double c2y = cy + halfWeb * math.sin(chiselAngle);

      final chiselP = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2.2;
      canvas.drawLine(Offset(c1x, c1y), Offset(c2x, c2y), chiselP);

      final lipP = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.3;
      canvas.drawLine(Offset(c1x, c1y), const Offset(658.9, 107.0), lipP);
      canvas.drawLine(Offset(c2x, c2y), const Offset(731.1, 113.0), lipP);

      final notchP = Paint()..color = const Color(0xFF616161)..style = PaintingStyle.stroke..strokeWidth = 0.8;
      final path1 = Path()..moveTo(c1x, c1y)..cubicTo(c1x - 8, c1y + 6, c1x - 14, c1y + 12, cx - 18, cy + 22);
      final path2 = Path()..moveTo(c2x, c2y)..cubicTo(c2x + 8, c2y - 6, c2x + 14, c2y - 12, cx + 18, cy - 22);
      canvas.drawPath(path1, notchP);
      canvas.drawPath(path2, notchP);
    } else {
      final lipP = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.3;
      for (int k = 0; k < 3; k++) {
        final double th = k * (2 * math.pi / 3);
        canvas.drawLine(const Offset(cx, cy), Offset(cx + rAx * 0.95 * math.cos(th), cy + rAx * 0.95 * math.sin(th)), lipP);
      }
      canvas.drawCircle(const Offset(cx, cy), 3.5, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.0);
    }

    // Çap Ölçülendirmesi (Ø d1) ve Denetim Balonu (11)
    const double diag = rAx * 0.707;
    final dimP = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 0.7;
    canvas.drawLine(const Offset(cx - diag, cy - diag), const Offset(cx + diag, cy + diag), dimP);
    _drawCanvasArrow(canvas, const Offset(cx - diag, cy - diag), const Offset(-1, -1), Colors.black);
    _drawCanvasArrow(canvas, const Offset(cx + diag, cy + diag), const Offset(1, 1), Colors.black);
    _drawCanvasText(canvas, 'd1 = ${drillDiameter.toStringAsFixed(2)}', const Offset(cx + diag + 4, cy + diag + 2), fontSize: 7.5, fontWeight: FontWeight.bold);
    _drawCanvasInspectionBalloon(canvas, const Offset(cx + diag + 38, cy + diag + 6), 11);
  }

  void _drawCanvasDetailC(Canvas canvas, Size size) {
    const double bx = 695.0;
    const double by = 245.0;

    _drawCanvasText(canvas, 'C ( 4 : 1 )', const Offset(bx - 35, 192), fontSize: 8.0, fontWeight: FontWeight.bold);
    _drawCanvasText(canvas, 'E 0,4x0,2 DIN 509', const Offset(bx - 35, 200), fontSize: 6.5, color: const Color(0xFF616161));
    _drawCanvasInspectionBalloon(canvas, const Offset(bx + 42, 196), 12);

    final profP = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.2;
    final path = Path()
      ..moveTo(bx - 25, by - 18)
      ..lineTo(bx - 12, by - 18)
      ..lineTo(bx - 12, by + 4)
      ..cubicTo(bx - 12, by + 10, bx - 6, by + 10, bx - 4, by + 10)
      ..lineTo(bx + 14, by + 5)
      ..lineTo(bx + 26, by + 5);
    canvas.drawPath(path, profP);

    final dimP = Paint()..color = const Color(0xFF424242)..style = PaintingStyle.stroke..strokeWidth = 0.6;
    // Genişlik 2
    canvas.drawLine(const Offset(bx - 12, by - 22), const Offset(bx + 14, by - 22), dimP);
    _drawCanvasArrow(canvas, const Offset(bx - 12, by - 22), const Offset(-1, 0), const Color(0xFF424242), size: 3);
    _drawCanvasArrow(canvas, const Offset(bx + 14, by - 22), const Offset(1, 0), const Color(0xFF424242), size: 3);
    _drawCanvasText(canvas, '2', const Offset(bx - 1, by - 28), fontSize: 6.5, fontWeight: FontWeight.bold);

    // Derinlik 0.2
    canvas.drawLine(const Offset(bx + 22, by + 10), const Offset(bx + 22, by + 5), dimP);
    _drawCanvasArrow(canvas, const Offset(bx + 22, by + 10), const Offset(0, 1), const Color(0xFF424242), size: 2.8);
    _drawCanvasArrow(canvas, const Offset(bx + 22, by + 5), const Offset(0, -1), const Color(0xFF424242), size: 2.8);
    _drawCanvasText(canvas, '0,2', const Offset(bx + 25, by + 6), fontSize: 6.0);

    _drawCanvasText(canvas, '15°', const Offset(bx + 18, by - 4), fontSize: 6.0);
    _drawCanvasText(canvas, 'R0,4', const Offset(bx - 10, by + 13), fontSize: 6.0);
  }

  void _drawCanvasSectionA(Canvas canvas, Size size) {
    const double cy = 445.0;

    _drawCanvasText(canvas, 'A - A  ( 1 : 1 )', const Offset(40, 325), fontSize: 8.5, fontWeight: FontWeight.bold);
    _drawCanvasChainLine(canvas, const Offset(38, cy), const Offset(248, cy));

    const double x0 = 48.0;
    const double xEnd = 235.0;
    const double rExt = 18.0;
    final double webCore = (drillDiameter * 0.22).clamp(1.2, 5.0);
    final double rWeb = webCore * 2.8;

    final bodyP = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.1;
    canvas.drawRect(const Rect.fromLTWH(x0, cy - rExt, xEnd - x0, rExt * 2), bodyP);

    // 45° Tarama Çizgileri (Hatching)
    final hatchP = Paint()..color = const Color(0xFF78909C)..style = PaintingStyle.stroke..strokeWidth = 0.5;
    for (double hx = x0 - rExt; hx < xEnd + rExt; hx += 3.8) {
      final double px1 = hx.clamp(x0, xEnd);
      final double py1 = (cy - rExt + (px1 - hx)).clamp(cy - rExt, cy + rExt);
      final double px2 = (hx + rExt * 2).clamp(x0, xEnd);
      final double py2 = (cy - rExt + (px2 - hx)).clamp(cy - rExt, cy + rExt);
      if ((px2 - px1).abs() > 1.0) {
        canvas.drawLine(Offset(px1, py1), Offset(px2, py2), hatchP);
      }
    }

    // İç Öz Kanalı
    canvas.drawLine(Offset(x0, cy - rWeb), Offset(xEnd - 40, cy - rWeb), bodyP);
    canvas.drawLine(Offset(x0, cy + rWeb), Offset(xEnd - 40, cy + rWeb), bodyP);

    // Ölçüler ve Balonlar (13, 14, 15)
    final dimP = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 0.6;
    canvas.drawLine(Offset(85, cy - rWeb), Offset(85, cy + rWeb), dimP);
    _drawCanvasArrow(canvas, Offset(85, cy - rWeb), const Offset(0, -1), Colors.black, size: 3.5);
    _drawCanvasArrow(canvas, Offset(85, cy + rWeb), const Offset(0, 1), Colors.black, size: 3.5);
    _drawCanvasText(canvas, 'b = ${webCore.toStringAsFixed(2)}', const Offset(90, cy - 3), fontSize: 6.5, fontWeight: FontWeight.bold);
    _drawCanvasInspectionBalloon(canvas, const Offset(120, cy - 22), 13);

    _drawCanvasText(canvas, 'Kanal = ${((drillDiameter - webCore) / 2).toStringAsFixed(2)}', const Offset(135, cy + 24), fontSize: 6.5);
    _drawCanvasInspectionBalloon(canvas, const Offset(182, cy + 24), 14);

    _drawCanvasText(canvas, '0,5x45°', const Offset(215, cy + 24), fontSize: 6.5);
    _drawCanvasInspectionBalloon(canvas, const Offset(245, cy + 24), 15);
  }

  void _drawCanvas3DModelZone(Canvas canvas, Size size) {
    const double bx = 265.0;
    const double by = 310.0;
    const double bw = 245.0;
    const double bh = 255.0;

    final borderP = Paint()..color = const Color(0xFFD6DBE1)..style = PaintingStyle.stroke..strokeWidth = 0.8;
    canvas.drawRect(const Rect.fromLTWH(bx, by, bw, bh), borderP);

    final badgeP = Paint()..color = const Color(0xFFF1F4F8)..style = PaintingStyle.fill;
    canvas.drawRect(const Rect.fromLTWH(bx, by, bw, 18), badgeP);
    _drawCanvasText(canvas, '3D İZOMETRİK CAD MODELİ (ISO 13399)', const Offset(bx + 10, by + 4), fontSize: 7.5, fontWeight: FontWeight.bold, color: const Color(0xFF0D47A1));

    // Paint 3D Model into viewport
    canvas.save();
    canvas.translate(bx + 5, by + 20);
    canvas.clipRect(const Rect.fromLTWH(0, 0, bw - 10, bh - 24));
    final modelPainter = Tool3DModelPainter(
      rotX: -0.42,
      rotY: 0.58,
      rotZ: 0.0,
      zoom: 0.95,
      isWireframe: false,
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
      coatingColor: coatingColor,
      fluteCount: fluteCount,
      show3DDimensions: false,
    );
    modelPainter.paint(canvas, const Size(bw - 10, bh - 24));
    canvas.restore();
  }

  void _drawCanvasGeneralNotesAndRoughness(Canvas canvas, Size size) {
    const double nx = 525.0;
    const double ny = 318.0;

    _drawCanvasText(canvas, 'GENEL İMALAT VE HAVACILIK NOTLARI:', const Offset(nx, ny), fontSize: 7.5, fontWeight: FontWeight.bold);
    _drawCanvasText(canvas, '1. General tolerance DIN ISO 2768 -medium.', const Offset(nx, ny + 13), fontSize: 6.8);
    _drawCanvasText(canvas, '2. Deburr and break sharp edges 0,1...0,3 mm.', const Offset(nx, ny + 24), fontSize: 6.8);
    _drawCanvasText(canvas, '3. Scratches and dents are not acceptable.', const Offset(nx, ny + 35), fontSize: 6.8);
    _drawCanvasText(canvas, '4. Havacılık Standardı: NAS 907 / NAS 965 Tip D - ISO 13399', const Offset(nx, ny + 46), fontSize: 6.8);
    _drawCanvasText(canvas, '5. Malzeme: $materialName ($materialHardness)', const Offset(nx, ny + 57), fontSize: 6.8);
    _drawCanvasText(canvas, '6. Yüzey: $coatingName PVD kaplama', const Offset(nx, ny + 68), fontSize: 6.8);

    // Genel Yüzey Pürüzlülüğü Sembolü (ISO 1302: 3,2 / \ ( \/ ) )
    const double rx = 765.0;
    const double ry = 350.0;
    final rP = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 0.8;
    final path = Path()
      ..moveTo(rx, ry - 10)
      ..lineTo(rx + 4, ry)
      ..lineTo(rx + 11, ry - 20)
      ..lineTo(rx + 24, ry - 20);
    canvas.drawPath(path, rP);
    _drawCanvasText(canvas, '3,2', const Offset(rx + 10, ry - 28), fontSize: 7.5, fontWeight: FontWeight.bold);
    _drawCanvasText(canvas, '( \\/ )', const Offset(rx + 27, ry - 20), fontSize: 8.0);
  }

  void _drawCanvasTitleBlock(Canvas canvas, Size size) {
    const double tx = 520.0;
    const double ty = 428.0;
    const double tw = 297.89;
    const double th = 143.28;

    final borderP = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.3;
    canvas.drawRect(const Rect.fromLTWH(tx, ty, tw, th), borderP);

    final divP = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 0.7;
    canvas.drawLine(const Offset(tx, ty + 24), const Offset(tx + tw, ty + 24), divP);
    canvas.drawLine(const Offset(tx, ty + 54), const Offset(tx + tw, ty + 54), divP);
    canvas.drawLine(const Offset(tx, ty + 84), const Offset(tx + tw, ty + 84), divP);
    canvas.drawLine(const Offset(tx, ty + 114), const Offset(tx + tw, ty + 114), divP);

    canvas.drawLine(const Offset(tx + 145, ty), const Offset(tx + 145, ty + th), divP);
    canvas.drawLine(const Offset(tx + 60, ty + 24), const Offset(tx + 60, ty + 84), divP);
    canvas.drawLine(const Offset(tx + 225, ty), const Offset(tx + 225, ty + 24), divP);

    // Satır 1
    _drawCanvasText(canvas, 'Tolerans: DIN ISO 2768-m', const Offset(tx + 8, ty + 7), fontSize: 6.5);
    _drawCanvasText(canvas, 'Gewicht: ~38g', const Offset(tx + 152, ty + 7), fontSize: 6.5);
    _drawCanvasText(canvas, 'Format: A4', const Offset(tx + 233, ty + 7), fontSize: 7.5, fontWeight: FontWeight.bold);

    // Satır 2
    _drawCanvasText(canvas, 'Draw', const Offset(tx + 8, ty + 36), fontSize: 6.8, fontWeight: FontWeight.bold);
    _drawCanvasText(canvas, DateTime.now().toString().substring(0, 10), const Offset(tx + 66, ty + 31), fontSize: 6.5);
    _drawCanvasText(canvas, 'H.CANLI', const Offset(tx + 66, ty + 41), fontSize: 7.0, fontWeight: FontWeight.bold);
    _drawCanvasText(canvas, 'Scale: 1:1 / 4:1', const Offset(tx + 152, ty + 32), fontSize: 6.5);
    _drawCanvasText(canvas, 'Proj: 1. AÇI (ISO)', const Offset(tx + 152, ty + 42), fontSize: 6.5);

    // Satır 3
    _drawCanvasText(canvas, 'Check', const Offset(tx + 8, ty + 66), fontSize: 6.8, fontWeight: FontWeight.bold);
    _drawCanvasText(canvas, DateTime.now().toString().substring(0, 10), const Offset(tx + 66, ty + 61), fontSize: 6.5);
    _drawCanvasText(canvas, 'QC-PASS', const Offset(tx + 66, ty + 71), fontSize: 7.0, fontWeight: FontWeight.bold);
    _drawCanvasText(canvas, 'DWG NO: 53-2971-Z$fluteCount', const Offset(tx + 152, ty + 66), fontSize: 7.5, fontWeight: FontWeight.bold);

    // Satır 4
    _drawCanvasText(canvas, 'Material:', const Offset(tx + 8, ty + 91), fontSize: 6.5, fontWeight: FontWeight.bold);
    _drawCanvasText(canvas, 'Solid Carbide (VHM)', const Offset(tx + 8, ty + 101), fontSize: 6.5);
    _drawCanvasText(canvas, 'AERO-TOOL-53-2971-Z$fluteCount', const Offset(tx + 152, ty + 96), fontSize: 9.0, fontWeight: FontWeight.bold);

    // Satır 5
    _drawCanvasText(canvas, 'Finish:', const Offset(tx + 8, ty + 121), fontSize: 6.5, fontWeight: FontWeight.bold);
    _drawCanvasText(canvas, coatingName.split(' ')[0], const Offset(tx + 8, ty + 131), fontSize: 6.5);
    _drawCanvasText(canvas, 'HAVACILIK MATKAP / FREZE TAKIMI', const Offset(tx + 152, ty + 121), fontSize: 7.5, fontWeight: FontWeight.bold);
    _drawCanvasText(canvas, 'NAS 965 TIP D / DIN 6527 (ISO 13399)', const Offset(tx + 152, ty + 131), fontSize: 6.5);
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
    FocusManager.instance.primaryFocus?.unfocus();
    _inchController.text = fraction;
    _convertFromInch(fraction);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hassas Ölçü & Havacılık Tel/Numara Tablosu'),
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                        onChanged: _convertFromInch,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'İnç (in / " veya 1/4 kesir)',
                          suffixText: 'inch',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF00E5FF)),
                            tooltip: 'Tamam',
                            onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
                          ),
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
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                        onChanged: _convertFromMm,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'Milimetre (mm)',
                          suffixText: 'mm',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFFFFB300)),
                            tooltip: 'Tamam',
                            onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
                          ),
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
    ),
  );
  }
}
