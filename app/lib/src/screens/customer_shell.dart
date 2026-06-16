import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_service.dart';
import '../core/auth_controller.dart';

class CustomerShell extends ConsumerStatefulWidget {
  const CustomerShell({super.key});

  @override
  ConsumerState<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends ConsumerState<CustomerShell> {
  int _currentIndex = 0;
  List<dynamic> _products = const [];
  Map<String, dynamic>? _cart;
  List<dynamic> _orders = const [];
  List<dynamic> _services = const [];
  List<dynamic> _notifications = const [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;
    final api = ref.read(apiServiceProvider);

    final responses = await Future.wait<dynamic>([
      api.get('/customer/home', token: token),
      api.get('/customer/cart', token: token),
      api.get('/customer/orders', token: token),
      api.get('/customer/services', token: token),
      api.get('/customer/notifications', token: token),
    ]);

    setState(() {
      _products = (responses[0] as Map<String, dynamic>)['products'] as List<dynamic>;
      _cart = responses[1] as Map<String, dynamic>;
      _orders = responses[2] as List<dynamic>;
      _services = responses[3] as List<dynamic>;
      _notifications = responses[4] as List<dynamic>;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user ?? {};
    final views = [
      _homeView(),
      _cartView(),
      _ordersView(),
      _servicesView(),
      _notificationsView(),
      _profileView(user),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('مكتبة عليشو'),
        actions: [
          IconButton(onPressed: _loadAll, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: views[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), label: 'السلة'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'الطلبات'),
          NavigationDestination(icon: Icon(Icons.print_outlined), label: 'الخدمات'),
          NavigationDestination(icon: Icon(Icons.notifications_none), label: 'الإشعارات'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'الحساب'),
        ],
      ),
    );
  }

  Widget _homeView() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.78,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index] as Map<String, dynamic>;
        final isAvailable = product['isAvailable'] as bool? ?? false;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E1D3),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: isAvailable
                        ? const Icon(Icons.inventory_2_outlined, size: 44)
                        : const Icon(Icons.block_outlined, size: 44),
                  ),
                ),
                const SizedBox(height: 12),
                Text(product['name'] as String? ?? ''),
                const SizedBox(height: 6),
                Text(product['description'] as String? ?? ''),
                const Spacer(),
                Text('${product['price']} د.ع'),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: isAvailable
                      ? () => _addToCart(product['id'] as String)
                      : null,
                  child: Text(isAvailable ? 'إضافة للسلة' : 'غير متوفر'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cartView() {
    final items = (_cart?['items'] as List<dynamic>? ?? const []);
    final pricing = _cart?['pricing'] as Map<String, dynamic>? ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final rawItem in items)
          Card(
            child: ListTile(
              title: Text((rawItem as Map<String, dynamic>)['product']['name'] as String),
              subtitle: Text('الكمية: ${rawItem['quantity']}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteCartItem(rawItem['id'] as String),
              ),
            ),
          ),
        if (items.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('السلة فارغة حاليًا.'),
            ),
          ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _priceRow('Subtotal', pricing['subtotal']),
                _priceRow('Delivery', pricing['deliveryFee']),
                _priceRow('Service', pricing['serviceFee']),
                _priceRow('Extra', pricing['extraFee']),
                _priceRow('Discount', pricing['discount']),
                const Divider(),
                _priceRow('Final', pricing['finalTotal'], emphasized: true),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: items.isEmpty ? null : _checkout,
                  child: const Text('تأكيد الطلب'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _ordersView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _orders.map((rawOrder) {
        final order = rawOrder as Map<String, dynamic>;
        return Card(
          child: ListTile(
            title: Text(order['orderNumber'] as String? ?? ''),
            subtitle: Text(order['status'] as String? ?? ''),
            trailing: Text('${order['finalTotal']} د.ع'),
          ),
        );
      }).toList(),
    );
  }

  Widget _servicesView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _services.map((rawService) {
        final service = rawService as Map<String, dynamic>;
        return Card(
          child: ListTile(
            title: Text(service['name'] as String? ?? ''),
            subtitle: Text(service['description'] as String? ?? ''),
            trailing: FilledButton.tonal(
              onPressed: () => _uploadServiceFiles(service),
              child: const Text('رفع ملف'),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _notificationsView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _notifications.map((rawNotification) {
        final item = rawNotification as Map<String, dynamic>;
        return Card(
          child: ListTile(
            title: Text(item['title'] as String? ?? ''),
            subtitle: Text(item['body'] as String? ?? ''),
          ),
        );
      }).toList(),
    );
  }

  Widget _profileView(Map<String, dynamic> user) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            title: Text(user['fullName'] as String? ?? ''),
            subtitle: Text(user['phone'] as String? ?? ''),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          child: const Text('تسجيل الخروج'),
        ),
      ],
    );
  }

  Widget _priceRow(String label, dynamic value, {bool emphasized = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label),
          const Spacer(),
          Text(
            '${value ?? 0} د.ع',
            style: emphasized ? const TextStyle(fontWeight: FontWeight.bold) : null,
          ),
        ],
      ),
    );
  }

  Future<void> _addToCart(String productId) async {
    final token = ref.read(authControllerProvider).accessToken!;
    await ref.read(apiServiceProvider).post(
      '/customer/cart/items',
      token: token,
      data: {
        'productId': productId,
        'quantity': 1,
        'selectedOptionValueIds': const <String>[],
      },
    );
    await _loadAll();
  }

  Future<void> _deleteCartItem(String itemId) async {
    final token = ref.read(authControllerProvider).accessToken!;
    await ref.read(apiServiceProvider).delete(
      '/customer/cart/items/$itemId',
      token: token,
    );
    await _loadAll();
  }

  Future<void> _checkout() async {
    final token = ref.read(authControllerProvider).accessToken!;
    await ref.read(apiServiceProvider).post(
      '/customer/orders',
      token: token,
      data: const {'notes': 'طلب من تطبيق Flutter'},
    );
    await _loadAll();
  }

  Future<void> _uploadServiceFiles(Map<String, dynamic> service) async {
    final token = ref.read(authControllerProvider).accessToken!;
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;

    final files = <MultipartFile>[];
    for (final file in result.files) {
      if (file.bytes == null) continue;
      files.add(MultipartFile.fromBytes(file.bytes!, filename: file.name));
    }

    await ref.read(apiServiceProvider).postMultipart(
      '/customer/service-orders',
      token: token,
      fields: {
        'serviceId': service['id'],
        'notes': 'تم الرفع من Flutter',
      },
      files: files,
    );

    await _loadAll();
  }
}
