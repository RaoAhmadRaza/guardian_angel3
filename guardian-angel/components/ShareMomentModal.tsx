import React, { useState } from 'react';
import { X, Camera, Image as ImageIcon, ArrowUp, Plus } from 'lucide-react';

interface ShareMomentModalProps {
  isOpen: boolean;
  onClose: () => void;
  onShare: (caption: string, imageUrl: string) => void;
}

export const ShareMomentModal: React.FC<ShareMomentModalProps> = ({ isOpen, onClose, onShare }) => {
  const [caption, setCaption] = useState('');
  const [selectedImage, setSelectedImage] = useState<string | null>(null);
  const [isUploading, setIsUploading] = useState(false);

  if (!isOpen) return null;

  const handleSimulateUpload = () => {
    setIsUploading(true);
    // Simulate a high-end photo selection/upload
    setTimeout(() => {
      setSelectedImage("https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&q=80&w=800");
      setIsUploading(false);
    }, 1200);
  };

  const handleShare = () => {
    if (!selectedImage) return;
    onShare(caption, selectedImage);
    setCaption('');
    setSelectedImage(null);
    onClose();
  };

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center p-6">
      {/* Backdrop */}
      <div 
        className="absolute inset-0 bg-black/40 backdrop-blur-md animate-in fade-in duration-300"
        onClick={onClose}
      />
      
      {/* Modal Card */}
      <div className="relative w-full max-w-sm bg-white/90 backdrop-blur-2xl rounded-[32px] shadow-2xl overflow-hidden animate-in zoom-in-95 slide-in-from-bottom-10 duration-500 border border-white/40">
        
        {/* Header */}
        <div className="p-4 flex items-center justify-between border-b border-gray-100">
            <button onClick={onClose} className="p-2 text-gray-400 hover:text-gray-600">
                <X className="w-5 h-5" />
            </button>
            <h3 className="text-[17px] font-bold text-gray-900">Share Moment</h3>
            <div className="w-9" /> {/* Spacer */}
        </div>

        {/* Content */}
        <div className="p-6 space-y-6">
            
            {/* Image Placeholder / Preview */}
            <button 
                onClick={handleSimulateUpload}
                disabled={isUploading}
                className={`w-full aspect-square rounded-[24px] border-2 border-dashed transition-all flex flex-col items-center justify-center gap-3 overflow-hidden group relative
                    ${selectedImage ? 'border-transparent bg-gray-100' : 'border-gray-200 bg-gray-50/50 hover:bg-gray-100/50'}
                    ${isUploading ? 'opacity-50' : ''}
                `}
            >
                {selectedImage ? (
                    <>
                        <img src={selectedImage} className="w-full h-full object-cover" />
                        <div className="absolute inset-0 bg-black/20 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                            <Camera className="w-8 h-8 text-white" />
                        </div>
                    </>
                ) : (
                    <>
                        <div className="w-16 h-16 rounded-full bg-blue-50 flex items-center justify-center text-blue-500 group-hover:scale-110 transition-transform">
                            {isUploading ? (
                                <div className="w-6 h-6 border-3 border-blue-500 border-t-transparent rounded-full animate-spin" />
                            ) : (
                                <Camera className="w-8 h-8" />
                            )}
                        </div>
                        <span className="text-sm font-bold text-gray-400">Tap to capture or upload</span>
                    </>
                )}
            </button>

            {/* Caption Input */}
            <div className="space-y-1">
                <label className="text-[11px] font-bold text-gray-400 uppercase tracking-widest px-1">Caption</label>
                <textarea 
                    className="w-full bg-transparent border-none outline-none text-[17px] font-medium text-gray-900 placeholder-gray-300 resize-none h-20 px-1"
                    placeholder="Tell your community about this moment..."
                    value={caption}
                    onChange={(e) => setCaption(e.target.value)}
                />
            </div>

            {/* Share Button */}
            <button 
                onClick={handleShare}
                disabled={!selectedImage || isUploading}
                className={`w-full py-4 rounded-2xl flex items-center justify-center gap-2 font-bold transition-all active:scale-95 shadow-lg
                    ${selectedImage && !isUploading 
                        ? 'bg-blue-600 text-white shadow-blue-500/20' 
                        : 'bg-gray-100 text-gray-400 cursor-not-allowed shadow-none'}
                `}
            >
                <ArrowUp className="w-5 h-5 stroke-[3px]" />
                Share to Community
            </button>
        </div>
      </div>
    </div>
  );
};