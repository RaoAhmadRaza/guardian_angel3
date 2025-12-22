export enum ViewType {
  HUB = 'HUB',
  CAREGIVER = 'CAREGIVER',
  AI_COMPANION = 'AI_COMPANION',
  DOCTOR = 'DOCTOR',
  SYSTEM = 'SYSTEM',
  PEACE_OF_MIND = 'PEACE_OF_MIND',
  COMMUNITY = 'COMMUNITY',
}

export interface MessageAction {
  label: string;
  id: string;
  style?: 'primary' | 'secondary' | 'danger';
}

export interface Prescription {
  name: string;
  dosage: string;
  instructions: string;
}

export interface MedicationReminder {
  name: string;
  dosage: string;
  context: string;
  pillType: 'round' | 'capsule' | 'tablet';
  pillColor: string; // Tailwind class
  inventory?: {
    remaining: number;
    total: number;
    status: 'ok' | 'low' | 'refill';
  };
  sideEffects?: string[];
  doctorNotes?: string;
  streakDays?: number;
  nextDose?: {
    name: string;
    time: string;
  };
}

export interface Message {
  id: string;
  text: string;
  sender: 'user' | 'other' | 'system';
  timestamp: Date;
  type?: 'text' | 'audio' | 'alert' | 'health-snapshot';
  status?: 'sending' | 'sent' | 'delivered' | 'read';
  actions?: MessageAction[];
  reactions?: { emoji: string; fromMe: boolean }[];
  chartData?: number[];
  prescription?: Prescription;
  medication?: MedicationReminder;
  imageUrl?: string; // Support for community photos
}

export interface ChatSession {
  id: string;
  type: ViewType;
  name: string;
  subtitle?: string;
  avatarColor?: string; // Tailwind class equivalent or hex
  coverImage?: string; // For community views
  dailyPrompt?: string; // For community engagement
  goalProgress?: number; // Community target goal
  isOnline?: boolean;
  statusText?: string;
  messages: Message[];
  unreadCount?: number;
  nextAppointment?: Date;
  medicationProgress?: number;
}

export enum UserStatus {
  OK = 'OK',
  SOS = 'SOS',
}

export interface Vitals {
  heartRate: number;
  spO2: number;
  lastUpdated: Date;
}