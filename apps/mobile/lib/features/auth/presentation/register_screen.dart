import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/app_session_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  String? _consentError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final validForm = _formKey.currentState?.validate() ?? false;
    setState(() {
      _consentError = _termsAccepted && _privacyAccepted
          ? null
          : 'Bạn cần đồng ý cả Điều khoản và Chính sách quyền riêng tư.';
    });
    if (!validForm || _consentError != null) {
      return;
    }
    await ref
        .read(appSessionControllerProvider.notifier)
        .register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appSessionControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký FireSafe')),
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
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty || !email.contains('@')) {
                          return 'Nhập địa chỉ email hợp lệ.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(labelText: 'Mật khẩu'),
                      validator: (value) {
                        final length = value?.length ?? 0;
                        if (length < 12 || length > 128) {
                          return 'Mật khẩu phải có từ 12 đến 128 ký tự.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _termsAccepted,
                      onChanged: state.isLoading
                          ? null
                          : (value) =>
                                setState(() => _termsAccepted = value ?? false),
                      title: const Text('Tôi đồng ý với Điều khoản sử dụng'),
                      subtitle: const Text('Phiên bản phát triển: draft-v1'),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _privacyAccepted,
                      onChanged: state.isLoading
                          ? null
                          : (value) => setState(
                              () => _privacyAccepted = value ?? false,
                            ),
                      title: const Text(
                        'Tôi đồng ý với Chính sách quyền riêng tư',
                      ),
                      subtitle: const Text('Phiên bản phát triển: draft-v1'),
                    ),
                    if (_consentError != null)
                      Text(
                        _consentError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'Nội dung pháp lý cuối cùng phải được Product/Legal phê duyệt trước production.',
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
                          : const Text('Tạo tài khoản'),
                    ),
                    TextButton(
                      onPressed: state.isLoading
                          ? null
                          : () => context.go('/login'),
                      child: const Text('Đã có tài khoản? Đăng nhập'),
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
