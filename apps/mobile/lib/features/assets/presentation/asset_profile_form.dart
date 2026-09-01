import 'package:flutter/material.dart';

import '../application/asset_draft.dart';

class AssetProfileControllers {
  AssetProfileControllers([AssetDraft draft = const AssetDraft()])
    : type = TextEditingController(text: draft.type),
      subtype = TextEditingController(text: draft.subtype),
      capacityValue = TextEditingController(text: draft.capacityValue),
      capacityUnit = TextEditingController(text: draft.capacityUnit),
      manufacturer = TextEditingController(text: draft.manufacturer),
      model = TextEditingController(text: draft.model),
      serial = TextEditingController(text: draft.serial),
      locationText = TextEditingController(text: draft.locationText);

  final TextEditingController type;
  final TextEditingController subtype;
  final TextEditingController capacityValue;
  final TextEditingController capacityUnit;
  final TextEditingController manufacturer;
  final TextEditingController model;
  final TextEditingController serial;
  final TextEditingController locationText;

  AssetDraft toDraft() => AssetDraft(
    type: type.text,
    subtype: subtype.text,
    capacityValue: capacityValue.text,
    capacityUnit: capacityUnit.text,
    manufacturer: manufacturer.text,
    model: model.text,
    serial: serial.text,
    locationText: locationText.text,
  );

  void dispose() {
    type.dispose();
    subtype.dispose();
    capacityValue.dispose();
    capacityUnit.dispose();
    manufacturer.dispose();
    model.dispose();
    serial.dispose();
    locationText.dispose();
  }
}

class AssetProfileForm extends StatelessWidget {
  const AssetProfileForm({required this.controllers, super.key});

  final AssetProfileControllers controllers;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: controllers.type,
          decoration: const InputDecoration(labelText: 'Loại thiết bị *'),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Loại thiết bị là bắt buộc.'
              : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controllers.subtype,
          decoration: const InputDecoration(labelText: 'Loại phụ'),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: controllers.capacityValue,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Sức chứa'),
                validator: (_) => _capacityError(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: controllers.capacityUnit,
                decoration: const InputDecoration(labelText: 'Đơn vị'),
                validator: (_) => _capacityError(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controllers.manufacturer,
          decoration: const InputDecoration(labelText: 'Nhà sản xuất'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controllers.model,
          decoration: const InputDecoration(labelText: 'Model'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controllers.serial,
          decoration: const InputDecoration(labelText: 'Serial'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controllers.locationText,
          decoration: const InputDecoration(
            labelText: 'Vị trí chi tiết',
            hintText: 'Ví dụ: Cạnh cửa thoát hiểm số 2',
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  String? _capacityError() {
    final valueText = controllers.capacityValue.text.trim();
    final unitText = controllers.capacityUnit.text.trim();
    if (valueText.isEmpty != unitText.isEmpty) {
      return 'Nhập đủ giá trị và đơn vị.';
    }
    if (valueText.isNotEmpty) {
      final value = num.tryParse(valueText);
      if (value == null || value <= 0) {
        return 'Phải lớn hơn 0.';
      }
    }
    return null;
  }
}
