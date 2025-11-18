import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room_model.dart';
import '../src/data/models/device_model.dart' as domain;
import '../src/logic/providers/device_providers.dart';
import '../src/logic/providers/ui_state_providers.dart';
import '../src/logic/providers/sync_providers.dart';
import '../src/logic/sync/failed_ops_provider.dart';
import '../src/automation/device_protocol.dart';
import '../src/logic/providers/room_providers.dart';
import '../src/data/models/room_model.dart' as domain_room;
import '../src/core/keys.dart';

class RoomDetailScreen extends ConsumerStatefulWidget {
  final RoomModel room;
  final Function(RoomModel updatedRoom, List<domain.DeviceModel> updatedDevices)? onRoomUpdated;
  final Function()? onRoomDeleted;

  const RoomDetailScreen({
    super.key,
    required this.room,
    this.onRoomUpdated,
    this.onRoomDeleted,
  });

  @override
  ConsumerState<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends ConsumerState<RoomDetailScreen> {
  late RoomModel currentRoom;

  @override
  void initState() {
    super.initState();
    currentRoom = widget.room;
    // Expose selected room id to UI state providers
    // Set after first frame to ensure ref is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedRoomIdProvider.notifier).state = currentRoom.id;
    });
  }

  String _getRoomImageUrl() {
    // Extract icon filename from the imageUrl path
    final iconName = currentRoom.imageUrl.split('/').last.toLowerCase();
    
    // Map icon names to appropriate network images
    switch (iconName) {
      case 'sofa.png':
        // Living room image
        return 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=800&q=80';
      case 'utensils.png':
        // Kitchen image
        return 'https://images.unsplash.com/photo-1556911220-bff31c812dba?w=800&q=80';
      case 'bed.png':
        // Bedroom image
        return 'https://images.unsplash.com/photo-1540518614846-7eded433c457?w=800&q=80';
      case 'bathtub.png':
        // Bathroom image
        return 'https://images.unsplash.com/photo-1552321554-5fefe8c9ef14?w=800&q=80';
      default:
        // Default living room image for any other icon
        return 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=800&q=80';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Column(
        children: [
          // Header with curved image (static)
          Stack(
              children: [
                // Purple background
                Container(
                  height: 370,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                    color: Color(0xFF2B1F4D),
                  ),
                ),
                // Circular image container
                Positioned(
  top: 210,
  left: 190, // adjust to place the circle where you want
  child: Container(
    width: 230,
    height: 230,
    // outer ring style (the dark ring you see in screenshot)
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.fromARGB(255, 155, 146, 205), // dark outer
          Color.fromARGB(255, 155, 146, 205), // slightly lighter
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.85),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    // padding creates the visible ring thickness
    child: Padding(
      padding: const EdgeInsets.all(18.0), // ring thickness — tweak as needed
      child: Container(
        // inner circle container so we can add a thin border if we want
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF2E2A4A).withOpacity(0.1), // inner ring edge
            width: 1, // inner border thickness
          ),
        ),
        child: ClipOval(
          child: Image.network(
            _getRoomImageUrl(),
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: Icon(
                  Icons.image,
                  color: Colors.grey[500],
                  size: 60,
                ),
              );
            },
          ),
        ),
      ),
    ),
  ),
),

                // Top navigation bar
                Positioned(
                  top: 60,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showEditRoomDialog(context),
                          child: const Icon(
                            Icons.edit_outlined,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Room name and device count
                Positioned(
                  top: 290,
                  left: 29,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayRoomName(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (_) {
                          final devicesAsync = ref.watch(devicesControllerProvider(currentRoom.id));
                          final count = devicesAsync.maybeWhen(data: (d) => d.length, orElse: () => 0);
                          return Text(
                            '$count devices',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          // Reduce vertical gap between header and temperature card
          const SizedBox(height: 17),
          // Temperature card (static)
          Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              height: 75,
              width: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.device_thermostat,
                    color: Color(0xFFFFA726),
                    size: 40,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current temperature',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Text(
                          'in the ${_displayRoomName()}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    '25°',
                    style: TextStyle(
                      color: Color(0xFF2D2D2D),
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          // Tighter spacing before devices grid
          //const SizedBox(height: 6),
          
          // Device grid (only scrollable part)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Consumer(
                builder: (context, ref, _) {
                  final devicesAsync = ref.watch(devicesControllerProvider(currentRoom.id));
                  return devicesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, st) => Center(child: Text('Failed to load devices: $e')),
                    data: (devices) => GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        return _buildDeviceCard(devices[index]);
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      
    );
  }

  Widget _buildDeviceCard(domain.DeviceModel device) {
    // Map device type to image
    String getDeviceImage(domain.DeviceType type) {
      switch (type) {
        case domain.DeviceType.bulb:
          return 'images/bulb.png';
        case domain.DeviceType.lamp:
          return 'images/lamp.png';
        case domain.DeviceType.fan:
          return 'images/fan.png';
      }
    }

    String _timeAgo(DateTime dt) {
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    }

    return PhysicalModel(
      key: AppKeys.deviceTileKey(device.id),
      color: Colors.white,
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      shadowColor: Colors.black.withOpacity(0.3),
      clipBehavior: Clip.antiAlias,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 4),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Circular icon positioned at top-left corner (75% visible)
              Positioned(
                left: -12,
                top: -12,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color.fromARGB(255, 150, 150, 191),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Image.asset(
                      getDeviceImage(device.type),
                      width: 45,
                      height: 45,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              // Main content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Toggle Switch at top-right
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Builder(builder: (context) {
                          final pending = ref.watch(devicesPendingOpsProvider(currentRoom.id));
                          final isPending = pending.contains(device.id);
                          final failedOps = ref.watch(failedOpsListProvider).maybeWhen(
                                data: (list) => list,
                                orElse: () => const [],
                              );
                          final failedForDevice = failedOps.where((o) => o.entityType == 'device' && o.entityId == device.id).toList()
                            ..sort((a,b) => (b.lastAttemptAt ?? b.queuedAt).compareTo(a.lastAttemptAt ?? a.queuedAt));
                          final failedOp = failedForDevice.isNotEmpty ? failedForDevice.first : null;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isPending)
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    key: AppKeys.devicePendingIndicator(device.id),
                                    strokeWidth: 2,
                                  ),
                                ),
                              if (!isPending && failedOp != null)
                                IconButton(
                                  onPressed: () {
                                    final snack = SnackBar(
                                      content: const Text('Device action failed'),
                                      backgroundColor: Colors.red,
                                      action: SnackBarAction(
                                        label: 'Retry',
                                        textColor: Colors.white,
                                        onPressed: () async {
                                          await ref.read(failedOpsControllerProvider).retry(failedOp.opId);
                                        },
                                      ),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(snack);
                                  },
                                  icon: const Icon(Icons.error_outline, color: Colors.red),
                                  tooltip: 'Retry failed action',
                                ),
                              const SizedBox(width: 6),
                              Transform.scale(
                                scale: 0.9,
                                child: Switch(
                                  key: AppKeys.deviceToggleKey(device.id),
                                  value: device.isOn,
                                  onChanged: isPending
                                      ? null
                                      : (value) async {
                                          await ref
                                              .read(devicesControllerProvider(currentRoom.id).notifier)
                                              .toggleDevice(device.id, value);
                                        },
                                  activeColor: Colors.white,
                                  activeTrackColor: const Color(0xFF4D7CFE),
                                  inactiveThumbColor: Colors.white,
                                  inactiveTrackColor: const Color(0xFFE0E0E0),
                                  trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Device Name
                    Text(
                      device.name,
                      style: const TextStyle(
                        color: Color(0xFF2D2D2D),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Location
                      Text(
                    _displayRoomName(),
                      style: const TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Builder(builder: (context) {
                      final pending = ref.watch(devicesPendingOpsProvider(currentRoom.id));
                      final isPending = pending.contains(device.id);
                      final failedOps = ref.watch(failedOpsListProvider).maybeWhen(
                            data: (list) => list,
                            orElse: () => const [],
                          );
                      final hasFailed = failedOps.any((o) => o.entityType == 'device' && o.entityId == device.id);
                      final statusText = isPending ? 'Pending' : (hasFailed ? 'Failed' : 'OK');
                      final statusColor = isPending ? const Color(0xFFFFA726) : (hasFailed ? Colors.red : Colors.green);
                      return Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusText,
                            style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Text(
                            'Last seen ${_timeAgo(device.lastSeen)}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditRoomDialog(BuildContext context) {
  final TextEditingController nameController = TextEditingController(text: currentRoom.name);
    String selectedIcon = currentRoom.icon;
    int selectedColor = currentRoom.color;

    // Initialize the editing buffer with current domain devices
    final originalDevices = ref.read(devicesControllerProvider(currentRoom.id)).value ?? <domain.DeviceModel>[];
    ref.read(editingDevicesProvider(currentRoom.id).notifier).state = List<domain.DeviceModel>.from(originalDevices);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final tempDevices = ref.watch(editingDevicesProvider(currentRoom.id));
            return Container(
              height: MediaQuery.of(context).size.height * 0.5,
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
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
                              'Edit Room Details',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2D2D2D),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFF9E9E9E)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Room Name Field
                    TextField(
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
                    const SizedBox(height: 20),

                    const Divider(),
                    const SizedBox(height: 12),

                    // Devices Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Devices (${tempDevices.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D2D2D),
                          ),
                        ),
                        TextButton.icon(
                          key: AppKeys.addDeviceButton,
                          onPressed: tempDevices.length < 10
                              ? () {
                                  _showAddDeviceDialog(context);
                                }
                              : null,
                          icon: Icon(
                            Icons.add_circle_outline,
                            color: tempDevices.length < 10
                                ? const Color(0xFF4D7CFE)
                                : Colors.grey,
                          ),
                          label: Text(
                            'Add Device',
                            style: TextStyle(
                              color: tempDevices.length < 10
                                  ? const Color(0xFF4D7CFE)
                                  : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Device List
                    ...tempDevices.map((device) {
                      IconData deviceIcon;
                      switch (device.type) {
                        case domain.DeviceType.bulb:
                          deviceIcon = Icons.lightbulb_outline;
                          break;
                        case domain.DeviceType.lamp:
                          deviceIcon = Icons.light_outlined;
                          break;
                        case domain.DeviceType.fan:
                          deviceIcon = Icons.air;
                          break;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Color(selectedColor).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(deviceIcon, color: Color(selectedColor), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    device.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2D2D2D),
                                    ),
                                  ),
                                  Text(
                                    device.type.name,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF9E9E9E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: device.isOn
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                device.isOn ? 'ON' : 'OFF',
                                style: TextStyle(
                                  color: device.isOn ? Colors.green : Colors.grey,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () {
                                final list = [...ref.read(editingDevicesProvider(currentRoom.id))]
                                  ..remove(device);
                                ref.read(editingDevicesProvider(currentRoom.id).notifier).state = list;
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),

                    if (tempDevices.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.devices_other, size: 40, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                'No devices added yet',
                                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Delete Room Button
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      onPressed: () {
                        _confirmDeleteRoom(context, tempDevices);
                      },
                      child: const Text(
                        'Delete Room',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF9E9E9E),
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
                            onPressed: () async {
                              final roomName = nameController.text.trim();

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

                              // Get image URL based on selected icon
                              String imageUrl = _getImageUrlFromIcon(selectedIcon);

                              // Create updated room
                              final updatedRoom = currentRoom.copyWith(
                                name: roomName,
                                icon: selectedIcon,
                                color: selectedColor,
                                imageUrl: imageUrl,
                                deviceCount: tempDevices.length,
                              );

                              // Persist room changes to domain via RoomsController (Riverpod)
                              try {
                                final roomsAsync = ref.read(roomsControllerProvider);
                                final rooms = roomsAsync.value ?? const <domain_room.RoomModel>[];
                                domain_room.RoomModel? existing;
                                for (final r in rooms) {
                                  if (r.id == currentRoom.id) { existing = r; break; }
                                }

                                // Map selected asset path to iconId
                                final iconId = selectedIcon.split('/').last.split('.').first;

                                final updatedDomain = (existing ?? domain_room.RoomModel(
                                  id: currentRoom.id,
                                  name: currentRoom.name,
                                  iconId: iconId,
                                  color: selectedColor,
                                )).copyWith(
                                  name: roomName,
                                  iconId: iconId,
                                  color: selectedColor,
                                );

                                await ref.read(roomsControllerProvider.notifier).updateRoom(updatedDomain);
                              } catch (_) {
                                // Non-fatal: UI will still update devices; name fallback remains legacy until rooms refresh
                              }

                              // Persist device changes via controller
                              final notifier = ref.read(devicesControllerProvider(currentRoom.id).notifier);
                              final drafts = ref.read(editingDevicesProvider(currentRoom.id));
                              final original = originalDevices;

                              // Deletes
                              final originalIds = original.map((d) => d.id).toSet();
                              final draftIds = drafts.map((d) => d.id).toSet();
                              final toDelete = originalIds.difference(draftIds);
                              for (final id in toDelete) {
                                await notifier.deleteDevice(id);
                              }

                              // Creates and Updates
                              for (final d in drafts) {
                                if (d.id.isEmpty) {
                                  await notifier.addDevice(d);
                                } else {
                                  await notifier.updateDevice(d);
                                }
                              }

                              Navigator.pop(context);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${updatedRoom.name} updated successfully!'),
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
                              'Save Changes',
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

  void _showAddDeviceDialog(BuildContext context) {
    if (ref.read(editingDevicesProvider(currentRoom.id)).length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You can only add up to 10 devices per room.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

  String selectedType = 'Bulb';
    String selectedMode = 'MQTT';
    final TextEditingController brokerController = TextEditingController(text: '127.0.0.1');
    final TextEditingController topicController = TextEditingController();
    final TextEditingController stateTopicController = TextEditingController();
    final TextEditingController payloadOnController = TextEditingController(text: '{"isOn":true}');
    final TextEditingController payloadOffController = TextEditingController(text: '{"isOn":false}');
    bool linking = false;
    bool linked = false;
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Add Device', style: TextStyle(color: Color(0xFF2D2D2D))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                style: const TextStyle(color: Color(0xFF2D2D2D)),
                decoration: InputDecoration(
                  labelText: 'Device Type',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'Bulb', child: Text('Light Bulb')),
                  DropdownMenuItem(value: 'Lamp', child: Text('Lamp')),
                  DropdownMenuItem(value: 'Fan', child: Text('Fan')),
                ],
                onChanged: (value) {
                  setDialogState(() => selectedType = value!);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: AppKeys.deviceProtocolDropdown,
                value: selectedMode,
                decoration: InputDecoration(
                  labelText: 'Control Mode',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'MQTT',
                    child: Text(
                      'Local (MQTT)',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Cloud',
                    child: Text(
                      'Cloud',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    selectedMode = value!;
                    // reset
                    linking = selectedMode == 'Cloud';
                    linked = selectedMode == 'Cloud' ? false : true;
                  });
                  if (selectedMode == 'Cloud') {
                    Future.delayed(const Duration(seconds: 1), () {
                      if (mounted) {
                        setDialogState(() {
                          linking = false;
                          linked = true;
                        });
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              if (selectedMode == 'MQTT') ...[
                TextField(
                  key: AppKeys.deviceBrokerField,
                  controller: brokerController,
                  style: const TextStyle(color: Color(0xFF2D2D2D)),
                  decoration: InputDecoration(
                    labelText: 'MQTT Broker',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hintText: 'e.g., localhost or 192.168.1.10',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: AppKeys.deviceTopicField,
                  controller: topicController,
                  style: const TextStyle(color: Color(0xFF2D2D2D)),
                  decoration: InputDecoration(
                    labelText: 'MQTT Topic',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hintText: 'e.g., home/living/main_light',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: AppKeys.deviceStateTopicField,
                  controller: stateTopicController,
                  style: const TextStyle(color: Color(0xFF2D2D2D)),
                  decoration: InputDecoration(
                    labelText: 'State Topic (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hintText: 'Leave blank to default to <cmdTopic>/state',
                  ),
                ),
                const SizedBox(height: 12),
                ExpansionTile(
                  title: const Text('Advanced Payload Templates'),
                  children: [
                    TextField(
                      controller: payloadOnController,
                      style: const TextStyle(color: Color(0xFF2D2D2D)),
                      decoration: InputDecoration(
                        labelText: 'Payload ON Template',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        hintText: '{"isOn":true}'
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: payloadOffController,
                      style: const TextStyle(color: Color(0xFF2D2D2D)),
                      decoration: InputDecoration(
                        labelText: 'Payload OFF Template',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        hintText: '{"isOn":false}'
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Placeholders supported: \'\${deviceId}\' (replaced at publish time)', style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
                  ],
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tip: MQTT topics are case-sensitive, with levels separated by / and no spaces.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                  ),
                ),
              ],
              if (selectedMode == 'Cloud') ...[
                Row(
                  children: [
                    if (linking) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    if (!linking && linked) const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(linking ? 'Linking device…' : (linked ? 'Linked' : '')),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                key: AppKeys.deviceNameField,
                controller: nameController,
                style: const TextStyle(color: Color(0xFF2D2D2D)),
                decoration: InputDecoration(
                  labelText: 'Device Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'e.g., Main Light',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF9E9E9E))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4D7CFE),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please enter a device name'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                // Validate MQTT topic if needed
                if (selectedMode == 'MQTT') {
                  final topic = topicController.text.trim();
                  final valid = topic.isNotEmpty && topic.contains('/') && !topic.contains(' ');
                  if (!valid) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Please enter a valid MQTT topic (no spaces, contains /).'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                }

                // For cloud: wait until linked
                if (selectedMode == 'Cloud' && !linked) {
                  return; // ignore presses until link completes
                }

                domain.DeviceType mapType(String s) {
                  switch (s) {
                    case 'Lamp':
                      return domain.DeviceType.lamp;
                    case 'Fan':
                      return domain.DeviceType.fan;
                    case 'Bulb':
                    default:
                      return domain.DeviceType.bulb;
                  }
                }

                Map<String, dynamic> state = const {};
                if (selectedMode == 'MQTT') {
                  final topic = topicController.text.trim();
                  final userStateTopic = stateTopicController.text.trim();
                  final effectiveStateTopic = userStateTopic.isEmpty ? '${topic}/state' : userStateTopic;
                  // Validation: if user explicitly entered same state topic as cmd, confirm intent
                  if (userStateTopic.isNotEmpty && userStateTopic == topic) {
                    final proceed = await showDialog<bool>(
                      context: dialogContext,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Use Same Topic?'),
                        content: const Text('State topic matches the command topic. This is uncommon and can cause loops. Proceed anyway?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Proceed')),
                        ],
                      ),
                    );
                    if (proceed != true) return;
                  }
                  // If user explicitly sets same as cmd topic, omit to keep legacy normalization simple
                  state = {
                    'protocolData': buildMqttProtocolData(
                      broker: brokerController.text.trim().isEmpty ? 'localhost' : brokerController.text.trim(),
                      topic: topic,
                      stateTopic: (effectiveStateTopic == topic) ? null : effectiveStateTopic,
                      payloadOn: payloadOnController.text.trim().isEmpty ? '{"isOn":true}' : payloadOnController.text.trim(),
                      payloadOff: payloadOffController.text.trim().isEmpty ? '{"isOn":false}' : payloadOffController.text.trim(),
                    ),
                  };
                }

                final newDevice = domain.DeviceModel(
                  id: '', // repo will assign
                  roomId: currentRoom.id,
                  type: mapType(selectedType),
                  name: name,
                  isOn: false,
                  state: state,
                );

                final list = [...ref.read(editingDevicesProvider(currentRoom.id))]..add(newDevice);
                ref.read(editingDevicesProvider(currentRoom.id).notifier).state = list;

                Navigator.pop(dialogContext);
              },
              key: AppKeys.saveDeviceButton,
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteRoom(BuildContext context, List<domain.DeviceModel> tempDevices) {
    // Edge Case 1: Check if any device is running
  final hasActiveDevices = tempDevices.any((device) => device.isOn == true);
    if (hasActiveDevices) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Cannot Delete Room', style: TextStyle(color: Color(0xFF2D2D2D))),
          content: const Text(
            'This room has active devices running. Turn them off before deleting.',
            style: TextStyle(color: Color(0xFF9E9E9E)),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4D7CFE),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Room', style: TextStyle(color: Color(0xFF2D2D2D))),
        content: Text(
          'Are you sure you want to delete "${currentRoom.name}"? This action cannot be undone.',
          style: const TextStyle(color: Color(0xFF9E9E9E)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF9E9E9E))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              // Persistently delete the room via controller
              try {
                await ref.read(roomsControllerProvider.notifier).deleteRoom(currentRoom.id);
              } finally {
                // Close confirmation dialog, bottom sheet (if open), and detail screen
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.pop(dialogContext);
                }
                if (Navigator.of(context).canPop()) {
                  Navigator.pop(context);
                }
                if (Navigator.of(context).canPop()) {
                  Navigator.pop(context);
                }
                // Notify parent callback if provided
                widget.onRoomDeleted?.call();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _getImageUrlFromIcon(String iconPath) {
    // Extract filename from path
    final filename = iconPath.split('/').last;

    // Map to network images
    switch (filename) {
      case 'sofa.png':
        return 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=800';
      case 'utensils.png':
        return 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=800';
      case 'bed.png':
        return 'https://images.unsplash.com/photo-1540518614846-7eded433c457?w=800';
      case 'bathtub.png':
        return 'https://images.unsplash.com/photo-1552321554-5fefe8c9ef14?w=800';
      default:
        return 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=800';
    }
  }
  String _displayRoomName() {
    final roomsAsync = ref.watch(roomsControllerProvider);
    final rooms = roomsAsync.value;
    if (rooms != null) {
      for (final r in rooms) {
        if (r.id == currentRoom.id) return r.name;
      }
    }
    return currentRoom.name;
  }
}
