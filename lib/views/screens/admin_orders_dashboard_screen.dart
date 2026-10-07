import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/language_controller.dart';
import '../../controllers/marketplace_controller.dart';
import '../../models/marketplace_order_model.dart';
import '../../theme/app_theme.dart';

class AdminOrdersDashboardScreen extends StatefulWidget {
  const AdminOrdersDashboardScreen({super.key});

  @override
  State<AdminOrdersDashboardScreen> createState() => _AdminOrdersDashboardScreenState();
}

class _AdminOrdersDashboardScreenState extends State<AdminOrdersDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MarketplaceController>(context, listen: false).loadAdminOrders();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _isUserAuthorizedAdmin(AuthController auth) {
    final email = auth.currentProfile?.email?.toLowerCase().trim() ?? '';
    final configuredAdmin = AppConfig.adminEmail.toLowerCase().trim();
    return email == configuredAdmin ||
        email == 'wernesto66@gmail.com' ||
        email == 'wernesto66@gmail.con';
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final langController = Provider.of<LanguageController>(context);
    final marketplaceController = Provider.of<MarketplaceController>(context);

    // SECURITY CHECK: Only wernesto66@gmail.com / wernesto66@gmail.con
    if (!_isUserAuthorizedAdmin(authController)) {
      return _buildAccessDeniedScaffold(context, authController, langController);
    }

    final pendingOrders = marketplaceController.pendingOrders.where(_filterOrder).toList();
    final shippedOrders = marketplaceController.shippedOrders.where(_filterOrder).toList();

    return Scaffold(
      backgroundColor: AppTheme.bgWarmCream,
      appBar: AppBar(
        backgroundColor: AppTheme.bgWarmCream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.primaryTerracotta),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📦 Dashboard de Pedidos',
              style: GoogleFonts.fredoka(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTerracotta,
                fontSize: 20,
              ),
            ),
            Text(
              'Admin: ${AppConfig.adminEmail}',
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                color: AppTheme.textMutedWarm,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar pedidos',
            icon: marketplaceController.isLoadingOrders
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: AppTheme.primaryTerracotta, strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, color: AppTheme.primaryTerracotta),
            onPressed: () => marketplaceController.loadAdminOrders(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryTerracotta,
        onRefresh: () => marketplaceController.loadAdminOrders(),
        child: Column(
          children: [
            // Resumen de Métricas
            _buildMetricsHeader(
              pendingCount: marketplaceController.pendingOrders.length,
              shippedCount: marketplaceController.shippedOrders.length,
            ),

            // Buscador
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Buscar por cliente, bandana, país, guía...',
                  hintStyle: GoogleFonts.outfit(fontSize: 12.5, color: AppTheme.textMutedWarm),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryTerracotta, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.borderWarm),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.borderWarm),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.primaryTerracotta, width: 1.5),
                  ),
                ),
              ),
            ),

            // TabBar: Pendientes vs Enviados
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWarm,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderWarm),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: AppTheme.textPrimaryDark,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppTheme.primaryTerracotta,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.hourglass_top_rounded, size: 17),
                        const SizedBox(width: 6),
                        Text(
                          'Pendientes (${marketplaceController.pendingOrders.length})',
                          style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.local_shipping_rounded, size: 17),
                        const SizedBox(width: 6),
                        Text(
                          'Enviados (${marketplaceController.shippedOrders.length})',
                          style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Pendientes
                  _buildOrdersList(
                    orders: pendingOrders,
                    isShippedTab: false,
                    emptyMessage: 'No hay pedidos pendientes de envío 🎉',
                    onMarkShipped: (order) => _showMarkAsShippedDialog(context, order, marketplaceController),
                  ),

                  // Tab 2: Enviados
                  _buildOrdersList(
                    orders: shippedOrders,
                    isShippedTab: true,
                    emptyMessage: 'Aún no hay pedidos enviados registrados.',
                    onMarkShipped: (order) => _showMarkAsShippedDialog(context, order, marketplaceController, isEditing: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _filterOrder(MarketplaceOrderModel order) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery;
    return order.recipientName.toLowerCase().contains(q) ||
        order.productName.toLowerCase().contains(q) ||
        order.city.toLowerCase().contains(q) ||
        order.country.toLowerCase().contains(q) ||
        order.address.toLowerCase().contains(q) ||
        (order.trackingNumber?.toLowerCase().contains(q) ?? false) ||
        (order.userEmail?.toLowerCase().contains(q) ?? false);
  }

  Widget _buildMetricsHeader({required int pendingCount, required int shippedCount}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryTerracotta.withOpacity(0.9),
            AppTheme.accentOrange.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryTerracotta.withOpacity(0.18),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetricPill(
            icon: Icons.hourglass_top_rounded,
            title: 'Por Enviar',
            count: '$pendingCount',
            color: Colors.amberAccent,
          ),
          Container(width: 1, height: 38, color: Colors.white24),
          _buildMetricPill(
            icon: Icons.check_circle_rounded,
            title: 'Enviados',
            count: '$shippedCount',
            color: Colors.white,
          ),
          Container(width: 1, height: 38, color: Colors.white24),
          _buildMetricPill(
            icon: Icons.inventory_2_rounded,
            title: 'Total Pedidos',
            count: '${pendingCount + shippedCount}',
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill({
    required IconData icon,
    required String title,
    required String count,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              count,
              style: GoogleFonts.fredoka(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        Text(
          title,
          style: GoogleFonts.outfit(fontSize: 11, color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildOrdersList({
    required List<MarketplaceOrderModel> orders,
    required bool isShippedTab,
    required String emptyMessage,
    required Function(MarketplaceOrderModel) onMarkShipped,
  }) {
    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isShippedTab ? Icons.local_shipping_outlined : Icons.inventory_2_outlined,
                size: 56,
                color: AppTheme.textMutedWarm.withOpacity(0.6),
              ),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.fredoka(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMutedWarm,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (ctx, idx) {
        final order = orders[idx];
        return _buildOrderCard(context, order, isShippedTab, onMarkShipped);
      },
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    MarketplaceOrderModel order,
    bool isShippedTab,
    Function(MarketplaceOrderModel) onMarkShipped,
  ) {
    final dateFormat = DateFormat('dd/MM/yyyy • HH:mm');
    final formattedDate = dateFormat.format(order.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isShippedTab ? AppTheme.emeraldGreen.withOpacity(0.3) : AppTheme.borderWarm,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: ID del pedido y Fecha de compra
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: isShippedTab
                      ? AppTheme.emeraldGreen.withOpacity(0.12)
                      : AppTheme.accentOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '#${order.id.length > 14 ? order.id.substring(order.id.length - 10) : order.id}',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isShippedTab ? AppTheme.emeraldGreen : AppTheme.primaryTerracotta,
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 13, color: AppTheme.textMutedWarm),
                  const SizedBox(width: 4),
                  Text(
                    formattedDate,
                    style: GoogleFonts.outfit(fontSize: 11.5, color: AppTheme.textMutedWarm),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Producto comprado
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  order.productImage,
                  width: 58,
                  height: 58,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 58,
                    height: 58,
                    color: AppTheme.surfaceWarm,
                    child: const Icon(Icons.pets, color: AppTheme.primaryTerracotta),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.productName,
                      style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimaryDark),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.bgWarmCream,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderWarm),
                          ),
                          child: Text(
                            'Cant: ${order.quantity}',
                            style: GoogleFonts.fredoka(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryDark),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: order.paymentMethod == 'POINTS'
                                ? AppTheme.accentOrange.withOpacity(0.15)
                                : AppTheme.solanaPurple.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            order.totalPaidFormatted.isNotEmpty
                                ? order.totalPaidFormatted
                                : '\$${order.totalPriceUsd.toStringAsFixed(2)} (${order.paymentMethod})',
                            style: GoogleFonts.fredoka(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: order.paymentMethod == 'POINTS' ? AppTheme.accentOrange : AppTheme.solanaPurple,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // SECCIÓN DESTACADA: DATOS DE ENVÍO
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.bgWarmCream.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderWarm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.pin_drop_rounded, size: 16, color: AppTheme.primaryTerracotta),
                    const SizedBox(width: 6),
                    Text(
                      'Dirección de Entrega',
                      style: GoogleFonts.fredoka(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.primaryTerracotta,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildInfoRow('👤 Receptor:', order.recipientName, isBold: true),
                _buildInfoRow(
                  '📞 Teléfono:',
                  order.phoneNumber,
                  trailingAction: () {
                    Clipboard.setData(ClipboardData(text: order.phoneNumber));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Teléfono copiado: ${order.phoneNumber}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                _buildInfoRow('🏠 Dirección:', order.address),
                _buildInfoRow(
                  '🏙️ Ubicación:',
                  '${order.city}${order.stateProvince.isNotEmpty ? ", ${order.stateProvince}" : ""} • C.P. ${order.postalCode}',
                ),
                _buildInfoRow('🌎 País:', order.country),
                if (order.deliveryNotes != null && order.deliveryNotes!.isNotEmpty)
                  _buildInfoRow('📝 Notas:', order.deliveryNotes!),
                if (order.userEmail != null && order.userEmail!.isNotEmpty)
                  _buildInfoRow('✉️ Email comprador:', order.userEmail!),
                if (order.transactionSignature != null && order.transactionSignature!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '🔗 Solana Tx: ',
                        style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMutedWarm, fontWeight: FontWeight.w600),
                      ),
                      Expanded(
                        child: Text(
                          order.transactionSignature!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.solanaPurple),
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.solanaPurple),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: order.transactionSignature!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Firma de Solana copiada al portapapeles')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // SI ES ENVIADO: FECHA DE ENVÍO Y GUÍA
          if (isShippedTab && order.shippedAt != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.emeraldGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.emeraldGreen.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.mark_email_read_rounded, color: AppTheme.emeraldGreen, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '📅 Fecha de Envío: ${DateFormat("dd/MM/yyyy • HH:mm").format(order.shippedAt!)}',
                          style: GoogleFonts.fredoka(
                            color: AppTheme.emeraldGreen,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (order.trackingNumber != null && order.trackingNumber!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '📦 Guía: ${order.trackingNumber}${order.shippingCarrier != null ? " (${order.shippingCarrier})" : ""}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.textPrimaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // BOTONES DE ACCIÓN
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isShippedTab)
                TextButton.icon(
                  onPressed: () => onMarkShipped(order),
                  icon: const Icon(Icons.edit_calendar_rounded, size: 16, color: AppTheme.primaryTerracotta),
                  label: Text(
                    'Editar Fecha / Guía',
                    style: GoogleFonts.fredoka(color: AppTheme.primaryTerracotta, fontSize: 12.5),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emeraldGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 1,
                    ),
                    icon: const Icon(Icons.local_shipping_rounded, size: 18),
                    label: Text(
                      '🚚 Marcar como Enviado (Anexar Fecha)',
                      style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    onPressed: () => onMarkShipped(order),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, VoidCallback? trailingAction}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMutedWarm,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: AppTheme.textPrimaryDark,
              ),
            ),
          ),
          if (trailingAction != null)
            InkWell(
              onTap: trailingAction,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.copy_rounded, size: 14, color: AppTheme.accentOrange),
              ),
            ),
        ],
      ),
    );
  }

  void _showMarkAsShippedDialog(
    BuildContext context,
    MarketplaceOrderModel order,
    MarketplaceController marketplaceController, {
    bool isEditing = false,
  }) {
    DateTime selectedDate = order.shippedAt ?? DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);
    final trackingCtrl = TextEditingController(text: order.trackingNumber ?? '');
    final carrierCtrl = TextEditingController(text: order.shippingCarrier ?? 'DHL');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final formattedDate =
                '${DateFormat("dd/MM/yyyy").format(selectedDate)} a las ${selectedTime.format(context)}';

            return Container(
              decoration: const BoxDecoration(
                color: AppTheme.bgWarmCream,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                top: 24,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppTheme.borderWarm,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.emeraldGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.local_shipping_rounded, color: AppTheme.emeraldGreen, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing ? '✏️ Actualizar Fecha de Envío' : '🚚 Registrar Envío de Pedido',
                                style: GoogleFonts.fredoka(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryTerracotta,
                                ),
                              ),
                              Text(
                                'Para: ${order.recipientName} (${order.productName})',
                                style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMutedWarm),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // SELECTOR DE FECHA Y HORA DE ENVÍO (MANDATORY REQUIREMENT)
                    Text(
                      '📅 Fecha y Hora de Envío *',
                      style: GoogleFonts.fredoka(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.textPrimaryDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                          builder: (ctx, child) {
                            return Theme(
                              data: Theme.of(ctx).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppTheme.primaryTerracotta,
                                  onPrimary: Colors.white,
                                  onSurface: AppTheme.textPrimaryDark,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );

                        if (pickedDate != null) {
                          if (context.mounted) {
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            setSheetState(() {
                              selectedDate = pickedDate;
                              if (pickedTime != null) {
                                selectedTime = pickedTime;
                              }
                            });
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.emeraldGreen, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, color: AppTheme.emeraldGreen, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                formattedDate,
                                style: GoogleFonts.fredoka(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.emeraldGreen,
                                ),
                              ),
                            ),
                            Text(
                              'Cambiar',
                              style: GoogleFonts.fredoka(
                                fontSize: 12,
                                color: AppTheme.primaryTerracotta,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Empresa de Paquetería / Courier
                    Text(
                      'Paquetería / Courier (Opcional)',
                      style: GoogleFonts.fredoka(fontSize: 13, color: AppTheme.textPrimaryDark),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: carrierCtrl,
                      decoration: InputDecoration(
                        hintText: 'Ej. DHL, FedEx, Estafeta, Correos, UPS',
                        hintStyle: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMutedWarm),
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primaryTerracotta)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Número de Guía / Tracking
                    Text(
                      'Número de Guía / Rastreo (Opcional)',
                      style: GoogleFonts.fredoka(fontSize: 13, color: AppTheme.textPrimaryDark),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: trackingCtrl,
                      decoration: InputDecoration(
                        hintText: 'Ej. 74839201829',
                        hintStyle: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMutedWarm),
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primaryTerracotta)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Botón Guardar
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.emeraldGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle_outline_rounded),
                        label: Text(
                          isSaving ? 'Guardando...' : 'Confirmar y Guardar Fecha de Envío',
                          style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                setSheetState(() => isSaving = true);
                                final finalDateTime = DateTime(
                                  selectedDate.year,
                                  selectedDate.month,
                                  selectedDate.day,
                                  selectedTime.hour,
                                  selectedTime.minute,
                                );

                                final ok = await marketplaceController.markOrderAsShipped(
                                  orderId: order.id,
                                  shippedAt: finalDateTime,
                                  trackingNumber: trackingCtrl.text.trim().isNotEmpty ? trackingCtrl.text.trim() : null,
                                  shippingCarrier: carrierCtrl.text.trim().isNotEmpty ? carrierCtrl.text.trim() : null,
                                );

                                if (context.mounted) {
                                  Navigator.pop(sheetCtx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppTheme.emeraldGreen,
                                      content: Text(
                                        '✅ ¡Pedido marcado como enviado con fecha $formattedDate!',
                                        style: GoogleFonts.fredoka(),
                                      ),
                                    ),
                                  );
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAccessDeniedScaffold(
    BuildContext context,
    AuthController authController,
    LanguageController langController,
  ) {
    return Scaffold(
      backgroundColor: AppTheme.bgWarmCream,
      appBar: AppBar(
        backgroundColor: AppTheme.bgWarmCream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.primaryTerracotta),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded, size: 54, color: Colors.redAccent),
              ),
              const SizedBox(height: 18),
              Text(
                'Acceso Restringido al Admin',
                style: GoogleFonts.fredoka(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryTerracotta),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Este dashboard de envíos está reservado exclusivamente para la cuenta administradora:\n${AppConfig.adminEmail}',
                style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textMutedWarm, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTerracotta,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text('Regresar', style: GoogleFonts.fredoka(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
