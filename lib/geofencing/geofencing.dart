/// Geofencing module barrel file.
///
/// Provides all geofencing-related exports for easy importing.
library;

// Models
export 'models/safe_zone_model.dart';

// Adapters
export 'adapters/safe_zone_adapter.dart';

// Repositories
export 'repositories/safe_zone_repository.dart';

// Services
export 'services/geofencing_service.dart';
export 'services/geofence_alert_service.dart';
export 'services/geocoding_service.dart';

// Providers
export 'providers/safe_zone_data_provider.dart';

// Widgets
export 'widgets/safe_zone_map_widget.dart';
