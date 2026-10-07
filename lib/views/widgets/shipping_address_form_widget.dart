import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/shipping_address_storage.dart';
import '../../theme/app_theme.dart';

class ShippingAddressControllers {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController countryController;
  final TextEditingController addressController;
  final TextEditingController cityController;
  final TextEditingController stateController;
  final TextEditingController postalCodeController;
  final TextEditingController notesController;

  ShippingAddressControllers({
    TextEditingController? nameController,
    TextEditingController? phoneController,
    TextEditingController? countryController,
    TextEditingController? addressController,
    TextEditingController? cityController,
    TextEditingController? stateController,
    TextEditingController? postalCodeController,
    TextEditingController? notesController,
  })  : nameController = nameController ?? TextEditingController(),
        phoneController = phoneController ?? TextEditingController(),
        countryController = countryController ?? TextEditingController(text: 'México'),
        addressController = addressController ?? TextEditingController(),
        cityController = cityController ?? TextEditingController(),
        stateController = stateController ?? TextEditingController(),
        postalCodeController = postalCodeController ?? TextEditingController(),
        notesController = notesController ?? TextEditingController();

  Future<void> populateFromSaved() async {
    final saved = await ShippingAddressStorage.loadSavedAddress();
    if (saved.recipientName.isNotEmpty && nameController.text.isEmpty) {
      nameController.text = saved.recipientName;
    }
    if (saved.phoneNumber.isNotEmpty && phoneController.text.isEmpty) {
      phoneController.text = saved.phoneNumber;
    }
    if (saved.country.isNotEmpty) {
      countryController.text = saved.country;
    }
    if (saved.address.isNotEmpty && addressController.text.isEmpty) {
      addressController.text = saved.address;
    }
    if (saved.city.isNotEmpty && cityController.text.isEmpty) {
      cityController.text = saved.city;
    }
    if (saved.stateProvince.isNotEmpty && stateController.text.isEmpty) {
      stateController.text = saved.stateProvince;
    }
    if (saved.postalCode.isNotEmpty && postalCodeController.text.isEmpty) {
      postalCodeController.text = saved.postalCode;
    }
    if (saved.deliveryNotes.isNotEmpty && notesController.text.isEmpty) {
      notesController.text = saved.deliveryNotes;
    }
  }

  Future<void> saveToStorage() async {
    await ShippingAddressStorage.saveAddress(
      recipientName: nameController.text,
      phoneNumber: phoneController.text,
      country: countryController.text,
      address: addressController.text,
      city: cityController.text,
      stateProvince: stateController.text,
      postalCode: postalCodeController.text,
      deliveryNotes: notesController.text,
    );
  }

  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    countryController.dispose();
    addressController.dispose();
    cityController.dispose();
    stateController.dispose();
    postalCodeController.dispose();
    notesController.dispose();
  }
}

class ShippingAddressFormWidget extends StatefulWidget {
  final ShippingAddressControllers controllers;
  final bool isCompact;

  const ShippingAddressFormWidget({
    super.key,
    required this.controllers,
    this.isCompact = false,
  });

  @override
  State<ShippingAddressFormWidget> createState() => _ShippingAddressFormWidgetState();
}

class _ShippingAddressFormWidgetState extends State<ShippingAddressFormWidget> {
  @override
  void initState() {
    super.initState();
    widget.controllers.populateFromSaved().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controllers;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderWarm),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_shipping_rounded, color: AppTheme.accentOrange, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📦 Datos para Envío del Paquete',
                      style: GoogleFonts.fredoka(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.primaryTerracotta,
                      ),
                    ),
                    Text(
                      'Requerido para enviar tus bandanas a tu domicilio',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: AppTheme.textMutedWarm,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Nombre Completo
          _buildTextField(
            controller: c.nameController,
            label: 'Nombre de quien recibe *',
            hint: 'Ej. Ana García / Carlos Pérez',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 10),

          // Teléfono y País en fila
          Row(
            children: [
              Expanded(
                flex: 6,
                child: _buildTextField(
                  controller: c.phoneController,
                  label: 'Teléfono de contacto *',
                  hint: '+52 55 1234 5678',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: _buildTextField(
                  controller: c.countryController,
                  label: 'País *',
                  hint: 'México, España, etc.',
                  icon: Icons.public_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Dirección (Calle, Número, Apto / Colonia)
          _buildTextField(
            controller: c.addressController,
            label: 'Dirección completa (Calle, # ext/int, colonia) *',
            hint: 'Ej. Av. Reforma 123, Depto 4B, Col. Juárez',
            icon: Icons.home_outlined,
            maxLines: 2,
          ),
          const SizedBox(height: 10),

          // Ciudad, Estado y Código Postal
          Row(
            children: [
              Expanded(
                flex: 4,
                child: _buildTextField(
                  controller: c.cityController,
                  label: 'Ciudad *',
                  hint: 'Ej. CDMX / Guadalajara',
                  icon: Icons.location_city_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _buildTextField(
                  controller: c.stateController,
                  label: 'Estado/Prov.',
                  hint: 'Ej. Jalisco',
                  icon: Icons.map_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _buildTextField(
                  controller: c.postalCodeController,
                  label: 'C. Postal *',
                  hint: '03100',
                  icon: Icons.markunread_mailbox_outlined,
                  keyboardType: TextInputType.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Notas de Entrega (Opcional)
          _buildTextField(
            controller: c.notesController,
            label: 'Indicaciones de entrega (Opcional)',
            hint: 'Ej. Timbre 4B, dejar en portería o caseta de vigilancia',
            icon: Icons.note_alt_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.fredoka(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryDark,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textPrimaryDark),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMutedWarm.withOpacity(0.7)),
            prefixIcon: Icon(icon, size: 18, color: AppTheme.accentOrange),
            prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: AppTheme.bgWarmCream.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.borderWarm),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.borderWarm),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryTerracotta, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
