import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/payment.dart';
import '../../services/api_service.dart'; // Keep for specific actions if needed
import '../../services/data_manager.dart'; // ✅ Import DataManager
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
  final df = DateFormat('dd MMM yyyy • hh:mm a');
  final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---------------------------------------------------------
  // 🚀 OPTIMIZED LOAD LOGIC
  // ---------------------------------------------------------
  Future<void> _load() async {
    // 1. Try Cache First (Instant)
    final cached = await DataManager().getPayments(widget.installmentId);
    if (cached.isNotEmpty) {
      if (mounted) {
        setState(() {
          _payments = cached;
          _loading = false;
        });
      }
    } else {
      if (mounted) setState(() => _loading = true);
    }

    // 2. Fetch Fresh Data (Background)
    try {
      final freshList = await DataManager().getPayments(widget.installmentId, forceRefresh: true);
      if (mounted) {
        setState(() {
          _payments = freshList;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && _payments.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load: $e'),
            backgroundColor: Colors.red.shade400,
          ),
        );
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
      // Invalidate cache so we get the new payment
      DataManager().invalidatePayments(widget.installmentId);
      _load();
    }
  }

  void _copyToClipboard(String text, [String? successText]) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, size: 18, color: Colors.green.shade100),
            const SizedBox(width: 8),
            Text(successText ?? 'Copied to clipboard'),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 160,
              width: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurple.shade50,
                    Colors.deepPurple.shade100.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.deepPurple.shade100, width: 2),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 30,
                    left: 30,
                    child: Icon(
                      Icons.receipt_long,
                      size: 60,
                      color: Colors.deepPurple.shade400,
                    ),
                  ),
                  Positioned(
                    bottom: 40,
                    right: 40,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.shade200,
                            blurRadius: 15,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.add,
                        size: 24,
                        color: Colors.deepPurple.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Payments Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start tracking your payments by recording the first transaction',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(Payment p) {
    final method = (p.paymentMethod ?? 'Unknown').trim();
    final ref = p.reference ?? '';
    final paidOn = p.paidOn;
    final amount = p.amount;

    final dateText = paidOn != null ? df.format(paidOn.toLocal()) : '—';
    final amountText = money.format(amount ?? 0);

    // Get payment method icon
    IconData getMethodIcon() {
      final lowerMethod = method.toLowerCase();
      if (lowerMethod.contains('card')) return Icons.credit_card;
      if (lowerMethod.contains('cash')) return Icons.money;
      if (lowerMethod.contains('bank') || lowerMethod.contains('transfer')) return Icons.account_balance;
      if (lowerMethod.contains('upi')) return Icons.payment;
      if (lowerMethod.contains('wallet')) return Icons.wallet;
      return Icons.payment;
    }

    // Get gradient colors based on payment method
    List<Color> getGradientColors() {
      final lowerMethod = method.toLowerCase();
      if (lowerMethod.contains('card')) return [Colors.blue.shade600, Colors.blue.shade400];
      if (lowerMethod.contains('cash')) return [Colors.green.shade600, Colors.green.shade400];
      if (lowerMethod.contains('bank') || lowerMethod.contains('transfer')) return [Colors.purple.shade600, Colors.purple.shade400];
      if (lowerMethod.contains('upi')) return [Colors.teal.shade600, Colors.teal.shade400];
      return [Colors.deepPurple.shade600, Colors.deepPurple.shade400];
    }

    final gradientColors = getGradientColors();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Top row: Icon, method, and date
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon with gradient background
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        getMethodIcon(),
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Method and date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            method.toUpperCase(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateText,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Amount badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade600, Colors.green.shade400],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        amountText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Reference section (if exists)
                if (ref.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.tag,
                          size: 18,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reference ID',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ref,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _copyToClipboard(ref, 'Reference copied'),
                          icon: Icon(
                            Icons.content_copy,
                            size: 20,
                            color: Colors.grey.shade600,
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final summary = '${method.toUpperCase()} • $amountText • $dateText${ref.isNotEmpty ? ' • Ref: $ref' : ''}';
                          _copyToClipboard(summary, 'Payment summary copied');
                        },
                        icon: Icon(
                          Icons.copy_all,
                          size: 18,
                          color: Colors.grey.shade700,
                        ),
                        label: Text(
                          'Copy Details',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: IconButton(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(24),
                              ),
                            ),
                            builder: (ctx) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                                    height: 4,
                                    width: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.share, color: Colors.blue.shade600),
                                    title: Text(
                                      'Share Payment',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      // TODO: Implement share
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.download, color: Colors.green.shade600),
                                    title: Text(
                                      'Export Receipt',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      // TODO: Implement export
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.receipt_long, color: Colors.purple.shade600),
                                    title: Text(
                                      'View Full Details',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      // TODO: Show full details
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.more_vert,
                          color: Colors.grey.shade700,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final totalPaid = _payments.fold<double>(0, (sum, payment) => sum + (payment.amount ?? 0));

    return Container(
      // ✅ FIX: Added 100px top padding to accommodate Status Bar + AppBar
      padding: const EdgeInsets.only(top: 100, left: 24, right: 24, bottom: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.shade600,
            Colors.purple.shade600,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment History',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_payments.length} ${_payments.length == 1 ? 'transaction' : 'transactions'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.receipt_long,
                  size: 28,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Total paid card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Paid',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        money.format(totalPaid),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        // ✅ Explicit Back Button
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRecord,
        backgroundColor: Colors.deepPurple.shade600,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        icon: const Icon(Icons.add_circle, size: 24),
        label: const Text(
          'Record Payment',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(
          color: Colors.deepPurple,
          strokeWidth: 2.5,
        ),
      )
          : Column(
        children: [
          // Header section
          _buildHeader(),

          // List of payments
          Expanded(
            child: _payments.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _load,
              color: Colors.deepPurple,
              backgroundColor: Colors.white,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Text(
                    'Recent Payments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._payments.map((payment) => _buildPaymentCard(payment)),
                  const SizedBox(height: 80), // Space for FAB
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}