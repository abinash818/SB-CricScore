import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/location_service.dart';
import '../../core/theme.dart';

class LocationPickerDialog extends StatefulWidget {
  const LocationPickerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F0F1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const LocationPickerDialog(),
    );
  }

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  final LocationService _locService = LocationService();
  final TextEditingController _searchCtrl = TextEditingController();
  List<String> _filteredDistricts = [];
  String _selectedState = 'Tamil Nadu';

  final List<String> _popularChips = [
    'Coimbatore',
    'Chennai',
    'Madurai',
    'Salem',
    'Tiruppur',
    'Erode',
    'Tiruchirappalli (Trichy)',
  ];

  @override
  void initState() {
    super.initState();
    _selectedState = _locService.currentState.value;
    _filteredDistricts = List.from(LocationService.tamilNaduDistricts);
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredDistricts = List.from(LocationService.tamilNaduDistricts);
      } else {
        _filteredDistricts = LocationService.tamilNaduDistricts
            .where((d) => d.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _selectDistrict(String district) {
    _locService.setLocation(district: district, state: _selectedState);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📍 Location set to $district, $_selectedState'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentDist = _locService.currentDistrict.value;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: AppTheme.primaryGold, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Select Your District',
                        style: GoogleFonts.outfit(
                          color: AppTheme.primaryGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 19,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Text(
                'Filter live matches & tournaments happening in your city',
                style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),

              // Search Bar
              TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search district (e.g. Coimbatore, Salem)...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGold),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF131326),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.primaryGold),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Quick Popular Chips
              if (_searchCtrl.text.isEmpty) ...[
                Text(
                  'Popular Cricket Hubs in Tamil Nadu:',
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _popularChips.map((dist) {
                      final isSelected = (dist == currentDist);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ActionChip(
                          backgroundColor: isSelected
                              ? AppTheme.primaryGold
                              : const Color(0xFF1A1A32),
                          side: BorderSide(
                            color: isSelected
                                ? AppTheme.primaryGold
                                : AppTheme.cardBorder,
                          ),
                          label: Text(
                            dist,
                            style: TextStyle(
                              color: isSelected ? const Color(0xFF070710) : Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                          onPressed: () => _selectDistrict(dist),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(color: Colors.white12),
              ],

              // All 38 Districts List
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Text(
                  'All Tamil Nadu Districts (${_filteredDistricts.length}):',
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),

              Expanded(
                child: _filteredDistricts.isEmpty
                    ? Center(
                        child: Text(
                          'No district found matching "${_searchCtrl.text}"',
                          style: const TextStyle(color: Colors.white38),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: _filteredDistricts.length,
                        separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                        itemBuilder: (ctx, idx) {
                          final dist = _filteredDistricts[idx];
                          final isSelected = (dist == currentDist);

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            leading: Icon(
                              Icons.location_city,
                              color: isSelected ? AppTheme.primaryGold : Colors.white38,
                              size: 20,
                            ),
                            title: Text(
                              dist,
                              style: TextStyle(
                                color: isSelected ? AppTheme.primaryGold : Colors.white,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 15,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: AppTheme.primaryGold, size: 20)
                                : const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
                            onTap: () => _selectDistrict(dist),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
