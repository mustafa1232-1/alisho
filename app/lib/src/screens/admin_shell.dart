import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../core/api_service.dart';
import '../core/auth_controller.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _selected = 0;
  Map<String, dynamic>? _kpis;
  List<dynamic> _products = const [];
  List<dynamic> _orders = const [];
  List<dynamic> _serviceOrders = const [];
  List<dynamic> _deliveryUsers = const [];
  Map<String, dynamic>? _settings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;
    final api = ref.read(apiServiceProvider);
    final responses = await Future.wait<dynamic>([
      api.get('/admin/dashboard/kpis', token: token),
      api.get('/admin/products', token: token),
      api.get('/admin/orders', token: token),
      api.get('/admin/service-orders', token: token),
      api.get('/admin/delivery-users', token: token),
      api.get('/admin/settings', token: token),
    ]);

    setState(() {
      _kpis = responses[0] as Map<String, dynamic>;
      _products = responses[1] as List<dynamic>;
      _orders = responses[2] as List<dynamic>;
      _serviceOrders = responses[3] as List<dynamic>;
      _deliveryUsers = responses[4] as List<dynamic>;
      _settings = responses[5] as Map<String, dynamic>;
    });
  }

  @override
  Widget build(BuildContext context) {
    final views = [
      _dashboard(),
      _productsView(),
      _ordersView(),
      _serviceOrdersView(),
      _deliveryView(),
      _settingsView(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الأدمن'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selected,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (index) => setState(() => _selected = index),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), label: Text('KPIs')),
              NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), label: Text('Products')),
              NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), label: Text('Orders')),
              NavigationRailDestination(icon: Icon(Icons.print_outlined), label: Text('Services')),
              NavigationRailDestination(icon: Icon(Icons.delivery_dining_outlined), label: Text('Delivery')),
              NavigationRailDestination(icon: Icon(Icons.settings_outlined), label: Text('Settings')),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: views[_selected],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboard() {
    final entries = (_kpis ?? {}).entries.toList();
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 120,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.key),
                const Spacer(),
                Text(
                  '${entry.value}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _productsView() {
    return ListView(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _createProductDialog,
            child: const Text('إضافة منتج'),
          ),
        ),
        const SizedBox(height: 12),
        for (final rawProduct in _products)
          Card(
            child: ListTile(
              title: Text((rawProduct as Map<String, dynamic>)['name'] as String),
              subtitle: Text('السعر: ${rawProduct['price']}'),
              trailing: Text(rawProduct['isAvailable'] == true ? 'متوفر' : 'غير متوفر'),
            ),
          ),
      ],
    );
  }

  Widget _ordersView() {
    return ListView(
      children: _orders.map((rawOrder) {
        final order = rawOrder as Map<String, dynamic>;
        return Card(
          child: ListTile(
            title: Text(order['orderNumber'] as String? ?? ''),
            subtitle: Text(order['status'] as String? ?? ''),
            trailing: FilledButton.tonal(
              onPressed: () => _confirmOrder(order['id'] as String),
              child: const Text('Confirm'),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _serviceOrdersView() {
    return ListView(
      children: _serviceOrders.map((rawServiceOrder) {
        final serviceOrder = rawServiceOrder as Map<String, dynamic>;
        return Card(
          child: ListTile(
            title: Text(serviceOrder['orderNumber'] as String? ?? ''),
            subtitle: Text(serviceOrder['status'] as String? ?? ''),
            trailing: IconButton(
              icon: const Icon(Icons.print_outlined),
              onPressed: () => _printServiceOrder(serviceOrder),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _deliveryView() {
    return ListView(
      children: _deliveryUsers.map((rawUser) {
        final user = rawUser as Map<String, dynamic>;
        final profile = user['user'] as Map<String, dynamic>;
        return Card(
          child: ListTile(
            title: Text(profile['fullName'] as String? ?? ''),
            subtitle: Text(profile['phone'] as String? ?? ''),
          ),
        );
      }).toList(),
    );
  }

  Widget _settingsView() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Text(const JsonEncoder.withIndent('  ').convert(_settings ?? {})),
        ),
      ),
    );
  }

  Future<void> _confirmOrder(String orderId) async {
    final token = ref.read(authControllerProvider).accessToken!;
    await ref.read(apiServiceProvider).post(
      '/admin/orders/$orderId/confirm',
      token: token,
    );
    await _load();
  }

  Future<void> _printServiceOrder(Map<String, dynamic> serviceOrder) async {
    final token = ref.read(authControllerProvider).accessToken!;
    final response = await ref.read(apiServiceProvider).post(
      '/admin/service-orders/${serviceOrder['id']}/print',
      token: token,
    );
    final path = response['printableFileUrl'] as String?;
    if (path == null) return;
    final bytes = await ref.read(apiServiceProvider).downloadBytes(path, token: token);
    await Printing.layoutPdf(
      onLayout: (_) async => Uint8List.fromList(bytes),
    );
  }

  Future<void> _createProductDialog() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController(text: '1000');
    final stockController = TextEditingController(text: '10');

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة منتج'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم')),
            const SizedBox(height: 12),
            TextField(controller: priceController, decoration: const InputDecoration(labelText: 'السعر')),
            const SizedBox(height: 12),
            TextField(controller: stockController, decoration: const InputDecoration(labelText: 'المخزون')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final token = ref.read(authControllerProvider).accessToken!;
              await ref.read(apiServiceProvider).post(
                '/admin/products',
                token: token,
                data: {
                  'name': nameController.text.trim(),
                  'price': priceController.text.trim(),
                  'stock': stockController.text.trim(),
                  'isAvailable': 'true',
                  'isActive': 'true',
                },
              );
              if (!mounted) return;
              Navigator.of(this.context).pop();
              await _load();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
