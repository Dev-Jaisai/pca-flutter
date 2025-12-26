import 'dart:ui'; // Glassmorphism sathi garjeche ahe
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/event_bus.dart';

class RecordPaymentScreen extends StatefulWidget {
  final int installmentId;
  final double? remainingAmount;

  const RecordPaymentScreen({super.key, required this.installmentId, this.remainingAmount});

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtl = TextEditingController();
  final _methodCtl = TextEditingController();
  final _refCtl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _amountCtl.dispose();
    _methodCtl.dispose();
    _refCtl.dispose();
    super.dispose();
  }
// RecordPaymentScreen मध्ये initState मध्ये:
  @override
  void initState() {
    super.initState();
    debugPrint("🎯 RecordPaymentScreen opened:");
    debugPrint("  - Installment ID: ${widget.installmentId}");
    debugPrint("  - Remaining Amount: ${widget.remainingAmount}");
  }
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountCtl.text.trim())!;
    final method = _methodCtl.text.trim().isEmpty ? null : _methodCtl.text.trim();
    final ref = _refCtl.text.trim().isEmpty ? null : _refCtl.text.trim();

    setState(() => _loading = true);
    try {
      await ApiService.recordPayment(
        installmentId: widget.installmentId,
        amount: amount,
        paymentMethod: method,
        reference: ref,
      );

      // Event Fire kara (Global refresh sathi)
      EventBus().fire(PlayerEvent('payment_recorded'));
      EventBus().fire(PlayerEvent('installment_updated'));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment recorded successfully'),
            backgroundColor: Colors.green,
          )
      );

      // 🔥🔥🔥 IMP CHANGE IS HERE 🔥🔥🔥
      // Juna code 'popUntil' waparat hota, tyamule magchya screen la signal bhetat navhta.
      // Aata apan 'true' return kartoy.
      Navigator.pop(context, true);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Record failed: $e'), backgroundColor: Colors.redAccent)
        );
        setState(() => _loading = false);
      }
    }
  }

  // --- GLASS CONTAINER HELPER ---
  Widget _glassContainer({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05), // Transparent White
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, spreadRadius: 2)
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  // --- NEON INPUT DECORATION ---
  InputDecoration _neonInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      prefixIcon: Icon(icon, color: Colors.cyanAccent.withOpacity(0.7)),
      filled: true,
      fillColor: Colors.black.withOpacity(0.3),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.cyanAccent, width: 2), // GLOW EFFECT
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black26),
            child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // 1. BACKGROUND (Deep Sci-Fi Theme)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F2027), // Deep Black-Blue
                  Color(0xFF203A43), // Slate
                  Color(0xFF2C5364), // Teal-Dark
                ],
              ),
            ),
          ),

          // 2. GLOWING ORBS
          Positioned(
            top: -60, left: -40,
            child: Container(
              height: 250, width: 250,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.cyan.withOpacity(0.15), boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.2), blurRadius: 100, spreadRadius: 40)]),
            ),
          ),
          Positioned(
            bottom: -50, right: -50,
            child: Container(
              height: 250, width: 250,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purple.withOpacity(0.15), boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.2), blurRadius: 100, spreadRadius: 40)]),
            ),
          ),

          // 3. MAIN CONTENT
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 120), // Top spacing for AppBar

                  // --- HEADER CARD (Remaining Amount) ---
                  _glassContainer(
                    child: Column(
                      children: [
                        Text(
                          "PAYABLE AMOUNT",
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.remainingAmount != null
                              ? "₹${widget.remainingAmount!.toStringAsFixed(0)}"
                              : "Unknown",
                          style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.cyanAccent,
                              shadows: [Shadow(color: Colors.cyanAccent.withOpacity(0.6), blurRadius: 20)]
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                          child: const Text("Pending Dues", style: TextStyle(color: Colors.white, fontSize: 12)),
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- FORM ---
                  _glassContainer(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Amount Field
                          TextFormField(
                            controller: _amountCtl,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _neonInputDecoration("Enter Amount", Icons.attach_money),
                            validator: (v) {
                              final n = double.tryParse(v ?? '');
                              if (n == null || n <= 0) return 'Enter valid amount';
                              if (widget.remainingAmount != null && n > widget.remainingAmount!) return 'Amount exceeds remaining';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Method Field
                          TextFormField(
                            controller: _methodCtl,
                            style: const TextStyle(color: Colors.white),
                            decoration: _neonInputDecoration("Payment Method (e.g. UPI)", Icons.payment),
                          ),
                          const SizedBox(height: 16),

                          // Reference Field
                          TextFormField(
                            controller: _refCtl,
                            style: const TextStyle(color: Colors.white),
                            decoration: _neonInputDecoration("Reference / Note (Optional)", Icons.note_alt_outlined),
                          ),

                          const SizedBox(height: 30),

                          // --- SUBMIT BUTTON ---
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                gradient: const LinearGradient(
                                  colors: [Colors.blueAccent, Colors.purpleAccent],
                                ),
                                boxShadow: [
                                  BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))
                                ]
                            ),
                            child: ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              child: const Text(
                                'RECORD PAYMENT',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white, letterSpacing: 1.2),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}