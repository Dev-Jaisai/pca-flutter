import 'dart:ui'; // Required for Glassmorphism
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/payment.dart';
import '../../services/data_manager.dart';
import 'record_payment_screen.dart';

class PaymentsListScreen extends StatefulWidget {
  final int installmentId;
  final double? remainingAmount;

  const PaymentsListScreen({
    super.key,
    required this.installmentId,
    this.remainingAmount,
  });

  @override
  State<PaymentsListScreen> createState() => _PaymentsListScreenState();
}

class _PaymentsListScreenState extends State<PaymentsListScreen> {
  bool _loading = true;
  List<Payment> _payments = [];

  final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final dateFormat = DateFormat('dd MMM yyyy');
  final timeFormat = DateFormat('hh:mm a');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = await DataManager().getPayments(widget.installmentId);
    if (cached.isNotEmpty) {
      if (mounted) setState(() { _payments = cached; _loading = false; });
    } else {
      if (mounted) setState(() => _loading = true);
    }

    try {
      final freshList = await DataManager().getPayments(widget.installmentId, forceRefresh: true);
      if (mounted) setState(() { _payments = freshList; _loading = false; });
    } catch (e) {
      if (mounted && _payments.isEmpty) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openRecord() async {
    final didCreate = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecordPaymentScreen(
          installmentId: widget.installmentId,
          remainingAmount: widget.remainingAmount,
        ),
      ),
    );
    if (didCreate == true) {
      DataManager().invalidatePayments(widget.installmentId);
      _load();
    }
  }

  // --- GLASS CONTAINER HELPER ---
  Widget _glassContainer({required Widget child, EdgeInsetsGeometry? padding, double radius = 20}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08), // Transparent White
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  // --- TOTAL SUMMARY CARD ---
  Widget _buildGlassCard() {
    double totalPaid = _payments.fold(0, (sum, item) => sum + (item.amount ?? 0));
    double remaining = widget.remainingAmount ?? 0;
    double totalDue = totalPaid + remaining;
    double percentage = totalDue == 0 ? 0 : (totalPaid / totalDue);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 100, 20, 20), // Top margin for AppBar
      child: _glassContainer(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("TOTAL PAID",
                        style: TextStyle(color: Colors.white.withOpacity(0.6), letterSpacing: 1.5, fontSize: 12, fontWeight: FontWeight.bold)
                    ),
                    const SizedBox(height: 8),
                    Text(money.format(totalPaid),
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1)
                    ),
                  ],
                ),
                Container(
                  height: 50, width: 50,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Colors.greenAccent.shade400, Colors.green.shade800]),
                      boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.4), blurRadius: 12)]
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 30),
                )
              ],
            ),
            const SizedBox(height: 25),

            // Progress Bar
            Stack(
              children: [
                Container(height: 6, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10))),
                FractionallySizedBox(
                  widthFactor: percentage > 1 ? 1 : percentage,
                  child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.purpleAccent]),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.5), blurRadius: 6)]
                      )
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Collected", style: TextStyle(color: Colors.blueAccent.shade100, fontSize: 12)),
                Text(remaining > 0 ? "Pending: ₹${remaining.toStringAsFixed(0)}" : "Fully Paid",
                    style: TextStyle(color: remaining > 0 ? Colors.orangeAccent : Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // --- LIST TILE ---
  Widget _buildTransactionTile(Payment p) {
    final isCash = (p.paymentMethod ?? '').toUpperCase().contains('CASH');
    final color = isCash ? Colors.greenAccent : Colors.cyanAccent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: _glassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        radius: 16,
        child: Row(
          children: [
            // Icon Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(
                isCash ? Icons.attach_money : Icons.account_balance_wallet,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.paymentMethod ?? 'Unknown Method',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${dateFormat.format(p.paidOn!)}  •  ${timeFormat.format(p.paidOn!)}",
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                  if (p.reference != null && p.reference!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        "Ref: ${p.reference}",
                        style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontFamily: 'monospace'),
                      ),
                    ),
                ],
              ),
            ),

            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "+ ${money.format(p.amount)}",
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16, shadows: [Shadow(color: color.withOpacity(0.5), blurRadius: 10)]),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Important for background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text("Transaction History", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
            icon:  Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black26),
              child: Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
            ),
            onPressed: () => Navigator.pop(context)
        ),
      ),
      body: Stack(
        children: [
          // 1. BACKGROUND (Deep Dark Gradient)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F2027), // Deep Dark Blue/Black
                  Color(0xFF203A43), // Slate
                  Color(0xFF2C5364), // Teal-ish dark
                ],
              ),
            ),
          ),

          // 2. BACKGROUND ORBS (Glow effects)
          Positioned(
            top: -50, right: -50,
            child: Container(
              height: 200, width: 200,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purple.withOpacity(0.3), boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 100, spreadRadius: 50)]),
            ),
          ),
          Positioned(
            bottom: 100, left: -50,
            child: Container(
              height: 200, width: 200,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.withOpacity(0.2), boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 100, spreadRadius: 50)]),
            ),
          ),

          // 3. CONTENT
          _loading
              ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
              : _payments.isEmpty
              ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hourglass_empty, size: 60, color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 10),
                Text("No payments found", style: TextStyle(color: Colors.white.withOpacity(0.5))),
              ],
            ),
          )
              : ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              _buildGlassCard(),
              Padding(
                padding: const EdgeInsets.only(left: 24, bottom: 10, top: 10),
                child: Text("RECENT TRANSACTIONS", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ),
              ..._payments.map((p) => _buildTransactionTile(p)),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRecord,
        backgroundColor: Colors.transparent, // Glass button
        elevation: 0,
        label: _glassContainer(
          radius: 30,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: const [
              Icon(Icons.add, color: Colors.white),
              SizedBox(width: 8),
              Text("Record Payment", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}