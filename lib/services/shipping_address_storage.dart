import 'package:shared_preferences/shared_preferences.dart';

class ShippingAddressData {
  final String recipientName;
  final String phoneNumber;
  final String country;
  final String address;
  final String city;
  final String stateProvince;
  final String postalCode;
  final String deliveryNotes;

  ShippingAddressData({
    this.recipientName = '',
    this.phoneNumber = '',
    this.country = '',
    this.address = '',
    this.city = '',
    this.stateProvince = '',
    this.postalCode = '',
    this.deliveryNotes = '',
  });

  bool get isComplete =>
      recipientName.trim().isNotEmpty &&
      phoneNumber.trim().isNotEmpty &&
      country.trim().isNotEmpty &&
      address.trim().isNotEmpty &&
      postalCode.trim().isNotEmpty;
}

class ShippingAddressStorage {
  static const String _keyRecipient = 'shipping_recipient_name';
  static const String _keyPhone = 'shipping_phone_number';
  static const String _keyCountry = 'shipping_country';
  static const String _keyAddress = 'shipping_address';
  static const String _keyCity = 'shipping_city';
  static const String _keyState = 'shipping_state_province';
  static const String _keyPostal = 'shipping_postal_code';
  static const String _keyNotes = 'shipping_delivery_notes';

  static Future<ShippingAddressData> loadSavedAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return ShippingAddressData(
        recipientName: prefs.getString(_keyRecipient) ?? '',
        phoneNumber: prefs.getString(_keyPhone) ?? '',
        country: prefs.getString(_keyCountry) ?? '',
        address: prefs.getString(_keyAddress) ?? '',
        city: prefs.getString(_keyCity) ?? '',
        stateProvince: prefs.getString(_keyState) ?? '',
        postalCode: prefs.getString(_keyPostal) ?? '',
        deliveryNotes: prefs.getString(_keyNotes) ?? '',
      );
    } catch (_) {
      return ShippingAddressData();
    }
  }

  static Future<void> saveAddress({
    required String recipientName,
    required String phoneNumber,
    required String country,
    required String address,
    required String city,
    required String stateProvince,
    required String postalCode,
    String? deliveryNotes,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRecipient, recipientName.trim());
      await prefs.setString(_keyPhone, phoneNumber.trim());
      await prefs.setString(_keyCountry, country.trim());
      await prefs.setString(_keyAddress, address.trim());
      await prefs.setString(_keyCity, city.trim());
      await prefs.setString(_keyState, stateProvince.trim());
      await prefs.setString(_keyPostal, postalCode.trim());
      if (deliveryNotes != null) {
        await prefs.setString(_keyNotes, deliveryNotes.trim());
      }
    } catch (_) {}
  }
}
