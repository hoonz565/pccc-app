import 'package:firesafe_mobile/features/areas/data/area_models.dart';
import 'package:firesafe_mobile/features/areas/data/area_repository.dart';
import 'package:firesafe_mobile/features/assets/data/asset_models.dart';
import 'package:firesafe_mobile/features/assets/data/asset_repository.dart';

Area areaFixture({
  String id = 'area-id',
  String facilityId = 'facility-id',
  String name = 'Tầng 1',
}) => Area(
  id: id,
  facilityId: facilityId,
  name: name,
  revision: 1,
  createdAt: DateTime.utc(2026, 9),
  updatedAt: DateTime.utc(2026, 9),
);

Asset assetFixture({
  String id = 'asset-id',
  String areaId = 'area-id',
  String type = 'Bình chữa cháy',
  int revision = 1,
  String? operationalStatus,
}) => Asset(
  id: id,
  areaId: areaId,
  assetCode: 'AST-550E8400-E29B-41D4-A716-446655440000',
  type: type,
  subtype: 'CO2',
  capacityValue: 5,
  capacityUnit: 'kg',
  manufacturer: 'FireSafe',
  model: 'FS-5',
  serial: 'SN-001',
  locationText: 'Cạnh cửa thoát hiểm số 2',
  lifecycleState: 'ACTIVE',
  source: 'MANUAL',
  revision: revision,
  createdAt: DateTime.utc(2026, 9),
  updatedAt: DateTime.utc(2026, 9),
  operationalStatus: operationalStatus,
);

class FakeAreaRepository implements AreaRepository {
  FakeAreaRepository({this.areas = const [], this.error, this.createCompleter});

  List<Area> areas;
  AreaRequestException? error;
  final Future<Area>? createCompleter;
  int createCalls = 0;
  String? lastFacilityId;
  String? lastName;

  @override
  Future<Area> create({
    required String facilityId,
    required String name,
  }) async {
    createCalls += 1;
    lastFacilityId = facilityId;
    lastName = name;
    if (error case final requestError?) {
      throw requestError;
    }
    if (createCompleter case final pending?) {
      return pending;
    }
    return areaFixture(facilityId: facilityId, name: name);
  }

  @override
  Future<List<Area>> list({required String facilityId}) async {
    lastFacilityId = facilityId;
    if (error case final requestError?) {
      throw requestError;
    }
    return areas.where((area) => area.facilityId == facilityId).toList();
  }
}

typedef AssetListHandler = Future<List<Asset>> Function({
  required String areaId,
  required int limit,
  required int offset,
});

class FakeAssetRepository implements AssetRepository {
  FakeAssetRepository({
    this.assets = const [],
    this.error,
    this.createCompleter,
    this.updateError,
    this.listHandler,
    this.getSequence,
  });

  List<Asset> assets;
  AssetRequestException? error;
  final Future<Asset>? createCompleter;
  AssetRequestException? updateError;
  final AssetListHandler? listHandler;
  final List<Asset>? getSequence;
  int createCalls = 0;
  int getCalls = 0;
  int listCalls = 0;
  int updateCalls = 0;
  final List<int> requestedOffsets = [];
  String? lastAreaId;
  int? lastBaseRevision;
  AssetWriteFields? lastFields;

  @override
  Future<Asset> create({
    required String areaId,
    required AssetWriteFields fields,
  }) async {
    createCalls += 1;
    lastAreaId = areaId;
    lastFields = fields;
    if (error case final requestError?) {
      throw requestError;
    }
    if (createCompleter case final pending?) {
      return pending;
    }
    return assetFixture(areaId: areaId, type: fields.type);
  }

  @override
  Future<Asset> get({required String assetId}) async {
    final callIndex = getCalls;
    getCalls += 1;
    if (error case final requestError?) {
      throw requestError;
    }
    if (getSequence case final sequence? when sequence.isNotEmpty) {
      return sequence[callIndex < sequence.length
          ? callIndex
          : sequence.length - 1];
    }
    return assets.firstWhere(
      (asset) => asset.id == assetId,
      orElse: () => assetFixture(id: assetId),
    );
  }

  @override
  Future<List<Asset>> list({
    required String areaId,
    int limit = 50,
    int offset = 0,
  }) async {
    lastAreaId = areaId;
    listCalls += 1;
    requestedOffsets.add(offset);
    if (error case final requestError?) {
      throw requestError;
    }
    if (listHandler case final handler?) {
      return handler(areaId: areaId, limit: limit, offset: offset);
    }
    return assets
        .where((asset) => asset.areaId == areaId)
        .skip(offset)
        .take(limit)
        .toList();
  }

  @override
  Future<Asset> update({
    required String assetId,
    required int baseRevision,
    required AssetWriteFields fields,
  }) async {
    updateCalls += 1;
    lastBaseRevision = baseRevision;
    lastFields = fields;
    if (updateError case final requestError?) {
      throw requestError;
    }
    return assetFixture(
      id: assetId,
      areaId: assets.firstOrNull?.areaId ?? 'area-id',
      type: fields.type,
      revision: baseRevision + 1,
    );
  }
}
