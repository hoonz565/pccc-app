import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/app_session_controller.dart';
import '../application/asset_detail_controller.dart';
import '../application/asset_draft.dart';
import '../application/asset_list_controller.dart';
import '../data/asset_models.dart';
import '../data/asset_repository.dart';
import 'asset_profile_form.dart';

class EditAssetScreen extends ConsumerStatefulWidget {
  const EditAssetScreen({required this.assetId, super.key});

  final String assetId;

  @override
  ConsumerState<EditAssetScreen> createState() => _EditAssetScreenState();
}

class _EditAssetScreenState extends ConsumerState<EditAssetScreen> {
  final _formKey = GlobalKey<FormState>();
  AssetProfileControllers? _controllers;
  Asset? _asset;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasConflict = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _controllers?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final sessionIdentity = ref.read(authenticatedSessionIdentityProvider);
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _hasConflict = false;
      });
    }
    try {
      final asset = await ref
          .read(assetRepositoryProvider)
          .get(assetId: widget.assetId);
      if (mounted &&
          identical(
            sessionIdentity,
            ref.read(authenticatedSessionIdentityProvider),
          )) {
        final previousControllers = _controllers;
        setState(() {
          _asset = asset;
          _controllers = AssetProfileControllers(AssetDraft.fromAsset(asset));
        });
        previousControllers?.dispose();
        ref
            .read(assetDetailControllerProvider(asset.id).notifier)
            .setAsset(asset, sessionIdentity: sessionIdentity);
        ref
            .read(assetListControllerProvider(asset.areaId).notifier)
            .replace(asset, sessionIdentity: sessionIdentity);
      }
    } on AssetRequestException catch (error) {
      if (!mounted ||
          !identical(
            sessionIdentity,
            ref.read(authenticatedSessionIdentityProvider),
          )) {
        return;
      }
      if (error.invalidSession) {
        _clearLoadedAsset();
        await ref
            .read(appSessionControllerProvider.notifier)
            .invalidateSession();
        return;
      }
      if (error.statusCode == 404) {
        _clearLoadedAsset(errorMessage: error.message);
      } else {
        setState(() => _errorMessage = error.message);
      }
    } on Object {
      if (mounted) {
        setState(
          () => _errorMessage = 'Không thể tải thiết bị. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submit() async {
    final asset = _asset;
    final controllers = _controllers;
    if (_isSubmitting ||
        asset == null ||
        controllers == null ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _hasConflict = false;
    });
    final sessionIdentity = ref.read(authenticatedSessionIdentityProvider);
    try {
      final updated = await ref
          .read(assetRepositoryProvider)
          .update(
            assetId: asset.id,
            baseRevision: asset.revision,
            fields: controllers.toDraft().toWriteFields(),
          );
      if (!mounted ||
          !identical(
            sessionIdentity,
            ref.read(authenticatedSessionIdentityProvider),
          )) {
        return;
      }
      ref
          .read(assetDetailControllerProvider(asset.id).notifier)
          .setAsset(updated, sessionIdentity: sessionIdentity);
      ref
          .read(assetListControllerProvider(asset.areaId).notifier)
          .replace(updated, sessionIdentity: sessionIdentity);
      context.pop();
    } on AssetRequestException catch (error) {
      if (!mounted ||
          !identical(
            sessionIdentity,
            ref.read(authenticatedSessionIdentityProvider),
          )) {
        return;
      }
      if (error.invalidSession) {
        _clearLoadedAsset();
        await ref
            .read(appSessionControllerProvider.notifier)
            .invalidateSession();
        return;
      }
      if (error.statusCode == 404) {
        _clearLoadedAsset(errorMessage: error.message);
      } else {
        setState(() {
          _hasConflict = error.revisionConflict;
          _errorMessage = error.message;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _errorMessage = 'Không thể cập nhật thiết bị. Vui lòng thử lại.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _clearLoadedAsset({String? errorMessage}) {
    final previousControllers = _controllers;
    setState(() {
      _asset = null;
      _controllers = null;
      _hasConflict = false;
      _errorMessage = errorMessage;
    });
    previousControllers?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa thiết bị')),
      body: _isLoading && _controllers == null
          ? const Center(child: CircularProgressIndicator())
          : _content(),
    );
  }

  Widget _content() {
    final controllers = _controllers;
    if (controllers == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage ?? 'Không thể tải thiết bị.'),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    return SafeArea(
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
                  AssetProfileForm(controllers: controllers),
                  if (_errorMessage case final error?) ...[
                    const SizedBox(height: 16),
                    Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (_hasConflict) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _isSubmitting ? null : _load,
                      child: const Text('Tải dữ liệu mới nhất'),
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
                        : const Text('Lưu thay đổi'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
