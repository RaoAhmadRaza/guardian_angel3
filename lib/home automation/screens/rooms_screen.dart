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
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
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
                        const Text(
                          'Add New Room',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2D2D2D),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Room Name Field
                    TextField(
                      key: AppKeys.roomNameField,
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Room Name',
                        hintText: 'e.g., Living Room',
                        prefixIcon: const Icon(Icons.meeting_room, color: Color(0xFF4D7CFE)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF4D7CFE),
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
                      decoration: InputDecoration(
                        labelText: 'Number of Devices',
                        hintText: '3',
                        prefixIcon: const Icon(Icons.devices, color: Color(0xFF4D7CFE)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF4D7CFE),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Icon Selector
                    const Text(
                      'Select Icon',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D2D2D),
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
                                    : const Color(0xFFF5F5F7),
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
                                      return const Icon(
                                        Icons.image,
                                        size: 40,
                                        color: Colors.grey,
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
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: Color(0xFF9E9E9E),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Stack(
        children: [
          // Header
          Container(
            height: 160,
            decoration: const BoxDecoration(
              color: Color(0xFF3D2E6B),
              borderRadius: BorderRadius.only(
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
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Rooms',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_horiz,
                      color: Colors.white,
                      size: 28,
                    ),
                    color: Colors.white,
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
                            const Text(
                              'Add new room',
                              style: TextStyle(
                                color: Color(0xFF2D2D2D),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE0E0E0),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
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
                          color: Colors.grey[400],
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: const TextStyle(
                        color: Color(0xFF2D2D2D),
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.search,
                    color: Colors.grey[400],
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
                      const Text(
                        'Your Rooms',
                        style: TextStyle(
                          color: Color(0xFF2D2D2D),
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8E8E8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: roomsAsync.when(
                          data: (rooms) => Text(
                            '${rooms.length}',
                            style: const TextStyle(
                              color: Color(0xFF6B6B6B),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          loading: () => const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          error: (_, __) => const Text(
                            '—',
                            style: TextStyle(
                              color: Color(0xFF6B6B6B),
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
                              const Icon(Icons.search_off, size: 48, color: Color(0xFF9E9E9E)),
                              const SizedBox(height: 12),
                              Text(
                                'No rooms match "${_searchQuery}"',
                                style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
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
                            style: const TextStyle(
                              color: Color(0xFF2D2D2D),
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
                            color: Colors.grey[400],
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
                          color: Colors.grey[300],
                          child: Icon(
                            Icons.image,
                            color: Colors.grey[500],
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
