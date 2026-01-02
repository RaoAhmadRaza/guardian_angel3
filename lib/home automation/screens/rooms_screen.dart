import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../navigation/drawer_wrapper.dart';
import '../models/room_model.dart' as legacy;
import 'room_detail_screen.dart';
import '../src/data/models/room_model.dart' as domain;
import '../src/logic/providers/room_providers.dart';
import '../src/logic/providers/device_providers.dart';
import '../src/core/utils/id_generator.dart';
import '../src/core/keys.dart';

class RoomsScreen extends ConsumerStatefulWidget {
  const RoomsScreen({super.key});

  @override
  ConsumerState<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends ConsumerState<RoomsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _menuAnimationController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _menuAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _menuAnimationController.dispose();
    super.dispose();
  }

  void _toggleDrawer() {
    final drawerState = DrawerWrapper.of(context);
    if (drawerState != null) {
      drawerState.toggleDrawer();
      if (drawerState.isDrawerOpen) {
        _menuAnimationController.reverse();
      } else {
        _menuAnimationController.forward();
      }
    }
  }

  void _showAddRoomDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController deviceCountController = TextEditingController(text: '3');

    // Available room icons
    final List<Map<String, String>> availableIcons = [
      {'name': 'Living Room', 'icon': 'images/sofa.png'},
      {'name': 'Kitchen', 'icon': 'images/utensils.png'},
      {'name': 'Bedroom', 'icon': 'images/bed.png'},
      {'name': 'Bathroom', 'icon': 'images/bathtub.png'},
    ];
    
    String selectedIcon = availableIcons[0]['icon']!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final colors = _ScreenColors(isDark);

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4D7CFE),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Add New Room',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: colors.textPri,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Room Name Field
                    TextField(
                      key: AppKeys.roomNameField,
                      controller: nameController,
                      style: TextStyle(color: colors.textPri),
                      decoration: InputDecoration(
                        labelText: 'Room Name',
                        labelStyle: TextStyle(color: colors.textSec),
                        hintText: 'e.g., Living Room',
                        hintStyle: TextStyle(color: colors.textTer),
                        prefixIcon: const Icon(Icons.meeting_room, color: Color(0xFF4D7CFE)),
                        filled: true,
                        fillColor: colors.inputBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colors.inputBorderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colors.inputBorderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: colors.inputFocusBorder,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Device Count Field
                    TextField(
                      controller: deviceCountController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: colors.textPri),
                      decoration: InputDecoration(
                        labelText: 'Number of Devices',
                        labelStyle: TextStyle(color: colors.textSec),
                        hintText: '3',
                        hintStyle: TextStyle(color: colors.textTer),
                        prefixIcon: const Icon(Icons.devices, color: Color(0xFF4D7CFE)),
                        filled: true,
                        fillColor: colors.inputBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colors.inputBorderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colors.inputBorderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: colors.inputFocusBorder,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Icon Selector
                    Text(
                      'Select Icon',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.textPri,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: availableIcons.length,
                        itemBuilder: (context, index) {
                          final iconData = availableIcons[index];
                          final isSelected = selectedIcon == iconData['icon'];
                          
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                selectedIcon = iconData['icon']!;
                              });
                            },
                            child: Container(
                              width: 70,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? const Color(0xFF4D7CFE).withOpacity(0.1)
                                    : colors.bgSec,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected 
                                      ? const Color(0xFF4D7CFE)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    iconData['icon']!,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.image,
                                        size: 40,
                                        color: colors.textTer,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: colors.textSec,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            key: AppKeys.saveRoomButton,
                            onPressed: () async {
                              final roomName = nameController.text.trim();
                              
                              // Validation: Check if name is empty
                              if (roomName.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Please enter a room name'),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
                              
                              // Edge Case 2: Check for duplicate room name (current rooms from provider)
                              final currentRooms = ref.read(roomsControllerProvider).maybeWhen<List<domain.RoomModel>?>(
                                data: (r) => r,
                                orElse: () => null,
                              ) ?? [];
                              final isDuplicate = currentRooms.any((room) => 
                                room.name.toLowerCase() == roomName.toLowerCase()
                              );
                              
                              if (isDuplicate) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('A room with this name already exists.'),
                                    backgroundColor: Colors.orange,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
                              
                              // Map selected asset to iconId (filename without extension)
                              final iconId = selectedIcon.split('/').last.split('.').first;
                              final newRoom = domain.RoomModel(
                                id: generateId(),
                                name: roomName,
                                iconId: iconId,
                                color: 0xFF6C63FF,
                              );

                              await ref.read(roomsControllerProvider.notifier).addRoom(newRoom);

                              if (!mounted) return;
                              Navigator.pop(context);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${newRoom.name} added successfully!'),
                                  backgroundColor: const Color(0xFF4D7CFE),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4D7CFE),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Add Room',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(roomsControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _ScreenColors(isDark);

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: [
          // Header
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: colors.bgSec,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 24, top: 45, right: 24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _toggleDrawer,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: AnimatedIcon(
                        icon: AnimatedIcons.menu_close,
                        progress: _menuAnimationController,
                        color: colors.textPri,
                        size: 24,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Rooms',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textPri,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_horiz,
                      color: colors.textPri,
                      size: 28,
                    ),
                    color: colors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    offset: const Offset(0, 50),
                    onSelected: (String value) {
                      if (value == 'add_room') {
                        _showAddRoomDialog(context);
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem<String>(
                        key: AppKeys.addRoomButton, // repurpose existing key for menu item
                        value: 'add_room',
                        child: Row(
                          children: [
                            Icon(
                              Icons.add_circle_outline,
                              color: const Color(0xFF4D7CFE),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Add new room',
                              style: TextStyle(
                                color: colors.textPri,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Search Bar - Positioned to overlap
          Positioned(
            top: 140,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.border,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow,
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) {
                        setState(() {
                          _searchQuery = v.trim();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search rooms',
                        disabledBorder: InputBorder.none,
                        hintStyle: TextStyle(
                          color: colors.textTer,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: TextStyle(
                        color: colors.textPri,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.search,
                    color: colors.textTer,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          // Content Area
          Padding(
            padding: const EdgeInsets.only(top: 230),
            child: Column(
              children: [
                // Your Rooms Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        'Your Rooms',
                        style: TextStyle(
                          color: colors.textPri,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.bgSec,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: roomsAsync.when(
                          data: (rooms) => Text(
                            '${rooms.length}',
                            style: TextStyle(
                              color: colors.textSec,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          loading: () => const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          error: (_, __) => Text(
                            '—',
                            style: TextStyle(
                              color: colors.textSec,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Rooms List
                Expanded(
                  child: roomsAsync.when(
                    data: (rooms) {
                      final filtered = (_searchQuery.isEmpty)
                          ? rooms
                          : rooms.where((r) => r.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                      if (filtered.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off, size: 48, color: colors.textTer),
                              const SizedBox(height: 12),
                              Text(
                                'No rooms match "${_searchQuery}"',
                                style: TextStyle(color: colors.textTer, fontSize: 14),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                                child: const Text('Clear search'),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _buildRoomCard(filtered[index]);
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, st) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Failed to load rooms'),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => ref.read(roomsControllerProvider.notifier).refresh(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _iconAssetFor(String iconId) {
    final known = <String>{'sofa', 'utensils', 'bed', 'bathtub'};
    final id = known.contains(iconId) ? iconId : 'sofa';
    return 'images/$id.png';
  }

  Widget _buildRoomCard(domain.RoomModel room) {
    final devicesAsync = ref.watch(devicesControllerProvider(room.id));
    final imageUrl = _iconAssetFor(room.iconId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _ScreenColors(isDark);

    return GestureDetector(
      key: AppKeys.roomTileKey(room.id),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RoomDetailScreen(
              room: legacy.RoomModel(
                id: room.id,
                name: room.name,
                deviceCount: devicesAsync.maybeWhen(data: (d) => d.length, orElse: () => 0),
                imageUrl: imageUrl,
                icon: imageUrl,
                color: room.color,
              ),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 38.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            room.name,
                            style: TextStyle(
                              color: colors.textPri,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Removed overflow menu (three dots) per request
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF5B67F5),
                              width: 3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          devicesAsync.when(
                            data: (d) => '${d.length} device${d.length == 1 ? '' : 's'}',
                            loading: () => '— devices',
                            error: (_, __) => '— devices',
                          ),
                          style: TextStyle(
                            color: colors.textTer,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 170,
              height: 140,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      imageUrl,
                      //fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 100,
                          height: 100,
                          color: colors.bgSec,
                          child: Icon(
                            Icons.image,
                            color: colors.textTer,
                            size: 40,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreenColors {
  static const bgPrimary = Color(0xFFFDFDFD);
  static const bgPrimaryDark = Color(0xFF0F0F0F);
  static const bgSecondary = Color(0xFFF5F5F7);
  static const bgSecondaryDark = Color(0xFF1C1C1E); // Adjusted for dark mode contrast
  static const surfacePrimary = Color(0xFFFFFFFF);
  static const surfacePrimaryDark = Color(0xFF1C1C1E);
  static const textPrimary = Color(0xFF0F172A);
  static const textPrimaryDark = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF475569);
  static const textSecondaryDark = Color(0xB3FFFFFF); // 70%
  static const textTertiary = Color(0xFF64748B);
  static const textTertiaryDark = Color(0x80FFFFFF); // 50%
  static const iconPrimary = Color(0xFF475569);
  static const iconPrimaryDark = Color(0xB3FFFFFF); // 70%
  static const actionPrimaryBg = Color(0xFFFFFFFF);
  static const actionPrimaryBgDark = Color(0xFF2C2C2E);
  static const shadowCard = Color(0x26475569); // 15%
  static const shadowCardDark = Color(0x66000000); // 40%
  static const borderSubtle = Color(0x4DFFFFFF); // 30%
  static const borderSubtleDark = Color(0x1AFFFFFF); // 10%
  static const inputBg = Color(0xFFFEFEFE);
  static const inputBgDark = Color(0xFF1A1A1A);
  static const inputBorder = Color(0xFFE2E8F0);
  static const inputBorderDark = Color(0xFF3C4043);
  static const inputBorderFocus = Color(0xFF3B82F6);
  static const inputBorderFocusDark = Color(0xFFF8F9FA);

  final bool isDark;

  const _ScreenColors(this.isDark);

  Color get bg => isDark ? bgPrimaryDark : bgPrimary;
  Color get bgSec => isDark ? bgSecondaryDark : bgSecondary;
  Color get surface => isDark ? surfacePrimaryDark : surfacePrimary;
  Color get textPri => isDark ? textPrimaryDark : textPrimary;
  Color get textSec => isDark ? textSecondaryDark : textSecondary;
  Color get textTer => isDark ? textTertiaryDark : textTertiary;
  Color get iconPri => isDark ? iconPrimaryDark : iconPrimary;
  Color get actionBg => isDark ? actionPrimaryBgDark : actionPrimaryBg;
  Color get shadow => isDark ? shadowCardDark : shadowCard;
  Color get border => isDark ? borderSubtleDark : borderSubtle;
  Color get inputBackground => isDark ? inputBgDark : inputBg;
  Color get inputBorderColor => isDark ? inputBorderDark : inputBorder;
  Color get inputFocusBorder => isDark ? inputBorderFocusDark : inputBorderFocus;
}
