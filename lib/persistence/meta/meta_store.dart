import 'package:hive/hive.dart';
import '../box_registry.dart';

class MetaStore {
  static const boxName = BoxRegistry.metaBox;
  final Box _box;

  MetaStore(this._box);

  int getSchemaVersion(String module) => _box.get('$module.version', defaultValue: 0) as int;

  Future<void> setSchemaVersion(String module, int version) => _box.put('$module.version', version);

  Future<void> setMigrationApplied(String module, int version, String timestamp) =>
      _box.put('$module.applied.$version', timestamp);
}
