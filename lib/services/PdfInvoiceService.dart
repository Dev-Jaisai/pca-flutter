import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart'; // DateFormat sathi
import '../models/player.dart';
import '../models/player_installment_summary.dart';

class PdfInvoiceService {

  static Future<void> generateAndPrint(
      Player player,
      PlayerInstallmentSummary installment,
      ) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    // Dates Formatting
    final df = DateFormat('dd MMM yyyy');
    final generationDate = DateTime.now();

    // Check Payment Date (Backend madhun 'lastPaymentDate' yet asel tar te vapra, nahitar aajchi date)
    // Note: Tumchya model madhye 'lastPaymentDate' asel tar te uncomment kara.
    // Sadhya mi 'generationDate' vapartoy example sathi.
    final paymentDate = installment.lastPaymentDate ?? DateTime.now();

    final monthName = _getMonthName(installment.dueDate?.month ?? 1);
    final year = installment.dueDate?.year ?? 2025;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // 1. Watermark
              pw.Center(
                child: pw.Transform.rotate(
                  angle: -0.5,
                  child: pw.Text(
                    "PAID",
                    style: pw.TextStyle(
                      fontSize: 100,
                      color: PdfColors.grey200,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // 2. Main Content
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // --- HEADER (Academy Info Update) ---
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            // ✅ NEW NAME
                            pw.Text("PCA", style: pw.TextStyle(font: fontBold, fontSize: 24, color: PdfColors.blue900)),
                            pw.Text("Professional Cricket Academy", style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey700)),
                            pw.SizedBox(height: 4),
                            // ✅ NEW PHONE NUMBER
                            pw.Text("Phone: +91 9157648885", style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                            pw.Text("Sports Complex, Pune", style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                          ],
                        ),
                        pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColors.green, width: 2),
                                borderRadius: pw.BorderRadius.circular(8)
                            ),
                            child: pw.Text("PAYMENT RECEIPT", style: pw.TextStyle(color: PdfColors.green, fontWeight: pw.FontWeight.bold))
                        )
                      ],
                    ),
                    pw.SizedBox(height: 20),
                    pw.Divider(color: PdfColors.grey300),
                    pw.SizedBox(height: 20),

                    // --- BILL DETAILS ---
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text("RECEIVED FROM:", style: pw.TextStyle(font: fontRegular, color: PdfColors.grey600, fontSize: 10)),
                            pw.SizedBox(height: 5),
                            pw.Text(player.name.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 16)),
                            pw.Text("Group: ${player.group ?? 'N/A'}", style: pw.TextStyle(font: fontRegular, fontSize: 12)),
                            pw.Text("Mobile: ${player.phone}", style: pw.TextStyle(font: fontRegular, fontSize: 12)),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text("RECEIPT #: ${installment.installmentId ?? 'AUTO'}", style: pw.TextStyle(font: fontBold)),
                            pw.Text("Issue Date: ${df.format(generationDate)}", style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                            pw.SizedBox(height: 4),
                            // ✅ IMPORTANT: PAID ON DATE
                            pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                color: PdfColors.green50,
                                child: pw.Row(
                                    children: [
                                      pw.Text("Paid On: ", style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.green900)),
                                      pw.Text(df.format(paymentDate), style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.green900)),
                                    ]
                                )
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 30),

                    // --- TABLE ---
                    pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey300),
                        children: [
                          // Header
                          pw.TableRow(
                              decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                              children: [
                                _buildCell("Description", fontBold, align: pw.TextAlign.left),
                                _buildCell("Due Date", fontBold),
                                _buildCell("Status", fontBold),
                                _buildCell("Amount", fontBold, align: pw.TextAlign.right),
                              ]
                          ),
                          // Data
                          pw.TableRow(
                              children: [
                                _buildCell("Monthly Fee - $monthName $year", fontRegular, align: pw.TextAlign.left),
                                _buildCell(installment.dueDate != null ? df.format(installment.dueDate!) : "-", fontRegular),
                                _buildCell("PAID", fontBold, color: PdfColors.green),
                                _buildCell("Rs. ${installment.totalPaid.toStringAsFixed(2)}", fontBold, align: pw.TextAlign.right),
                              ]
                          ),
                        ]
                    ),

                    pw.SizedBox(height: 20),

                    // --- TOTAL ---
                    pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Text("Total Amount Received:", style: pw.TextStyle(font: fontRegular, fontSize: 12)),
                                pw.SizedBox(height: 5),
                                pw.Text("Rs. ${installment.totalPaid.toStringAsFixed(2)}", style: pw.TextStyle(font: fontBold, fontSize: 22, color: PdfColors.blue900)),
                              ]
                          )
                        ]
                    ),

                    pw.Spacer(),

                    // --- FOOTER ---
                    pw.Divider(color: PdfColors.grey300),
                    pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text("Thank you! This is a computer-generated receipt.", style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey600)),
                                pw.Text("PCA - Transforming Passion into Profession", style: pw.TextStyle(font: fontBold, fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
                              ]
                          ),
                          pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Text("PCA Admin", style: pw.TextStyle(font: fontBold, fontSize: 10)),
                                pw.Text("Authorized Signature", style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                              ]
                          ),
                        ]
                    ),
                    pw.SizedBox(height: 20),
                  ]
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Receipt_${player.name}_${monthName}_$year.pdf',
    );
  }

  static pw.Widget _buildCell(String text, pw.Font font, {pw.TextAlign align = pw.TextAlign.center, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(10),
      child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(font: font, fontSize: 10, color: color ?? PdfColors.black)
      ),
    );
  }

  static String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}