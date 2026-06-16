import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_service.dart';
import '../core/auth_controller.dart';

class DeliveryShell extends ConsumerStatefulWidget {
  const DeliveryShell({super.key});

  @override
  ConsumerState<DeliveryShell> createState() => _DeliveryShellState();
}

class _DeliveryShellState extends ConsumerState<DeliveryShell> {
  List<dynamic> _orders = const [];
  List<dynamic> _settlements = const [];

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
      api.get('/delivery/orders', token: token),
      api.get('/delivery/settlements', token: token),
    ]);

    setState(() {
      _orders = responses[0] as List<dynamic>;
      _settlements = responses[1] as List<dynamic>;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الدلفري'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('الطلبات الحالية: ${_orders.length}'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _closeDay,
                    child: const Text('إغلاق اليوم والتحاسب'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final rawOrder in _orders)
            Card(
              child: ListTile(
                title: Text((rawOrder as Map<String, dynamic>)['orderNumber'] as String? ?? ''),
                subtitle: Text(rawOrder['status'] as String? ?? ''),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'pickup':
                        _transition(rawOrder['orderId'] as String, 'pickup');
                      case 'delivered':
                        _transition(rawOrder['orderId'] as String, 'delivered');
                      case 'failed':
                        _transition(rawOrder['orderId'] as String, 'failed');
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'pickup', child: Text('استلام')),
                    PopupMenuItem(value: 'delivered', child: Text('تم التسليم')),
                    PopupMenuItem(value: 'failed', child: Text('فشل التسليم')),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('التحاسب', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final rawSettlement in _settlements)
            Card(
              child: ListTile(
                title: Text('Settlement ${(rawSettlement as Map<String, dynamic>)['id']}'),
                subtitle: Text('Collected: ${rawSettlement['totalCollected']}'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _transition(String orderId, String action) async {
    final token = ref.read(authControllerProvider).accessToken!;
    if (action == 'failed') {
      await ref.read(apiServiceProvider).post(
        '/delivery/orders/$orderId/failed',
        token: token,
        data: const {'reason': 'الزبون لا يرد'},
      );
    } else {
      await ref.read(apiServiceProvider).post(
        '/delivery/orders/$orderId/$action',
        token: token,
      );
    }
    await _load();
  }

  Future<void> _closeDay() async {
    final token = ref.read(authControllerProvider).accessToken!;
    await ref.read(apiServiceProvider).post('/delivery/close-day', token: token);
    await _load();
  }
}
