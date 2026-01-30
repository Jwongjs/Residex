
import React from 'react';

export const AmbientBackground: React.FC = () => {
  return (
    <div className="fixed inset-0 z-0 overflow-hidden bg-[#000212] pointer-events-none">
      <div className="absolute inset-0 bg-[#020617]" />
      {/* Top Left Blue Glow */}
      <div className="absolute top-[-10%] left-[-10%] w-[100vw] h-[100vw] rounded-full bg-blue-600/10 blur-[120px] mix-blend-screen animate-pulse-slow" />
      {/* Center Purple Glow */}
      <div className="absolute top-[20%] right-[-20%] w-[100vw] h-[100vw] rounded-full bg-purple-600/10 blur-[130px] mix-blend-screen animate-pulse-slow" style={{ animationDelay: '2s' }} />
      {/* Bottom Subtle Cyan */}
      <div className="absolute bottom-[-20%] left-[10%] w-[80vw] h-[80vw] rounded-full bg-cyan-600/5 blur-[150px] mix-blend-screen" />
      
      <style>{`
        @keyframes pulse-slow {
          0%, 100% { opacity: 0.3; transform: scale(1); }
          50% { opacity: 0.6; transform: scale(1.1); }
        }
        .animate-pulse-slow {
          animation: pulse-slow 8s infinite ease-in-out;
        }
      `}</style>
    </div>
  );
};
