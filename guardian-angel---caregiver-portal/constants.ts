
import { AlertTriangle, Home, User, Bell, ClipboardList, FileText, MessageSquare, Settings } from 'lucide-react';

export const COLORS = {
  primary: '#3B82F6', // Blue
  success: '#10B981', // Green
  warning: '#F59E0B', // Amber
  danger: '#EF4444',  // Red
  background: '#F8FAFC',
  card: '#FFFFFF',
};

export const NAVIGATION_ITEMS = [
  { id: 'dashboard', label: 'Dashboard', icon: Home },
  { id: 'patient', label: 'Patient', icon: User },
  { id: 'alerts', label: 'Alerts', icon: Bell },
  { id: 'tasks', label: 'Tasks', icon: ClipboardList },
  { id: 'reports', label: 'Reports', icon: FileText },
  { id: 'chat', label: 'Chat', icon: MessageSquare },
  { id: 'settings', label: 'Settings', icon: Settings },
];

export const MOCK_PATIENT = {
  id: 'p1',
  name: 'Eleanor Vance',
  age: 78,
  photoUrl: 'https://picsum.photos/id/64/200/200',
  status: 'Stable' as const,
};

export const MOCK_ALERTS = [
  { id: 'a1', type: 'SOS', description: 'SOS triggered from bedroom', timestamp: '2 mins ago', resolved: false },
  { id: 'a2', type: 'Medication', description: 'Morning vitamins missed', timestamp: '1 hour ago', resolved: false },
  { id: 'a3', type: 'Geo-Fence', description: 'Exited safe zone: Back Garden', timestamp: 'Yesterday', resolved: true },
] as const;
