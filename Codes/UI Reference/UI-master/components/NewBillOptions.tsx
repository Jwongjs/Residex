import React, { useEffect, useState, useRef } from 'react';
import { ArrowLeft, ScanLine, Keyboard, Sparkles, ChevronRight, Zap, Upload, FileText } from 'lucide-react';

interface NewBillOptionsProps {
  onBack: () => void;
  onScan: () => void;
  onManual: () => void;
  onUpload: (fileData: string) => void;
}

export const NewBillOptions: React.FC<NewBillOptionsProps> = ({ onBack, onScan, onManual, onUpload }) => {
  const [isVisible, setIsVisible] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    setIsVisible(true);
  }, []);

  const handleUploadClick = () => {
    fileInputRef.current?.click();
  };

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onloadend = () => {
        if (reader.result) {
            onUpload(reader.result as string);
        }
      };
      reader.readAsDataURL(file);
    }
  };

  return (
    <div className={`flex flex-col h-full transition-all duration-500 ease-out ${isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4'}`}>
      {/* Header */}
      <div className="flex items-center gap-4 pt-6 pb-6">
        <button 
          onClick={onBack}
          className="h-10 w-10 rounded-full bg-slate-800/50 border border-white/10 flex items-center justify-center text-slate-300 hover:bg-white/10 hover:text-white transition-all backdrop-blur-md group"
        >
          <ArrowLeft size={20} className="group-hover:-translate-x-0.5 transition-transform" />
        </button>
        <h1 className="text-white font-bold text-xl tracking-tight">Create New Bill</h1>
      </div>

      <div className="flex flex-col gap-4 overflow-y-auto no-scrollbar pb-20">
        <p className="text-slate-400 text-sm font-medium px-1">Choose how you'd like to add items:</p>

        {/* Option 1: AI Scan (Hero Option) */}
        <button 
          onClick={onScan}
          className="group relative w-full text-left overflow-hidden rounded-[2rem] bg-gradient-to-br from-slate-800/80 to-slate-900/80 border border-white/10 hover:border-cyan-500/50 transition-all duration-500 hover:-translate-y-1 shadow-lg shadow-black/30"
        >
          {/* Background Glow Effects */}
          <div className="absolute top-0 right-0 w-32 h-32 bg-cyan-500/20 rounded-full blur-[60px] group-hover:bg-cyan-400/30 transition-colors duration-500"></div>
          <div className="absolute bottom-0 left-0 w-32 h-32 bg-blue-600/10 rounded-full blur-[60px]"></div>
          
          <div className="relative p-6 z-10">
            <div className="flex justify-between items-start mb-4">
              <div className="h-14 w-14 rounded-2xl bg-gradient-to-br from-cyan-400 to-blue-600 flex items-center justify-center text-white shadow-lg shadow-cyan-900/20 ring-1 ring-white/20 group-hover:scale-110 transition-transform duration-500">
                <ScanLine size={28} strokeWidth={2} />
              </div>
              <div className="bg-white/10 backdrop-blur-md border border-white/10 px-3 py-1 rounded-full flex items-center gap-1.5">
                <Sparkles size={12} className="text-cyan-300 animate-pulse" />
                <span className="text-[10px] font-bold text-cyan-100 uppercase tracking-wider">AI Powered</span>
              </div>
            </div>

            <div className="space-y-1 mb-4">
              <h3 className="text-white font-bold text-lg group-hover:text-cyan-200 transition-colors">Scan Receipt</h3>
              <p className="text-slate-400 text-sm leading-relaxed">
                Instantly extract items from a physical receipt using your camera.
              </p>
            </div>

            <div className="flex items-center gap-2 text-cyan-400 text-sm font-bold mt-2 group-hover:translate-x-2 transition-transform duration-300">
              <span>Start Camera</span>
              <ChevronRight size={16} />
            </div>
          </div>
        </button>

        {/* Option 2: Upload (Digital/PDF) */}
        <button 
          onClick={handleUploadClick}
          className="group relative w-full text-left overflow-hidden rounded-[2rem] bg-gradient-to-br from-slate-800/80 to-slate-900/80 border border-white/10 hover:border-purple-500/50 transition-all duration-500 hover:-translate-y-1 shadow-lg shadow-black/30"
        >
           {/* Background Glow Effects */}
           <div className="absolute top-0 left-0 w-40 h-40 bg-purple-600/10 rounded-full blur-[60px] group-hover:bg-purple-500/20 transition-colors duration-500"></div>

           <div className="relative p-6 z-10">
            <div className="flex justify-between items-start mb-4">
              <div className="h-14 w-14 rounded-2xl bg-gradient-to-br from-purple-500 to-indigo-600 flex items-center justify-center text-white shadow-lg shadow-purple-900/20 ring-1 ring-white/20 group-hover:scale-110 transition-transform duration-500">
                <Upload size={28} strokeWidth={2} />
              </div>
            </div>

            <div className="space-y-1 mb-4">
              <h3 className="text-white font-bold text-lg group-hover:text-purple-200 transition-colors">Upload Digital Receipt</h3>
              <p className="text-slate-400 text-sm leading-relaxed">
                Import screenshots or PDF receipts from your gallery or files.
              </p>
            </div>

            <div className="flex items-center gap-2 text-purple-400 text-sm font-bold mt-2 group-hover:translate-x-2 transition-transform duration-300">
              <span>Select File</span>
              <ChevronRight size={16} />
            </div>
          </div>
        </button>

        {/* Option 3: Manual Input */}
        <button 
          onClick={onManual}
          className="group relative w-full text-left overflow-hidden rounded-[2rem] bg-gradient-to-br from-slate-800/80 to-slate-900/80 border border-white/10 hover:border-white/30 transition-all duration-500 hover:-translate-y-1 shadow-lg shadow-black/30"
        >
           {/* Background Glow Effects */}
           <div className="absolute bottom-0 right-0 w-32 h-32 bg-slate-600/20 rounded-full blur-[60px] group-hover:bg-slate-500/30 transition-colors duration-500"></div>

           <div className="relative p-6 z-10">
            <div className="flex justify-between items-start mb-4">
              <div className="h-14 w-14 rounded-2xl bg-gradient-to-br from-slate-600 to-slate-700 flex items-center justify-center text-white shadow-lg shadow-black/20 ring-1 ring-white/10 group-hover:scale-110 transition-transform duration-500">
                <Keyboard size={28} strokeWidth={2} />
              </div>
            </div>

            <div className="space-y-1 mb-4">
              <h3 className="text-white font-bold text-lg group-hover:text-slate-200 transition-colors">Manual Entry</h3>
              <p className="text-slate-400 text-sm leading-relaxed">
                Type in the items and prices manually one by one.
              </p>
            </div>

            <div className="flex items-center gap-2 text-slate-300 text-sm font-bold mt-2 group-hover:translate-x-2 transition-transform duration-300">
              <span>Enter Details</span>
              <ChevronRight size={16} />
            </div>
          </div>
        </button>
        
        {/* Quick Tip Footer */}
        <div className="mt-2 p-4 rounded-2xl bg-cyan-900/10 border border-cyan-500/10 flex gap-3 items-start">
            <Zap size={16} className="text-cyan-400 mt-0.5 flex-shrink-0" />
            <p className="text-xs text-slate-400">
                <span className="text-cyan-200 font-bold">Pro Tip:</span> Scanning works best in good lighting. For e-receipts, use the Upload option for better accuracy.
            </p>
        </div>

        {/* Hidden File Input */}
        <input 
            type="file" 
            ref={fileInputRef}
            className="hidden"
            accept="image/*,.pdf"
            onChange={handleFileChange}
        />

      </div>
    </div>
  );
};