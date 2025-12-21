import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/group.dart';
import '../../services/api_service.dart';
import '../../services/data_manager.dart'; // To invalidate cache

class BulkExtendScreen extends StatefulWidget {
  const BulkExtendScreen({super.key});

  @override
  State<BulkExtendScreen> createState() => _BulkExtendScreenState();
}

class _BulkExtendScreenState extends State<BulkExtendScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  int _daysToAdd = 0;

  List<Group> _groups = [];
  Group? _selectedGroup; // Null means "All Groups"
  bool _isLoading = false;
  bool _isFetchingGroups = true;

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    try {
      final list = await ApiService.fetchGroups();
      if (mounted) {
        setState(() {
          _groups = list;
          _isFetchingGroups = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isFetchingGroups = false);
      print("Error fetching groups: $e");
    }
  }

  void _calculateDays() {
    if (_startDate != null && _endDate != null) {
      // +1 because both days are inclusive (e.g., 25 to 25 is 1 day)
      final diff = _endDate!.difference(_startDate!).inDays + 1;
      setState(() => _daysToAdd = diff > 0 ? diff : 0);
    }
  }
  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(), // किंवा DateTime(2024) जर जुन्या तारखा हव्या असतील
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          // ✅ FIX: पूर्ण Dark Theme Force करा
          data: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF0F2027), // पूर्ण स्क्रीनचा बॅकग्राऊंड Dark
            primaryColor: Colors.cyanAccent,

            colorScheme: const ColorScheme.dark(
              primary: Colors.cyanAccent,    // सिलेक्ट केलेली तारीख (Circle Color)
              onPrimary: Colors.black,       // सिलेक्ट केलेल्या तारखेचा नंबर (Black Text)
              surface: Color(0xFF203A43),    // वरचा हेडर आणि कार्ड्स
              onSurface: Colors.white,       // सामान्य तारखा आणि टेक्स्ट (White Text)
              secondary: Colors.purpleAccent, // रेंज हायलाईट कलर
            ),

            // वरचा ॲप बार (Save/Close बटन्स)
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF203A43),
              foregroundColor: Colors.white,
              elevation: 0,
            ),

            // "Save" बटण
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.cyanAccent, // बटण कलर
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _calculateDays();
    }
  }

  Future<void> _submitExtension() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a holiday range")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final msg = await ApiService.bulkExtendForHolidays(
        holidayStart: _startDate!,
        holidayEnd: _endDate!,
        groupId: _selectedGroup?.id,
      );

      // Clear Cache so updated dates reflect everywhere
      DataManager().clearAllCache();

      if (mounted) {
        // Success Dialog
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF203A43),
            title: const Text("Success", style: TextStyle(color: Colors.cyanAccent)),
            content: Text(msg, style: const TextStyle(color: Colors.white)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close Dialog
                  Navigator.pop(context); // Go Back
                },
                child: const Text("OK", style: TextStyle(color: Colors.cyanAccent)),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- GLASS WIDGETS ---
  Widget _glassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, spreadRadius: 2)],
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Extend Due Dates", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black26),
              child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white)
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // 1. BACKGROUND
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
              ),
            ),
          ),
          // 2. ORBS
          Positioned(top: -50, right: -50, child: Container(height: 250, width: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.cyan.withOpacity(0.15), boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.2), blurRadius: 100)]))),
          Positioned(bottom: 100, left: -50, child: Container(height: 250, width: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purple.withOpacity(0.15), boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.2), blurRadius: 100)]))),

          // 3. CONTENT
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "HOLIDAY MANAGEMENT",
                    style: TextStyle(color: Colors.cyanAccent, letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // --- DATE PICKER CARD ---
                  _glassContainer(
                    child: Column(
                      children: [
                        const Text("Select Holiday Period", style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _pickDateRange,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
                                  child: Column(
                                    children: [
                                      const Icon(Icons.calendar_today, color: Colors.cyanAccent, size: 20),
                                      const SizedBox(height: 8),
                                      Text(_startDate == null ? "Start Date" : df.format(_startDate!), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Icon(Icons.arrow_forward, color: Colors.white30),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: _pickDateRange,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
                                  child: Column(
                                    children: [
                                      const Icon(Icons.event_busy, color: Colors.purpleAccent, size: 20),
                                      const SizedBox(height: 8),
                                      Text(_endDate == null ? "End Date" : df.format(_endDate!), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- CALCULATED DAYS ---
                  if (_daysToAdd > 0)
                    _glassContainer(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Days to be Extended:", style: TextStyle(color: Colors.white70, fontSize: 16)),
                          Text(
                            "+ $_daysToAdd Days",
                            style: const TextStyle(color: Colors.cyanAccent, fontSize: 24, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 10)]),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // --- GROUP SELECTOR ---
                  _glassContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Target Audience", style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<Group>(
                          value: _selectedGroup,
                          dropdownColor: const Color(0xFF2C5364),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          hint: const Text("Select Group (Default: All)", style: TextStyle(color: Colors.white38)),
                          items: [
                            const DropdownMenuItem<Group>(
                              value: null,
                              child: Text("All Groups (Everyone)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                            ),
                            ..._groups.map((g) => DropdownMenuItem(value: g, child: Text(g.name))),
                          ],
                          onChanged: (val) => setState(() => _selectedGroup = val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // --- SUBMIT BUTTON ---
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                  else
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.purpleAccent]),
                        boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))],
                      ),
                      child: ElevatedButton(
                        onPressed: _daysToAdd > 0 ? _submitExtension : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: const Text(
                          "CONFIRM EXTENSION",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2),
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),
                  const Text(
                    "Note: This will move future due dates forward by the selected number of days. Overdue installments will not be affected.",
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}