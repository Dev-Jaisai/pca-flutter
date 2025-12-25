import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BillingHelper {
  static final df = DateFormat('dd MMM yyyy');
  static final chipDf = DateFormat('dd MMM');

  /// 🔥 CRITICAL FIX: Calculate Billing Cycle from Due Date
  ///
  /// Backend Storage Logic:
  /// - periodMonth = Due Date चा month (not cycle start month!)
  /// - Cycle = (billingDay of previous month) to (billingDay of due month)
  ///
  /// Example:
  /// - Due Date = 1 Dec 2025 (periodMonth=12)
  /// - Billing Day = 1
  /// - Actual Cycle = 1 Nov 2025 - 1 Dec 2025
  ///
  static String getFormattedPeriod({
    required DateTime dueDate,
    required int billingDay,
    int cycleMonths = 1,
  }) {
    // 🎯 KEY INSIGHT:
    // Due Date = End of billing cycle
    // Start Date = Due Date MINUS cycleMonths

    // Step 1: Due Date IS the cycle end date
    DateTime periodEnd = dueDate;

    // Step 2: Calculate cycle start (go back by cycleMonths)
    // Simple approach: Just subtract months and let DateTime handle it
    DateTime periodStart = DateTime(
        dueDate.year,
        dueDate.month - cycleMonths,
        billingDay
    );

    // 🔥 FIX: Only apply correction if billingDay > days in that month
    // Example: billingDay=31 but Feb only has 28 days
    int actualMonth = dueDate.month - cycleMonths;
    if (actualMonth <= 0) {
      actualMonth += 12; // Handle year boundary
    }

    // Get max days in the target month
    int maxDays = DateTime(periodStart.year, periodStart.month + 1, 0).day;

    // If billing day doesn't exist in that month, use last day
    if (billingDay > maxDays) {
      periodStart = DateTime(periodStart.year, periodStart.month + 1, 0);
    }

    return "${chipDf.format(periodStart)} - ${df.format(periodEnd)}";
  }

  static Color getStatusColor(String status, bool isOverdue) {
    status = status.toUpperCase();
    if (status == 'SKIPPED') return Colors.white; // 🔥 White for HOLIDAY
    if (status == 'CANCELLED') return Colors.grey;
    if (status == 'PAID') return Colors.greenAccent;
    if (isOverdue) return Colors.redAccent;
    return Colors.orangeAccent;
  }

  static String getStatusText(String status, bool isOverdue) {
    status = status.toUpperCase();
    if (status == 'SKIPPED') return "HOLIDAY";
    if (status == 'CANCELLED') return "LEFT";
    if (status == 'PAID') return "PAID";
    if (isOverdue) return "OVERDUE";
    return "PENDING";
  }

}