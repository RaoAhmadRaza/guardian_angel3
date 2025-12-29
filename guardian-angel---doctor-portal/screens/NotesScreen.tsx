
import React, { useState } from 'react';
import { initialNotes } from '../mockData';
import { Patient, NoteVisibility } from '../types';

export const NotesScreen: React.FC<{ patient: Patient | null }> = ({ patient }) => {
  const [notes, setNotes] = useState(initialNotes);
  const [newNote, setNewNote] = useState('');
  const [visibility, setVisibility] = useState<NoteVisibility>(NoteVisibility.DOCTOR_ONLY);

  const addNote = () => {
    if (!newNote.trim()) return;
    const note = {
      id: Date.now().toString(),
      content: newNote,
      timestamp: new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
      visibility
    };
    setNotes([note, ...notes]);
    setNewNote('');
  };

  return (
    <div className="p-4 space-y-6">
      <div className="mb-2">
        <p className="text-xs font-black uppercase text-slate-400 tracking-widest mb-1">Observation Log</p>
        <h2 className="text-2xl font-black text-slate-900">Clinical Notes</h2>
      </div>

      <div className="bg-white rounded-[28px] p-5 shadow-sm border border-slate-100">
        <textarea 
          value={newNote}
          onChange={(e) => setNewNote(e.target.value)}
          placeholder="Clinical findings..." 
          className="w-full h-28 p-4 bg-slate-50 border-none rounded-2xl text-sm font-medium focus:ring-2 focus:ring-blue-100 transition-all resize-none mb-4"
        />
        <div className="flex flex-col space-y-3">
          <div className="flex bg-slate-100 p-1 rounded-2xl w-full">
            <button 
              onClick={() => setVisibility(NoteVisibility.DOCTOR_ONLY)}
              className={`flex-1 py-2 rounded-xl text-[10px] font-black uppercase transition-all ${
                visibility === NoteVisibility.DOCTOR_ONLY ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-400'
              }`}
            >
              Private
            </button>
            <button 
              onClick={() => setVisibility(NoteVisibility.SHARED)}
              className={`flex-1 py-2 rounded-xl text-[10px] font-black uppercase transition-all ${
                visibility === NoteVisibility.SHARED ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-400'
              }`}
            >
              Share with Team
            </button>
          </div>
          <button 
            onClick={addNote}
            className="w-full bg-blue-600 text-white py-4 rounded-[20px] font-bold shadow-lg shadow-blue-100 active:scale-95 transition-all"
          >
            Save Record
          </button>
        </div>
      </div>

      <div className="space-y-4">
        {notes.map((note) => (
          <div key={note.id} className="bg-white p-5 rounded-[28px] border border-slate-100 shadow-sm relative">
            <div className="flex justify-between items-center mb-3">
               <span className="text-[10px] font-black text-slate-300 uppercase tracking-widest">{note.timestamp}</span>
               <span className={`text-[9px] font-black uppercase px-2 py-0.5 rounded-full ${
                  note.visibility === NoteVisibility.SHARED 
                  ? 'bg-emerald-50 text-emerald-600' 
                  : 'bg-slate-100 text-slate-500'
               }`}>
                  {note.visibility === NoteVisibility.SHARED ? 'Shared' : 'Private'}
               </span>
            </div>
            <p className="text-sm font-medium text-slate-700 leading-relaxed mb-4">{note.content}</p>
            <div className="flex space-x-4 border-t border-slate-50 pt-3">
              <button className="text-[10px] font-black uppercase text-blue-600">Edit</button>
              <button className="text-[10px] font-black uppercase text-rose-400">Archive</button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};
