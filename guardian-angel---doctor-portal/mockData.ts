
import { Patient, PatientStatus, NoteVisibility, MessageTag } from './types';

export const patients: Patient[] = [
  {
    id: '1',
    name: 'Eleanor Vance',
    age: 78,
    caregiverName: 'Sarah Vance',
    status: PatientStatus.STABLE,
    lastUpdate: '10 mins ago',
    photo: 'https://picsum.photos/seed/eleanor/200',
    conditions: ['Hypertension', 'Osteoarthritis']
  },
  {
    id: '2',
    name: 'Arthur Miller',
    age: 84,
    caregiverName: 'John Miller',
    status: PatientStatus.NEEDS_ATTENTION,
    lastUpdate: '2 mins ago',
    photo: 'https://picsum.photos/seed/arthur/200',
    conditions: ['Type 2 Diabetes', 'AFib']
  },
  {
    id: '3',
    name: 'Martha Stewart',
    age: 72,
    caregiverName: 'Emily Clark',
    status: PatientStatus.STABLE,
    lastUpdate: '1 hour ago',
    photo: 'https://picsum.photos/seed/martha/200',
    conditions: ['Post-Op Recovery', 'Mild Cognitive Impairment']
  }
];

export const vitalsHistory = [
  { time: '08:00', value: 72 },
  { time: '10:00', value: 75 },
  { time: '12:00', value: 82 },
  { time: '14:00', value: 70 },
  { time: '16:00', value: 78 },
  { time: '18:00', value: 85 },
  { time: '20:00', value: 74 },
];

export const medications = [
  { name: 'Lisinopril', dosage: '10mg', frequency: 'Daily', adherence: 98 },
  { name: 'Metformin', dosage: '500mg', frequency: 'Twice daily', adherence: 92 },
  { name: 'Atorvastatin', dosage: '20mg', frequency: 'Bedtime', adherence: 100 }
];

export const reports = [
  { id: 'r1', type: 'Blood Panel', date: '2023-10-24', source: 'Quest Diagnostics', url: '#' },
  { id: 'r2', type: 'ECG Report', date: '2023-10-15', source: 'CardioCenter', url: '#' },
  { id: 'r3', type: 'Urinalysis', date: '2023-09-30', source: 'St. Mary\'s Lab', url: '#' }
];

export const initialNotes = [
  { id: 'n1', content: 'Patient reports mild fatigue after morning walks. Adjusting sodium intake.', timestamp: 'Oct 25, 2023', visibility: NoteVisibility.SHARED },
  { id: 'n2', content: 'Observation: Blood pressure slightly elevated during night cycles.', timestamp: 'Oct 22, 2023', visibility: NoteVisibility.DOCTOR_ONLY }
];

export const initialMessages = [
  { id: 'm1', sender: 'Caregiver', text: 'Dr. Smith, Eleanor seems a bit more tired than usual this morning.', timestamp: '09:15 AM' },
  { id: 'm2', sender: 'Doctor', text: 'Thank you for noting that. I see her vitals were stable overnight. Let\'s monitor for another 24h.', timestamp: '09:25 AM', tag: MessageTag.ADVICE },
  { id: 'm3', sender: 'AI Guardian', text: 'System Check: Vitals within normal deviation. No emergency detected.', timestamp: '09:26 AM' }
];
