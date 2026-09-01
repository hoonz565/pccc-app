import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/app_session_controller.dart';

class FirstFacilityScreen extends ConsumerStatefulWidget {
  const FirstFacilityScreen({super.key});

  @override
  ConsumerState<FirstFacilityScreen> createState() =>
      _FirstFacilityScreenState();
}

class _FirstFacilityScreenState extends ConsumerState<FirstFacilityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _provinceController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _provinceController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await ref
        .read(appSessionControllerProvider.notifier)
        .createFirstFacility(
          name: _nameController.text.trim(),
          type: _typeController.text.trim(),
          province: _provinceController.text.trim(),
          address: _addressController.text.trim(),
        );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Trường này là bắt buộc.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appSessionControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo cơ sở đầu tiên')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Thông tin này giúp FireSafe xác định phạm vi dữ liệu bạn sở hữu.',
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Tên cơ sở'),
                      validator: _required,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _typeController,
                      decoration: const InputDecoration(
                        labelText: 'Loại hình cơ sở',
                        helperText: 'Nhập tự do; chưa có danh mục đóng.',
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _provinceController,
                      decoration: const InputDecoration(
                        labelText: 'Tỉnh/Thành phố',
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: 'Địa chỉ'),
                      validator: _required,
                      maxLines: 2,
                    ),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        state.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: state.isLoading ? null : _submit,
                      child: state.isLoading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Tạo cơ sở và vào Home'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
