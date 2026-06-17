import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appLocaleProvider =
    StateNotifierProvider<AppLocaleController, Locale>((ref) {
  return AppLocaleController();
});

class AppLocaleController extends StateNotifier<Locale> {
  AppLocaleController() : super(const Locale('ar'));

  bool get isArabic => state.languageCode == 'ar';

  void setLocale(Locale locale) {
    if (locale.languageCode == state.languageCode) {
      return;
    }
    state = locale;
  }

  void toggle() {
    state = isArabic ? const Locale('en') : const Locale('ar');
  }
}

class AppStrings {
  AppStrings(this.locale);

  final Locale locale;

  bool get isArabic => locale.languageCode == 'ar';
  TextDirection get direction =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  String get appName => isArabic ? 'مكتبة عليشو' : 'Alisho Library';
  String get appSubtitle => isArabic
      ? 'مكتبة، مطبعة، وخدمات طلابية'
      : 'Library, printing, and student services';
  String get login => isArabic ? 'تسجيل الدخول' : 'Login';
  String get register => isArabic ? 'إنشاء حساب' : 'Create account';
  String get createAccount => isArabic ? 'إنشاء حساب جديد' : 'Create a new account';
  String get fullName => isArabic ? 'الاسم الكامل' : 'Full name';
  String get age => isArabic ? 'العمر' : 'Age';
  String get phone => isArabic ? 'رقم الهاتف' : 'Phone number';
  String get password => isArabic ? 'كلمة المرور' : 'Password';
  String get confirmPassword =>
      isArabic ? 'تأكيد كلمة المرور' : 'Confirm password';
  String get streetAddress => isArabic ? 'عنوان السكن' : 'Street address';
  String get block => isArabic ? 'البلوك' : 'Block';
  String get complex => isArabic ? 'المجمع' : 'Complex';
  String get building => isArabic ? 'العمارة' : 'Building';
  String get apartment => isArabic ? 'رقم الشقة' : 'Apartment';
  String get customerType => isArabic ? 'نوع المستخدم' : 'Customer type';
  String get studentStage => isArabic ? 'المرحلة الدراسية' : 'Student stage';
  String get jobTitle => isArabic ? 'الوظيفة' : 'Job title';
  String get student => isArabic ? 'طالب' : 'Student';
  String get employee => isArabic ? 'موظف' : 'Employee';
  String get retry => isArabic ? 'إعادة المحاولة' : 'Retry';
  String get submit => isArabic ? 'إرسال' : 'Submit';
  String get cancel => isArabic ? 'إلغاء' : 'Cancel';
  String get save => isArabic ? 'حفظ' : 'Save';
  String get delete => isArabic ? 'حذف' : 'Delete';
  String get edit => isArabic ? 'تعديل' : 'Edit';
  String get close => isArabic ? 'إغلاق' : 'Close';
  String get refresh => isArabic ? 'تحديث' : 'Refresh';
  String get loading => isArabic ? 'جارٍ التحميل...' : 'Loading...';
  String get language => isArabic ? 'اللغة' : 'Language';
  String get arabic => isArabic ? 'العربية' : 'Arabic';
  String get english => isArabic ? 'الإنكليزية' : 'English';
  String get home => isArabic ? 'الرئيسية' : 'Home';
  String get cart => isArabic ? 'السلة' : 'Cart';
  String get cartReview => isArabic ? 'راجع السلة قبل الإرسال' : 'Review your cart before sending';
  String get orders => isArabic ? 'الطلبات' : 'Orders';
  String get services => isArabic ? 'الخدمات' : 'Services';
  String get notifications => isArabic ? 'الإشعارات' : 'Notifications';
  String get account => isArabic ? 'الحساب' : 'Account';
  String get dashboard => isArabic ? 'لوحة التحكم' : 'Dashboard';
  String get products => isArabic ? 'المنتجات' : 'Products';
  String get delivery => isArabic ? 'الدلفري' : 'Delivery';
  String get settings => isArabic ? 'الإعدادات' : 'Settings';
  String get marketing => isArabic ? 'العروض والإدارة' : 'Marketing';
  String get adminPanel => isArabic ? 'لوحة الأدمن' : 'Admin panel';
  String get deliveryPanel => isArabic ? 'لوحة الدلفري' : 'Delivery panel';
  String get addToCart => isArabic ? 'إضافة للسلة' : 'Add to cart';
  String get viewProduct => isArabic ? 'عرض المادة' : 'View item';
  String get unavailable => isArabic ? 'غير متوفر' : 'Unavailable';
  String get available => isArabic ? 'متوفر' : 'Available';
  String get details => isArabic ? 'التفاصيل' : 'Details';
  String get banners => isArabic ? 'الإعلانات' : 'Banners';
  String get quickActions => isArabic ? 'اختصارات سريعة' : 'Quick actions';
  String get todayOffers => isArabic ? 'عروض اليوم' : "Today's offers";
  String get mostRequested => isArabic ? 'الأكثر طلباً' : 'Most requested';
  String get printArchive => isArabic ? 'أرشيف الطباعة' : 'Print archive';
  String get recentServiceOrders =>
      isArabic ? 'طلبات الخدمة الأخيرة' : 'Recent service orders';
  String get emptyCart => isArabic ? 'السلة فارغة حالياً.' : 'Your cart is empty.';
  String get emptyOrders => isArabic ? 'لا توجد طلبات بعد.' : 'No orders yet.';
  String get emptyServices =>
      isArabic ? 'لا توجد خدمات متاحة حالياً.' : 'No services are available right now.';
  String get emptyNotifications => isArabic
      ? 'لا توجد إشعارات حالياً.'
      : 'No notifications right now.';
  String get emptyProducts =>
      isArabic ? 'لا توجد منتجات متاحة حالياً.' : 'No products are available right now.';
  String get chooseFile => isArabic ? 'رفع ملف' : 'Upload file';
  String get uploadFiles => isArabic ? 'رفع الملفات' : 'Upload files';
  String get checkout => isArabic ? 'تأكيد الطلب' : 'Checkout';
  String get reviewAndSendOrder =>
      isArabic ? 'مراجعة وإرسال الطلب' : 'Review and send order';
  String get placeOrder => isArabic ? 'إرسال الطلب' : 'Place order';
  String get applyPromo => isArabic ? 'تطبيق البروموكود' : 'Apply promo code';
  String get promoCode => isArabic ? 'بروموكود' : 'Promo code';
  String get promoHint => isArabic
      ? 'البروموكود يطبّق على طلبات المنتجات فقط.'
      : 'Promo codes apply to product orders only.';
  String get subtotal => isArabic ? 'المجموع الفرعي' : 'Subtotal';
  String get deliveryFee => isArabic ? 'أجور التوصيل' : 'Delivery fee';
  String get serviceFee => isArabic ? 'عمولة الخدمة' : 'Service fee';
  String get extraFee => isArabic ? 'رسوم إضافية' : 'Extra fee';
  String get discount => isArabic ? 'الخصم' : 'Discount';
  String get finalTotal => isArabic ? 'الإجمالي النهائي' : 'Final total';
  String get quantity => isArabic ? 'الكمية' : 'Quantity';
  String get notes => isArabic ? 'ملاحظات' : 'Notes';
  String get optional => isArabic ? 'اختياري' : 'Optional';
  String get noAddress => isArabic ? 'لا يوجد عنوان محفوظ' : 'No saved address';
  String get orderMethod => isArabic ? 'طريقة الطلب' : 'Order method';
  String get orderMethodSummary => isArabic
      ? 'سيتم إرسال الطلب إلى المكتبة ثم توصيله إلى عنوانك المحفوظ بعد التأكيد.'
      : 'Your order will be sent to the store, then delivered to your saved address after confirmation.';
  String get revisedOrderPolicy => isArabic
      ? 'إذا أصبحت مادة غير متوفرة، سنرسل لك طلباً معدلاً لتوافق عليه أو تلغيه.'
      : 'If an item becomes unavailable, we will send you a revised order to approve or cancel.';
  String get orderNoteHint => isArabic
      ? 'يمكنك إضافة ملاحظة للمكتبة قبل إرسال الطلب.'
      : 'You can add a note for the store before placing the order.';
  String get openProductHint => isArabic
      ? 'افتح المادة لاختيار التفاصيل قبل الإضافة.'
      : 'Open the item to choose details before adding it.';
  String get statusLabel => isArabic ? 'الحالة' : 'Status';
  String get approveRevisedOrder => isArabic
      ? 'الموافقة على الطلب المعدل'
      : 'Approve revised order';
  String get approvePrice => isArabic ? 'الموافقة على التسعير' : 'Approve price';
  String get confirmOrder => isArabic ? 'تأكيد الطلب' : 'Confirm order';
  String get markUnavailable =>
      isArabic ? 'تحديد مواد غير متوفرة' : 'Mark unavailable items';
  String get assignDelivery => isArabic ? 'تعيين دلفري' : 'Assign delivery';
  String get readyForPickup => isArabic ? 'جاهز للاستلام' : 'Ready for pickup';
  String get archive => isArabic ? 'أرشفة' : 'Archive';
  String get printFile => isArabic ? 'طباعة الملف' : 'Print file';
  String get priceService => isArabic ? 'تسعير الخدمة' : 'Price service';
  String get createProduct => isArabic ? 'إضافة منتج' : 'Create product';
  String get createBanner => isArabic ? 'إضافة إعلان' : 'Create banner';
  String get createPromoCode => isArabic ? 'إضافة بروموكود' : 'Create promo code';
  String get createService => isArabic ? 'إضافة خدمة' : 'Create service';
  String get createDeliveryUser =>
      isArabic ? 'إضافة حساب دلفري' : 'Create delivery user';
  String get price => isArabic ? 'السعر' : 'Price';
  String get value => isArabic ? 'القيمة' : 'Value';
  String get stock => isArabic ? 'المخزون' : 'Stock';
  String get description => isArabic ? 'الوصف' : 'Description';
  String get title => isArabic ? 'العنوان' : 'Title';
  String get link => isArabic ? 'الرابط' : 'Link';
  String get discountType => isArabic ? 'نوع الخصم' : 'Discount type';
  String get startsAt => isArabic ? 'يبدأ في' : 'Starts at';
  String get endsAt => isArabic ? 'ينتهي في' : 'Ends at';
  String get vehicleInfo => isArabic ? 'بيانات المركبة' : 'Vehicle info';
  String get active => isArabic ? 'فعال' : 'Active';
  String get inactive => isArabic ? 'غير فعال' : 'Inactive';
  String get status => isArabic ? 'الحالة' : 'Status';
  String get role => isArabic ? 'الدور' : 'Role';
  String get logout => isArabic ? 'تسجيل الخروج' : 'Logout';
  String get profile => isArabic ? 'الملف الشخصي' : 'Profile';
  String get reports => isArabic ? 'التقارير' : 'Reports';
  String get kpis => isArabic ? 'المؤشرات' : 'KPIs';
  String get closeDaySettlement =>
      isArabic ? 'إغلاق اليوم والتحاسب' : 'Close day settlement';
  String get assignedOrders =>
      isArabic ? 'الطلبات المسندة' : 'Assigned orders';
  String get settlements => isArabic ? 'التحاسبات' : 'Settlements';
  String get pickup => isArabic ? 'استلام الطلب' : 'Pick up';
  String get delivered => isArabic ? 'تم التسليم' : 'Delivered';
  String get failedDelivery => isArabic ? 'فشل التسليم' : 'Failed delivery';
  String get reason => isArabic ? 'السبب' : 'Reason';
  String get systemError =>
      isArabic ? 'حدث خطأ غير متوقع.' : 'An unexpected error occurred.';
  String get checkConnection => isArabic
      ? 'تأكد من اتصال التطبيق بالسيرفر ثم أعد المحاولة.'
      : 'Check the app connection to the server and try again.';
  String get noData => isArabic ? 'لا توجد بيانات.' : 'No data available.';
  String get requiredField => isArabic ? 'هذا الحقل مطلوب' : 'This field is required';
  String get invalidPhone => isArabic
      ? 'أدخل رقم هاتف عراقي يبدأ بـ 07'
      : 'Enter an Iraqi phone number starting with 07';
  String get passwordMismatch =>
      isArabic ? 'كلمتا المرور غير متطابقتين' : 'Passwords do not match';
  String get passwordTooShort => isArabic
      ? 'كلمة المرور يجب أن تكون 8 أحرف على الأقل'
      : 'Password must be at least 8 characters';
  String get quantityUpdated =>
      isArabic ? 'تم تحديث الكمية' : 'Quantity updated';
  String get actionCompleted =>
      isArabic ? 'تم تنفيذ العملية بنجاح' : 'Action completed successfully';
  String get loginHint => isArabic
      ? 'ليس لديك حساب؟ أنشئ حسابًا'
      : "Don't have an account? Register";
  String get registerHint => isArabic
      ? 'لديك حساب؟ سجّل الدخول'
      : 'Already have an account? Log in';
  String get chooseDeliveryUser =>
      isArabic ? 'اختر حساب الدلفري' : 'Choose a delivery user';
  String get eta => isArabic ? 'وقت الوصول المتوقع' : 'ETA';
  String get orderItems => isArabic ? 'مواد الطلب' : 'Order items';
  String get pricingBreakdown =>
      isArabic ? 'تفاصيل الفاتورة' : 'Pricing breakdown';
  String get customerServiceFlow =>
      isArabic ? 'تدفق طلبات الخدمة' : 'Service order flow';
  String get orderTracking => isArabic ? 'تتبع الطلب' : 'Order tracking';
  String get filePreview => isArabic ? 'معاينة الملف' : 'File preview';
  String get generatedPdf => isArabic ? 'PDF المولد' : 'Generated PDF';
  String get fileUrl => isArabic ? 'رابط الملف' : 'File URL';
  String get noPrinterFallback => isArabic
      ? 'إذا لم تتوفر طابعة، يمكنك حفظ الملف أو فتحه خارجياً.'
      : 'If no printer is available, you can save the file or open it externally.';
  String get notesForOrder => isArabic
      ? 'أضف ملاحظة للطلب إن احتجت'
      : 'Add an order note if needed';
  String get switchLanguage => isArabic ? 'تبديل اللغة' : 'Switch language';
  String get uploadTip => isArabic
      ? 'يدعم النظام PDF والصور فقط في هذه النسخة.'
      : 'This version supports PDF and images only.';
  String get filesSelected => isArabic ? 'ملفات جاهزة للرفع' : 'file(s) ready to upload';

  // KPI dashboard labels
  String get salesToday => isArabic ? 'مبيعات اليوم' : 'Sales today';
  String get salesMonth => isArabic ? 'مبيعات الشهر' : 'Sales this month';
  String get ordersToday => isArabic ? 'طلبات اليوم' : 'Orders today';
  String get ordersMonth => isArabic ? 'طلبات الشهر' : 'Orders this month';
  String get pendingOrders => isArabic ? 'طلبات معلقة' : 'Pending orders';
  String get confirmedOrders => isArabic ? 'طلبات مؤكدة' : 'Confirmed orders';
  String get ordersInDelivery => isArabic ? 'طلبات قيد التوصيل' : 'Orders in delivery';
  String get deliveredOrders => isArabic ? 'طلبات مسلّمة' : 'Delivered orders';
  String get returnedOrders => isArabic ? 'طلبات مُرجعة' : 'Returned orders';
  String get totalDiscounts => isArabic ? 'إجمالي الخصومات' : 'Total discounts';
  String get netSales => isArabic ? 'صافي المبيعات' : 'Net sales';
  String get totalDeliveryFees => isArabic ? 'إجمالي أجور التوصيل' : 'Total delivery fees';
  String get totalServiceFees => isArabic ? 'إجمالي رسوم الخدمة' : 'Total service fees';
  String get bestSellingProduct => isArabic ? 'أكثر منتج مبيعاً' : 'Best selling product';
  String get leastSellingProduct => isArabic ? 'أقل منتج مبيعاً' : 'Least selling product';
  String get bestDelivery => isArabic ? 'أفضل دلفري' : 'Best delivery user';

  // Admin dialog field labels
  String get deliveryFeeMode => isArabic ? 'وضع رسوم التوصيل' : 'Delivery fee mode';
  String get deliveryFeeAmount => isArabic ? 'مبلغ التوصيل' : 'Delivery amount';
  String get serviceFeeMode => isArabic ? 'وضع عمولة الخدمة' : 'Service fee mode';
  String get serviceFeeAmount => isArabic ? 'مبلغ العمولة' : 'Service amount';
  String get pricingMode => isArabic ? 'طريقة التسعير' : 'Pricing mode';
  String get requiresFiles => isArabic ? 'يتطلب ملفات' : 'Requires files';
  String get requiresImages => isArabic ? 'يتطلب صور' : 'Requires images';
  String get maxUses => isArabic ? 'أقصى عدد استخدامات' : 'Max uses';
  String get maxUsesPerUser => isArabic ? 'أقصى استخدام للمستخدم' : 'Max uses per user';
  String get sortOrder => isArabic ? 'ترتيب العرض' : 'Sort order';
  String get optionGroupsJson => isArabic ? 'مجموعات الخيارات (JSON)' : 'Option groups (JSON)';
  String get appPreferencesJson => isArabic ? 'تفضيلات التطبيق (JSON)' : 'App preferences (JSON)';
  String get markAvailable => isArabic ? 'تحديد كمتوفر' : 'Mark available';
  String get deliveredCount => isArabic ? 'طلبات مسلّمة' : 'Delivered';
  String get returnedCount => isArabic ? 'طلبات مُرجعة' : 'Returned';
  String get perPage => isArabic ? 'لكل صفحة' : 'Per page';
  String get perFile => isArabic ? 'لكل ملف' : 'Per file';
  String get manualReview => isArabic ? 'مراجعة يدوية' : 'Manual review';
  String get percentage => isArabic ? 'نسبة مئوية' : 'Percentage';
  String get fixedAmount => isArabic ? 'مبلغ ثابت' : 'Fixed amount';

  String formatCurrency(Object? value) {
    final raw = value == null ? 0 : double.tryParse('$value') ?? 0;
    final number = raw % 1 == 0 ? raw.toStringAsFixed(0) : raw.toStringAsFixed(2);
    return isArabic ? '$number د.ع' : 'IQD $number';
  }

  String formatBool(bool value) => value ? active : inactive;

  String translateContent(String raw) {
    if (isArabic) {
      return raw;
    }

    const translations = <String, String>{
      'دفاتر': 'Notebooks',
      'أقلام': 'Pens',
      'ملازم': 'Study booklets',
      'أوراق A4': 'A4 paper',
      'ملفات': 'Folders',
      'حبر': 'Ink',
      'آلة حاسبة': 'Calculator',
      'مواد مدرسية': 'School supplies',
      'طباعة PDF': 'PDF printing',
      'طباعة صور': 'Photo printing',
      'طباعة ملازم': 'Booklet printing',
      'تصوير مستندات': 'Document copying',
      'تغليف': 'Binding',
      'عروض اليوم': "Today's offers",
      'خصومات على القرطاسية وخدمات الطباعة.':
          'Discounts on stationery and printing services.',
      'طلبات سريعة للطلاب': 'Quick orders for students',
      'إعادة طلب آخر طباعة': 'Reorder last print',
      'مواد الأكثر طلبًا': 'Most requested items',
      'أرشيف ملفات الطباعة السابقة': 'Previous print archive',
      'دفاتر جامعية ومدرسية متنوعة.':
          'A variety of school and university notebooks.',
      'أقلام جافة وملونة.': 'Ballpoint and colored pens.',
      'ملازم دراسية مطبوعة وجاهزة.': 'Printed study notes ready for pickup.',
      'رزم ورق للطباعة.': 'Paper packs for printing.',
      'ملفات شفافة ومجلدات.': 'Clear files and folders.',
      'حبر طابعات وألوان متنوعة.': 'Printer ink and assorted colors.',
      'آلات حاسبة للطلاب.': 'Calculators for students.',
      'مواد متنوعة للطلاب.': 'Assorted supplies for students.',
      'تم تأكيد الطلب': 'Order confirmed',
      'تم تجهيز الطلب': 'Order prepared',
      'تم تعيين دلفري': 'Delivery assigned',
      'تم التسليم': 'Delivered',
      'فشل التسليم': 'Delivery failed',
      'مبيعات اليوم': 'Sales today',
      'مبيعات الشهر': 'Sales this month',
      'طلبات اليوم': 'Orders today',
      'طلبات الشهر': 'Orders this month',
      'طلبات معلقة': 'Pending orders',
      'طلبات مؤكدة': 'Confirmed orders',
      'طلبات قيد التوصيل': 'Orders in delivery',
      'طلبات مسلّمة': 'Delivered orders',
      'طلبات مُرجعة': 'Returned orders',
      'أفضل دلفري': 'Best delivery',
      'لوحة التحكم': 'Dashboard',
      'لوحة الأدمن': 'Admin panel',
      'لوحة الدلفري': 'Delivery panel',
      'السلة فارغة': 'Cart is empty',
      'طلب مُعدل': 'Revised order',
      'تم إلغاء الطلب': 'Order cancelled',
      'الزبون غير متاح': 'Customer unavailable',
      'تم إرسال الطلب': 'Order placed',
      'لا توجد بيانات': 'No data',
      'إعادة المحاولة': 'Retry',
      'تسجيل الدخول': 'Login',
      'إنشاء حساب': 'Create account',
      'مكتبة عليشو': 'Alisho Library',
      'نسبة مئوية': 'Percentage',
      'مبلغ ثابت': 'Fixed amount',
      'لكل صفحة': 'Per page',
      'لكل ملف': 'Per file',
      'مراجعة يدوية': 'Manual review',
    };

    return translations[raw] ?? raw;
  }

  String roleLabel(String? roleCode) {
    return switch (roleCode) {
      'ADMIN' => isArabic ? 'أدمن' : 'Admin',
      'DELIVERY' => isArabic ? 'دلفري' : 'Delivery',
      'CUSTOMER' => isArabic ? 'زبون' : 'Customer',
      _ => roleCode ?? '-',
    };
  }

  String customerTypeLabel(String? code) {
    return switch (code) {
      'STUDENT' => student,
      'EMPLOYEE' => employee,
      _ => code ?? '-',
    };
  }

  String feeModeLabel(String? code) {
    return switch (code) {
      'FIXED' => fixedAmount,
      'PERCENTAGE' => percentage,
      _ => code ?? '-',
    };
  }

  String servicePricingModeLabel(String? code) {
    return switch (code) {
      'PER_PAGE' => perPage,
      'PER_FILE' => perFile,
      'MANUAL_REVIEW' => manualReview,
      _ => code ?? '-',
    };
  }

  String orderStatusLabel(String? statusCode) {
    return switch (statusCode) {
      'CART' => isArabic ? 'في السلة' : 'In cart',
      'PENDING_STORE_CONFIRMATION' => isArabic
          ? 'بانتظار تأكيد المكتبة'
          : 'Pending store confirmation',
      'WAITING_CUSTOMER_APPROVAL_AFTER_UNAVAILABLE_ITEMS' => isArabic
          ? 'بانتظار موافقة الزبون بعد نفاد مواد'
          : 'Waiting for customer approval',
      'REVISED_PENDING_STORE_CONFIRMATION' => isArabic
          ? 'طلب معدل بانتظار التأكيد'
          : 'Revised order pending confirmation',
      'CONFIRMED' => isArabic ? 'تم التأكيد' : 'Confirmed',
      'DELIVERY_ASSIGNED' => isArabic ? 'تم تعيين دلفري' : 'Delivery assigned',
      'READY_FOR_PICKUP' => isArabic ? 'جاهز للاستلام' : 'Ready for pickup',
      'OUT_FOR_DELIVERY' => isArabic ? 'في الطريق للتسليم' : 'Out for delivery',
      'DELIVERED' => isArabic ? 'تم التسليم' : 'Delivered',
      'FAILED_DELIVERY' => isArabic ? 'فشل التسليم' : 'Delivery failed',
      'RETURNED' => isArabic ? 'راجع' : 'Returned',
      'CANCELLED' => isArabic ? 'ملغي' : 'Cancelled',
      'ARCHIVED' => isArabic ? 'مؤرشف' : 'Archived',
      _ => statusCode ?? '-',
    };
  }

  String serviceOrderStatusLabel(String? statusCode) {
    return switch (statusCode) {
      'UPLOADED_WAITING_ADMIN_REVIEW' => isArabic
          ? 'تم الرفع وبانتظار مراجعة الأدمن'
          : 'Uploaded and waiting admin review',
      'PRICED_WAITING_CUSTOMER_APPROVAL' => isArabic
          ? 'تم التسعير وبانتظار موافقة الزبون'
          : 'Priced and waiting customer approval',
      'CUSTOMER_APPROVED_PRICE' => isArabic
          ? 'الزبون وافق على السعر'
          : 'Customer approved the price',
      'CONFIRMED' => isArabic ? 'تم التأكيد' : 'Confirmed',
      'DELIVERY_ASSIGNED' => isArabic ? 'تم تعيين دلفري' : 'Delivery assigned',
      'READY_FOR_PICKUP' => isArabic ? 'جاهز للاستلام' : 'Ready for pickup',
      'OUT_FOR_DELIVERY' => isArabic ? 'في الطريق للتسليم' : 'Out for delivery',
      'DELIVERED' => isArabic ? 'تم التسليم' : 'Delivered',
      'FAILED_DELIVERY' => isArabic ? 'فشل التسليم' : 'Delivery failed',
      'RETURNED' => isArabic ? 'راجع' : 'Returned',
      'CANCELLED' => isArabic ? 'ملغي' : 'Cancelled',
      'ARCHIVED' => isArabic ? 'مؤرشف' : 'Archived',
      _ => statusCode ?? '-',
    };
  }
}

extension AppStringsBuildContextX on BuildContext {
  AppStrings get strings => AppStrings(Localizations.localeOf(this));
}
