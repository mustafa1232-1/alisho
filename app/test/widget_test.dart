import 'dart:convert';
import 'package:alisholibrary/src/app.dart';
import 'package:alisholibrary/src/core/api_service.dart';
import 'package:alisholibrary/src/core/app_locale.dart';
import 'package:alisholibrary/src/screens/admin_shell.dart';
import 'package:alisholibrary/src/screens/auth_screen.dart';
import 'package:alisholibrary/src/screens/customer_shell.dart';
import 'package:dio/dio.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeApiService extends ApiService {
  FakeApiService() : super(Dio());

  @override
  Future<dynamic> get(
    String path, {
    String? token,
    Map<String, dynamic>? queryParameters,
  }) async {
    switch (path) {
      case '/admin/dashboard/kpis':
        return <String, dynamic>{'salesToday': 0, 'ordersToday': 0};
      case '/admin/products':
      case '/admin/orders':
      case '/admin/service-orders':
      case '/admin/delivery-users':
        return <dynamic>[];
      case '/admin/settings':
        return <String, dynamic>{};
      case '/customer/home':
        return <String, dynamic>{
          'products': <dynamic>[],
          'services': <dynamic>[],
          'banners': <dynamic>[],
          'unreadNotifications': 0,
        };
      case '/meta/registration':
        return <String, dynamic>{
          'blocks': <String, dynamic>{
            'A': <String, dynamic>{
              'A1': <dynamic>[101, 102],
            },
            'B': <String, dynamic>{
              'B1': <dynamic>[101, 102],
            },
          },
          'studentStages': <dynamic>['Primary', 'University'],
        };
      case '/customer/cart':
        return <String, dynamic>{
          'items': <dynamic>[],
          'pricing': <String, dynamic>{},
        };
      case '/customer/orders':
      case '/customer/services':
      case '/customer/notifications':
        return <dynamic>[];
      default:
        return <dynamic>[];
    }
  }
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  void setPhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
  }

  testWidgets('app redirects anonymous users to login', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          apiServiceProvider.overrideWithValue(FakeApiService()),
        ],
        child: const AlishoApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
  });

  testWidgets('app restores admin sessions into the admin shell', (tester) async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'access_token': 'admin-access',
      'refresh_token': 'admin-refresh',
      'user_payload': jsonEncode(<String, dynamic>{
        'role': 'ADMIN',
        'fullName': 'Admin User',
        'phone': '07700000000',
      }),
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          apiServiceProvider.overrideWithValue(FakeApiService()),
        ],
        child: const AlishoApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(AdminShell), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('app restores customer sessions into the customer shell', (tester) async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'access_token': 'customer-access',
      'refresh_token': 'customer-refresh',
      'user_payload': jsonEncode(<String, dynamic>{
        'role': 'CUSTOMER',
        'fullName': 'Customer User',
        'phone': '07722222222',
      }),
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          apiServiceProvider.overrideWithValue(FakeApiService()),
        ],
        child: const AlishoApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(CustomerShell), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('register screen stays stable on narrow phones', (tester) async {
    setPhoneViewport(tester);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          apiServiceProvider.overrideWithValue(FakeApiService()),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            final strings = context.strings;
            return Directionality(
              textDirection: strings.direction,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const AuthScreen(isRegister: true),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin product dialog opens on narrow phones without overflow', (tester) async {
    setPhoneViewport(tester);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'access_token': 'admin-access',
      'refresh_token': 'admin-refresh',
      'user_payload': jsonEncode(<String, dynamic>{
        'role': 'ADMIN',
        'fullName': 'Admin User',
        'phone': '07700000000',
      }),
    });

    final strings = AppStrings(const Locale('ar'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          apiServiceProvider.overrideWithValue(FakeApiService()),
        ],
        child: const AlishoApp(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.products));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, strings.createProduct));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin delivery dialog opens on narrow phones without overflow', (tester) async {
    setPhoneViewport(tester);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'access_token': 'admin-access',
      'refresh_token': 'admin-refresh',
      'user_payload': jsonEncode(<String, dynamic>{
        'role': 'ADMIN',
        'fullName': 'Admin User',
        'phone': '07700000000',
      }),
    });

    final strings = AppStrings(const Locale('ar'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          apiServiceProvider.overrideWithValue(FakeApiService()),
        ],
        child: const AlishoApp(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.delivery));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, strings.createDeliveryUser));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
