import React, { useState } from 'react';
import { X, User, Stethoscope, Heart, Users, Check, Camera, Shield, Bell } from 'lucide-react';
import { ViewType, ChatSession } from '../types';

interface AddMemberModalProps {
  isOpen: boolean;
  onClose: () => void;
  onAdd: (newMember: Partial<ChatSession>) => void;
}

const ROLES = [
  { type: ViewType.CAREGIVER, label: 'Family', icon: Heart, color: 'bg-blue-500' },
  { type: ViewType.DOCTOR, label: 'Doctor', icon: Stethoscope, color: 'bg-indigo-500' },
  { type: ViewType.COMMUNITY, label: 'Neighbor', icon: Users, color: 'bg-orange-500' },
  { type: ViewType.AI_COMPANION, label: 'Assistant', icon: Shield, color: 'bg-purple-500' },
];

export const AddMemberModal: React.FC<AddMemberModalProps> = ({ isOpen, onClose, onAdd }) => {
  const [name, setName] = useState('');
  const [selectedRole, setSelectedRole] = useState(ROLES[0]);
  const [isSubmitting, setIsSubmitting] = useState(false);

  if (!isOpen) return null;

  const handleSubmit = () => {
    if (!name.trim()) return;
    
    setIsSubmitting(true);
    // Simulate haptic/processing
    setTimeout(() => {
      onAdd({
        name,
        type: selectedRole.type,
        subtitle: `Added today`,
        isOnline: true,
        messages: [],
      });
      setIsSubmitting(false);
      setName('');
      onClose();
    }, 600);
  };

  return (
    <div className="fixed inset-0 z-[70] flex flex-col justify-end">
      {/* Backdrop */}
      <div 
        className="absolute inset-0 bg-black/40 backdrop-blur-[2px] animate-in fade-in duration-300" 
        onClick={onClose}
      />
      
      {/* Bottom Sheet */}
      <div className="relative w-full max-w-lg mx-auto bg-white/80 backdrop-blur-2xl rounded-t-[32px] shadow-2xl p-6 pb-12 animate-in slide-in-from-bottom-full duration-500 border-t border-white/50">
        
        {/* Grabber Handle */}
        <div className="absolute top-3 left-1/2 -translate-x-1/2 w-10 h-1.5 bg-gray-300/60 rounded-full" />

        {/* Header */}
        <div className="flex items-center justify-between mb-8 pt-2">
            <button onClick={onClose} className="text-[17px] text-blue-600 font-medium px-2">Cancel</button>
            <h2 className="text-[17px] font-bold text-gray-900">New Member</h2>
            <button 
                onClick={handleSubmit} 
                disabled={!name.trim() || isSubmitting}
                className={`text-[17px] font-bold px-2 transition-opacity ${!name.trim() || isSubmitting ? 'opacity-30' : 'text-blue-600'}`}
            >
                {isSubmitting ? 'Adding...' : 'Add'}
            </button>
        </div>

        {/* Profile Creation Section */}
        <div className="flex flex-col items-center gap-6 mb-8">
            <div className={`w-28 h-28 rounded-full ${selectedRole.color} flex items-center justify-center text-white shadow-xl relative group overflow-hidden transition-all duration-500`}>
                <selectedRole.icon className="w-12 h-12" />
                <div className="absolute inset-0 bg-black/10 opacity-0 group-hover:opacity-100 flex items-center justify-center transition-opacity">
                    <Camera className="w-6 h-6" />
                </div>
            </div>
            
            <div className="w-full space-y-4">
                <div className="bg-gray-100/50 rounded-2xl p-1 shadow-inner">
                    <input 
                        type="text" 
                        placeholder="Member Name" 
                        value={name}
                        onChange={(e) => setName(e.target.value)}
                        className="w-full bg-transparent border-none outline-none px-4 py-4 text-xl font-medium text-gray-900 placeholder-gray-400 text-center"
                        autoFocus
                    />
                </div>
            </div>
        </div>

        {/* Role Selector */}
        <div className="space-y-4">
            <h3 className="text-[13px] font-bold text-gray-400 uppercase tracking-widest px-1">Choose Role</h3>
            <div className="grid grid-cols-4 gap-3">
                {ROLES.map((role, i) => {
                    const isSelected = selectedRole.type === role.type;
                    return (
                        <button 
                            key={i}
                            onClick={() => setSelectedRole(role)}
                            className={`flex flex-col items-center gap-2 p-3 rounded-2xl transition-all active:scale-90
                                ${isSelected ? 'bg-white shadow-md border border-gray-100' : 'bg-transparent'}
                            `}
                        >
                            <div className={`w-12 h-12 rounded-full flex items-center justify-center transition-colors
                                ${isSelected ? role.color + ' text-white' : 'bg-gray-100 text-gray-400'}
                            `}>
                                <role.icon className="w-6 h-6" />
                            </div>
                            <span className={`text-[11px] font-bold ${isSelected ? 'text-gray-900' : 'text-gray-400'}`}>{role.label}</span>
                        </button>
                    );
                })}
            </div>
        </div>

        {/* Verification Note */}
        <div className="mt-10 p-4 bg-blue-50/50 rounded-2xl border border-blue-100/50 flex items-start gap-3">
            <Shield className="w-5 h-5 text-blue-500 shrink-0" />
            <p className="text-[12px] text-blue-700 leading-snug">
                This member will be able to message you and see your recent health status if shared.
            </p>
        </div>

      </div>
    </div>
  );
};