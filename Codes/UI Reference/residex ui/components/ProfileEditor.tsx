
import React, { useState, useRef } from 'react';
import { X, Camera, Check, Trash2, Upload } from 'lucide-react';
import { User } from '../types';

interface ProfileEditorProps {
  user: User;
  onSave: (updatedUser: Partial<User>) => void;
  onClose: () => void;
}

const GRADIENTS = [
  'bg-gradient-to-br from-cyan-400 to-blue-600',
  'bg-gradient-to-br from-emerald-400 to-teal-600',
  'bg-gradient-to-br from-purple-400 to-indigo-600',
  'bg-gradient-to-br from-rose-400 to-red-600',
  'bg-gradient-to-br from-amber-400 to-orange-600',
  'bg-gradient-to-br from-slate-400 to-slate-600',
];

export const ProfileEditor: React.FC<ProfileEditorProps> = ({ user, onSave, onClose }) => {
  const [name, setName] = useState(user.name);
  const [selectedColor, setSelectedColor] = useState(user.color || GRADIENTS[0]);
  const [imageLink, setImageLink] = useState(user.profileImage || '');
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleSave = () => {
    onSave({
      name,
      color: selectedColor,
      profileImage: imageLink,
      avatarInitials: name.split(' ').map(n => n[0]).join('').substring(0, 2).toUpperCase()
    });
    onClose();
  };

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onloadend = () => {
        setImageLink(reader.result as string);
      };
      reader.readAsDataURL(file);
    }
  };

  const triggerFileInput = () => {
    fileInputRef.current?.click();
  };

  const removeImage = () => {
    setImageLink('');
    if (fileInputRef.current) {
        fileInputRef.current.value = '';
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/80 backdrop-blur-sm animate-in fade-in duration-300">
      <div className="w-full max-w-md bg-[#0f172a] sm:rounded-3xl rounded-t-3xl p-6 border border-white/10 shadow-2xl animate-in slide-in-from-bottom-4 duration-500">
        
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-white font-bold text-xl">Edit Profile</h2>
          <button onClick={onClose} className="p-2 bg-white/5 rounded-full hover:bg-white/10 text-slate-400 hover:text-white transition-colors">
            <X size={20} />
          </button>
        </div>

        {/* Avatar Preview & Upload */}
        <div className="flex flex-col items-center mb-8 gap-4">
          <div 
            className="relative group cursor-pointer" 
            onClick={triggerFileInput}
          >
             <div className={`h-28 w-28 rounded-full flex items-center justify-center text-white font-bold text-4xl shadow-2xl overflow-hidden ring-4 ring-[#0f172a] transition-transform group-hover:scale-105 ${selectedColor}`}>
                {imageLink ? (
                    <img src={imageLink} alt="Profile" className="w-full h-full object-cover" />
                ) : (
                    name.split(' ').map(n => n[0]).join('').substring(0, 2).toUpperCase()
                )}
             </div>
             
             <div className="absolute -bottom-2 -right-2 bg-cyan-500 p-2.5 rounded-xl text-white shadow-lg border-2 border-[#0f172a] group-hover:bg-cyan-400 transition-colors">
                <Camera size={18} />
             </div>
          </div>

          <input 
              type="file" 
              ref={fileInputRef} 
              className="hidden" 
              accept="image/*" 
              onChange={handleFileChange} 
          />
          
          <div className="flex gap-3">
            <button 
                onClick={triggerFileInput}
                className="text-xs text-cyan-300 hover:text-white font-bold bg-cyan-500/10 px-4 py-2 rounded-xl border border-cyan-500/20 transition-colors flex items-center gap-2"
            >
                <Upload size={14} />
                Upload Photo
            </button>
            {imageLink && (
                <button 
                    onClick={removeImage}
                    className="text-xs text-red-400 hover:text-red-300 font-bold bg-red-500/10 px-4 py-2 rounded-xl border border-red-500/20 transition-colors flex items-center gap-2"
                >
                    <Trash2 size={14} />
                    Remove
                </button>
            )}
          </div>
        </div>

        <div className="space-y-5">
          {/* Name Input */}
          <div>
            <label className="text-xs text-slate-400 font-bold uppercase tracking-wider mb-2 block">Display Name</label>
            <input 
                type="text" 
                value={name}
                onChange={(e) => setName(e.target.value)}
                className="w-full bg-slate-800/50 border border-white/10 rounded-xl px-4 py-3 text-white font-medium focus:outline-none focus:border-cyan-500/50 transition-colors"
            />
          </div>

          {/* Color Selection */}
          <div>
            <label className="text-xs text-slate-400 font-bold uppercase tracking-wider mb-3 block">Theme Color</label>
            <div className="flex gap-3 justify-center flex-wrap">
                {GRADIENTS.map(gradient => (
                    <button
                        key={gradient}
                        onClick={() => setSelectedColor(gradient)}
                        className={`h-10 w-10 rounded-full ${gradient} shadow-lg ring-offset-2 ring-offset-[#0f172a] transition-all ${selectedColor === gradient ? 'ring-2 ring-white scale-110' : 'hover:scale-105 opacity-70 hover:opacity-100'}`}
                    />
                ))}
            </div>
          </div>

          <button 
            onClick={handleSave}
            className="w-full bg-gradient-to-r from-cyan-500 to-blue-600 text-white font-bold py-4 rounded-2xl shadow-lg shadow-cyan-500/20 hover:shadow-cyan-500/30 active:scale-95 transition-all mt-4 flex items-center justify-center gap-2"
          >
            <Check size={20} strokeWidth={3} />
            Save Changes
          </button>
        </div>

      </div>
    </div>
  );
};
