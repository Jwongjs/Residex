import React, { useState } from 'react';
import { Mail, Phone, User as UserIcon, ArrowRight, Lock, Play } from 'lucide-react';
import { Logo } from './Logo';

interface RegisterProps {
  onRegister: (userData: { name: string; email: string; phone: string }) => void;
  onSwitchToLogin: () => void;
}

export const Register: React.FC<RegisterProps> = ({ onRegister, onSwitchToLogin }) => {
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    phone: '',
    password: ''
  });
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.name || !formData.email || !formData.phone || !formData.password) return;
    
    setIsLoading(true);
    // Simulate API call for registration
    setTimeout(() => {
        onRegister({
            name: formData.name,
            email: formData.email,
            phone: formData.phone
        });
    }, 1500);
  };

  const handleSimulate = () => {
    onRegister({
        name: 'New User',
        email: 'new@example.com',
        phone: '987654321'
    });
  };

  return (
    <div className="h-full w-full relative z-10 flex flex-col justify-center">
        {/* Main Content Container - Centered, no scroll */}
        <div className="w-full max-w-sm mx-auto px-6 py-2">
            
            {/* Logo / Brand Area - Very Compact */}
            <div className="mb-2 text-center">
                <div className="inline-block mb-2 relative group cursor-pointer">
                    <div className="absolute inset-0 bg-blue-500/20 blur-xl rounded-[1.5rem] group-hover:bg-blue-500/30 transition-all duration-500 opacity-60"></div>
                    <Logo size={50} className="relative z-10 drop-shadow-xl transition-transform duration-500 group-hover:scale-105" />
                </div>
                <h1 className="text-2xl font-black text-white tracking-tight mb-0.5">Create Account</h1>
                <p className="text-slate-400 text-xs font-medium">Join SplitLah.</p>
            </div>

            {/* Main Card */}
            <div className="bg-slate-800/40 backdrop-blur-xl border border-white/10 rounded-[2rem] p-5 shadow-2xl shadow-black/50 relative overflow-hidden group">
                {/* Ambient Glow inside card */}
                <div className="absolute -bottom-24 -left-24 w-48 h-48 bg-blue-600/20 rounded-full blur-[60px] pointer-events-none"></div>
                
                <div className="relative z-10">
                    <form onSubmit={handleSubmit} className="space-y-2.5">
                        
                        {/* Name Input */}
                        <div className="space-y-0.5">
                            <label className="text-[10px] text-slate-400 font-bold uppercase tracking-wider ml-1">Full Name</label>
                            <div className="relative group/input">
                                <div className="absolute left-3 top-2.5 text-slate-500 group-focus-within/input:text-cyan-400 transition-colors">
                                    <UserIcon size={16} />
                                </div>
                                <input 
                                    type="text"
                                    required
                                    placeholder="e.g. Ali Rahman"
                                    value={formData.name}
                                    onChange={(e) => setFormData({...formData, name: e.target.value})}
                                    className="w-full bg-black/20 border border-white/10 rounded-xl py-2 pl-9 pr-3 text-white placeholder-slate-600 focus:outline-none focus:border-cyan-500/50 focus:bg-black/40 transition-all font-medium text-sm"
                                />
                            </div>
                        </div>

                        {/* Email Input */}
                        <div className="space-y-0.5">
                            <label className="text-[10px] text-slate-400 font-bold uppercase tracking-wider ml-1">Email Address</label>
                            <div className="relative group/input">
                                <div className="absolute left-3 top-2.5 text-slate-500 group-focus-within/input:text-cyan-400 transition-colors">
                                    <Mail size={16} />
                                </div>
                                <input 
                                    type="email"
                                    required
                                    placeholder="ali@example.com"
                                    value={formData.email}
                                    onChange={(e) => setFormData({...formData, email: e.target.value})}
                                    className="w-full bg-black/20 border border-white/10 rounded-xl py-2 pl-9 pr-3 text-white placeholder-slate-600 focus:outline-none focus:border-cyan-500/50 focus:bg-black/40 transition-all font-medium text-sm"
                                />
                            </div>
                        </div>

                        {/* Phone Input */}
                        <div className="space-y-0.5">
                            <label className="text-[10px] text-slate-400 font-bold uppercase tracking-wider ml-1">Phone Number</label>
                            <div className="relative group/input flex gap-2">
                                <div className="bg-black/20 border border-white/10 rounded-xl px-2 py-2 flex items-center gap-1 text-slate-300 font-bold font-mono text-sm">
                                    <span>+60</span>
                                </div>
                                <div className="relative flex-1">
                                    <div className="absolute left-3 top-2.5 text-slate-500 group-focus-within/input:text-cyan-400 transition-colors">
                                        <Phone size={16} />
                                    </div>
                                    <input 
                                        type="tel"
                                        required
                                        placeholder="12 345 6789"
                                        value={formData.phone}
                                        onChange={(e) => setFormData({...formData, phone: e.target.value})}
                                        className="w-full bg-black/20 border border-white/10 rounded-xl py-2 pl-9 pr-3 text-white placeholder-slate-600 focus:outline-none focus:border-cyan-500/50 focus:bg-black/40 transition-all font-medium tracking-wide text-sm"
                                    />
                                </div>
                            </div>
                        </div>

                        {/* Password Input */}
                        <div className="space-y-0.5">
                            <label className="text-[10px] text-slate-400 font-bold uppercase tracking-wider ml-1">Password</label>
                            <div className="relative group/input">
                                <div className="absolute left-3 top-2.5 text-slate-500 group-focus-within/input:text-cyan-400 transition-colors">
                                    <Lock size={16} />
                                </div>
                                <input 
                                    type="password"
                                    required
                                    placeholder="••••••••"
                                    value={formData.password}
                                    onChange={(e) => setFormData({...formData, password: e.target.value})}
                                    className="w-full bg-black/20 border border-white/10 rounded-xl py-2 pl-9 pr-3 text-white placeholder-slate-600 focus:outline-none focus:border-cyan-500/50 focus:bg-black/40 transition-all font-medium text-sm"
                                />
                            </div>
                        </div>

                        <div className="pt-3 space-y-2">
                            <button 
                                type="submit"
                                disabled={isLoading}
                                className="w-full bg-gradient-to-r from-blue-600 to-cyan-500 text-white h-11 rounded-xl font-bold text-sm shadow-lg shadow-cyan-500/20 hover:shadow-cyan-500/40 hover:scale-[1.02] active:scale-95 transition-all flex items-center justify-center gap-2 disabled:opacity-70 disabled:cursor-not-allowed"
                            >
                                {isLoading ? (
                                    <div className="h-4 w-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                                ) : (
                                    <>
                                        Sign Up
                                        <ArrowRight size={16} />
                                    </>
                                )}
                            </button>

                            {/* Simulation Button */}
                            <button 
                                type="button"
                                onClick={handleSimulate}
                                className="w-full bg-slate-800/50 text-cyan-400 h-8 rounded-lg font-bold text-[10px] border border-cyan-500/20 hover:bg-cyan-500/10 transition-all flex items-center justify-center gap-2"
                            >
                                <Play size={12} />
                                Simulate Register
                            </button>
                        </div>

                    </form>

                    {/* Third Party & Login Link - Compact Footer */}
                    <div className="mt-3 pt-3 border-t border-white/5">
                        <div className="flex items-center gap-3 mb-3">
                            <div className="h-px bg-white/10 flex-1"></div>
                            <span className="text-slate-500 text-[10px] font-bold uppercase tracking-wider">Or register with</span>
                            <div className="h-px bg-white/10 flex-1"></div>
                        </div>

                        <div className="flex justify-center gap-3 mb-3">
                            <SocialButton icon={<img src="https://www.svgrepo.com/show/475656/google-color.svg" alt="Google" className="w-4 h-4" />} />
                            <SocialButton icon={
                                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="text-blue-500">
                                    <path d="M18 2h-3a5 5 0 0 0-5 5v3H7v4h3v8h4v-8h3l1-4h-4V7a1 1 0 0 1 1-1h3z"></path>
                                </svg>
                            } />
                        </div>

                        {/* Login Link */}
                        <div className="text-center">
                            <p className="text-slate-400 text-xs">
                                Already have an account?{' '}
                                <button 
                                    onClick={onSwitchToLogin}
                                    className="text-cyan-400 font-bold hover:text-cyan-300 transition-colors inline-block px-2 py-1 -my-1 rounded-lg hover:bg-cyan-500/10"
                                >
                                    Log In
                                </button>
                            </p>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
  );
};

const SocialButton = ({ icon }: { icon: React.ReactNode }) => (
    <button className="h-10 w-16 rounded-xl bg-black/20 border border-white/10 flex items-center justify-center hover:bg-white/10 hover:border-white/20 transition-all hover:-translate-y-1 active:scale-95 group">
        <div className="group-hover:scale-110 transition-transform duration-300">
            {icon}
        </div>
    </button>
);