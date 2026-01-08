
export type PatientStatus = 'Stable' | 'Attention Needed' | 'Alert Active';

export interface Patient {
  id: string;
  name: string;
  age: number;
  photoUrl: string;
  status: PatientStatus;
}

export interface SafetyStatus {
  sos: {
    lastTrigger: string;
    status: 'Active' | 'Inactive';
  };
  geoFencing: {
    status: 'Inside Safe Zone' | 'Outside Safe Zone';
    lastExit?: string;
  };
  fallDetection: {
    lastEvent: string;
    status: 'Normal' | 'Detected';
  };
}

export interface HealthSummary {
  heartRate: 'Normal' | 'Irregular' | 'Elevated';
  oxygen: string; // e.g. "98%"
  sleepQuality: string; // e.g. "Good"
}

export interface Task {
  id: string;
  title: string;
  type: 'Medication' | 'Appointment' | 'Report';
  status: 'Pending' | 'Completed';
  time?: string;
}

export interface Alert {
  id: string;
  type: 'SOS' | 'Fall' | 'Geo-Fence' | 'Medication';
  description: string;
  timestamp: string;
  resolved: boolean;
}

export interface ChatMessage {
  id: string;
  sender: 'Patient' | 'Doctor' | 'AI Guardian' | 'Caregiver';
  text: string;
  timestamp: string;
}
