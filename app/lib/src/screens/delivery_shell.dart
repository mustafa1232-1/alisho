import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_service.dart';
import '../core/app_locale.dart';
import '../core/auth_controller.dart';
import '../widgets/common_views.dart';
import '../widgets/language_button.dart';
import '../widgets/responsive_dialog.dart';

class DeliveryShell extends ConsumerStatefulWidget {
  const DeliveryShell({super.key});

  @override
  ConsumerState<DeliveryShell> createState() => _DeliveryShellState();
}

class _DeliveryShellState extends ConsumerState<DeliveryShell> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _orders = const [];
  List<dynamic> _settlements = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).logout();
  }

  Future<void> _load({bool silent = false}) async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) {
      return;
    }

    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final api = ref.read(apiServiceProvider);
      final responses = await Future.wait<dynamic>([
        api.get('/delivery/orders', token: token),
        api.get('/delivery/settlements', token: token),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _orders = responses[0] as List<dynamic>;
        _settlements = responses[1] as List<dynamic>;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _error = describeApiError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.deliveryPanel),
        actions: [
          IconButton(
            tooltip: strings.refresh,
            onPressed: () => _load(silent: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: strings.logout,
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
          const LanguageButton(),
        ],
      ),
      body: _isLoading && _orders.isEmpty && _settlements.isEmpty
          ? const LoadingView()
          : _error != null && _orders.isEmpty && _settlements.isEmpty
              ? ErrorView(message: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    strings.assignedOrders,
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 6),
                                  Text('${_orders.length}'),
                                ],
                              ),
                            ),
                            FilledButton(
                              onPressed: _orders.isEmpty ? null : _closeDay,
                              child: Text(strings.closeDaySettlement),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_orders.isEmpty)
                      EmptyView(
                        icon: Icons.local_shipping_outlined,
                        title: strings.noData,
                        subtitle: strings.assignedOrders,
                      )
                    else
                      ..._orders.map((rawOrder) {
                        final order = rawOrder as Map<String, dynamic>;
                        final customer =
                            order['customer'] as Map<String, dynamic>? ?? <String, dynamic>{};
                        final address =
                            order['address'] as Map<String, dynamic>? ?? <String, dynamic>{};
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          order['orderNumber']?.toString() ?? '',
                                          style: Theme.of(context).textTheme.titleMedium,
                                        ),
                                      ),
                                      Chip(
                                        label: Text(
                                          order['targetType'] == 'SERVICE'
                                              ? strings.services
                                              : strings.orders,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(customer['fullName']?.toString() ?? ''),
                                  const SizedBox(height: 4),
                                  Text(customer['phone']?.toString() ?? ''),
                                  const SizedBox(height: 6),
                                  Text(address['label']?.toString() ?? strings.noAddress),
                                  const SizedBox(height: 6),
                                  Text(strings.formatCurrency(order['total'])),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton(
                                        onPressed: () => _showOrderDetails(
                                          order['orderId']?.toString() ?? '',
                                        ),
                                        child: Text(strings.details),
                                      ),
                                      FilledButton.tonal(
                                        onPressed: () => _transition(
                                          order['orderId']?.toString() ?? '',
                                          'pickup',
                                        ),
                                        child: Text(strings.pickup),
                                      ),
                                      FilledButton.tonal(
                                        onPressed: () => _transition(
                                          order['orderId']?.toString() ?? '',
                                          'delivered',
                                        ),
                                        child: Text(strings.delivered),
                                      ),
                                      TextButton(
                                        onPressed: () => _showFailDialog(
                                          order['orderId']?.toString() ?? '',
                                        ),
                                        child: Text(strings.failedDelivery),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 16),
                    Text(
                      strings.settlements,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (_settlements.isEmpty)
                      EmptyView(
                        icon: Icons.account_balance_wallet_outlined,
                        title: strings.noData,
                        subtitle: strings.settlements,
                      )
                    else
                      ..._settlements.map((rawSettlement) {
                        final settlement = rawSettlement as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            child: ListTile(
                              title: Text(settlement['id']?.toString() ?? ''),
                              subtitle: Text(
                                '${settlement['totalDeliveredCount']} • '
                                '${settlement['totalReturnedCount']}',
                              ),
                              trailing: Text(
                                strings.formatCurrency(settlement['totalCollected']),
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
    );
  }

  Future<void> _showOrderDetails(String orderId) async {
    final token = ref.read(authControllerProvider).accessToken!;

    try {
      final order = await ref.read(apiServiceProvider).get(
            '/delivery/orders/$orderId',
            token: token,
          ) as Map<String, dynamic>;
      if (!mounted) {
        return;
      }

      final strings = context.strings;
      final address = order['address'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final customer = order['customer'] as Map<String, dynamic>? ?? <String, dynamic>{};

      await showDialog<void>(
        context: context,
        builder: (context) => ResponsiveDialog(
          title: order['orderNumber']?.toString() ?? '',
          maxWidth: 480,
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.orderStatusLabel(order['status']?.toString())),
                const SizedBox(height: 8),
                Text(customer['fullName']?.toString() ?? ''),
                const SizedBox(height: 4),
                Text(customer['phone']?.toString() ?? ''),
                const SizedBox(height: 8),
                Text(address['label']?.toString() ?? strings.noAddress),
                const SizedBox(height: 8),
                Text(strings.formatCurrency(order['total'])),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(strings.close),
            ),
          ],
        ),
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _showFailDialog(String orderId) async {
    final strings = context.strings;
    final reasonController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ResponsiveDialog(
        title: strings.failedDelivery,
        maxWidth: 420,
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: InputDecoration(labelText: strings.reason),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.close),
          ),
          FilledButton.tonal(
            onPressed: () async {
              try {
                await _transition(orderId, 'failed', reason: reasonController.text.trim());
                if (!mounted || !dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
              } catch (_) {
                if (!mounted || !dialogContext.mounted) {
                  return;
                }
              }
            },
            child: Text(strings.save),
          ),
        ],
      ),
    );

    reasonController.dispose();
  }

  Future<void> _transition(
    String orderId,
    String action, {
    String? reason,
  }) async {
    final token = ref.read(authControllerProvider).accessToken!;
    try {
      if (action == 'failed') {
        await ref.read(apiServiceProvider).post(
          '/delivery/orders/$orderId/failed',
          token: token,
          data: {
            'reason': reason?.isNotEmpty == true ? reason : 'Customer unavailable',
          },
        );
      } else {
        await ref.read(apiServiceProvider).post(
          '/delivery/orders/$orderId/$action',
          token: token,
        );
      }
      await _load(silent: true);
    } catch (error) {
      _showError(error);
      rethrow;
    }
  }

  Future<void> _closeDay() async {
    final token = ref.read(authControllerProvider).accessToken!;
    try {
      await ref.read(apiServiceProvider).post('/delivery/close-day', token: token);
      await _load(silent: true);
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(describeApiError(error))),
    );
  }
}
