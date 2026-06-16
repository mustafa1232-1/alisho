import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_service.dart';
import '../core/auth_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, required this.isRegister});

  final bool isRegister;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _ageController = TextEditingController(text: '20');
  final _streetController = TextEditingController(text: 'مجمع A1');
  final _apartmentController = TextEditingController(text: '1');
  String _block = 'A';
  String? _complex;
  String? _building;
  String _customerType = 'STUDENT';
  String? _studentStage;
  String? _jobTitle;
  Map<String, dynamic>? _meta;
  bool _isMetaLoading = false;
  String? _metaError;

  @override
  void initState() {
    super.initState();
    if (widget.isRegister) {
      _loadMeta();
    }
  }

  Future<void> _loadMeta() async {
    setState(() {
      _isMetaLoading = true;
      _metaError = null;
    });

    try {
      final meta =
          await ref.read(apiServiceProvider).get('/meta/registration') as Map<String, dynamic>;
      final blocks = meta['blocks'] as Map<String, dynamic>;
      final blockData = blocks[_block] as Map<String, dynamic>? ?? <String, dynamic>{};
      final complex = blockData.keys.isEmpty ? null : blockData.keys.first;
      final buildingValues = complex == null
          ? const <dynamic>[]
          : (blockData[complex] as List<dynamic>? ?? const <dynamic>[]);
      final studentStages = (meta['studentStages'] as List<dynamic>? ?? const <dynamic>[])
          .map((stage) => stage.toString())
          .toList();

      if (!mounted) return;
      setState(() {
        _meta = meta;
        _complex = complex;
        _building = buildingValues.isEmpty ? null : buildingValues.first.toString();
        _studentStage = studentStages.isEmpty ? null : studentStages.first;
        _isMetaLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isMetaLoading = false;
        _metaError = 'تعذر تحميل بيانات التسجيل. تأكد من اتصال التطبيق بالسيرفر.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final blocks = (_meta?['blocks'] as Map<String, dynamic>? ?? {});
    final complexes = (blocks[_block] as Map<String, dynamic>? ?? {});
    final buildings = (complexes[_complex] as List<dynamic>? ?? []);
    final studentStages = ((_meta?['studentStages'] as List<dynamic>?) ?? const [])
        .map((stage) => stage.toString())
        .toList();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF5F1E8), Color(0xFFE8E1D6), Color(0xFFD7D1C1)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        Text(
                          widget.isRegister ? 'إنشاء حساب جديد' : 'تسجيل الدخول',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        const Text('مكتبة عليشو - مكتبة، مطبعة، وخدمات طلابية'),
                        const SizedBox(height: 24),
                        if (widget.isRegister && _isMetaLoading) ...[
                          const LinearProgressIndicator(),
                          const SizedBox(height: 16),
                        ],
                        if (widget.isRegister && _metaError != null) ...[
                          Text(
                            _metaError!,
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _loadMeta,
                              child: const Text('إعادة المحاولة'),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (widget.isRegister) ...[
                          _field(_fullNameController, 'الاسم الكامل'),
                          const SizedBox(height: 12),
                          _field(
                            _ageController,
                            'العمر',
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 12),
                        ],
                        _field(
                          _phoneController,
                          'رقم الهاتف',
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          _passwordController,
                          'كلمة المرور',
                          obscureText: true,
                        ),
                        if (widget.isRegister) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            key: ValueKey('block-$_block'),
                            initialValue: _block,
                            decoration: const InputDecoration(labelText: 'البلوك'),
                            items: const [
                              DropdownMenuItem(value: 'A', child: Text('Block A')),
                              DropdownMenuItem(value: 'B', child: Text('Block B')),
                            ],
                            onChanged: (value) {
                              final newBlock = value ?? 'A';
                              final newComplex =
                                  (blocks[newBlock] as Map<String, dynamic>).keys.first;
                              final newBuilding =
                                  ((blocks[newBlock][newComplex] as List<dynamic>).first)
                                      .toString();
                              setState(() {
                                _block = newBlock;
                                _complex = newComplex;
                                _building = newBuilding;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            key: ValueKey('complex-$_complex'),
                            initialValue: _complex,
                            decoration: const InputDecoration(labelText: 'المجمع'),
                            items: complexes.keys
                                .map((complex) => DropdownMenuItem<String>(
                                      value: complex,
                                      child: Text(complex),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              final newBuilding =
                                  ((complexes[value] as List<dynamic>).first).toString();
                              setState(() {
                                _complex = value;
                                _building = newBuilding;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            key: ValueKey('building-$_building'),
                            initialValue: _building,
                            decoration: const InputDecoration(labelText: 'العمارة'),
                            items: buildings
                                .map((building) => DropdownMenuItem<String>(
                                      value: building.toString(),
                                      child: Text(building.toString()),
                                    ))
                                .toList(),
                            onChanged: (value) => setState(() => _building = value),
                          ),
                          const SizedBox(height: 12),
                          _field(_streetController, 'عنوان السكن'),
                          const SizedBox(height: 12),
                          _field(_apartmentController, 'رقم الشقة'),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            key: ValueKey('customer-type-$_customerType'),
                            initialValue: _customerType,
                            decoration:
                                const InputDecoration(labelText: 'نوع المستخدم'),
                            items: const [
                              DropdownMenuItem(value: 'STUDENT', child: Text('طالب')),
                              DropdownMenuItem(value: 'EMPLOYEE', child: Text('موظف')),
                            ],
                            onChanged: (value) {
                              setState(() => _customerType = value ?? 'STUDENT');
                            },
                          ),
                          const SizedBox(height: 12),
                          if (_customerType == 'STUDENT')
                            DropdownButtonFormField<String>(
                              key: ValueKey('student-stage-$_studentStage'),
                              initialValue: _studentStage,
                              decoration: const InputDecoration(
                                labelText: 'المرحلة الدراسية',
                              ),
                              items: studentStages
                                  .map(
                                    (stage) => DropdownMenuItem<String>(
                                      value: stage,
                                      child: Text(stage),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) => setState(() => _studentStage = value),
                            ),
                          if (_customerType == 'EMPLOYEE')
                            _field(
                              TextEditingController(text: _jobTitle ?? ''),
                              'الوظيفة',
                              onChanged: (value) => _jobTitle = value,
                            ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: authState.isLoading || (widget.isRegister && _meta == null)
                              ? null
                              : _submit,
                          child: Text(widget.isRegister ? 'إنشاء الحساب' : 'دخول'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context.go(
                            widget.isRegister ? '/login' : '/register',
                          ),
                          child: Text(
                            widget.isRegister
                                ? 'لديك حساب؟ سجّل الدخول'
                                : 'ليس لديك حساب؟ أنشئ حسابًا',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    bool obscureText = false,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onChanged: onChanged,
      validator: (value) =>
          (value ?? '').trim().isEmpty ? 'هذا الحقل مطلوب' : null,
      decoration: InputDecoration(labelText: label),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = ref.read(authControllerProvider.notifier);

    try {
      if (widget.isRegister) {
        await auth.register({
          'fullName': _fullNameController.text.trim(),
          'age': int.tryParse(_ageController.text.trim()) ?? 18,
          'phone': _phoneController.text.trim(),
          'streetAddress': _streetController.text.trim(),
          'block': _block,
          'complex': _complex,
          'building': _building,
          'apartment': _apartmentController.text.trim(),
          'customerType': _customerType,
          'jobTitle': _jobTitle,
          'studentStage': _studentStage,
          'password': _passwordController.text.trim(),
          'confirmPassword': _passwordController.text.trim(),
        });
      } else {
        await auth.login(
          _phoneController.text.trim(),
          _passwordController.text.trim(),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }
}
