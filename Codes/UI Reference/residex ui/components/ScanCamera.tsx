
import React, { useRef, useEffect, useState } from 'react';
import { ArrowLeft, Camera, X, Zap, Image as ImageIcon, Play } from 'lucide-react';

interface ScanCameraProps {
  onCapture: (imageBlob: string) => void;
  onBack: () => void;
}

export const ScanCamera: React.FC<ScanCameraProps> = ({ onCapture, onBack }) => {
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [stream, setStream] = useState<MediaStream | null>(null);
  const [error, setError] = useState<string>('');

  useEffect(() => {
    const startCamera = async () => {
      try {
        const mediaStream = await navigator.mediaDevices.getUserMedia({ 
          video: { facingMode: 'environment' },
          audio: false 
        });
        setStream(mediaStream);
        if (videoRef.current) {
          videoRef.current.srcObject = mediaStream;
        }
      } catch (err) {
        console.error("Error accessing camera:", err);
        setError("Could not access camera. Use the simulation button to test.");
      }
    };

    startCamera();

    return () => {
      if (stream) {
        stream.getTracks().forEach(track => track.stop());
      }
    };
  }, []);

  const handleCapture = () => {
    if (videoRef.current && canvasRef.current) {
      const context = canvasRef.current.getContext('2d');
      if (context) {
        const { videoWidth, videoHeight } = videoRef.current;
        canvasRef.current.width = videoWidth;
        canvasRef.current.height = videoHeight;
        context.drawImage(videoRef.current, 0, 0, videoWidth, videoHeight);
        
        const imageData = canvasRef.current.toDataURL('image/jpeg');
        onCapture(imageData);
      }
    }
  };

  const handleSimulate = () => {
    // Pass dummy data to simulate a scan
    onCapture("data:image/jpeg;base64,simulation");
  };

  return (
    <div className="fixed inset-0 bg-black z-50 flex flex-col">
      {/* Header Overlay */}
      <div className="absolute top-0 left-0 right-0 p-6 z-20 flex justify-between items-center bg-gradient-to-b from-black/70 to-transparent">
        <button 
          onClick={onBack}
          className="h-10 w-10 rounded-full bg-black/20 backdrop-blur-md border border-white/20 flex items-center justify-center text-white hover:bg-white/20 transition-all"
        >
          <X size={20} />
        </button>
        <div className="flex gap-4">
           <button className="h-10 w-10 rounded-full bg-black/20 backdrop-blur-md border border-white/20 flex items-center justify-center text-white hover:bg-white/20 transition-all">
              <Zap size={20} className="text-yellow-400" />
           </button>
        </div>
      </div>

      {/* Camera View */}
      <div className="relative flex-1 bg-slate-900 flex items-center justify-center overflow-hidden">
        {error ? (
          <div className="text-white text-center px-6 max-w-xs">
            <p className="text-red-400 mb-2 font-bold">Camera Error</p>
            <p className="text-sm text-slate-400 mb-4">{error}</p>
            <button 
                onClick={handleSimulate}
                className="bg-cyan-600 text-white px-4 py-2 rounded-lg text-sm font-bold hover:bg-cyan-500 transition-colors"
            >
                Continue with Simulation
            </button>
          </div>
        ) : (
          <video 
            ref={videoRef}
            autoPlay 
            playsInline 
            className="absolute inset-0 w-full h-full object-cover"
          />
        )}
        
        {/* Scanning Overlay Frame - Only show if no error */}
        {!error && (
            <div className="absolute inset-0 pointer-events-none flex flex-col items-center justify-center">
                <div className="w-[70%] h-[60%] border-2 border-white/30 rounded-3xl relative shadow-[0_0_0_9999px_rgba(0,0,0,0.5)]">
                    <div className="absolute top-0 left-0 w-10 h-10 border-t-4 border-l-4 border-cyan-400 rounded-tl-3xl -mt-[2px] -ml-[2px]"></div>
                    <div className="absolute top-0 right-0 w-10 h-10 border-t-4 border-r-4 border-cyan-400 rounded-tr-3xl -mt-[2px] -mr-[2px]"></div>
                    <div className="absolute bottom-0 left-0 w-10 h-10 border-b-4 border-l-4 border-cyan-400 rounded-bl-3xl -mb-[2px] -ml-[2px]"></div>
                    <div className="absolute bottom-0 right-0 w-10 h-10 border-b-4 border-r-4 border-cyan-400 rounded-br-3xl -mb-[2px] -mr-[2px]"></div>
                    
                    {/* Scanning Line Animation */}
                    <div className="absolute left-0 right-0 h-0.5 bg-cyan-400 shadow-[0_0_15px_rgba(34,211,238,0.8)] top-0 animate-[scan_3s_ease-in-out_infinite]"></div>
                </div>
                <p className="text-white/80 text-sm font-medium mt-8 bg-black/40 px-4 py-2 rounded-full backdrop-blur-sm">
                    Position receipt within frame
                </p>
            </div>
        )}
      </div>

      {/* Bottom Controls */}
      <div className="h-32 bg-black flex items-center justify-around px-8 pb-6">
         <button className="h-12 w-12 rounded-2xl bg-slate-800 border border-white/10 flex items-center justify-center text-slate-400 hover:text-white transition-colors">
            <ImageIcon size={20} />
         </button>

         <button 
           onClick={handleCapture}
           className="h-20 w-20 rounded-full bg-white border-4 border-slate-300 flex items-center justify-center shadow-[0_0_30px_rgba(255,255,255,0.3)] active:scale-95 transition-transform"
         >
            <div className="h-16 w-16 rounded-full border-2 border-slate-900"></div>
         </button>

         {/* Simulation / Test Button */}
         <button 
            onClick={handleSimulate}
            className="h-12 w-12 rounded-2xl bg-slate-800 border border-cyan-500/30 flex items-center justify-center text-cyan-400 hover:text-cyan-300 hover:bg-cyan-950/30 transition-colors"
            title="Simulate Scan (Dev)"
         >
            <Play size={20} fill="currentColor" />
         </button>
      </div>

      {/* Hidden Canvas for processing */}
      <canvas ref={canvasRef} className="hidden" />
      
      <style>{`
        @keyframes scan {
          0%, 100% { top: 0%; opacity: 0; }
          10% { opacity: 1; }
          90% { opacity: 1; }
          100% { top: 100%; opacity: 0; }
        }
      `}</style>
    </div>
  );
};
