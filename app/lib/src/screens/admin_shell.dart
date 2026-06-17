import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api_service.dart';
import '../core/app_locale.dart';
import '../core/auth_controller.dart';
import '../widgets/common_views.dart';
import '../widgets/language_button.dart';
import '../widgets/responsive_dialog.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _selected = 0;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _kpis;
  Map<String, dynamic>? _settings;
  List<dynamic> _products = const [];
  List<dynamic> _orders = const [];
  List<dynamic> _serviceOrders = const [];
  List<dynamic> _deliveryUsers = const [];
  List<dynamic> _promoCodes = const [];
  List<dynamic> _services = const [];
  List<dynamic> _banners = const [];

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
        api.get('/admin/dashboard/kpis', token: token),
        api.get('/admin/products', token: token),
        api.get('/admin/orders', token: token),
        api.get('/admin/service-orders', token: token),
        api.get('/admin/delivery-users', token: token),
        api.get('/admin/settings', token: token),
        api.get('/admin/promo-codes', token: token),
        api.get('/admin/services', token: token),
        api.get('/admin/banners', token: token),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _kpis = responses[0] as Map<String, dynamic>;
        _products = responses[1] as List<dynamic>;
        _orders = responses[2] as List<dynamic>;
        _serviceOrders = responses[3] as List<dynamic>;
        _deliveryUsers = responses[4] as List<dynamic>;
        _settings = responses[5] as Map<String, dynamic>;
        _promoCodes = responses[6] as List<dynamic>;
        _services = responses[7] as List<dynamic>;
        _banners = responses[8] as List<dynamic>;
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
    final destinations = [
      (Icons.dashboard_outlined, strings.kpis),
      (Icons.inventory_2_outlined, strings.products),
      (Icons.receipt_long_outlined, strings.orders),
      (Icons.print_outlined, strings.services),
      (Icons.delivery_dining_outlined, strings.delivery),
      (Icons.campaign_outlined, strings.marketing),
      (Icons.settings_outlined, strings.settings),
    ];
    final views = [
      _dashboard(),
      _productsView(),
      _ordersView(),
      _serviceOrdersView(),
      _deliveryView(),
      _marketingView(),
      _settingsView(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 760;
        return Scaffold(
          appBar: AppBar(
            title: Text(strings.adminPanel),
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
          body: useRail
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _selected,
                      labelType: NavigationRailLabelType.all,
                      onDestinationSelected: (index) {
                        setState(() => _selected = index);
                      },
                      destinations: destinations
                          .map(
                            (item) => NavigationRailDestination(
                              icon: Icon(item.$1),
                              label: Text(item.$2),
                            ),
                          )
                          .toList(),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: views[_selected],
                      ),
                    ),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: views[_selected],
                ),
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  selectedIndex: _selected,
                  onDestinationSelected: (index) {
                    setState(() => _selected = index);
                  },
                  destinations: destinations
                      .map(
                        (item) => NavigationDestination(
                          icon: Icon(item.$1),
                          label: item.$2,
                        ),
                      )
                      .toList(),
                ),
        );
      },
    );
  }

  Widget _dashboard() {
    final strings = context.strings;
    if (_isLoading && _kpis == null) {
      return const LoadingView();
    }
    if (_error != null && _kpis == null) {
      return ErrorView(message: _error!, onRetry: _load);
    }

    final kpis = _kpis ?? <String, dynamic>{};

    const currencyKeys = {
      'salesToday', 'salesMonth', 'totalDiscounts',
      'netSales', 'totalDeliveryFees', 'totalServiceFees',
    };
    const complexKeys = {'bestSellingProduct', 'leastSellingProduct', 'bestDelivery'};

    final simpleEntries = kpis.entries
        .where((e) => !complexKeys.contains(e.key))
        .toList();

    final bestProduct = kpis['bestSellingProduct'] as Map<String, dynamic>?;
    final leastProduct = kpis['leastSellingProduct'] as Map<String, dynamic>?;
    final bestDeliveryData = kpis['bestDelivery'] as Map<String, dynamic>?;

    return ListView(
      children: [
        SectionHeader(
          title: strings.dashboard,
          subtitle: strings.reports,
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 240,
            mainAxisExtent: 126,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
          ),
          itemCount: simpleEntries.length,
          itemBuilder: (context, index) {
            final entry = simpleEntries[index];
            final isCurrency = currencyKeys.contains(entry.key);
            final displayValue = isCurrency
                ? strings.formatCurrency(entry.value)
                : '${entry.value}';
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _kpiLabel(entry.key),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    Text(
                      displayValue,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isCurrency
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        if (bestProduct != null) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.emoji_events_outlined),
              title: Text(strings.bestSellingProduct),
              subtitle: Text(
                strings.translateContent(bestProduct['productName']?.toString() ?? '-'),
              ),
              trailing: Text(
                '${bestProduct['quantity']}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (leastProduct != null) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.trending_down_rounded),
              title: Text(strings.leastSellingProduct),
              subtitle: Text(
                strings.translateContent(leastProduct['productName']?.toString() ?? '-'),
              ),
              trailing: Text(
                '${leastProduct['quantity']}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (bestDeliveryData != null) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.delivery_dining_outlined),
              title: Text(strings.bestDelivery),
              subtitle: Text(bestDeliveryData['fullName']?.toString() ?? '-'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${strings.deliveredCount}: ${bestDeliveryData['deliveredCount'] ?? 0}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '${strings.returnedCount}: ${bestDeliveryData['returnedCount'] ?? 0}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _productsView() {
    final strings = context.strings;
    if (_isLoading && _products.isEmpty) {
      return const LoadingView();
    }
    if (_error != null && _products.isEmpty) {
      return ErrorView(message: _error!, onRetry: _load);
    }

    return ListView(
      children: [
        SectionHeader(
          title: strings.products,
          subtitle: strings.createProduct,
          action: FilledButton(
            onPressed: () => _showProductEditor(),
            child: Text(strings.createProduct),
          ),
        ),
        const SizedBox(height: 16),
        for (final rawProduct in _products) ...[
          _productCard(rawProduct as Map<String, dynamic>),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _productCard(Map<String, dynamic> product) {
    final strings = context.strings;
    final isAvailable = product['isAvailable'] == true;
    final optionGroups =
        (product['optionGroups'] as List<dynamic>? ?? const <dynamic>[]);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.translateContent(product['name']?.toString() ?? ''),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(isAvailable ? strings.available : strings.unavailable)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              strings.translateContent(product['description']?.toString() ?? ''),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                Chip(label: Text('${strings.price}: ${strings.formatCurrency(product['price'])}')),
                Chip(label: Text('${strings.stock}: ${product['stock']}')),
                Chip(label: Text('${strings.details}: ${optionGroups.length}')),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _showProductEditor(product: product),
                  child: Text(strings.edit),
                ),
                FilledButton.tonal(
                  onPressed: () => _toggleAvailability(
                    product['id'] as String,
                    !(product['isAvailable'] == true),
                  ),
                  child: Text(isAvailable ? strings.markUnavailable : strings.markAvailable),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _ordersView() {
    final strings = context.strings;
    if (_isLoading && _orders.isEmpty) {
      return const LoadingView();
    }
    if (_error != null && _orders.isEmpty) {
      return ErrorView(message: _error!, onRetry: _load);
    }

    return ListView(
      children: [
        SectionHeader(
          title: strings.orders,
          subtitle: strings.orderTracking,
        ),
        const SizedBox(height: 16),
        for (final rawOrder in _orders) ...[
          _orderCard(rawOrder as Map<String, dynamic>),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final strings = context.strings;
    final customer = order['customer'] as Map<String, dynamic>?;
    final status = order['status']?.toString();

    return Card(
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
                Chip(label: Text(strings.orderStatusLabel(status))),
              ],
            ),
            const SizedBox(height: 8),
            if (customer != null) Text(customer['fullName']?.toString() ?? ''),
            const SizedBox(height: 8),
            Text(strings.formatCurrency(order['finalTotal'])),
            const SizedBox(height: 8),
            Text(order['addressLabel']?.toString() ?? strings.noAddress),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _showAdminOrderDetails(order['id'] as String),
                  child: Text(strings.details),
                ),
                if (status == 'PENDING_STORE_CONFIRMATION' ||
                    status == 'REVISED_PENDING_STORE_CONFIRMATION')
                  FilledButton.tonal(
                    onPressed: () => _confirmOrder(order['id'] as String),
                    child: Text(strings.confirmOrder),
                  ),
                if (status == 'PENDING_STORE_CONFIRMATION' ||
                    status == 'REVISED_PENDING_STORE_CONFIRMATION')
                  TextButton(
                    onPressed: () => _markUnavailableDialog(order),
                    child: Text(strings.markUnavailable),
                  ),
                if (status == 'CONFIRMED' || status == 'REVISED_PENDING_STORE_CONFIRMATION')
                  TextButton(
                    onPressed: () => _assignDeliveryDialog(
                      orderId: order['id'] as String,
                      serviceOrderId: null,
                    ),
                    child: Text(strings.assignDelivery),
                  ),
                if (status == 'DELIVERY_ASSIGNED' || status == 'CONFIRMED')
                  TextButton(
                    onPressed: () => _readyOrder(order['id'] as String),
                    child: Text(strings.readyForPickup),
                  ),
                TextButton(
                  onPressed: () => _archiveOrder(order['id'] as String),
                  child: Text(strings.archive),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _serviceOrdersView() {
    final strings = context.strings;
    if (_isLoading && _serviceOrders.isEmpty) {
      return const LoadingView();
    }
    if (_error != null && _serviceOrders.isEmpty) {
      return ErrorView(message: _error!, onRetry: _load);
    }

    return ListView(
      children: [
        SectionHeader(
          title: strings.services,
          subtitle: strings.customerServiceFlow,
        ),
        const SizedBox(height: 16),
        for (final rawOrder in _serviceOrders) ...[
          _serviceOrderCard(rawOrder as Map<String, dynamic>),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _serviceOrderCard(Map<String, dynamic> order) {
    final strings = context.strings;
    final service = order['service'] as Map<String, dynamic>?;
    final status = order['status']?.toString();

    return Card(
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
                Chip(label: Text(strings.serviceOrderStatusLabel(status))),
              ],
            ),
            const SizedBox(height: 8),
            Text(strings.translateContent(service?['name']?.toString() ?? '')),
            const SizedBox(height: 8),
            Text(strings.formatCurrency(order['finalTotal'])),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () =>
                      _showAdminServiceOrderDetails(order['id'] as String),
                  child: Text(strings.details),
                ),
                if (status == 'UPLOADED_WAITING_ADMIN_REVIEW' ||
                    status == 'PRICED_WAITING_CUSTOMER_APPROVAL')
                  FilledButton.tonal(
                    onPressed: () =>
                        _priceServiceOrderDialog(order['id'] as String),
                    child: Text(strings.priceService),
                  ),
                if (status == 'CUSTOMER_APPROVED_PRICE' ||
                    status == 'PRICED_WAITING_CUSTOMER_APPROVAL')
                  TextButton(
                    onPressed: () => _confirmServiceOrder(order['id'] as String),
                    child: Text(strings.confirmOrder),
                  ),
                if (status == 'CONFIRMED' || status == 'CUSTOMER_APPROVED_PRICE')
                  TextButton(
                    onPressed: () => _assignDeliveryDialog(
                      orderId: null,
                      serviceOrderId: order['id'] as String,
                    ),
                    child: Text(strings.assignDelivery),
                  ),
                if (status == 'DELIVERY_ASSIGNED' || status == 'CONFIRMED')
                  TextButton(
                    onPressed: () => _readyServiceOrder(order['id'] as String),
                    child: Text(strings.readyForPickup),
                  ),
                TextButton(
                  onPressed: () => _printServiceOrder(order),
                  child: Text(strings.printFile),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _deliveryView() {
    final strings = context.strings;
    if (_isLoading && _deliveryUsers.isEmpty) {
      return const LoadingView();
    }
    if (_error != null && _deliveryUsers.isEmpty) {
      return ErrorView(message: _error!, onRetry: _load);
    }

    return ListView(
      children: [
        SectionHeader(
          title: strings.delivery,
          subtitle: strings.createDeliveryUser,
          action: FilledButton(
            onPressed: () => _showDeliveryUserDialog(),
            child: Text(strings.createDeliveryUser),
          ),
        ),
        const SizedBox(height: 16),
        for (final rawUser in _deliveryUsers) ...[
          _deliveryUserCard(rawUser as Map<String, dynamic>),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _deliveryUserCard(Map<String, dynamic> deliveryUser) {
    final strings = context.strings;
    final user = deliveryUser['user'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final counts = deliveryUser['_count'] as Map<String, dynamic>? ?? <String, dynamic>{};

    return Card(
      child: ListTile(
        title: Text(user['fullName']?.toString() ?? ''),
        subtitle: Text(
          '${user['phone']}\n${deliveryUser['vehicleInfo'] ?? ''}',
        ),
        isThreeLine: true,
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Chip(label: Text(deliveryUser['isActive'] == true ? strings.active : strings.inactive)),
            const SizedBox(height: 4),
            Text('${counts['assignments'] ?? 0} / ${counts['settlements'] ?? 0}'),
          ],
        ),
        onTap: () => _showDeliveryUserDialog(deliveryUser: deliveryUser),
      ),
    );
  }

  Widget _marketingView() {
    final strings = context.strings;
    if (_isLoading && _promoCodes.isEmpty && _services.isEmpty && _banners.isEmpty) {
      return const LoadingView();
    }
    if (_error != null && _promoCodes.isEmpty && _services.isEmpty && _banners.isEmpty) {
      return ErrorView(message: _error!, onRetry: _load);
    }

    return ListView(
      children: [
        SectionHeader(
          title: strings.promoCode,
          subtitle: strings.createPromoCode,
          action: FilledButton.tonal(
            onPressed: _showPromoCodeDialog,
            child: Text(strings.createPromoCode),
          ),
        ),
        const SizedBox(height: 12),
        for (final rawPromo in _promoCodes) ...[
          _marketingCard(
            title: (rawPromo as Map<String, dynamic>)['code']?.toString() ?? '',
            subtitle:
                '${strings.feeModeLabel(rawPromo['discountType']?.toString())} • '
                '${rawPromo['value']}',
            onDelete: () => _deleteEntity('/admin/promo-codes/${rawPromo['id']}'),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 20),
        SectionHeader(
          title: strings.services,
          subtitle: strings.createService,
          action: FilledButton.tonal(
            onPressed: _showServiceDialog,
            child: Text(strings.createService),
          ),
        ),
        const SizedBox(height: 12),
        for (final rawService in _services) ...[
          _marketingCard(
            title: strings.translateContent(
              (rawService as Map<String, dynamic>)['name']?.toString() ?? '',
            ),
            subtitle: strings.servicePricingModeLabel(rawService['pricingMode']?.toString()),
            onDelete: () => _deleteEntity('/admin/services/${rawService['id']}'),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 20),
        SectionHeader(
          title: strings.banners,
          subtitle: strings.createBanner,
          action: FilledButton.tonal(
            onPressed: _showBannerDialog,
            child: Text(strings.createBanner),
          ),
        ),
        const SizedBox(height: 12),
        for (final rawBanner in _banners) ...[
          _marketingCard(
            title: strings.translateContent(
              (rawBanner as Map<String, dynamic>)['title']?.toString() ?? '',
            ),
            subtitle: rawBanner['description']?.toString() ?? '',
            onDelete: () => _deleteEntity('/admin/banners/${rawBanner['id']}'),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _marketingCard({
    required String title,
    required String subtitle,
    required VoidCallback onDelete,
  }) {
    final strings = context.strings;
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
          tooltip: strings.delete,
        ),
      ),
    );
  }

  Widget _settingsView() {
    final strings = context.strings;
    if (_isLoading && _settings == null) {
      return const LoadingView();
    }
    if (_error != null && _settings == null) {
      return ErrorView(message: _error!, onRetry: _load);
    }

    final settings = _settings ?? <String, dynamic>{};
    final deliveryFee = settings['deliveryFee'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final serviceFee = settings['serviceFee'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final appPreferences =
        settings['appPreferences'] as Map<String, dynamic>? ?? <String, dynamic>{};

    return ListView(
      children: [
        SectionHeader(
          title: strings.settings,
          subtitle: strings.pricingBreakdown,
          action: FilledButton(
            onPressed: _showSettingsDialog,
            child: Text(strings.edit),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.deliveryFee, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  '${strings.feeModeLabel(deliveryFee['mode']?.toString())} • '
                  '${strings.formatCurrency(deliveryFee['amount'])}',
                ),
                const SizedBox(height: 4),
                Text(strings.formatBool(deliveryFee['isEnabled'] == true)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.serviceFee, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  '${strings.feeModeLabel(serviceFee['mode']?.toString())} • '
                  '${strings.formatCurrency(serviceFee['amount'])}',
                ),
                const SizedBox(height: 4),
                Text(
                  '${strings.extraFee}: ${strings.formatCurrency(serviceFee['extraFeeAmount'])}',
                ),
                const SizedBox(height: 4),
                Text(strings.formatBool(serviceFee['isEnabled'] == true)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(const JsonEncoder.withIndent('  ').convert(appPreferences)),
          ),
        ),
      ],
    );
  }

  Future<void> _showProductEditor({Map<String, dynamic>? product}) async {
    final strings = context.strings;
    final nameController =
        TextEditingController(text: product?['name']?.toString() ?? '');
    final descriptionController =
        TextEditingController(text: product?['description']?.toString() ?? '');
    final priceController =
        TextEditingController(text: product?['price']?.toString() ?? '1000');
    final stockController =
        TextEditingController(text: product?['stock']?.toString() ?? '10');
    final optionGroupsController = TextEditingController(
      text: product?['optionGroups'] != null
          ? const JsonEncoder.withIndent('  ').convert(product!['optionGroups'])
          : '',
    );
    var isAvailable = product?['isAvailable'] == true;
    var isActive = product == null ? true : product['isActive'] == true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => ResponsiveDialog(
          title: product == null ? strings.createProduct : strings.edit,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: strings.title),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: strings.description),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    decoration: InputDecoration(labelText: strings.price),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: stockController,
                    decoration: InputDecoration(labelText: strings.stock),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: optionGroupsController,
                    maxLines: 6,
                    decoration: InputDecoration(labelText: strings.optionGroupsJson),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: isAvailable,
                    onChanged: (value) => setDialogState(() => isAvailable = value),
                    title: Text(strings.available),
                  ),
                  SwitchListTile(
                    value: isActive,
                    onChanged: (value) => setDialogState(() => isActive = value),
                    title: Text(strings.active),
                  ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(strings.close),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final token = ref.read(authControllerProvider).accessToken!;
                  final data = {
                    'name': nameController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'price': priceController.text.trim(),
                    'stock': stockController.text.trim(),
                    'isAvailable': '$isAvailable',
                    'isActive': '$isActive',
                    if (optionGroupsController.text.trim().isNotEmpty)
                      'optionGroupsJson': optionGroupsController.text.trim(),
                  };
                  if (product == null) {
                    await ref.read(apiServiceProvider).post(
                      '/admin/products',
                      token: token,
                      data: data,
                    );
                  } else {
                    await ref.read(apiServiceProvider).patch(
                      '/admin/products/${product['id']}',
                      token: token,
                      data: data,
                    );
                  }
                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }
                  Navigator.of(dialogContext).pop();
                  await _load(silent: true);
                } catch (error) {
                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(describeApiError(error))),
                  );
                }
              },
              child: Text(strings.save),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    stockController.dispose();
    optionGroupsController.dispose();
  }

  Future<void> _toggleAvailability(String productId, bool nextValue) async {
    final token = ref.read(authControllerProvider).accessToken!;

    try {
      await ref.read(apiServiceProvider).patch(
        '/admin/products/$productId/availability',
        token: token,
        data: {'isAvailable': '$nextValue'},
      );
      await _load(silent: true);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _showAdminOrderDetails(String orderId) async {
    final token = ref.read(authControllerProvider).accessToken!;
    try {
      final order = await ref.read(apiServiceProvider).get(
            '/admin/orders/$orderId',
            token: token,
          ) as Map<String, dynamic>;
      if (!mounted) {
        return;
      }
      final strings = context.strings;
      final items = (order['items'] as List<dynamic>? ?? const <dynamic>[]);
    await showDialog<void>(
      context: context,
      builder: (context) => ResponsiveDialog(
          title: order['orderNumber']?.toString() ?? '',
          content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.orderStatusLabel(order['status']?.toString())),
                  const SizedBox(height: 8),
                  Text(order['addressLabel']?.toString() ?? strings.noAddress),
                  const SizedBox(height: 16),
                  for (final rawItem in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '• ${(rawItem as Map<String, dynamic>)['productName']}'
                        ' x ${rawItem['quantity']}',
                      ),
                    ),
                ],
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

  Future<void> _confirmOrder(String orderId) async {
    final token = ref.read(authControllerProvider).accessToken!;
    try {
      await ref.read(apiServiceProvider).post(
        '/admin/orders/$orderId/confirm',
        token: token,
      );
      await _load(silent: true);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _markUnavailableDialog(Map<String, dynamic> order) async {
    final strings = context.strings;
    final items =
        (order['items'] as List<dynamic>? ?? const <dynamic>[])
            .cast<Map<String, dynamic>>()
            .where((item) => item['isAvailable'] == true)
            .toList();
    final selected = <String>{};
    final noteController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => ResponsiveDialog(
          title: strings.markUnavailable,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                  for (final item in items)
                    CheckboxListTile(
                      value: selected.contains(item['id']),
                      title: Text(item['productName']?.toString() ?? ''),
                      subtitle: Text('x ${item['quantity']}'),
                      onChanged: (value) {
                        setDialogState(() {
                          if (value == true) {
                            selected.add(item['id'] as String);
                          } else {
                            selected.remove(item['id'] as String);
                          }
                        });
                      },
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: strings.notes),
                  ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(strings.close),
            ),
            FilledButton.tonal(
              onPressed: selected.isEmpty
                  ? null
                  : () async {
                      try {
                        final token = ref.read(authControllerProvider).accessToken!;
                        await ref.read(apiServiceProvider).post(
                          '/admin/orders/${order['id']}/mark-item-unavailable',
                          token: token,
                          data: {
                            'orderItemIds': selected.toList(),
                            'note': noteController.text.trim(),
                          },
                        );
                        if (!mounted || !dialogContext.mounted) {
                          return;
                        }
                        Navigator.of(dialogContext).pop();
                        await _load(silent: true);
                      } catch (error) {
                        if (!mounted || !dialogContext.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text(describeApiError(error))),
                        );
                      }
                    },
              child: Text(strings.save),
            ),
          ],
        ),
      ),
    );

    noteController.dispose();
  }

  Future<void> _assignDeliveryDialog({
    String? orderId,
    String? serviceOrderId,
  }) async {
    final strings = context.strings;
    final etaController = TextEditingController();
    String? selectedDeliveryUserId = _deliveryUsers.isEmpty
        ? null
        : (_deliveryUsers.first as Map<String, dynamic>)['id']?.toString();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => ResponsiveDialog(
          title: strings.assignDelivery,
          maxWidth: 420,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedDeliveryUserId,
                  decoration: InputDecoration(labelText: strings.chooseDeliveryUser),
                  items: _deliveryUsers.map((rawUser) {
                    final user = rawUser as Map<String, dynamic>;
                    final profile =
                        user['user'] as Map<String, dynamic>? ?? <String, dynamic>{};
                    return DropdownMenuItem<String>(
                      value: user['id']?.toString(),
                      child: Text(profile['fullName']?.toString() ?? ''),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedDeliveryUserId = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: etaController,
                  decoration: InputDecoration(labelText: strings.eta),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(strings.close),
            ),
            FilledButton(
              onPressed: selectedDeliveryUserId == null
                  ? null
                  : () async {
                      try {
                        final token = ref.read(authControllerProvider).accessToken!;
                        final endpoint = orderId != null
                            ? '/admin/orders/$orderId/assign-delivery'
                            : '/admin/service-orders/$serviceOrderId/assign-delivery';
                        await ref.read(apiServiceProvider).post(
                          endpoint,
                          token: token,
                          data: {
                            'deliveryUserId': selectedDeliveryUserId,
                            'etaText': etaController.text.trim().isEmpty
                                ? null
                                : etaController.text.trim(),
                          },
                        );
                        if (!mounted || !dialogContext.mounted) {
                          return;
                        }
                        Navigator.of(dialogContext).pop();
                        await _load(silent: true);
                      } catch (error) {
                        if (!mounted || !dialogContext.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text(describeApiError(error))),
                        );
                      }
                    },
              child: Text(strings.save),
            ),
          ],
        ),
      ),
    );

    etaController.dispose();
  }

  Future<void> _readyOrder(String orderId) async {
    final token = ref.read(authControllerProvider).accessToken!;
    try {
      await ref.read(apiServiceProvider).post(
        '/admin/orders/$orderId/ready',
        token: token,
      );
      await _load(silent: true);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _archiveOrder(String orderId) async {
    final token = ref.read(authControllerProvider).accessToken!;
    try {
      await ref.read(apiServiceProvider).post(
        '/admin/orders/$orderId/archive',
        token: token,
      );
      await _load(silent: true);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _showAdminServiceOrderDetails(String orderId) async {
    final token = ref.read(authControllerProvider).accessToken!;
    try {
      final order = await ref.read(apiServiceProvider).get(
            '/admin/service-orders/$orderId',
            token: token,
          ) as Map<String, dynamic>;
      if (!mounted) {
        return;
      }
      final strings = context.strings;
      final files =
          (order['files'] as List<dynamic>? ?? const <dynamic>[]);
      await showDialog<void>(
        context: context,
        builder: (context) => ResponsiveDialog(
          title: order['orderNumber']?.toString() ?? '',
          content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.serviceOrderStatusLabel(order['status']?.toString())),
                  const SizedBox(height: 8),
                  Text(order['addressLabel']?.toString() ?? strings.noAddress),
                  const SizedBox(height: 12),
                  for (final rawFile in files)
                    TextButton.icon(
                      onPressed: () => _openFile(
                        (rawFile as Map<String, dynamic>)['fileUrl'].toString(),
                      ),
                      icon: const Icon(Icons.attach_file_rounded),
                      label: Text(
                        rawFile['fileAsset']?['originalName']?.toString() ??
                            strings.filePreview,
                      ),
                    ),
                ],
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

  Future<void> _priceServiceOrderDialog(String orderId) async {
    final strings = context.strings;
    final priceController = TextEditingController(text: '2500');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ResponsiveDialog(
        title: strings.priceService,
        maxWidth: 420,
        content: TextField(
          controller: priceController,
          decoration: InputDecoration(labelText: strings.price),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.close),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final token = ref.read(authControllerProvider).accessToken!;
                await ref.read(apiServiceProvider).post(
                  '/admin/service-orders/$orderId/price',
                  token: token,
                  data: {'quotedPrice': priceController.text.trim()},
                );
                if (!mounted || !dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
                await _load(silent: true);
              } catch (error) {
                if (!mounted || !dialogContext.mounted) {
                  return;
                }
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(describeApiError(error))),
                );
              }
            },
            child: Text(strings.save),
          ),
        ],
      ),
    );

    priceController.dispose();
  }

  Future<void> _confirmServiceOrder(String orderId) async {
    final token = ref.read(authControllerProvider).accessToken!;
    try {
      await ref.read(apiServiceProvider).post(
        '/admin/service-orders/$orderId/confirm',
        token: token,
      );
      await _load(silent: true);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _readyServiceOrder(String orderId) async {
    final token = ref.read(authControllerProvider).accessToken!;
    try {
      await ref.read(apiServiceProvider).post(
        '/admin/service-orders/$orderId/ready',
        token: token,
      );
      await _load(silent: true);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _printServiceOrder(Map<String, dynamic> serviceOrder) async {
    final token = ref.read(authControllerProvider).accessToken!;
    final fallbackMessage = context.strings.noPrinterFallback;
    try {
      final response = await ref.read(apiServiceProvider).post(
        '/admin/service-orders/${serviceOrder['id']}/print',
        token: token,
      );
      final path = response['printableFileUrl']?.toString();
      if (path == null || path.isEmpty) {
        _showError(Exception(fallbackMessage));
        return;
      }

      final bytes = await ref.read(apiServiceProvider).downloadBytes(path, token: token);
      await Printing.layoutPdf(onLayout: (_) async => Uint8List.fromList(bytes));
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _showDeliveryUserDialog({Map<String, dynamic>? deliveryUser}) async {
    final strings = context.strings;
    final user = deliveryUser?['user'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final fullNameController =
        TextEditingController(text: user['fullName']?.toString() ?? '');
    final phoneController =
        TextEditingController(text: user['phone']?.toString() ?? '');
    final passwordController = TextEditingController();
    final vehicleInfoController =
        TextEditingController(text: deliveryUser?['vehicleInfo']?.toString() ?? '');
    final notesController =
        TextEditingController(text: deliveryUser?['notes']?.toString() ?? '');
    var isActive = deliveryUser == null ? true : deliveryUser['isActive'] == true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => ResponsiveDialog(
          title:
            deliveryUser == null ? strings.createDeliveryUser : strings.edit,
          maxWidth: 460,
          content: Column(
            children: [
                  TextField(
                    controller: fullNameController,
                    decoration: InputDecoration(labelText: strings.fullName),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(labelText: strings.phone),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(labelText: strings.password),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: vehicleInfoController,
                    decoration: InputDecoration(labelText: strings.vehicleInfo),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(labelText: strings.notes),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: isActive,
                    onChanged: (value) => setDialogState(() => isActive = value),
                    title: Text(strings.active),
                  ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(strings.close),
            ),
            FilledButton(
              onPressed: () async {
                final phone = phoneController.text.trim();
                final password = passwordController.text.trim();
                if (fullNameController.text.trim().isEmpty || phone.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(strings.requiredField)),
                  );
                  return;
                }
                if (!RegExp(r'^07\d{9}$').hasMatch(phone)) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(strings.invalidPhone)),
                  );
                  return;
                }
                if (deliveryUser == null && password.length < 8) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(strings.passwordTooShort)),
                  );
                  return;
                }
                try {
                  final token = ref.read(authControllerProvider).accessToken!;
                  final data = {
                    'fullName': fullNameController.text.trim(),
                    'phone': phone,
                    'vehicleInfo': vehicleInfoController.text.trim(),
                    'notes': notesController.text.trim(),
                    'isActive': '$isActive',
                    if (password.isNotEmpty) 'password': password,
                  };

                  if (deliveryUser == null) {
                    await ref.read(apiServiceProvider).post(
                      '/admin/delivery-users',
                      token: token,
                      data: data,
                    );
                  } else {
                    await ref.read(apiServiceProvider).patch(
                      '/admin/delivery-users/${deliveryUser['id']}',
                      token: token,
                      data: data,
                    );
                  }
                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }
                  Navigator.of(dialogContext).pop();
                  await _load(silent: true);
                } catch (error) {
                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(describeApiError(error))),
                  );
                }
              },
              child: Text(strings.save),
            ),
          ],
        ),
      ),
    );

    fullNameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    vehicleInfoController.dispose();
    notesController.dispose();
  }

  Future<void> _showPromoCodeDialog() async {
    final strings = context.strings;
    final codeController = TextEditingController(text: 'ALISHO15');
    final valueController = TextEditingController(text: '15');
    final startsAtController = TextEditingController(text: '2026-06-01T00:00:00.000Z');
    final endsAtController = TextEditingController(text: '2027-06-01T00:00:00.000Z');
    final maxUsesController = TextEditingController(text: '500');
    final maxUsesPerUserController = TextEditingController(text: '3');
    var discountType = 'PERCENTAGE';
    var isActive = true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => ResponsiveDialog(
          title: strings.createPromoCode,
          maxWidth: 460,
          content: Column(
            children: [
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(labelText: strings.promoCode),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: discountType,
                    decoration: InputDecoration(labelText: strings.discountType),
                    items: [
                      DropdownMenuItem(value: 'PERCENTAGE', child: Text(strings.percentage)),
                      DropdownMenuItem(value: 'FIXED', child: Text(strings.fixedAmount)),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => discountType = value ?? 'PERCENTAGE'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: valueController,
                    decoration: InputDecoration(labelText: strings.value),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: startsAtController,
                    decoration: InputDecoration(labelText: strings.startsAt),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: endsAtController,
                    decoration: InputDecoration(labelText: strings.endsAt),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: maxUsesController,
                    decoration: InputDecoration(labelText: strings.maxUses),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: maxUsesPerUserController,
                    decoration: InputDecoration(labelText: strings.maxUsesPerUser),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: isActive,
                    onChanged: (value) => setDialogState(() => isActive = value),
                    title: Text(strings.active),
                  ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(strings.close),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final token = ref.read(authControllerProvider).accessToken!;
                  await ref.read(apiServiceProvider).post(
                    '/admin/promo-codes',
                    token: token,
                    data: {
                      'code': codeController.text.trim(),
                      'discountType': discountType,
                      'value': valueController.text.trim(),
                      'startsAt': startsAtController.text.trim(),
                      'endsAt': endsAtController.text.trim(),
                      'maxUses': maxUsesController.text.trim(),
                      'maxUsesPerUser': maxUsesPerUserController.text.trim(),
                      'isActive': '$isActive',
                    },
                  );
                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }
                  Navigator.of(dialogContext).pop();
                  await _load(silent: true);
                } catch (error) {
                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(describeApiError(error))),
                  );
                }
              },
              child: Text(strings.save),
            ),
          ],
        ),
      ),
    );

    codeController.dispose();
    valueController.dispose();
    startsAtController.dispose();
    endsAtController.dispose();
    maxUsesController.dispose();
    maxUsesPerUserController.dispose();
  }

  Future<void> _showServiceDialog() async {
    final strings = context.strings;
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final defaultPriceController = TextEditingController(text: '250');
    var pricingMode = 'PER_PAGE';
    var requiresFiles = true;
    var requiresImages = false;
    var isActive = true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => ResponsiveDialog(
          title: strings.createService,
          maxWidth: 460,
          content: Column(
            children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: strings.title),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(labelText: strings.description),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: defaultPriceController,
                    decoration: InputDecoration(labelText: strings.price),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: pricingMode,
                    decoration: InputDecoration(labelText: strings.pricingMode),
                    items: [
                      DropdownMenuItem(value: 'PER_PAGE', child: Text(strings.perPage)),
                      DropdownMenuItem(value: 'PER_FILE', child: Text(strings.perFile)),
                      DropdownMenuItem(value: 'MANUAL_REVIEW', child: Text(strings.manualReview)),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => pricingMode = value ?? 'PER_PAGE'),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: requiresFiles,
                    onChanged: (value) => setDialogState(() => requiresFiles = value),
                    title: Text(strings.requiresFiles),
                  ),
                  SwitchListTile(
                    value: requiresImages,
                    onChanged: (value) => setDialogState(() => requiresImages = value),
                    title: Text(strings.requiresImages),
                  ),
                  SwitchListTile(
                    value: isActive,
                    onChanged: (value) => setDialogState(() => isActive = value),
                    title: Text(strings.active),
                  ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(strings.close),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final token = ref.read(authControllerProvider).accessToken!;
                  await ref.read(apiServiceProvider).post(
                    '/admin/services',
                    token: token,
                    data: {
                      'name': nameController.text.trim(),
                      'description': descriptionController.text.trim(),
                      'defaultPrice': defaultPriceController.text.trim(),
                      'pricingMode': pricingMode,
                      'requiresFiles': '$requiresFiles',
                      'requiresImages': '$requiresImages',
                      'isActive': '$isActive',
                    },
                  );
                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }
                  Navigator.of(dialogContext).pop();
                  await _load(silent: true);
                } catch (error) {
                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(describeApiError(error))),
                  );
                }
              },
              child: Text(strings.save),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    descriptionController.dispose();
    defaultPriceController.dispose();
  }

  Future<void> _showBannerDialog() async {
    final strings = context.strings;
    final titleController = TextEditingController(text: strings.todayOffers);
    final descriptionController = TextEditingController();
    final linkController = TextEditingController();
    final sortOrderController = TextEditingController(text: '1');
    var isActive = true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => ResponsiveDialog(
          title: strings.createBanner,
          maxWidth: 460,
          content: Column(
            children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(labelText: strings.title),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(labelText: strings.description),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: linkController,
                    decoration: InputDecoration(labelText: strings.link),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sortOrderController,
                    decoration: InputDecoration(labelText: strings.sortOrder),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: isActive,
                    onChanged: (value) => setDialogState(() => isActive = value),
                    title: Text(strings.active),
                  ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(strings.close),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final token = ref.read(authControllerProvider).accessToken!;
                  await ref.read(apiServiceProvider).post(
                    '/admin/banners',
                    token: token,
                    data: {
                      'title': titleController.text.trim(),
                      'description': descriptionController.text.trim(),
                      'link': linkController.text.trim(),
                      'sortOrder': sortOrderController.text.trim(),
                      'isActive': '$isActive',
                    },
                  );
                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }
                  Navigator.of(dialogContext).pop();
                  await _load(silent: true);
                } catch (error) {
                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(describeApiError(error))),
                  );
                }
              },
              child: Text(strings.save),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    descriptionController.dispose();
    linkController.dispose();
    sortOrderController.dispose();
  }

  Future<void> _showSettingsDialog() async {
    final strings = context.strings;
    final settings = _settings ?? <String, dynamic>{};
    final deliveryFee = settings['deliveryFee'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final serviceFee = settings['serviceFee'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final appPreferences =
        settings['appPreferences'] as Map<String, dynamic>? ?? <String, dynamic>{};

    final deliveryAmountController =
        TextEditingController(text: deliveryFee['amount']?.toString() ?? '1000');
    final serviceAmountController =
        TextEditingController(text: serviceFee['amount']?.toString() ?? '500');
    final extraFeeAmountController =
        TextEditingController(text: serviceFee['extraFeeAmount']?.toString() ?? '0');
    final appPreferencesController =
        TextEditingController(text: jsonEncode(appPreferences));
    var deliveryMode = deliveryFee['mode']?.toString() ?? 'FIXED';
    var serviceMode = serviceFee['mode']?.toString() ?? 'FIXED';
    var deliveryEnabled = deliveryFee['isEnabled'] == true;
    var serviceEnabled = serviceFee['isEnabled'] == true;
    var extraFeeEnabled = serviceFee['extraFeeEnabled'] == true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => ResponsiveDialog(
          title: strings.settings,
          content: Column(
            children: [
                  DropdownButtonFormField<String>(
                    initialValue: deliveryMode,
                    decoration: InputDecoration(labelText: strings.deliveryFeeMode),
                    items: [
                      DropdownMenuItem(value: 'FIXED', child: Text(strings.fixedAmount)),
                      DropdownMenuItem(value: 'PERCENTAGE', child: Text(strings.percentage)),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => deliveryMode = value ?? 'FIXED'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: deliveryAmountController,
                    decoration: InputDecoration(labelText: strings.deliveryFeeAmount),
                    keyboardType: TextInputType.number,
                  ),
                  SwitchListTile(
                    value: deliveryEnabled,
                    onChanged: (value) => setDialogState(() => deliveryEnabled = value),
                    title: Text(strings.deliveryFee),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: serviceMode,
                    decoration: InputDecoration(labelText: strings.serviceFeeMode),
                    items: [
                      DropdownMenuItem(value: 'FIXED', child: Text(strings.fixedAmount)),
                      DropdownMenuItem(value: 'PERCENTAGE', child: Text(strings.percentage)),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => serviceMode = value ?? 'FIXED'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: serviceAmountController,
                    decoration: InputDecoration(labelText: strings.serviceFeeAmount),
                    keyboardType: TextInputType.number,
                  ),
                  SwitchListTile(
                    value: serviceEnabled,
                    onChanged: (value) => setDialogState(() => serviceEnabled = value),
                    title: Text(strings.serviceFee),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: extraFeeAmountController,
                    decoration: InputDecoration(labelText: strings.extraFee),
                    keyboardType: TextInputType.number,
                  ),
                  SwitchListTile(
                    value: extraFeeEnabled,
                    onChanged: (value) => setDialogState(() => extraFeeEnabled = value),
                    title: Text(strings.extraFee),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: appPreferencesController,
                    maxLines: 5,
                    decoration: InputDecoration(labelText: strings.appPreferencesJson),
                  ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(strings.close),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final token = ref.read(authControllerProvider).accessToken!;
                  await ref.read(apiServiceProvider).patch(
                    '/admin/settings',
                    token: token,
                    data: {
                      'deliveryMode': deliveryMode,
                      'deliveryAmount': deliveryAmountController.text.trim(),
                      'deliveryEnabled': '$deliveryEnabled',
                      'serviceMode': serviceMode,
                      'serviceAmount': serviceAmountController.text.trim(),
                      'serviceEnabled': '$serviceEnabled',
                      'extraFeeAmount': extraFeeAmountController.text.trim(),
                      'extraFeeEnabled': '$extraFeeEnabled',
                      'appPreferencesJson': appPreferencesController.text.trim(),
                    },
                  );
                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }
                  Navigator.of(dialogContext).pop();
                  await _load(silent: true);
                } catch (error) {
                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(describeApiError(error))),
                  );
                }
              },
              child: Text(strings.save),
            ),
          ],
        ),
      ),
    );

    deliveryAmountController.dispose();
    serviceAmountController.dispose();
    extraFeeAmountController.dispose();
    appPreferencesController.dispose();
  }

  Future<void> _deleteEntity(String path) async {
    final token = ref.read(authControllerProvider).accessToken!;
    try {
      await ref.read(apiServiceProvider).delete(path, token: token);
      await _load(silent: true);
    } catch (error) {
      _showError(error);
    }
  }

  String _kpiLabel(String key) {
    final strings = context.strings;
    return switch (key) {
      'salesToday' => strings.salesToday,
      'salesMonth' => strings.salesMonth,
      'ordersToday' => strings.ordersToday,
      'ordersMonth' => strings.ordersMonth,
      'pendingOrders' => strings.pendingOrders,
      'confirmedOrders' => strings.confirmedOrders,
      'ordersInDelivery' => strings.ordersInDelivery,
      'deliveredOrders' => strings.deliveredOrders,
      'returnedOrders' => strings.returnedOrders,
      'totalDiscounts' => strings.totalDiscounts,
      'netSales' => strings.netSales,
      'totalDeliveryFees' => strings.totalDeliveryFees,
      'totalServiceFees' => strings.totalServiceFees,
      _ => key,
    };
  }

  Future<void> _openFile(String path) async {
    final errorMessage = context.strings.systemError;
    final uri = Uri.parse(ref.read(apiServiceProvider).resolveUrl(path));
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showError(Exception(errorMessage));
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
