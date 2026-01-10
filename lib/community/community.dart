/// Community Module
/// 
/// Master barrel export for the entire community feature.
/// 
/// This module implements location-based community features allowing
/// patients within a 10km radius to see each other's posts and chat.
/// 
/// Architecture:
/// - Models: Data structures for users, posts, and messages
/// - Services: Business logic for location, posts, chat, and nearby users
/// - Repositories: Firestore data access layer with geo-queries
/// - Providers: State management using ChangeNotifier pattern
/// 
/// Usage:
/// ```dart
/// import 'package:guardian_angel/community/community.dart';
/// 
/// // Initialize community
/// await CommunityFeedProvider.instance.initialize(currentUserId: userId);
/// await CommunityChatProvider.instance.initialize(userName: name);
/// ```
library;

// Models
export 'models/models.dart';

// Services
export 'services/services.dart';

// Repositories
export 'repositories/community_firestore_repository.dart';

// Providers
export 'providers/providers.dart';
