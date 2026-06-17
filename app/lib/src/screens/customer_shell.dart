import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api_service.dart';
import '../core/app_locale.dart';
import '../core/auth_controller.dart';
import '../widgets/common_views.dart';
import '../widgets/language_button.dart';
import '../widgets/responsive_dialog.dart';

class CustomerShell extends ConsumerStatefulWidget {
  const CustomerShell({super.key});

  @override
  ConsumerState<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends ConsumerState<CustomerShell> {
  final _promoController = TextEditingController();
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _home;
  Map<String, dynamic>? _cart;
  List<dynamic> _orders = const [];
  List<dynamic> _services = const [];
  List<dynamic> _serviceOrders = const [];
  List<dynamic> _notifications = const [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _loadAll({bool silent = false}) async {
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
        api.get('/customer/home', token: token),
        api.get('/customer/cart', token: token),
        api.get('/customer/orders', token: token),
        api.get('/customer/services', token: token),
        api.get('/customer/service-orders', token: token),
        api.get('/customer/notifications', token: token),
      ]);

      if (!mounted) {
        return;
      }

      final cart = responses[1] as Map<String, dynamic>;
      _promoController.text = cart['promoCode']?.toString() ?? '';

      setState(() {
        _home = responses[0] as Map<String, dynamic>;
        _cart = cart;
        _orders = responses[2] as List<dynamic>;
        _services = responses[3] as List<dynamic>;
        _serviceOrders = responses[4] as List<dynamic>;
        _notifications = responses[5] as List<dynamic>;
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
    final user = ref.watch(authControllerProvider).user ?? <String, dynamic>{};
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
        title: Text(strings.appName),
        actions: [
          IconButton(
            tooltip: strings.refresh,
            onPressed: () => _loadAll(silent: true),
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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: views[_currentIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            label: strings.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.shopping_cart_outlined),
            label: strings.cart,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            label: strings.orders,
          ),
          NavigationDestination(
            icon: const Icon(Icons.print_outlined),
            label: strings.services,
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _notifications.any((item) => item['isRead'] == false),
              child: const Icon(Icons.notifications_none_rounded),
            ),
            label: strings.notifications,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            label: strings.account,
          ),
        ],
      ),
    );
  }

  Widget _homeView() {
    final strings = context.strings;

    if (_isLoading && _home == null) {
      return const LoadingView();
    }
    if (_error != null && _home == null) {
      return ErrorView(message: _error!, onRetry: _loadAll);
    }

    final home = _home ?? <String, dynamic>{};
    final products = (home['products'] as List<dynamic>? ?? const <dynamic>[]);
    final banners = (home['banners'] as List<dynamic>? ?? const <dynamic>[]);
    final quickActions =
        (home['quickActions'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => item.toString())
            .toList();
    final store = home['store'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final unreadNotifications = home['unreadNotifications'] as int? ?? 0;

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF243640), Color(0xFF5F7352)],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.translateContent(
                    store['nameAr']?.toString() ?? strings.appName,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  store['nameEn']?.toString() ?? strings.appSubtitle,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _metricChip(
                      Icons.local_offer_outlined,
                      '${quickActions.length}',
                      strings.quickActions,
                    ),
                    _metricChip(
                      Icons.notifications_active_outlined,
                      '$unreadNotifications',
                      strings.notifications,
                    ),
                    _metricChip(
                      Icons.grid_view_rounded,
                      '${products.length}',
                      strings.products,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (banners.isNotEmpty) ...[
            SectionHeader(
              title: strings.banners,
              subtitle: strings.todayOffers,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 146,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: banners.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final banner = banners[index] as Map<String, dynamic>;
                  return Container(
                    width: 260,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: index.isEven
                          ? const Color(0xFFEADFCF)
                          : const Color(0xFFD7E1D1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.translateContent(banner['title']?.toString() ?? ''),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Text(
                            strings.translateContent(
                              banner['description']?.toString() ?? '',
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
          SectionHeader(
            title: strings.quickActions,
            subtitle: strings.customerServiceFlow,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: quickActions
                .map(
                  (label) => Chip(
                    avatar: const Icon(Icons.bolt_rounded, size: 18),
                    label: Text(strings.translateContent(label)),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          SectionHeader(
            title: strings.products,
            subtitle: strings.mostRequested,
          ),
          const SizedBox(height: 12),
          if (products.isEmpty)
            EmptyView(
              icon: Icons.inventory_2_outlined,
              title: strings.emptyProducts,
              subtitle: strings.checkConnection,
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, index) {
                final product = products[index] as Map<String, dynamic>;
                final isAvailable = product['isAvailable'] as bool? ?? false;
                return InkWell(
                  onTap: () => _showProductSheet(product['id'] as String),
                  borderRadius: BorderRadius.circular(24),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE7E0D2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    isAvailable
                                        ? Icons.inventory_2_outlined
                                        : Icons.block_outlined,
                                    size: 42,
                                  ),
                                ),
                                if (!isAvailable)
                                  PositionedDirectional(
                                    top: 10,
                                    start: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        strings.unavailable,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            strings.translateContent(product['name']?.toString() ?? ''),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            strings.translateContent(
                              product['description']?.toString() ?? '',
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                isAvailable
                                    ? Icons.check_circle_outline
                                    : Icons.remove_shopping_cart_outlined,
                                size: 16,
                                color: isAvailable
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  isAvailable
                                      ? strings.openProductHint
                                      : strings.unavailable,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            strings.formatCurrency(product['price']),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonal(
                            onPressed: () => _showProductSheet(product['id'] as String),
                            child: Text(
                              strings.viewProduct,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _cartView() {
    final strings = context.strings;

    if (_isLoading && _cart == null) {
      return const LoadingView();
    }
    if (_error != null && _cart == null) {
      return ErrorView(message: _error!, onRetry: _loadAll);
    }

    final cart = _cart ?? <String, dynamic>{};
    final items = (cart['items'] as List<dynamic>? ?? const <dynamic>[]);
    final pricing = cart['pricing'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final currentUser = ref.watch(authControllerProvider).user ?? <String, dynamic>{};
    final address = currentUser['address'] as Map<String, dynamic>?;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeader(
          title: strings.cart,
          subtitle: strings.cartReview,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.orderMethod,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(strings.orderMethodSummary),
                const SizedBox(height: 8),
                Text(address?['label']?.toString() ?? strings.noAddress),
                const SizedBox(height: 8),
                Text(
                  strings.revisedOrderPolicy,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          EmptyView(
            icon: Icons.shopping_cart_outlined,
            title: strings.emptyCart,
            subtitle: strings.orderMethodSummary,
          )
        else ...[
          for (final rawItem in items) ...[
            _cartItemCard(rawItem as Map<String, dynamic>),
            const SizedBox(height: 12),
          ],
        ],
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _promoController,
                  decoration: InputDecoration(
                    labelText: strings.promoCode,
                    helperText: strings.promoHint,
                    suffixIcon: TextButton(
                      onPressed: items.isEmpty ? null : _applyPromo,
                      child: Text(strings.applyPromo),
                    ),
                  ),
                ),
                if ((cart['promoCode']?.toString().isNotEmpty ?? false)) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Chip(
                      avatar: const Icon(Icons.local_offer_outlined, size: 18),
                      label: Text(cart['promoCode'].toString()),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _priceRow(strings.subtotal, pricing['subtotal']),
                _priceRow(strings.deliveryFee, pricing['deliveryFee']),
                _priceRow(strings.serviceFee, pricing['serviceFee']),
                _priceRow(strings.extraFee, pricing['extraFee']),
                _priceRow(strings.discount, pricing['discount']),
                const Divider(),
                _priceRow(strings.finalTotal, pricing['finalTotal'], emphasized: true),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: items.isEmpty ? null : _checkout,
                  child: Text(strings.reviewAndSendOrder),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _ordersView() {
    final strings = context.strings;

    if (_isLoading && _orders.isEmpty) {
      return const LoadingView();
    }
    if (_error != null && _orders.isEmpty) {
      return ErrorView(message: _error!, onRetry: _loadAll);
    }
    if (_orders.isEmpty) {
      return EmptyView(
        icon: Icons.receipt_long_outlined,
        title: strings.emptyOrders,
        subtitle: strings.orderTracking,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = _orders[index] as Map<String, dynamic>;
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
                Text(strings.formatCurrency(order['finalTotal'])),
                const SizedBox(height: 8),
                Text(order['addressLabel']?.toString() ?? strings.noAddress),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => _showOrderDetails(order['id'] as String),
                      child: Text(strings.details),
                    ),
                    if (status ==
                        'WAITING_CUSTOMER_APPROVAL_AFTER_UNAVAILABLE_ITEMS')
                      FilledButton.tonal(
                        onPressed: () => _approveRevisedOrder(order['id'] as String),
                        child: Text(strings.approveRevisedOrder),
                      ),
                    if (_canCancelOrder(status))
                      TextButton(
                        onPressed: () => _cancelOrder(order['id'] as String),
                        child: Text(strings.cancel),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _servicesView() {
    final strings = context.strings;

    if (_isLoading && _services.isEmpty && _serviceOrders.isEmpty) {
      return const LoadingView();
    }
    if (_error != null && _services.isEmpty && _serviceOrders.isEmpty) {
      return ErrorView(message: _error!, onRetry: _loadAll);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeader(
          title: strings.services,
          subtitle: strings.uploadTip,
        ),
        const SizedBox(height: 12),
        if (_services.isEmpty)
          EmptyView(
            icon: Icons.print_outlined,
            title: strings.emptyServices,
            subtitle: strings.uploadTip,
          )
        else
          ..._services.map((rawService) {
            final service = rawService as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  title: Text(
                    strings.translateContent(service['name']?.toString() ?? ''),
                  ),
                  subtitle: Text(
                    strings.translateContent(
                      service['description']?.toString() ?? '',
                    ),
                  ),
                  trailing: FilledButton.tonal(
                    onPressed: () => _uploadServiceFiles(service),
                    child: Text(strings.chooseFile),
                  ),
                ),
              ),
            );
          }),
        const SizedBox(height: 20),
        SectionHeader(
          title: strings.recentServiceOrders,
          subtitle: strings.customerServiceFlow,
        ),
        const SizedBox(height: 12),
        if (_serviceOrders.isEmpty)
          EmptyView(
            icon: Icons.history_rounded,
            title: strings.noData,
            subtitle: strings.orderTracking,
          )
        else
          ..._serviceOrders.map((rawOrder) {
            final order = rawOrder as Map<String, dynamic>;
            final status = order['status']?.toString();
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
                          Chip(label: Text(strings.serviceOrderStatusLabel(status))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        strings.translateContent(
                          (order['service'] as Map<String, dynamic>?)?['name']
                                  ?.toString() ??
                              '',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(strings.formatCurrency(order['finalTotal'])),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () =>
                                _showServiceOrderDetails(order['id'] as String),
                            child: Text(strings.details),
                          ),
                          if (status ==
                              'PRICED_WAITING_CUSTOMER_APPROVAL')
                            FilledButton.tonal(
                              onPressed: () =>
                                  _approveServicePrice(order['id'] as String),
                              child: Text(strings.approvePrice),
                            ),
                          if ((order['generatedPdfUrl']?.toString().isNotEmpty ?? false))
                            TextButton(
                              onPressed: () => _openFile(
                                order['generatedPdfUrl'].toString(),
                              ),
                              child: Text(strings.filePreview),
                            ),
                          if (_canCancelServiceOrder(status))
                            TextButton(
                              onPressed: () =>
                                  _cancelServiceOrder(order['id'] as String),
                              child: Text(strings.cancel),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _notificationsView() {
    final strings = context.strings;

    if (_isLoading && _notifications.isEmpty) {
      return const LoadingView();
    }
    if (_error != null && _notifications.isEmpty) {
      return ErrorView(message: _error!, onRetry: _loadAll);
    }
    if (_notifications.isEmpty) {
      return EmptyView(
        icon: Icons.notifications_none_rounded,
        title: strings.emptyNotifications,
        subtitle: strings.noData,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _notifications.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _notifications[index] as Map<String, dynamic>;
        final isRead = item['isRead'] == true;
        return Card(
          color: isRead ? null : const Color(0xFFF2E8D9),
          child: ListTile(
            title: Text(strings.translateContent(item['title']?.toString() ?? '')),
            subtitle: Text(
              strings.translateContent(item['body']?.toString() ?? ''),
            ),
            trailing: isRead
                ? const Icon(Icons.done_all_rounded)
                : IconButton(
                    icon: const Icon(Icons.mark_email_read_outlined),
                    onPressed: () => _markNotificationRead(item['id'] as String),
                  ),
          ),
        );
      },
    );
  }

  Widget _profileView(Map<String, dynamic> user) {
    final strings = context.strings;
    final address = user['address'] as Map<String, dynamic>?;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['fullName']?.toString() ?? '',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(user['phone']?.toString() ?? ''),
                const SizedBox(height: 6),
                Text(strings.roleLabel(user['role']?.toString())),
                if (user['customerType'] != null) ...[
                  const SizedBox(height: 6),
                  Text(strings.customerTypeLabel(user['customerType']?.toString())),
                ],
                if (user['studentStage'] != null) ...[
                  const SizedBox(height: 6),
                  Text('${strings.studentStage}: ${user['studentStage']}'),
                ],
                if (user['jobTitle'] != null) ...[
                  const SizedBox(height: 6),
                  Text('${strings.jobTitle}: ${user['jobTitle']}'),
                ],
                if (address != null) ...[
                  const SizedBox(height: 12),
                  Text(address['label']?.toString() ?? strings.noAddress),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.translate_rounded),
            title: Text(strings.language),
            subtitle: Text(
              Localizations.localeOf(context).languageCode == 'ar'
                  ? strings.arabic
                  : strings.english,
            ),
            trailing: const LanguageButton(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          child: Text(strings.logout),
        ),
      ],
    );
  }

  Widget _metricChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            '$value  $label',
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _cartItemCard(Map<String, dynamic> item) {
    final strings = context.strings;
    final product = item['product'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final selectedOptions =
        (item['selectedOptions'] as List<dynamic>? ?? const <dynamic>[]);

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
                IconButton(
                  onPressed: () => _deleteCartItem(item['id'] as String),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            if (selectedOptions.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: selectedOptions.map((rawOption) {
                  final option = rawOption as Map<String, dynamic>;
                  return Chip(
                    label: Text(
                      '${strings.translateContent(option['groupName']?.toString() ?? '')}: '
                      '${strings.translateContent(option['valueName']?.toString() ?? '')}',
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                IconButton(
                  onPressed: () => _updateCartQuantity(
                    item['id'] as String,
                    (item['quantity'] as int) - 1,
                  ),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('${item['quantity']}'),
                IconButton(
                  onPressed: () => _updateCartQuantity(
                    item['id'] as String,
                    (item['quantity'] as int) + 1,
                  ),
                  icon: const Icon(Icons.add_circle_outline),
                ),
                const Spacer(),
                Text(strings.formatCurrency(item['totalPrice'])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(String label, dynamic value, {bool emphasized = false}) {
    final strings = context.strings;
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          Text(strings.formatCurrency(value), style: style),
        ],
      ),
    );
  }

  Future<void> _showProductSheet(String productId) async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) {
      return;
    }

    try {
      final product = await ref
          .read(apiServiceProvider)
          .get('/customer/products/$productId', token: token) as Map<String, dynamic>;
      if (!mounted) {
        return;
      }

      var quantity = 1;
      final selectedByGroup = <String, String>{};
      final optionGroups =
          (product['optionGroups'] as List<dynamic>? ?? const <dynamic>[]);
      final strings = context.strings;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              strings.translateContent(
                                product['name']?.toString() ?? '',
                              ),
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        strings.translateContent(
                          product['description']?.toString() ?? '',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        strings.formatCurrency(product['price']),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      for (final rawGroup in optionGroups) ...[
                        _optionGroupSection(
                          rawGroup as Map<String, dynamic>,
                          selectedByGroup,
                          setSheetState,
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Text(strings.quantity),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: quantity > 1
                                ? () => setSheetState(() => quantity -= 1)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('$quantity'),
                          IconButton(
                            onPressed: () => setSheetState(() => quantity += 1),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () async {
                          try {
                            await _addToCart(
                              productId,
                              quantity,
                              selectedByGroup.values.toList(),
                            );
                            if (!mounted || !context.mounted) {
                              return;
                            }
                            Navigator.of(context).pop();
                          } catch (error) {
                            if (!mounted || !context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(describeApiError(error))),
                            );
                          }
                        },
                        child: Text(strings.addToCart),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (error) {
      _showError(error);
    }
  }

  Widget _optionGroupSection(
    Map<String, dynamic> group,
    Map<String, String> selectedByGroup,
    void Function(void Function()) setSheetState,
  ) {
    final strings = context.strings;
    final values = (group['values'] as List<dynamic>? ?? const <dynamic>[]);
    final groupId = group['id']?.toString() ?? '';
    final selectedValueId = selectedByGroup[groupId];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${strings.translateContent(group['name']?.toString() ?? '')}'
          '${group['isRequired'] == true ? ' *' : ''}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((rawValue) {
            final value = rawValue as Map<String, dynamic>;
            final valueId = value['id']?.toString() ?? '';
            final modifier = value['priceModifier'];
            final modifierText =
                (double.tryParse('$modifier') ?? 0) > 0 ? ' (+${strings.formatCurrency(modifier)})' : '';
            return ChoiceChip(
              selected: selectedValueId == valueId,
              label: Text(
                '${strings.translateContent(value['value']?.toString() ?? '')}$modifierText',
              ),
              onSelected: (_) {
                setSheetState(() {
                  selectedByGroup[groupId] = valueId;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _showOrderDetails(String orderId) async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) {
      return;
    }

    try {
      final order = await ref
          .read(apiServiceProvider)
          .get('/customer/orders/$orderId', token: token) as Map<String, dynamic>;
      if (!mounted) {
        return;
      }

      final strings = context.strings;
      final items = (order['items'] as List<dynamic>? ?? const <dynamic>[]);
      final history =
          (order['statusHistory'] as List<dynamic>? ?? const <dynamic>[]);
      await showDialog<void>(
        context: context,
        builder: (context) => ResponsiveDialog(
          title: order['orderNumber']?.toString() ?? '',
          maxWidth: 560,
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.orderStatusLabel(order['status']?.toString())),
                  const SizedBox(height: 8),
                  Text(order['addressLabel']?.toString() ?? strings.noAddress),
                  const SizedBox(height: 16),
                  Text(strings.orderItems, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final rawItem in items) ...[
                    Text(
                      '${(rawItem as Map<String, dynamic>)['productName']}'
                      ' x ${rawItem['quantity']}',
                    ),
                    const SizedBox(height: 4),
                  ],
                  const SizedBox(height: 16),
                  Text(strings.pricingBreakdown,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _priceRow(strings.subtotal, order['subtotal']),
                  _priceRow(strings.deliveryFee, order['deliveryFee']),
                  _priceRow(strings.serviceFee, order['serviceFee']),
                  _priceRow(strings.extraFee, order['extraFee']),
                  _priceRow(strings.discount, order['discount']),
                  _priceRow(strings.finalTotal, order['finalTotal'], emphasized: true),
                  const SizedBox(height: 16),
                  Text(strings.orderTracking,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final rawStep in history)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '• ${strings.orderStatusLabel((rawStep as Map<String, dynamic>)['status']?.toString())}',
                      ),
                    ),
                ],
              ),
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

  Future<void> _showServiceOrderDetails(String orderId) async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) {
      return;
    }

    try {
      final order = await ref.read(apiServiceProvider).get(
            '/customer/service-orders/$orderId',
            token: token,
          ) as Map<String, dynamic>;
      if (!mounted) {
        return;
      }

      final strings = context.strings;
      final files = (order['files'] as List<dynamic>? ?? const <dynamic>[]);
      await showDialog<void>(
        context: context,
        builder: (context) => ResponsiveDialog(
          title: order['orderNumber']?.toString() ?? '',
          maxWidth: 580,
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.serviceOrderStatusLabel(order['status']?.toString()),
                  ),
                  const SizedBox(height: 8),
                  Text(order['addressLabel']?.toString() ?? strings.noAddress),
                  const SizedBox(height: 16),
                  Text(strings.pricingBreakdown,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _priceRow(strings.subtotal, order['subtotal']),
                  _priceRow(strings.deliveryFee, order['deliveryFee']),
                  _priceRow(strings.serviceFee, order['serviceFee']),
                  _priceRow(strings.extraFee, order['extraFee']),
                  _priceRow(strings.finalTotal, order['finalTotal'], emphasized: true),
                  const SizedBox(height: 16),
                  Text(strings.filePreview,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final rawFile in files) ...[
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
                  if (order['generatedPdfUrl'] != null)
                    TextButton.icon(
                      onPressed: () => _openFile(order['generatedPdfUrl'].toString()),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(strings.generatedPdf),
                    ),
                ],
              ),
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

  Future<void> _addToCart(
    String productId,
    int quantity,
    List<String> selectedOptionValueIds,
  ) async {
    final token = ref.read(authControllerProvider).accessToken!;
    await ref.read(apiServiceProvider).post(
      '/customer/cart/items',
      token: token,
      data: {
        'productId': productId,
        'quantity': quantity,
        'selectedOptionValueIds': selectedOptionValueIds,
      },
    );
    await _loadAll(silent: true);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strings.actionCompleted)),
    );
  }

  Future<void> _updateCartQuantity(String itemId, int quantity) async {
    if (quantity <= 0) {
      await _deleteCartItem(itemId);
      return;
    }

    final token = ref.read(authControllerProvider).accessToken!;

    try {
      await ref.read(apiServiceProvider).patch(
        '/customer/cart/items/$itemId',
        token: token,
        data: {'quantity': quantity},
      );
      await _loadAll(silent: true);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteCartItem(String itemId) async {
    final token = ref.read(authControllerProvider).accessToken!;

    try {
      await ref.read(apiServiceProvider).delete(
        '/customer/cart/items/$itemId',
        token: token,
      );
      await _loadAll(silent: true);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _applyPromo() async {
    final token = ref.read(authControllerProvider).accessToken!;

    try {
      await ref.read(apiServiceProvider).post(
        '/customer/cart/apply-promo',
        token: token,
        data: {'code': _promoController.text.trim()},
      );
      await _loadAll(silent: true);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _checkout() async {
    final strings = context.strings;
    final noteController = TextEditingController();
    final currentUser = ref.read(authControllerProvider).user ?? <String, dynamic>{};
    final address = currentUser['address'] as Map<String, dynamic>?;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ResponsiveDialog(
        title: strings.placeOrder,
        maxWidth: 480,
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.orderMethod,
                style: Theme.of(dialogContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(strings.orderMethodSummary),
              const SizedBox(height: 8),
              Text(address?['label']?.toString() ?? strings.noAddress),
              const SizedBox(height: 8),
              Text(
                strings.revisedOrderPolicy,
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: '${strings.notes} (${strings.optional})',
                  helperText: strings.orderNoteHint,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final token = ref.read(authControllerProvider).accessToken!;
                await ref.read(apiServiceProvider).post(
                  '/customer/orders',
                  token: token,
                  data: {
                    'notes': noteController.text.trim().isEmpty
                        ? null
                        : noteController.text.trim(),
                  },
                );
                if (!mounted || !dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
                await _loadAll(silent: true);
              } catch (error) {
                if (!mounted || !dialogContext.mounted) {
                  return;
                }
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(describeApiError(error))),
                );
              }
            },
            child: Text(strings.placeOrder),
          ),
        ],
      ),
    );

    noteController.dispose();
  }

  Future<void> _approveRevisedOrder(String orderId) async {
    final token = ref.read(authControllerProvider).accessToken!;

    try {
      await ref.read(apiServiceProvider).post(
        '/customer/orders/$orderId/approve-revised',
        token: token,
      );
      await _loadAll(silent: true);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    final strings = context.strings;
    final reasonController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ResponsiveDialog(
        title: strings.cancel,
        maxWidth: 420,
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: '${strings.reason} (${strings.optional})',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.close),
          ),
          FilledButton.tonal(
            onPressed: () async {
              try {
                final token = ref.read(authControllerProvider).accessToken!;
                await ref.read(apiServiceProvider).post(
                  '/customer/orders/$orderId/cancel',
                  token: token,
                  data: {
                    'reason': reasonController.text.trim().isEmpty
                        ? null
                        : reasonController.text.trim(),
                  },
                );
                if (!mounted || !dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
                await _loadAll(silent: true);
              } catch (error) {
                if (!mounted || !dialogContext.mounted) {
                  return;
                }
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(describeApiError(error))),
                );
              }
            },
            child: Text(strings.cancel),
          ),
        ],
      ),
    );

    reasonController.dispose();
  }

  Future<void> _uploadServiceFiles(Map<String, dynamic> service) async {
    final strings = context.strings;
    final token = ref.read(authControllerProvider).accessToken!;
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) {
      return;
    }

    final noteController = TextEditingController();
    String? confirmedNote;

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ResponsiveDialog(
        title: strings.uploadFiles,
        maxWidth: 480,
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${result.files.length} ${strings.filesSelected}'),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: '${strings.notes} (${strings.optional})',
                  helperText: strings.notesForOrder,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () {
              confirmedNote = noteController.text.trim();
              Navigator.of(dialogContext).pop();
            },
            child: Text(strings.save),
          ),
        ],
      ),
    );

    final note = confirmedNote;
    noteController.dispose();

    if (note == null) {
      return;
    }

    try {
      final files = <MultipartFile>[];
      for (final file in result.files) {
        if (file.bytes != null) {
          files.add(MultipartFile.fromBytes(file.bytes!, filename: file.name));
        } else if (file.path != null) {
          files.add(await MultipartFile.fromFile(file.path!, filename: file.name));
        }
      }

      if (files.isEmpty) {
        throw Exception(strings.uploadTip);
      }

      await ref.read(apiServiceProvider).postMultipart(
        '/customer/service-orders',
        token: token,
        fields: {
          'serviceId': service['id'],
          if (note.isNotEmpty) 'notes': note,
        },
        files: files,
      );

      await _loadAll(silent: true);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.actionCompleted)),
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _approveServicePrice(String orderId) async {
    final token = ref.read(authControllerProvider).accessToken!;

    try {
      await ref.read(apiServiceProvider).post(
        '/customer/service-orders/$orderId/approve-price',
        token: token,
      );
      await _loadAll(silent: true);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _cancelServiceOrder(String orderId) async {
    final strings = context.strings;
    final reasonController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ResponsiveDialog(
        title: strings.cancel,
        maxWidth: 420,
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: '${strings.reason} (${strings.optional})',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.close),
          ),
          FilledButton.tonal(
            onPressed: () async {
              try {
                final token = ref.read(authControllerProvider).accessToken!;
                await ref.read(apiServiceProvider).post(
                  '/customer/service-orders/$orderId/cancel',
                  token: token,
                  data: {
                    'reason': reasonController.text.trim().isEmpty
                        ? null
                        : reasonController.text.trim(),
                  },
                );
                if (!mounted || !dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
                await _loadAll(silent: true);
              } catch (error) {
                if (!mounted || !dialogContext.mounted) {
                  return;
                }
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(describeApiError(error))),
                );
              }
            },
            child: Text(strings.cancel),
          ),
        ],
      ),
    );

    reasonController.dispose();
  }

  Future<void> _markNotificationRead(String notificationId) async {
    final token = ref.read(authControllerProvider).accessToken!;

    try {
      await ref.read(apiServiceProvider).patch(
        '/notifications/$notificationId/read',
        token: token,
      );
      await _loadAll(silent: true);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openFile(String path) async {
    final errorMessage = context.strings.systemError;
    final uri = Uri.parse(ref.read(apiServiceProvider).resolveUrl(path));
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  bool _canCancelOrder(String? status) {
    return !const {
      'DELIVERED',
      'FAILED_DELIVERY',
      'RETURNED',
      'CANCELLED',
      'ARCHIVED',
    }.contains(status);
  }

  bool _canCancelServiceOrder(String? status) {
    return !const {
      'DELIVERED',
      'FAILED_DELIVERY',
      'RETURNED',
      'CANCELLED',
      'ARCHIVED',
    }.contains(status);
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
