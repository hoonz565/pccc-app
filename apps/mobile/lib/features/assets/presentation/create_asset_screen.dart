import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/app_session_controller.dart';
import '../application/asset_list_controller.dart';
import '../data/asset_models.dart';
import '../data/asset_repository.dart';
import 'asset_profile_form.dart';

class CreateAssetScreen extends ConsumerStatefulWidget {
  const CreateAssetScreen({required this.areaId, super.key});

  final String areaId;

  @override
  ConsumerState<CreateAssetScreen> createState() => _CreateAssetScreenState();
}

class _CreateAssetScreenState extends ConsumerState<CreateAssetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = AssetProfileControllers();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controllers.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    final sessionIdentity = ref.read(authenticatedSessionIdentityProvider);
    try {
      final asset = await ref
          .read(assetRepositoryProvider)
          .create(
            areaId: widget.areaId,
            fields: _controllers.toDraft().toWriteFields(),
          );
      if (mounted &&
          identical(
            sessionIdentity,
            ref.read(authenticatedSessionIdentityProvider),
          )) {
        ref
            .read(assetListControllerProvider(widget.areaId).notifier)
            .add(asset, sessionIdentity: sessionIdentity);
        context.pushReplacement('/assets/${asset.id}');
      }
    } on AssetRequestException catch (error) {
      if (error.invalidSession) {
        await ref
            .read(appSessionControllerProvider.notifier)
            .invalidateSession();
        return;
      }
      if (mounted) {
        setState(() {
          _errorMessage = error.isTransient
              ? '${error.message} Không tự động gửi lại. Hãy kiểm tra danh sách trước khi thử lại.'
              : error.message;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _errorMessage = 'Không thể tạo thiết bị. Vui lòng thử lại.';
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
      appBar: AppBar(title: const Text('Thêm thiết bị thủ công')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Kiểm tra thông tin trước khi lưu. Đây là dữ liệu được người dùng xác nhận.',
                    ),
                    const SizedBox(height: 20),
                    AssetProfileForm(controllers: _controllers),
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
                          : const Text('Xác nhận và lưu'),
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
