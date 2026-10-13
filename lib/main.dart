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
  // Matkap Uç Parametreleri (mm)
  double drillDiameter = 3.26; // #30 Matkap (Ø 3.26 mm)
  double totalLength = 54.0; // Tam Boy (L)
  double fluteLength = 22.0; // Kesme Boyu (l)
  double pointAngle = 135.0; // 135° Split Point

  // Sap (Shank) Parametreleri: Kullanıcının İstediği Gibi Tam Değiştirilebilir!
  double threadLength = 6.35; // Dişli Bölüm Boyu (mm) - Standart 1/4" = 6.35 mm
  double threadDiameter = 6.35; // Diş Çapı (mm) - 1/4" = 6.35 mm
  double hexLength = 7.94; // Kalın Somun Kafa Boyu (mm) - 5/16" = 7.94 mm
  double hexWidth = 7.94; // Kalın Somun Kafa Çapı / Anahtar Ağzı (mm) - 5/16" = 7.94 mm

  String selectedModel = '#30 (Ø3.26mm / 0.1285") - 1/4"-28 Havacilik';

  // Matkap Gövdesi Controller'lar
  final _diamMmController = TextEditingController(text: '3.26');
  final _totalLenMmController = TextEditingController(text: '54.0');
  final _fluteLenMmController = TextEditingController(text: '22.0');
  final _diamInController = TextEditingController(text: '0.1285');
  final _totalLenInController = TextEditingController(text: '2.125');
  final _fluteLenInController = TextEditingController(text: '0.875');

  // Sap Bölümü Controller'lar (Dişli Yer ve Kalın Yer)
  final _threadLenController = TextEditingController(text: '6.35');
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
      'angle': 135.0,
    },
  ];

  @override
  void dispose() {
    _diamMmController.dispose();
    _totalLenMmController.dispose();
    _fluteLenMmController.dispose();
    _diamInController.dispose();
    _totalLenInController.dispose();
    _fluteLenInController.dispose();
    _threadLenController.dispose();
    _threadDiamController.dispose();
    _hexLenController.dispose();
    _hexWidthController.dispose();
    super.dispose();
  }

  void _applyPreset(Map<String, dynamic> item) {
    setState(() {
      selectedModel = item['label'];
      drillDiameter = item['dMm'];
      totalLength = item['lMm'];
      fluteLength = item['fluteMm'];
      pointAngle = item['angle'];

      _diamMmController.text = drillDiameter.toStringAsFixed(2);
      _totalLenMmController.text = totalLength.toStringAsFixed(1);
      _fluteLenMmController.text = fluteLength.toStringAsFixed(1);

      _diamInController.text = item['dIn'];
      _totalLenInController.text = item['lIn'];
      _fluteLenInController.text = item['fluteIn'];
    });
  }

  void _updateDrillFromMm() {
    setState(() {
      drillDiameter = double.tryParse(_diamMmController.text) ?? drillDiameter;
      totalLength = double.tryParse(_totalLenMmController.text) ?? totalLength;
      fluteLength = double.tryParse(_fluteLenMmController.text) ?? fluteLength;

      _diamInController.text = (drillDiameter / 25.4).toStringAsFixed(4);
      _totalLenInController.text = (totalLength / 25.4).toStringAsFixed(3);
      _fluteLenInController.text = (fluteLength / 25.4).toStringAsFixed(3);
    });
  }

  void _updateDrillFromInch() {
    setState(() {
      final inD = double.tryParse(_diamInController.text);
      final inL = double.tryParse(_totalLenInController.text);
      final inF = double.tryParse(_fluteLenInController.text);

      if (inD != null) drillDiameter = inD * 25.4;
      if (inL != null) totalLength = inL * 25.4;
      if (inF != null) fluteLength = inF * 25.4;

      _diamMmController.text = drillDiameter.toStringAsFixed(2);
      _totalLenMmController.text = totalLength.toStringAsFixed(1);
      _fluteLenMmController.text = fluteLength.toStringAsFixed(1);
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

  // Teknik Resmi Dogrudan Acma / Yazdirma Motoru
  Future<void> _openTechnicalDrawing() async {
    try {
      final pdfBytes = await _buildPdfDocument(PdfPageFormat.a4.landscape);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'NAS907_1-4-28_Drill_${drillDiameter.toStringAsFixed(2)}mm.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Olusturma Hatasi: $e')),
        );
      }
    }
  }

  Future<Uint8List> _buildPdfDocument(PdfPageFormat format) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(841.89, 595.28, marginAll: 20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. Antet Ust Bilgi
              pw.Container(
                width: 800,
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  border: pw.Border.all(color: PdfColors.black, width: 1),
                ),
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'TEKNIK IMALAT RESMI - 1/4"-28 THREADED SHANK MATKAP',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          'HAVACILIK STANDARDI (AEROSPACE NAS 907 TYPE J / 53-2971 SERISI)',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('KOD: 53-2971 | CAP: ${drillDiameter.toStringAsFixed(2)} mm (${(drillDiameter / 25.4).toStringAsFixed(4)}")', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.Text('TARIH: ${DateTime.now().toString().substring(0, 10)} | REV: 05', style: const pw.TextStyle(fontSize: 7.5)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),

              // 2. CAD Cizim Kutusu
              pw.Container(
                width: 800,
                height: 240,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1),
                ),
                alignment: pw.Alignment.center,
                child: pw.CustomPaint(
                  size: const PdfPoint(760, 220),
                  painter: (PdfGraphics canvas, PdfPoint size) {
                    _drawAeroPdfDrill(canvas, size);
                  },
                ),
              ),
              pw.SizedBox(height: 6),

              // 3. Alt Tablo
              pw.Container(
                width: 800,
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.SizedBox(
                      width: 500,
                      child: pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey600),
                        columnWidths: const {
                          0: pw.FlexColumnWidth(1.2),
                          1: pw.FlexColumnWidth(1.0),
                          2: pw.FlexColumnWidth(1.0),
                          3: pw.FlexColumnWidth(1.1),
                          4: pw.FlexColumnWidth(1.1),
                        },
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Matkap Capi (d)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Tam Boy (L)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Kesme Boyu (l)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Sap Disi (L1)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Somun Kafasi (L2)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                            ],
                          ),
                          pw.TableRow(
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('${drillDiameter.toStringAsFixed(2)} mm [${(drillDiameter / 25.4).toStringAsFixed(4)}"]', style: const pw.TextStyle(fontSize: 8))),
                              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('${totalLength.toStringAsFixed(1)} mm [${(totalLength / 25.4).toStringAsFixed(3)}"]', style: const pw.TextStyle(fontSize: 8))),
                              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('${fluteLength.toStringAsFixed(1)} mm [${(fluteLength / 25.4).toStringAsFixed(3)}"]', style: const pw.TextStyle(fontSize: 8))),
                              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('${threadLength.toStringAsFixed(1)} mm (Cap: ${threadDiameter.toStringAsFixed(1)})', style: const pw.TextStyle(fontSize: 8))),
                              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('${hexLength.toStringAsFixed(1)} mm (Agiz: ${hexWidth.toStringAsFixed(1)})', style: const pw.TextStyle(fontSize: 8))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(
                      width: 290,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(4),
                        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey600)),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Sap: 1/4"-28 Vida + 5/16" Altigen Somun', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            pw.Text('Malzeme: M2 / M42 HSS-Co (Havacilik Tipi)', style: const pw.TextStyle(fontSize: 7.5)),
                            pw.Text('Kullanim: 90 deg Havali Matkaplar (Angle Drill)', style: const pw.TextStyle(fontSize: 7.5)),
                            pw.Text('Yuzey: Siyah Oksit / Buhar Menevis', style: const pw.TextStyle(fontSize: 7.5)),
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

  void _drawAeroPdfDrill(PdfGraphics canvas, PdfPoint size) {
    const originX = 70.0;
    final originY = size.y / 2;
    final drawWidth = size.x - 140;

    final scaleX = drawWidth / totalLength;

    final threadLenPx = threadLength * scaleX;
    final hexLenPx = hexLength * scaleX;
    final shankShaftLenPx = (totalLength - fluteLength - threadLength - hexLength) * scaleX;
    final fluteLenPx = fluteLength * scaleX;

    final shankThreadH = (threadDiameter * 5.0).clamp(24.0, 50.0);
    final hexH = (hexWidth * 5.5).clamp(30.0, 60.0);
    final drillH = (drillDiameter * 6.0).clamp(16.0, 36.0);
    final tipLenPx = (drillH / 2) / math.tan((pointAngle / 2) * math.pi / 180);

    double curX = originX;

    // 1. Dişli Sap
    canvas.setColor(PdfColors.grey400);
    canvas.drawRect(curX, originY - shankThreadH / 2, threadLenPx, shankThreadH);
    canvas.fillPath();

    canvas.setColor(PdfColors.black);
    canvas.setLineWidth(1.2);
    canvas.drawRect(curX, originY - shankThreadH / 2, threadLenPx, shankThreadH);
    canvas.strokePath();

    canvas.setColor(PdfColors.grey800);
    for (double tx = curX + 2; tx < curX + threadLenPx - 2; tx += 3.5) {
      canvas.moveTo(tx, originY - shankThreadH / 2 - 2);
      canvas.lineTo(tx + 2, originY + shankThreadH / 2 + 2);
      canvas.strokePath();
    }
    curX += threadLenPx;

    // 2. Kalın Altıgen Somun Kafa
    canvas.setColor(PdfColors.grey600);
    canvas.drawRect(curX, originY - hexH / 2, hexLenPx, hexH);
    canvas.fillPath();

    canvas.setColor(PdfColors.black);
    canvas.setLineWidth(1.5);
    canvas.drawRect(curX, originY - hexH / 2, hexLenPx, hexH);
    canvas.strokePath();

    canvas.setColor(PdfColors.grey300);
    canvas.moveTo(curX, originY - hexH * 0.28);
    canvas.lineTo(curX + hexLenPx, originY - hexH * 0.28);
    canvas.moveTo(curX, originY + hexH * 0.28);
    canvas.lineTo(curX + hexLenPx, originY + hexH * 0.28);
    canvas.strokePath();
    curX += hexLenPx;

    // 3. Silindirik Ara Gövde
    if (shankShaftLenPx > 0) {
      canvas.setColor(PdfColors.grey400);
      canvas.drawRect(curX, originY - drillH / 2, shankShaftLenPx, drillH);
      canvas.fillPath();

      canvas.setColor(PdfColors.black);
      canvas.drawRect(curX, originY - drillH / 2, shankShaftLenPx, drillH);
      canvas.strokePath();
      curX += shankShaftLenPx;
    }

    // 4. Helis Kanalı
    final fluteBodyLen = fluteLenPx - tipLenPx;
    canvas.setColor(PdfColors.grey300);
    canvas.drawRect(curX, originY - drillH / 2, fluteBodyLen, drillH);
    canvas.fillPath();

    canvas.setColor(PdfColors.black);
    canvas.drawRect(curX, originY - drillH / 2, fluteBodyLen, drillH);
    canvas.strokePath();

    for (double hx = curX + 6; hx < curX + fluteBodyLen - 4; hx += 12.0) {
      canvas.moveTo(hx, originY - drillH / 2);
      canvas.curveTo(hx + 5, originY, hx + 7, originY, hx + 12, originY + drillH / 2);
      canvas.strokePath();
    }
    curX += fluteBodyLen;

    // 5. Matkap Ucu
    final tipEndX = curX + tipLenPx;
    canvas.setColor(PdfColors.grey400);
    canvas.moveTo(curX, originY - drillH / 2);
    canvas.lineTo(tipEndX, originY);
    canvas.lineTo(curX, originY + drillH / 2);
    canvas.closePath();
    canvas.fillPath();

    canvas.setColor(PdfColors.black);
    canvas.moveTo(curX, originY - drillH / 2);
    canvas.lineTo(tipEndX, originY);
    canvas.lineTo(curX, originY + drillH / 2);
    canvas.closePath();
    canvas.strokePath();

    // 6. Eksen Çizgisi
    canvas.setColor(PdfColors.red900);
    canvas.setLineWidth(0.8);
    canvas.moveTo(originX - 25, originY);
    canvas.lineTo(tipEndX + 30, originY);
    canvas.strokePath();

    // 7. Ölçü Çizgileri
    canvas.setColor(PdfColors.black);
    canvas.setLineWidth(1.0);

    final yDimL = originY + hexH / 2 + 25;
    canvas.moveTo(originX, yDimL - 6); canvas.lineTo(originX, yDimL + 6);
    canvas.moveTo(tipEndX, yDimL - 6); canvas.lineTo(tipEndX, yDimL + 6);
    canvas.moveTo(originX, yDimL); canvas.lineTo(tipEndX, yDimL);
    canvas.strokePath();

    final yDimFlute = originY - hexH / 2 - 25;
    final fluteStartX = tipEndX - fluteLenPx;
    canvas.moveTo(fluteStartX, yDimFlute - 6); canvas.lineTo(fluteStartX, yDimFlute + 6);
    canvas.moveTo(tipEndX, yDimFlute - 6); canvas.lineTo(tipEndX, yDimFlute + 6);
    canvas.moveTo(fluteStartX, yDimFlute); canvas.lineTo(tipEndX, yDimFlute);
    canvas.strokePath();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Icon(Icons.flight_takeoff, color: Color(0xFF00E5FF)),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text('TEKNİK RESİM AÇ / YAZDIR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: _openTechnicalDrawing,
          ),
          const SizedBox(width: 12),
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

            // CAD Önizleme Kartı
            Card(
              elevation: 4,
              color: const Color(0xFF141A24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF232E3E), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.tune, color: Color(0xFFFFB300), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'CANLI VİDALI SAP VE GÖVDE CAD ÇİZİMİ',
                              style: TextStyle(
                                color: Color(0xFFFFB300),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                          ),
                          child: Text(
                            'Matkap: Ø ${drillDiameter.toStringAsFixed(2)} mm | Sap: Ø ${threadDiameter.toStringAsFixed(2)} mm',
                            style: const TextStyle(
                              color: Color(0xFF00E5FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Canvas Alanı
                    Container(
                      height: 310,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF080D14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1D2838), width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CustomPaint(
                          painter: ThreadedShankDrillPainter(
                            drillDiameter: drillDiameter,
                            totalLength: totalLength,
                            fluteLength: fluteLength,
                            pointAngle: pointAngle,
                            threadLength: threadLength,
                            hexLength: hexLength,
                            threadDiameter: threadDiameter,
                            hexWidth: hexWidth,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 1. KISIM: VİDALI SAPIN DİŞLİ YERİ VE KALIN YERİ PARAMETRELERİ (YENİ!)
            Card(
              color: const Color(0xFF171E28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFFFB300), width: 1.2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.build_circle, color: Color(0xFFFFB300), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Vidalı Sap Parametreleri (Dişli Yer ve Kalın Yer)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFB300),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sapın en arkasındaki vidalı dişin uzunluğunu ve çapını, hemen yanındaki kalın somun kısmının boyunu ve kalınlığını buradan dilediğiniz gibi değiştirebilirsiniz:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            label: 'Dişli Yer Boyu (L_vida)',
                            controller: _threadLenController,
                            suffix: 'mm',
                            onChanged: (v) => _updateShankParams(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInputField(
                            label: 'Dişli Yer Çapı (Ø_vida)',
                            controller: _threadDiamController,
                            suffix: 'mm',
                            onChanged: (v) => _updateShankParams(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInputField(
                            label: 'Kalın Yer Boyu (L_somun)',
                            controller: _hexLenController,
                            suffix: 'mm',
                            onChanged: (v) => _updateShankParams(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInputField(
                            label: 'Kalın Yer Çapı (Genişlik)',
                            controller: _hexWidthController,
                            suffix: 'mm',
                            onChanged: (v) => _updateShankParams(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. KISIM: MATKAP GÖVDE VE KESME PARAMETRELERİ (mm ve İnç)
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
                      'Matkap Uç ve Gövde Parametreleri (mm ve İnç)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // mm Satırı
                    const Text('Metrik Ölçüler (mm):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            label: 'Matkap Çapı (d)',
                            controller: _diamMmController,
                            suffix: 'mm',
                            onChanged: (v) => _updateDrillFromMm(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInputField(
                            label: 'Kesme Boyu (l)',
                            controller: _fluteLenMmController,
                            suffix: 'mm',
                            onChanged: (v) => _updateDrillFromMm(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInputField(
                            label: 'Tam Boy (L)',
                            controller: _totalLenMmController,
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
                            label: 'Matkap Çapı (d - İnç)',
                            controller: _diamInController,
                            suffix: '"',
                            onChanged: (v) => _updateDrillFromInch(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInputField(
                            label: 'Kesme Boyu (l - İnç)',
                            controller: _fluteLenInController,
                            suffix: '"',
                            onChanged: (v) => _updateDrillFromInch(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInputField(
                            label: 'Tam Boy (L - İnç)',
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

            // Büyük Teknik Resim Aç / Yazdır Butonu
            ElevatedButton.icon(
              onPressed: _openTechnicalDrawing,
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 24),
              label: const Text(
                'TEKNİK RESMİ GÖRÜNTÜLE & YAZDIR (A4 ANTETLİ PDF)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
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

// -----------------------------------------------------------------------------
// VİDALI SAP (DİŞLİ VE KALIN KISIM DEĞİŞKENLİ) CUSTOM PAINTER
// -----------------------------------------------------------------------------

class ThreadedShankDrillPainter extends CustomPainter {
  final double drillDiameter;
  final double totalLength;
  final double fluteLength;
  final double pointAngle;
  final double threadLength;
  final double hexLength;
  final double threadDiameter;
  final double hexWidth;

  ThreadedShankDrillPainter({
    required this.drillDiameter,
    required this.totalLength,
    required this.fluteLength,
    required this.pointAngle,
    required this.threadLength,
    required this.hexLength,
    required this.threadDiameter,
    required this.hexWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Grid
    final gridMinor = Paint()..color = const Color(0xFF101926)..strokeWidth = 0.5;
    final gridMajor = Paint()..color = const Color(0xFF182436)..strokeWidth = 1.0;

    for (double i = 0; i < size.width; i += 10) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), (i % 50 == 0) ? gridMajor : gridMinor);
    }
    for (double j = 0; j < size.height; j += 20) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j), (j % 60 == 0) ? gridMajor : gridMinor);
    }

    final double startX = 75.0;
    final double centerY = size.height / 2;
    final double maxDrawWidth = size.width - 150.0;

    final double scaleX = maxDrawWidth / totalLength;

    final double threadLenPx = threadLength * scaleX;
    final double hexLenPx = hexLength * scaleX;
    final double shankShaftLenPx = (totalLength - fluteLength - threadLength - hexLength) * scaleX;
    final double fluteLenPx = fluteLength * scaleX;

    // Yükseklikler (Kullanıcının girdiği threadDiameter ve hexWidth değerlerine bağlı)
    final double threadHPx = (threadDiameter * 5.2).clamp(24.0, 56.0);
    final double hexHPx = (hexWidth * 5.5).clamp(28.0, 68.0);
    final double drillHPx = (drillDiameter * 6.0).clamp(16.0, 36.0);
    final double halfDrillH = drillHPx / 2;

    final double rad = (pointAngle / 2) * math.pi / 180;
    final double tipLenPx = halfDrillH / math.tan(rad);

    double curX = startX;

    final contourPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    // 1. DİŞLİ SAP (THREADED STUD)
    final threadRect = Rect.fromLTWH(curX, centerY - threadHPx / 2, threadLenPx, threadHPx);
    final threadGrad = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF3A4858), Color(0xFF1E2833), Color(0xFF11171E), Color(0xFF3A4858)],
    );
    canvas.drawRect(threadRect, Paint()..shader = threadGrad.createShader(threadRect));
    canvas.drawRect(threadRect, contourPaint);

    final threadLinePaint = Paint()..color = const Color(0xFFFFB300)..strokeWidth = 1.8;
    for (double tx = curX + 2; tx < curX + threadLenPx - 2; tx += 4.5) {
      canvas.drawLine(
        Offset(tx, centerY - threadHPx / 2 - 2),
        Offset(tx + 2.5, centerY + threadHPx / 2 + 2),
        threadLinePaint,
      );
    }
    curX += threadLenPx;

    // 2. KALIN ALTIGEN SOMUN KISMI (HEX COLLAR)
    final hexRect = Rect.fromLTWH(curX, centerY - hexHPx / 2, hexLenPx, hexHPx);
    final hexGrad = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF4A5A6C), Color(0xFF24303E), Color(0xFF151C24), Color(0xFF4A5A6C)],
    );
    canvas.drawRect(hexRect, Paint()..shader = hexGrad.createShader(hexRect));
    canvas.drawRect(hexRect, contourPaint);

    final hexEdgePaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.5)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(curX, centerY - hexHPx * 0.28), Offset(curX + hexLenPx, centerY - hexHPx * 0.28), hexEdgePaint);
    canvas.drawLine(Offset(curX, centerY + hexHPx * 0.28), Offset(curX + hexLenPx, centerY + hexHPx * 0.28), hexEdgePaint);
    curX += hexLenPx;

    // 3. SİLİNDİRİK ARA GÖVDE
    if (shankShaftLenPx > 0) {
      final shaftRect = Rect.fromLTWH(curX, centerY - halfDrillH, shankShaftLenPx, drillHPx);
      final shaftGrad = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF334252), Color(0xFF1B232C), Color(0xFF11171E), Color(0xFF334252)],
      );
      canvas.drawRect(shaftRect, Paint()..shader = shaftGrad.createShader(shaftRect));
      canvas.drawRect(shaftRect, contourPaint);
      curX += shankShaftLenPx;
    }

    // 4. KESME HELİSİ
    final fluteBodyLen = fluteLenPx - tipLenPx;
    final fluteRect = Rect.fromLTWH(curX, centerY - halfDrillH, fluteBodyLen, drillHPx);
    final fluteGrad = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF2A3644), Color(0xFF182029), Color(0xFF0E1318), Color(0xFF2A3644)],
    );
    canvas.drawRect(fluteRect, Paint()..shader = fluteGrad.createShader(fluteRect));
    canvas.drawRect(fluteRect, contourPaint);

    final helixLinePaint = Paint()..color = const Color(0xFF00E5FF).withOpacity(0.7)..strokeWidth = 2.0..style = PaintingStyle.stroke;
    final helixShadePaint = Paint()..color = const Color(0xFF080D14)..style = PaintingStyle.fill;

    const double step = 14.0;
    for (double hx = curX + 2; hx < curX + fluteBodyLen - 3; hx += step) {
      final curvePath = Path();
      curvePath.moveTo(hx, centerY - halfDrillH);
      curvePath.cubicTo(
        hx + step * 0.45, centerY - halfDrillH * 0.3,
        hx + step * 0.55, centerY + halfDrillH * 0.3,
        hx + step, centerY + halfDrillH,
      );

      final shadePath = Path.from(curvePath);
      shadePath.lineTo(hx + step + 3, centerY + halfDrillH);
      shadePath.cubicTo(
        hx + step * 0.55 + 3, centerY + halfDrillH * 0.3,
        hx + step * 0.45 + 3, centerY - halfDrillH * 0.3,
        hx + 3, centerY - halfDrillH,
      );
      shadePath.close();
      canvas.drawPath(shadePath, helixShadePaint);
      canvas.drawPath(curvePath, helixLinePaint);
    }
    curX += fluteBodyLen;

    // 5. UÇ KONİSİ
    final tipEndX = curX + tipLenPx;
    final tipPath = Path()
      ..moveTo(curX, centerY - halfDrillH)
      ..lineTo(tipEndX, centerY)
      ..lineTo(curX, centerY + halfDrillH)
      ..close();

    final tipGrad = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF4A5A6C), Color(0xFF24303E), Color(0xFF151C24), Color(0xFF4A5A6C)],
    );
    canvas.drawPath(tipPath, Paint()..shader = tipGrad.createShader(tipPath.getBounds()));
    canvas.drawPath(tipPath, contourPaint);

    canvas.drawLine(Offset(tipEndX - 3, centerY - 2), Offset(tipEndX, centerY + 2), Paint()..color = Colors.white..strokeWidth = 1.8);

    // 6. EKSEN ÇİZGİSİ
    _drawCenterLine(
      canvas,
      Offset(startX - 25, centerY),
      Offset(tipEndX + 35, centerY),
    );

    // 7. ÖLÇÜ ÇİZGİLERİ
    final inD = (drillDiameter / 25.4).toStringAsFixed(4);
    final inL = (totalLength / 25.4).toStringAsFixed(3);
    final inFlute = (fluteLength / 25.4).toStringAsFixed(3);

    // Dişli Yer Ölçüsü (Sol Dikey)
    _drawDimensionArrowY(
      canvas,
      startX - 18,
      centerY - threadHPx / 2,
      centerY + threadHPx / 2,
      'Ø ${threadDiameter.toStringAsFixed(2)} mm',
      subText: 'L=${threadLength.toStringAsFixed(1)}mm',
    );

    // Matkap Çapı (Sağ Uç)
    _drawDimensionArrowY(
      canvas,
      curX - 10,
      centerY - halfDrillH,
      centerY + halfDrillH,
      'Ø ${drillDiameter.toStringAsFixed(2)} mm ($inD")',
      subText: 'Matkap Çapı',
    );

    // Tam Boy (Alt Yatay)
    _drawDimensionArrowX(
      canvas,
      centerY + hexHPx / 2 + 34,
      startX,
      tipEndX,
      'Tam Boy (L) = ${totalLength.toStringAsFixed(1)} mm ($inL")',
    );

    // Kesme Boyu (Üst Yatay)
    _drawDimensionArrowX(
      canvas,
      centerY - hexHPx / 2 - 30,
      tipEndX - fluteLenPx,
      tipEndX,
      'Kesme (l) = ${fluteLength.toStringAsFixed(1)} mm ($inFlute")',
    );

    _drawAngleDimension(canvas, tipEndX, centerY, tipLenPx, halfDrillH, pointAngle);
  }

  void _drawCenterLine(Canvas canvas, Offset p1, Offset p2) {
    final paint = Paint()..color = const Color(0xFFFF5252).withOpacity(0.85)..strokeWidth = 1.0;
    const longDash = 14.0;
    const gap = 4.0;
    const dot = 2.0;

    final totalDist = (p2 - p1).distance;
    final dir = (p2 - p1) / totalDist;
    double d = 0;

    while (d < totalDist) {
      final sLong = p1 + dir * d;
      final eLong = p1 + dir * math.min(d + longDash, totalDist);
      canvas.drawLine(sLong, eLong, paint);
      d += longDash + gap;

      if (d < totalDist) {
        final dotPos = p1 + dir * d;
        canvas.drawCircle(dotPos, 0.8, paint);
        d += dot + gap;
      }
    }
  }

  void _drawDimensionArrowX(Canvas canvas, double y, double x1, double x2, String label) {
    final dimPaint = Paint()..color = const Color(0xFFFFB300)..strokeWidth = 1.2;

    canvas.drawLine(Offset(x1, y - 8), Offset(x1, y + 8), dimPaint);
    canvas.drawLine(Offset(x2, y - 8), Offset(x2, y + 8), dimPaint);
    canvas.drawLine(Offset(x1, y), Offset(x2, y), dimPaint);

    _drawSolidArrowHead(canvas, Offset(x1, y), Offset(x1 + 8, y - 3), Offset(x1 + 8, y + 3), const Color(0xFFFFB300));
    _drawSolidArrowHead(canvas, Offset(x2, y), Offset(x2 - 8, y - 3), Offset(x2 - 8, y + 3), const Color(0xFFFFB300));

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Color(0xFFFFB300), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final textRect = Rect.fromCenter(
      center: Offset((x1 + x2) / 2, y),
      width: textPainter.width + 10,
      height: 14,
    );
    canvas.drawRect(textRect, Paint()..color = const Color(0xFF080D14));
    textPainter.paint(canvas, Offset((x1 + x2) / 2 - textPainter.width / 2, y - textPainter.height / 2));
  }

  void _drawDimensionArrowY(Canvas canvas, double x, double y1, double y2, String label, {String? subText}) {
    final dimPaint = Paint()..color = const Color(0xFFFFB300)..strokeWidth = 1.2;

    canvas.drawLine(Offset(x - 8, y1), Offset(x + 8, y1), dimPaint);
    canvas.drawLine(Offset(x - 8, y2), Offset(x + 8, y2), dimPaint);
    canvas.drawLine(Offset(x, y1), Offset(x, y2), dimPaint);

    _drawSolidArrowHead(canvas, Offset(x, y1), Offset(x - 3, y1 + 8), Offset(x + 3, y1 + 8), const Color(0xFFFFB300));
    _drawSolidArrowHead(canvas, Offset(x, y2), Offset(x - 3, y2 - 8), Offset(x + 3, y2 - 8), const Color(0xFFFFB300));

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Color(0xFFFFB300), fontSize: 10, fontWeight: FontWeight.bold),
        children: subText != null ? [
          TextSpan(text: '\n$subText', style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 9)),
        ] : null,
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    )..layout();

    textPainter.paint(canvas, Offset(x - textPainter.width - 6, (y1 + y2) / 2 - textPainter.height / 2));
  }

  void _drawAngleDimension(Canvas canvas, double tipX, double centerY, double tipLen, double halfD, double angle) {
    final anglePaint = Paint()..color = const Color(0xFF00E676)..strokeWidth = 1.2..style = PaintingStyle.stroke;

    final arcRect = Rect.fromCircle(center: Offset(tipX, centerY), radius: 26);
    final startRad = math.pi - (angle / 2 * math.pi / 180);
    final sweepRad = angle * math.pi / 180;

    canvas.drawArc(arcRect, startRad, sweepRad, false, anglePaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: '${angle.toInt()}°',
        style: const TextStyle(color: Color(0xFF00E676), fontSize: 10, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(tipX - 42, centerY - textPainter.height / 2));
  }

  void _drawSolidArrowHead(Canvas canvas, Offset tip, Offset p1, Offset p2, Color color) {
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant ThreadedShankDrillPainter oldDelegate) {
    return oldDelegate.drillDiameter != drillDiameter ||
        oldDelegate.totalLength != totalLength ||
        oldDelegate.fluteLength != fluteLength ||
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
