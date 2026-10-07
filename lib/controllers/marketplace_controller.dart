import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/bandana_product_model.dart';
import '../models/marketplace_order_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class MarketplaceController extends ChangeNotifier {
  final SupabaseService _supabaseService;
  final List<BandanaProductModel> _products = [];
  bool _isLoading = false;

  final List<MarketplaceOrderModel> _pendingOrders = [];
  final List<MarketplaceOrderModel> _shippedOrders = [];
  bool _isLoadingOrders = false;

  List<BandanaProductModel> get products => List.unmodifiable(_products);
  bool get isLoading => _isLoading;
  List<MarketplaceOrderModel> get pendingOrders => List.unmodifiable(_pendingOrders);
  List<MarketplaceOrderModel> get shippedOrders => List.unmodifiable(_shippedOrders);
  bool get isLoadingOrders => _isLoadingOrders;

  MarketplaceController({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService() {
    _loadProducts();
    loadAdminOrders();
  }

  Future<void> _loadProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final supaProducts = await _supabaseService.fetchMarketplaceProducts();
      if (supaProducts.isNotEmpty) {
        _products.clear();
        for (final p in supaProducts) {
          final safeStock = p.stock <= 0 ? 25 : p.stock;
          // If product in DB has legacy low points (< 1000), upgrade to new point tier
          if (p.pricePoints < 1000 || p.stock <= 0) {
            final upgradedPoints = p.pricePoints < 1000
                ? (p.id == 'bdn_neon'
                    ? 10000
                    : p.id == 'bdn_ocean'
                        ? 12000
                        : p.id == 'bdn_solana'
                            ? 15000
                            : p.id == 'bdn_golden'
                                ? 25000
                                : (p.pricePoints * 50))
                : p.pricePoints;
            final upgraded = p.copyWith(pricePoints: upgradedPoints, stock: safeStock);
            _products.add(upgraded);
            _supabaseService.saveMarketplaceProduct(upgraded);
          } else {
            _products.add(p);
          }
        }
      } else {
        _initDefaultProducts();
        // Save initial default products to Supabase in background
        for (final p in _products) {
          _supabaseService.saveMarketplaceProduct(p);
        }
      }
    } catch (_) {
      if (_products.isEmpty) {
        _initDefaultProducts();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _initDefaultProducts() {
    _products.clear();
    _products.addAll([
      BandanaProductModel(
        id: 'bdn_neon',
        name: 'Neon Paw Glow Bandana 🌟',
        pricePoints: 10000,
        priceUsd: 9.99,
        imageUrl: 'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?w=600',
        tag: 'Limited Edition',
        colorValue: AppTheme.accentOrange.value,
        stock: 25,
        description: 'Colores vibrantes fluorescentes con visibilidad nocturna reflectante.',
      ),
      BandanaProductModel(
        id: 'bdn_ocean',
        name: 'Ocean Beach Walker 🌊',
        pricePoints: 12000,
        priceUsd: 10.99,
        imageUrl: 'https://images.unsplash.com/photo-1537151608828-ea2b11777ee8?w=600',
        tag: 'Summer Collection',
        colorValue: AppTheme.emeraldGreen.value,
        stock: 25,
        description: 'Bandana transpirable resistente al agua ideal para días de playa.',
      ),
      BandanaProductModel(
        id: 'bdn_solana',
        name: 'Solana Cyber Bandana ⚡',
        pricePoints: 15000,
        priceUsd: 12.99,
        imageUrl: 'https://images.unsplash.com/photo-1601758228041-f3b2795255f1?w=600',
        tag: 'Solana Exclusive',
        colorValue: AppTheme.solanaPurple.value,
        stock: 25,
        description: 'Bandana cyberpunk de edición limitada inspirada en el ecosistema Solana.',
      ),
      BandanaProductModel(
        id: 'bdn_golden',
        name: 'Pawtbook Gold Edition 👑',
        pricePoints: 25000,
        priceUsd: 24.99,
        imageUrl: 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=600',
        tag: 'Best Seller',
        colorValue: AppTheme.primaryTerracotta.value,
        stock: 25,
        description: 'Bandana premium de alta costura para mascotas con detalles dorados.',
      ),
    ]);
  }

  BandanaProductModel? getProductById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  bool canPurchase(String productId, int quantity) {
    final product = getProductById(productId);
    if (product == null) return false;
    return product.stock >= quantity && quantity > 0;
  }

  bool purchaseProduct(String productId, int quantity) {
    final idx = _products.indexWhere((p) => p.id == productId);
    if (idx == -1) return false;

    final product = _products[idx];
    if (product.stock < quantity || quantity <= 0) return false;

    final newStock = product.stock - quantity;
    _products[idx] = product.copyWith(stock: newStock);
    notifyListeners();

    // Async sync with Supabase
    _supabaseService.updateMarketplaceProductStock(productId, newStock);
    return true;
  }

  void addProduct(BandanaProductModel newProduct) {
    _products.insert(0, newProduct);
    notifyListeners();

    // Persist to Supabase
    _supabaseService.saveMarketplaceProduct(newProduct);
  }

  void updateProduct(BandanaProductModel updatedProduct) {
    final idx = _products.indexWhere((p) => p.id == updatedProduct.id);
    if (idx != -1) {
      _products[idx] = updatedProduct;
      notifyListeners();
      _supabaseService.saveMarketplaceProduct(updatedProduct);
    }
  }

  void updateStock(String productId, int newStock) {
    final idx = _products.indexWhere((p) => p.id == productId);
    if (idx != -1) {
      final safeStock = newStock < 0 ? 0 : newStock;
      _products[idx] = _products[idx].copyWith(stock: safeStock);
      notifyListeners();
      _supabaseService.updateMarketplaceProductStock(productId, safeStock);
    }
  }

  void restockProduct(String productId, int amount) {
    final idx = _products.indexWhere((p) => p.id == productId);
    if (idx != -1) {
      final current = _products[idx].stock;
      final newStock = current + amount;
      _products[idx] = _products[idx].copyWith(stock: newStock);
      notifyListeners();
      _supabaseService.updateMarketplaceProductStock(productId, newStock);
    }
  }

  void deleteProduct(String productId) {
    _products.removeWhere((p) => p.id == productId);
    notifyListeners();
    _supabaseService.deleteMarketplaceProduct(productId);
  }

  void resetToDefaults() {
    _products.clear();
    _initDefaultProducts();
    notifyListeners();
  }

  // ==========================================
  // ORDERS MANAGEMENT (ADMIN & CHECKOUT)
  // ==========================================

  Future<void> loadAdminOrders() async {
    _isLoadingOrders = true;
    notifyListeners();

    try {
      final allOrders = await _supabaseService.fetchMarketplaceOrders();
      _pendingOrders.clear();
      _shippedOrders.clear();

      for (final order in allOrders) {
        if (order.isShipped) {
          _shippedOrders.add(order);
        } else {
          _pendingOrders.add(order);
        }
      }
    } catch (e) {
      debugPrint('[MarketplaceController] Error loading admin orders: $e');
    } finally {
      _isLoadingOrders = false;
      notifyListeners();
    }
  }

  Future<MarketplaceOrderModel?> placeBandanaOrder({
    required BandanaProductModel product,
    required int quantity,
    required String paymentMethod,
    required String totalPaidFormatted,
    required double totalPriceUsd,
    String? transactionSignature,
    required String recipientName,
    required String phoneNumber,
    required String country,
    required String address,
    required String city,
    required String stateProvince,
    required String postalCode,
    String? deliveryNotes,
    required String userId,
    String? userEmail,
  }) async {
    // 1. Reduce stock
    final purchased = purchaseProduct(product.id, quantity);
    if (!purchased) {
      debugPrint('[MarketplaceController] Warning: Could not deduct stock, continuing order creation');
    }

    // 2. Create Order
    final orderId = 'ord_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 6)}';
    final now = DateTime.now();
    final newOrder = MarketplaceOrderModel(
      id: orderId,
      userId: userId,
      userEmail: userEmail,
      productId: product.id,
      productName: product.name,
      productImage: product.imageUrl,
      quantity: quantity,
      paymentMethod: paymentMethod,
      totalPriceUsd: totalPriceUsd,
      totalPaidFormatted: totalPaidFormatted,
      transactionSignature: transactionSignature,
      recipientName: recipientName.trim(),
      phoneNumber: phoneNumber.trim(),
      country: country.trim(),
      address: address.trim(),
      city: city.trim(),
      stateProvince: stateProvince.trim(),
      postalCode: postalCode.trim(),
      deliveryNotes: deliveryNotes?.trim(),
      status: 'pending',
      createdAt: now,
      updatedAt: now,
    );

    // 3. Persist to Supabase
    await _supabaseService.createMarketplaceOrder(newOrder);

    // 4. Update local list
    _pendingOrders.insert(0, newOrder);
    notifyListeners();

    return newOrder;
  }

  Future<bool> markOrderAsShipped({
    required String orderId,
    required DateTime shippedAt,
    String? trackingNumber,
    String? shippingCarrier,
  }) async {
    final success = await _supabaseService.updateMarketplaceOrderShipping(
      orderId: orderId,
      status: 'shipped',
      shippedAt: shippedAt,
      trackingNumber: trackingNumber?.trim(),
      shippingCarrier: shippingCarrier?.trim(),
    );

    if (success) {
      final pendingIdx = _pendingOrders.indexWhere((o) => o.id == orderId);
      if (pendingIdx != -1) {
        final order = _pendingOrders.removeAt(pendingIdx);
        final shippedOrder = order.copyWith(
          status: 'shipped',
          shippedAt: shippedAt,
          trackingNumber: trackingNumber?.trim(),
          shippingCarrier: shippingCarrier?.trim(),
          updatedAt: DateTime.now(),
        );
        _shippedOrders.insert(0, shippedOrder);
      } else {
        final shippedIdx = _shippedOrders.indexWhere((o) => o.id == orderId);
        if (shippedIdx != -1) {
          _shippedOrders[shippedIdx] = _shippedOrders[shippedIdx].copyWith(
            shippedAt: shippedAt,
            trackingNumber: trackingNumber?.trim(),
            shippingCarrier: shippingCarrier?.trim(),
            updatedAt: DateTime.now(),
          );
        }
      }
      notifyListeners();
    }
    return success;
  }
}
