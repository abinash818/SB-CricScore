import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  static const _storage = FlutterSecureStorage();
  static const String _keyDistrict = 'selected_district';
  static const String _keyState = 'selected_state';

  final ValueNotifier<String> currentDistrict = ValueNotifier<String>('Coimbatore');
  final ValueNotifier<String> currentState = ValueNotifier<String>('Tamil Nadu');

  // Master Tamil Nadu Districts List
  static const List<String> tamilNaduDistricts = [
    'Coimbatore',
    'Chennai',
    'Madurai',
    'Salem',
    'Tiruppur',
    'Erode',
    'Tiruchirappalli (Trichy)',
    'Tirunelveli',
    'Vellore',
    'Thanjavur',
    'Dindigul',
    'Kanyakumari (Nagercoil)',
    'Namakkal',
    'Nilgiris (Ooty)',
    'Karur',
    'Dharmapuri',
    'Krishnagiri',
    'Cuddalore',
    'Villupuram',
    'Kanchipuram',
    'Chengalpattu',
    'Thiruvallur',
    'Ranipet',
    'Tirupathur',
    'Tiruvannamalai',
    'Kallakurichi',
    'Nagapattinam',
    'Mayiladuthurai',
    'Tiruvarur',
    'Pudukkottai',
    'Sivagangai',
    'Ramanathapuram',
    'Virudhunagar',
    'Theni',
    'Tenkasi',
    'Thoothukudi (Tuticorin)',
    'Ariyalur',
    'Perambalur'
  ];

  static const List<String> popularStates = [
    'Tamil Nadu',
    'Kerala',
    'Karnataka',
    'Andhra Pradesh',
    'Telangana',
    'Puducherry',
    'Maharashtra',
    'Delhi NCR'
  ];

  Future<void> init() async {
    try {
      final savedDist = await _storage.read(key: _keyDistrict);
      if (savedDist != null && savedDist.isNotEmpty) {
        currentDistrict.value = savedDist;
      }
      final savedState = await _storage.read(key: _keyState);
      if (savedState != null && savedState.isNotEmpty) {
        currentState.value = savedState;
      }
    } catch (_) {}
  }

  Future<void> setLocation({required String district, String state = 'Tamil Nadu'}) async {
    currentDistrict.value = district;
    currentState.value = state;
    try {
      await _storage.write(key: _keyDistrict, value: district);
      await _storage.write(key: _keyState, value: state);
    } catch (_) {}
  }
}
