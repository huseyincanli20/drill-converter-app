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
    extends State<DrillTechnicalDrawingScreen> {
  // ISO / DIN Takım ve Matkap Parametreleri (mm)
  double drillDiameter = 3.26; // d1: Matkap / Kesme Çapı (h9)
  double totalLength = 54.0; // l1: Tam Boy
  double fluteLength = 22.0; // l2: Kesme Boyu
  double reachLength = 28.0; // l3: Boyunlu / Kullanılabilir Boy (KIRMIZI VURGULU)
  double neckDiameter = 3.00; // d3: Boyun Çapı
  double shankDiameter = 6.35; // d2: Sap Çapı (h6)
  double pointAngle = 135.0; // Uç Açısı (135° veya 180° Düz Freze)

  // Görünüm & Katalog Ayarları
  bool isCatalogWhiteMode = true; // Varsayılan: Katalog Beyazı (Kullanıcının görselindeki gibi)
  String toolTipType = 'endmill'; // 'endmill' (Düz Freze - görseldeki gibi) veya 'drill135' (135° Havacılık)
  String dimensionDisplayMode = 'both'; // 'both' (d1: Ø3.26 h9), 'symbols' (d1 h9), 'values' (Ø 3.26 mm)
  final TransformationController _transformController = TransformationController();

  // Sap (Shank) Parametreleri (1/4"-28 Vidalı Sap)
  bool hasThreadedShank = true; // Varsayılan olarak vidalı sap açık
  String hexPosition = 'behind'; // 'behind' = vidalı dişin arkasında (en arka uçta), 'front' = gövde ile vida arası (NAS 965)
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
  void dispose() {
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

  void _zoomIn() {
    setState(() {
      _transformController.value = _transformController.value.scaled(1.2, 1.2, 1.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _transformController.value = _transformController.value.scaled(0.833, 0.833, 1.0);
    });
  }

  void _resetZoom() {
    setState(() {
      _transformController.value = Matrix4.identity();
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
                            pw.Text('Standart: ${hasThreadedShank ? "NAS 907 Tip J (1/4\"-28)" : "DIN 6527 / NAS 907"}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            pw.Text('Malzeme: M2 / M42 HSS-Co %8 / Mikro Taneli Karbür', style: const pw.TextStyle(fontSize: 7.5)),
                            pw.Text('Tolerans: d1: h9, d2: h6 | Salgi: < 0.005 mm', style: const pw.TextStyle(fontSize: 7.5)),
                            pw.Text('Kaplama: TiAlN / Siyah Oksit Buhar Menevis', style: const pw.TextStyle(fontSize: 7.5)),
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

      if (hexPosition == 'behind') {
        // 1. Vidalı Dişin Arkasında 6-Gen Kafa (Uçta Kafa)
        final double hexEndX = shankEndX;
        final double hexStartX = hexEndX - hxLenPx;
        final double threadEndX = hexStartX;
        final double threadStartX = threadEndX - thLenPx;
        final double bodyEndX = threadStartX;

        // Gövde
        canvas.moveTo(reachEndX + 2, originY - halfD2); canvas.lineTo(bodyEndX, originY - halfD2);
        canvas.moveTo(reachEndX + 2, originY + halfD2); canvas.lineTo(bodyEndX, originY + halfD2);
        // Gövdeden dişe basamak
        canvas.moveTo(bodyEndX, originY - halfD2); canvas.lineTo(threadStartX, originY - halfThH);
        canvas.moveTo(bodyEndX, originY + halfD2); canvas.lineTo(threadStartX, originY + halfThH);
        // Diş dış hatları
        canvas.moveTo(threadStartX, originY - halfThH); canvas.lineTo(threadEndX, originY - halfThH);
        canvas.moveTo(threadStartX, originY + halfThH); canvas.lineTo(threadEndX, originY + halfThH);
        // Dişten kafaya basamak
        canvas.moveTo(threadEndX, originY - halfThH); canvas.lineTo(hexStartX, originY - halfHxH);
        canvas.moveTo(threadEndX, originY + halfThH); canvas.lineTo(hexStartX, originY + halfHxH);
        canvas.strokePath();

        // Diş Çizgileri
        canvas.setColor(PdfColors.amber800);
        canvas.setLineWidth(1.2);
        for (double tx = threadStartX + 3; tx < threadEndX - 2; tx += 3.5) {
          canvas.moveTo(tx, originY - halfThH);
          canvas.lineTo(tx + 2, originY + halfThH);
          canvas.strokePath();
        }

        // 6-Gen Kafa
        _drawPdfHexHead(canvas, hexStartX, hexEndX, originY, halfHxH);
      } else {
        // 2. Gövde ile Diş Arasında 6-Gen Kafa (Standart NAS 965)
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
                    // Kart Başlığı ve Model Etiketi
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.architecture, color: Color(0xFF00E5FF), size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'TEKNİK KATALOG ÇİZİMİ',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                              ),
                              child: const Text('ISO 13399', style: TextStyle(fontSize: 10, color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB300).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.3)),
                          ),
                          child: Text(
                            hasThreadedShank ? '1/4"-28 Vidalı Sap' : 'Düz Silindirik Sap',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFFB300)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // İnteraktif Çizim Araç Çubuğu (Toolbar)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // 1. Tema Değiştirici: Katalog Beyazı / Karanlık CAD
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

                          // 2. Takım Uç Tipi: Düz Freze / 135° Matkap
                          ChoiceChip(
                            label: const Text('Düz Freze (Görsel)', style: TextStyle(fontSize: 11)),
                            selected: toolTipType == 'endmill',
                            selectedColor: const Color(0xFF00E5FF).withOpacity(0.25),
                            onSelected: (val) => setState(() => toolTipType = 'endmill'),
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('135° Matkap', style: TextStyle(fontSize: 11)),
                            selected: toolTipType == 'drill135',
                            selectedColor: const Color(0xFF00E5FF).withOpacity(0.25),
                            onSelected: (val) => setState(() => toolTipType = 'drill135'),
                          ),
                          const SizedBox(width: 8),

                          // 3. Ölçü Gösterim Modu: ISO Sembol / Ölçülü / Birlikte
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

                          // 4. Zoom Butonları
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

                    // Canvas Alanı (Interactive Viewer ile Pan & Pinch-Zoom)
                    Container(
                      height: 330,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isCatalogWhiteMode ? Colors.white : const Color(0xFF080D14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCatalogWhiteMode ? const Color(0xFFD0D7DE) : const Color(0xFF1D2838),
                          width: 1.5,
                        ),
                        boxShadow: isCatalogWhiteMode
                            ? [
                                BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4)),
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: InteractiveViewer(
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
                              hexPosition: hexPosition,
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

            // 1. KISIM: VİDALI SAP (AÇMA / KAPAMA SİSTEMLİ VE KISALTILMIŞ)
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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('6-Gen Kafa Konumu: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('⬡ Vida Arkasında (Uçta)', style: TextStyle(fontSize: 11)),
                            selected: hexPosition == 'behind',
                            selectedColor: const Color(0xFFFFB300),
                            backgroundColor: const Color(0xFF0F141C),
                            onSelected: (val) => setState(() => hexPosition = 'behind'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('⬡ Gövde-Vida Arası (NAS 965)', style: TextStyle(fontSize: 11)),
                            selected: hexPosition == 'front',
                            selectedColor: const Color(0xFFFFB300),
                            backgroundColor: const Color(0xFF0F141C),
                            onSelected: (val) => setState(() => hexPosition = 'front'),
                          ),
                        ],
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
  final String hexPosition; // 'behind' = vida arkasında, 'front' = gövde ile vida arası
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
    this.hexPosition = 'behind',
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

      if (hexPosition == 'behind') {
        // 1. Vidalı Dişin Arkasında 6-Gen Kafa (Uçta Kafa)
        final double hexEndX = shankEndX;
        final double hexStartX = hexEndX - hxLenPx;
        final double threadEndX = hexStartX;
        final double threadStartX = threadEndX - thLenPx;
        final double bodyEndX = threadStartX;

        // Silindirik Gövde Hatları
        canvas.drawLine(Offset(reachEndX + 3, centerY - halfD2), Offset(bodyEndX, centerY - halfD2), contourPaint);
        canvas.drawLine(Offset(reachEndX + 3, centerY + halfD2), Offset(bodyEndX, centerY + halfD2), contourPaint);

        // Gövdeden Dişe Basamak
        canvas.drawLine(Offset(bodyEndX, centerY - halfD2), Offset(threadStartX, centerY - halfThH), contourPaint);
        canvas.drawLine(Offset(bodyEndX, centerY + halfD2), Offset(threadStartX, centerY + halfThH), contourPaint);

        // Vidalı Kısım Dış Çizgileri
        canvas.drawLine(Offset(threadStartX, centerY - halfThH), Offset(threadEndX, centerY - halfThH), contourPaint);
        canvas.drawLine(Offset(threadStartX, centerY + halfThH), Offset(threadEndX, centerY + halfThH), contourPaint);

        // Vida Diş Çizgileri (45° açılı)
        final threadLinePaint = Paint()
          ..color = isCatalogWhiteMode ? const Color(0xFFD97706) : const Color(0xFFFFB300)
          ..strokeWidth = 1.6;
        for (double tx = threadStartX + 3; tx < threadEndX - 2; tx += 4.0) {
          canvas.drawLine(Offset(tx, centerY - halfThH), Offset(tx + 2.5, centerY + halfThH), threadLinePaint);
        }

        // Dişten 6-Gen Kafaya Geçiş
        canvas.drawLine(Offset(threadEndX, centerY - halfThH), Offset(hexStartX, centerY - halfHxH), contourPaint);
        canvas.drawLine(Offset(threadEndX, centerY + halfThH), Offset(hexStartX, centerY + halfHxH), contourPaint);

        // 6-Gen Somun Kafa (3 Yüzeyli, Crease Çizgili, Pahlı)
        _drawHexHead(canvas, hexStartX, hexEndX, centerY, halfHxH, contourPaint, isCatalogWhiteMode);
      } else {
        // 2. Gövde ile Diş Arasında 6-Gen Kafa (Standart NAS 965 - Fotoğraftaki gibi)
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
        oldDelegate.hexPosition != hexPosition ||
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
