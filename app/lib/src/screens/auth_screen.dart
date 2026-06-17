import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_service.dart';
import '../core/app_locale.dart';
import '../core/auth_controller.dart';
import '../widgets/common_views.dart';
import '../widgets/language_button.dart';

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
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _ageController = TextEditingController(text: '20');
  final _streetController = TextEditingController(text: 'مجمع A1');
  final _apartmentController = TextEditingController(text: '1');
  final _jobTitleController = TextEditingController();
  String _block = 'A';
  String? _complex;
  String? _building;
  String _customerType = 'STUDENT';
  String? _studentStage;
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

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _ageController.dispose();
    _streetController.dispose();
    _apartmentController.dispose();
    _jobTitleController.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    setState(() {
      _isMetaLoading = true;
      _metaError = null;
    });

    try {
      final meta = await ref.read(apiServiceProvider).get('/meta/registration')
          as Map<String, dynamic>;
      final blocks = meta['blocks'] as Map<String, dynamic>;
      final blockData = blocks[_block] as Map<String, dynamic>? ?? <String, dynamic>{};
      final complex = blockData.keys.isEmpty ? null : blockData.keys.first;
      final buildingValues = complex == null
          ? const <dynamic>[]
          : (blockData[complex] as List<dynamic>? ?? const <dynamic>[]);
      final studentStages = (meta['studentStages'] as List<dynamic>? ?? const <dynamic>[])
          .map((stage) => stage.toString())
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _meta = meta;
        _complex = complex;
        _building = buildingValues.isEmpty ? null : buildingValues.first.toString();
        _studentStage = studentStages.isEmpty ? null : studentStages.first;
        _isMetaLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isMetaLoading = false;
        _metaError = describeApiError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final authState = ref.watch(authControllerProvider);
    final blocks = (_meta?['blocks'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final complexes = (blocks[_block] as Map<String, dynamic>? ?? <String, dynamic>{});
    final buildings = (complexes[_complex] as List<dynamic>? ?? const <dynamic>[]);
    final studentStages = ((_meta?['studentStages'] as List<dynamic>?) ?? const <dynamic>[])
        .map((stage) => strings.translateContent(stage.toString()))
        .toList();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 860;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.appName),
        actions: const [LanguageButton()],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF5F1E8), Color(0xFFE5DEC9), Color(0xFFD2D7C4)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: isCompact
                              ? Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: _heroPanel(strings),
                                    ),
                                    const SizedBox(height: 24),
                                    _formPanel(strings, authState, blocks, complexes, buildings, studentStages),
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _heroPanel(strings),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      child: _formPanel(
                                        strings,
                                        authState,
                                        blocks,
                                        complexes,
                                        buildings,
                                        studentStages,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _formPanel(
    AppStrings strings,
    AuthState authState,
    Map<String, dynamic> blocks,
    Map<String, dynamic> complexes,
    List<dynamic> buildings,
    List<String> studentStages,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
                                Text(
                                  widget.isRegister
                                      ? strings.createAccount
                                      : strings.login,
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                Text(strings.appSubtitle),
                                const SizedBox(height: 24),
                                if (widget.isRegister && _isMetaLoading) ...[
                                  const LinearProgressIndicator(),
                                  const SizedBox(height: 16),
                                ],
                                if (widget.isRegister && _metaError != null) ...[
                                  ErrorView(message: _metaError!, onRetry: _loadMeta),
                                  const SizedBox(height: 16),
                                ],
                                if (widget.isRegister) ...[
                                  _field(_fullNameController, strings.fullName),
                                  const SizedBox(height: 12),
                                  _field(
                                    _ageController,
                                    strings.age,
                                    keyboardType: TextInputType.number,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                _field(
                                  _phoneController,
                                  strings.phone,
                                  keyboardType: TextInputType.phone,
                                  validator: (value) {
                                    final normalized = (value ?? '').trim();
                                    if (normalized.isEmpty) {
                                      return strings.requiredField;
                                    }
                                    if (!RegExp(r'^07\d{9}$').hasMatch(normalized)) {
                                      return strings.invalidPhone;
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                _field(
                                  _passwordController,
                                  strings.password,
                                  obscureText: true,
                                ),
                                if (widget.isRegister) ...[
                                  const SizedBox(height: 12),
                                  _field(
                                    _confirmPasswordController,
                                    strings.confirmPassword,
                                    obscureText: true,
                                    validator: (value) {
                                      if ((value ?? '').trim().isEmpty) {
                                        return strings.requiredField;
                                      }
                                      if (value!.trim() != _passwordController.text.trim()) {
                                        return strings.passwordMismatch;
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    key: ValueKey('block-$_block'),
                                    initialValue: _block,
                                    decoration: InputDecoration(labelText: strings.block),
                                    items: const [
                                      DropdownMenuItem(value: 'A', child: Text('Block A')),
                                      DropdownMenuItem(value: 'B', child: Text('Block B')),
                                    ],
                                    onChanged: (value) {
                                      if (value == null) {
                                        return;
                                      }
                                      final blockMap =
                                          (blocks[value] as Map<String, dynamic>? ?? <String, dynamic>{});
                                      final nextComplex =
                                          blockMap.isEmpty ? null : blockMap.keys.first;
                                      final nextBuilding = nextComplex == null
                                          ? null
                                          : (blockMap[nextComplex] as List<dynamic>).first
                                              .toString();
                                      setState(() {
                                        _block = value;
                                        _complex = nextComplex;
                                        _building = nextBuilding;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    key: ValueKey('complex-$_complex'),
                                    initialValue: _complex,
                                    decoration: InputDecoration(labelText: strings.complex),
                                    items: complexes.keys
                                        .map(
                                          (complex) => DropdownMenuItem<String>(
                                            value: complex,
                                            child: Text(complex),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value == null) {
                                        return;
                                      }
                                      final nextBuilding =
                                          ((complexes[value] as List<dynamic>).first).toString();
                                      setState(() {
                                        _complex = value;
                                        _building = nextBuilding;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    key: ValueKey('building-$_building'),
                                    initialValue: _building,
                                    decoration: InputDecoration(labelText: strings.building),
                                    items: buildings
                                        .map(
                                          (building) => DropdownMenuItem<String>(
                                            value: building.toString(),
                                            child: Text(building.toString()),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) => setState(() => _building = value),
                                  ),
                                  const SizedBox(height: 12),
                                  _field(_streetController, strings.streetAddress),
                                  const SizedBox(height: 12),
                                  _field(_apartmentController, strings.apartment),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    key: ValueKey('customer-type-$_customerType'),
                                    initialValue: _customerType,
                                    decoration:
                                        InputDecoration(labelText: strings.customerType),
                                    items: [
                                      DropdownMenuItem(
                                        value: 'STUDENT',
                                        child: Text(strings.student),
                                      ),
                                      DropdownMenuItem(
                                        value: 'EMPLOYEE',
                                        child: Text(strings.employee),
                                      ),
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
                                      decoration: InputDecoration(labelText: strings.studentStage),
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
                                    _field(_jobTitleController, strings.jobTitle),
                                ],
                                const SizedBox(height: 24),
                                FilledButton(
                                  onPressed: authState.isLoading ||
                                          (widget.isRegister && _meta == null)
                                      ? null
                                      : _submit,
                                  child: Text(
                                    widget.isRegister ? strings.createAccount : strings.login,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () => context.go(
                                    widget.isRegister ? '/login' : '/register',
                                  ),
                                  child: Text(
                                    widget.isRegister
                                        ? strings.registerHint
                                        : strings.loginHint,
                                  ),
                                ),
                                if (authState.isLoading) ...[
                                  const SizedBox(height: 16),
                                  const LinearProgressIndicator(),
                                ],
                              ],
      ),
    );
  }

  Widget _heroPanel(AppStrings strings) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF243640), Color(0xFF5F7352)],
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.auto_stories_rounded, size: 54, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              strings.appName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              strings.appSubtitle,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _heroChip(strings.todayOffers),
                _heroChip(strings.mostRequested),
                _heroChip(strings.quickActions),
                _heroChip(strings.printArchive),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator ??
          (value) => (value ?? '').trim().isEmpty
              ? context.strings.requiredField
              : null,
      decoration: InputDecoration(labelText: label),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

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
          'jobTitle': _jobTitleController.text.trim().isEmpty
              ? null
              : _jobTitleController.text.trim(),
          'studentStage': _customerType == 'STUDENT' ? _studentStage : null,
          'password': _passwordController.text.trim(),
          'confirmPassword': _confirmPasswordController.text.trim(),
        });
      } else {
        await auth.login(
          _phoneController.text.trim(),
          _passwordController.text.trim(),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeApiError(error))),
      );
    }
  }
}
