import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/app_session_controller.dart';
import '../application/area_list_controller.dart';
import '../data/area_models.dart';
import '../data/area_repository.dart';

class CreateAreaScreen extends ConsumerStatefulWidget {
  const CreateAreaScreen({required this.facilityId, super.key});

  final String facilityId;

  @override
  ConsumerState<CreateAreaScreen> createState() => _CreateAreaScreenState();
}

class _CreateAreaScreenState extends ConsumerState<CreateAreaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final sessionIdentity = ref.read(authenticatedSessionIdentityProvider);
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final area = await ref
          .read(areaRepositoryProvider)
          .create(
            facilityId: widget.facilityId,
            name: _nameController.text.trim(),
          );
      ref
          .read(areaListControllerProvider(widget.facilityId).notifier)
          .add(area, sessionIdentity: sessionIdentity);
      if (mounted) {
        context.pop();
      }
    } on AreaRequestException catch (error) {
      if (error.invalidSession) {
        await ref
            .read(appSessionControllerProvider.notifier)
            .invalidateSession();
        return;
      }
      if (mounted) {
        setState(() {
          _errorMessage = error.isTransient
              ? '${error.message} Không tự động gửi lại yêu cầu tạo; hãy kiểm tra danh sách trước khi thử lại.'
              : error.message;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _errorMessage = 'Không thể tạo khu vực. Vui lòng thử lại.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo khu vực')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Tên khu vực',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Tên khu vực là bắt buộc.'
                          : null,
                    ),
                    if (_errorMessage case final error?) ...[
                      const SizedBox(height: 16),
                      Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Lưu khu vực'),
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
