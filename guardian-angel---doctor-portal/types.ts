
export enum PatientStatus {
  STABLE = 'Stable',
  NEEDS_ATTENTION = 'Needs Attention'
}

export enum MessageTag {
  ADVICE = 'Advice',
  FOLLOW_UP = 'Follow-up',
  OBSERVATION = 'Observation'
}

export enum NoteVisibility {
  DOCTOR_ONLY = 'Doctor Only',
  SHARED = 'Shared with Caregiver'
}

export interface Patient {
  id: string;
  name: string;
  age: number;
  caregiverName: string;
  status: PatientStatus;
  lastUpdate: string;
  photo?: string;
  conditions?: string[];
}

export interface VitalData {
  time: string;
  value: number;
}

export interface Medication {
  name: string;
  dosage: string;
  frequency: string;
  adherence: number; // percentage
}

export interface MedicalReport {
  id: string;
  type: string;
  date: string;
  source: string;
  url: string;
}

export interface DoctorNote {
  id: string;
  content: string;
  timestamp: string;
  visibility: NoteVisibility;
}

export interface ChatMessage {
  id: string;
  sender: 'Doctor' | 'Caregiver' | 'AI Guardian';
  text: string;
  timestamp: string;
  tag?: MessageTag;
}
