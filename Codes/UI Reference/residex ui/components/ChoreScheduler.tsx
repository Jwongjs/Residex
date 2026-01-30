
import React, { useState, useMemo } from 'react';
import { 
  Calendar as CalendarIcon, CheckCircle2, Circle, Clock, Plus, 
  X, ChevronLeft, ChevronRight, ArrowLeft, 
  ChevronDown, Maximize2
} from 'lucide-react';
import { User } from '../types';

interface Chore {
  id: string;
  name: string;
  assignedTo: string;
  time: string;
  status: 'PENDING' | 'COMPLETED';
  dateKey: string; 
}

interface ChoreSchedulerProps {
  tenants: User[];
  onBack?: () => void;
  onExpand?: () => void;
  isFullPage?: boolean;
}

const CHORE_TEMPLATES = [
  { name: 'General Cleaning', icon: '🧹' },
  { name: 'Kitchen Duty', icon: '🍳' },
  { name: 'Trash Disposal', icon: '🗑️' },
  { name: 'Utility Payment', icon: '⚡' },
  { name: 'Grocery Run', icon: '🛒' },
  { name: 'Guest Protocol', icon: '🤝' },
];

export const ChoreScheduler: React.FC<ChoreSchedulerProps> = ({ tenants, onBack, onExpand, isFullPage = false }) => {
  const [currentDate, setCurrentDate] = useState(new Date());
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [showAddModal, setShowAddModal] = useState(false);
  const [newChore, setNewChore] = useState({ name: '', assignee: '', time: '09:00' });

  const [allChores, setAllChores] = useState<Chore[]>([
    { id: '1', name: 'Kitchen Cleaning', assignedTo: 'u1', time: '09:00 AM', status: 'COMPLETED', dateKey: new Date().toISOString().split('T')[0] },
    { id: '2', name: 'Trash Disposal', assignedTo: 'u3', time: '08:00 PM', status: 'PENDING', dateKey: new Date().toISOString().split('T')[0] },
  ]);

  const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
  
  const calendarData = useMemo(() => {
    const year = currentDate.getFullYear();
    const month = currentDate.getMonth();
    const firstDayOfMonth = new Date(year, month, 1).getDay();
    const daysInMonth = new Date(year, month + 1, 0).getDate();
    const days = [];
    for (let i = 0; i < firstDayOfMonth; i++) days.push(null);
    for (let i = 1; i <= daysInMonth; i++) days.push(new Date(year, month, i));
    return days;
  }, [currentDate]);

  const weeklyDays = useMemo(() => {
    const start = new Date();
    start.setDate(start.getDate() - 2);
    return Array.from({ length: 14 }).map((_, i) => {
        const d = new Date(start);
        d.setDate(start.getDate() + i);
        return d;
    });
  }, []);

  const dateToKey = (date: Date) => date.toISOString().split('T')[0];
  const selectedDateKey = dateToKey(selectedDate);
  const filteredChores = allChores.filter(c => c.dateKey === selectedDateKey);

  const handleCreateChore = () => {
    if (!newChore.name || !newChore.assignee) return;
    const created: Chore = {
      id: Math.random().toString(),
      name: newChore.name,
      assignedTo: newChore.assignee,
      time: newChore.time,
      status: 'PENDING',
      dateKey: selectedDateKey
    };
    setAllChores([...allChores, created]);
    setShowAddModal(false);
  };

  const containerStyle = "bg-slate-900/80 backdrop-blur-xl border-white/10 shadow-2xl";

  return (
    <div className={`flex flex-col animate-in fade-in duration-500 relative overflow-hidden ${isFullPage ? 'bg-[#020205] h-full' : ''}`}>
      {isFullPage && (
        <>
            <div className="absolute top-0 left-0 right-0 h-[500px] bg-[radial-gradient(circle_at_top,_var(--tw-gradient-stops))] from-purple-800/50 via-black to-black pointer-events-none"></div>
            <div className="p-6 flex items-center justify-between border-b border-white/10 bg-black/20 backdrop-blur-md sticky top-0 z-50">
            <div className="flex items-center gap-4">
                <button onClick={onBack} className="p-2 rounded-full transition-all active:scale-90 bg-white/5 text-slate-400">
                <ArrowLeft size={20}/>
                </button>
                <div>
                <h1 className="text-white font-black text-xl uppercase tracking-tight">Shared Calendar</h1>
                <p className="text-purple-400 text-[10px] font-bold uppercase tracking-widest">Schedule of Operations</p>
                </div>
            </div>
            <button 
                onClick={() => setShowAddModal(true)}
                className="h-10 w-10 rounded-xl flex items-center justify-center shadow-lg shadow-purple-500/20 transition-all active:scale-95 bg-purple-600 text-white hover:bg-purple-500"
            >
                <Plus size={20} />
            </button>
            </div>
        </>
      )}

      <div className={`${isFullPage ? 'flex-1 overflow-y-auto no-scrollbar p-4 sm:p-6 pb-24 relative z-10' : 'mb-8'}`}>
        {!isFullPage && (
          <div className="flex justify-between items-center mb-4 px-2">
            <h2 className="text-white font-black text-lg uppercase tracking-wider flex items-center gap-2">
              <CalendarIcon size={18} className="text-purple-400" />
              Shared Calendar
            </h2>
            <div className="flex items-center gap-3">
                <button onClick={onExpand} className="p-1.5 rounded-lg bg-white/5 text-slate-500 hover:text-white transition-all active:scale-90">
                    <Maximize2 size={16} />
                </button>
                <button onClick={() => setShowAddModal(true)} className="text-[10px] font-black tracking-widest uppercase flex items-center gap-1 text-purple-400 hover:text-purple-300">
                    <Plus size={14} /> Add
                </button>
            </div>
          </div>
        )}

        <div className={`rounded-[2.5rem] border overflow-hidden relative ${isFullPage ? 'p-6' : 'p-4'} ${containerStyle}`}>
          {isFullPage ? (
            <>
              <div className="flex items-center justify-between mb-8">
                <div className="flex items-center gap-2">
                  <h2 className="text-white font-black text-lg uppercase">
                    {monthNames[currentDate.getMonth()]} <span className="text-purple-400">{currentDate.getFullYear()}</span>
                  </h2>
                </div>
                <div className="flex gap-2">
                  <button onClick={() => setCurrentDate(new Date(currentDate.getFullYear(), currentDate.getMonth() - 1, 1))} className="p-2.5 rounded-xl bg-white/5 text-slate-400 border border-white/5 hover:bg-white/10"><ChevronLeft size={18} /></button>
                  <button onClick={() => setCurrentDate(new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 1))} className="p-2.5 rounded-xl bg-white/5 text-slate-400 border border-white/5 hover:bg-white/10"><ChevronRight size={18} /></button>
                </div>
              </div>
              <div className="grid grid-cols-7 mb-4 text-center text-[10px] font-black text-slate-500 uppercase tracking-wider">
                {['S', 'M', 'T', 'W', 'T', 'F', 'S'].map(day => <div key={day} className="py-2">{day}</div>)}
              </div>
              <div className="grid grid-cols-7 gap-2">
                {calendarData.map((date, i) => {
                  if (!date) return <div key={i} className="aspect-square" />;
                  const isSelected = dateToKey(date) === selectedDateKey;
                  const hasChores = allChores.some(c => c.dateKey === dateToKey(date));
                  return (
                    <button
                      key={i}
                      onClick={() => setSelectedDate(date)}
                      className={`aspect-square rounded-2xl flex flex-col items-center justify-center relative transition-all duration-300 border
                        ${isSelected ? 'bg-purple-600 border-purple-400 text-white scale-110 shadow-lg shadow-purple-900/30' : 'bg-white/5 border-transparent text-slate-400 hover:bg-white/10'}`}
                    >
                      <span className="text-sm font-black">{date.getDate()}</span>
                      {hasChores && !isSelected && <div className="absolute bottom-2 w-1.5 h-1.5 rounded-full bg-purple-400 animate-pulse" />}
                    </button>
                  );
                })}
              </div>
            </>
          ) : (
            <div className="flex gap-3 overflow-x-auto no-scrollbar pb-1 px-1">
              {weeklyDays.map((date, i) => {
                const isSelected = dateToKey(date) === selectedDateKey;
                return (
                  <button
                    key={i}
                    onClick={() => setSelectedDate(date)}
                    className={`flex-shrink-0 w-12 h-16 rounded-2xl flex flex-col items-center justify-center transition-all duration-300 border relative ${
                      isSelected ? 'bg-purple-600 border-purple-400 text-white scale-110 shadow-lg shadow-purple-900/30' : 'bg-white/5 border-transparent text-slate-500 hover:bg-white/10'
                    }`}
                  >
                    <span className="text-[8px] font-bold uppercase mb-1">{date.toLocaleDateString(undefined, { weekday: 'short' }).toUpperCase()}</span>
                    <span className="text-sm font-black">{date.getDate()}</span>
                  </button>
                );
              })}
            </div>
          )}
        </div>

        <div className="flex justify-between items-center px-2 mb-4 mt-6">
            <h3 className="text-slate-500 text-[10px] font-black uppercase tracking-[0.2em]">
              Tasks for {selectedDate.toLocaleDateString(undefined, { day: 'numeric', month: 'short' })}
            </h3>
        </div>

        <div className="space-y-3 min-h-[100px]">
          {filteredChores.length === 0 ? (
            <div className="py-8 text-center bg-white/5 border border-dashed border-white/10 rounded-[1.5rem] opacity-30">
              <p className="text-[10px] font-black uppercase text-slate-400 tracking-widest">No Tasks Scheduled</p>
            </div>
          ) : (
            filteredChores.map((chore) => {
              const assignee = tenants.find(t => t.id === chore.assignedTo) || { name: 'You', avatarInitials: 'YO', color: 'bg-slate-700' };
              return (
                <div key={chore.id} className="bg-slate-800/40 backdrop-blur-md border border-white/5 rounded-[1.5rem] p-4 flex items-center justify-between group hover:border-purple-500/30 hover:bg-slate-800/60 transition-all shadow-sm">
                  <div className="flex items-center gap-4">
                    <div className={`h-10 w-10 rounded-xl flex items-center justify-center ${chore.status === 'COMPLETED' ? 'bg-emerald-500/20 text-emerald-400' : 'bg-slate-700/50 text-slate-500'}`}>
                      {chore.status === 'COMPLETED' ? <CheckCircle2 size={20} /> : <Circle size={20} />}
                    </div>
                    <div>
                      <h4 className={`text-sm font-bold tracking-tight ${chore.status === 'COMPLETED' ? 'text-slate-500 line-through' : 'text-white'}`}>{chore.name}</h4>
                      <div className="flex items-center gap-2 mt-1">
                        <Clock size={10} className="text-purple-400" />
                        <span className="text-[10px] font-mono text-slate-400">{chore.time}</span>
                      </div>
                    </div>
                  </div>
                  <div className={`h-10 w-10 rounded-2xl border-2 border-slate-900 shadow-lg flex items-center justify-center text-xs font-black text-white ${assignee.color || 'bg-slate-700'}`}>
                    {assignee.avatarInitials}
                  </div>
                </div>
              );
            })
          )}
        </div>
      </div>

      {showAddModal && (
        <div className="fixed inset-0 z-[200] flex items-end sm:items-center justify-center bg-black/95 backdrop-blur-md p-4 animate-in fade-in">
          <div className="w-full max-w-md bg-[#0f172a] border border-purple-500/20 rounded-[2.5rem] shadow-2xl overflow-hidden animate-in slide-in-from-bottom-8 max-h-[90vh] flex flex-col">
            <div className="p-8 overflow-y-auto no-scrollbar">
              <div className="flex justify-between items-center mb-8">
                <h3 className="text-white font-black text-2xl uppercase tracking-tighter">Schedule Task</h3>
                <button onClick={() => setShowAddModal(false)} className="h-10 w-10 bg-white/5 rounded-full flex items-center justify-center text-slate-400 hover:text-white"><X size={20} /></button>
              </div>
              <div className="grid grid-cols-2 gap-3 mb-6">
                {CHORE_TEMPLATES.map((t) => (
                    <button key={t.name} onClick={() => setNewChore({ ...newChore, name: t.name })} className={`p-4 rounded-2xl border text-left flex items-center gap-3 transition-all ${newChore.name === t.name ? 'bg-purple-500/20 border-purple-500 text-white' : 'bg-white/5 border-white/5 text-slate-500 hover:bg-white/10'}`}>
                      <span className="text-xl">{t.icon}</span>
                      <span className="text-[11px] font-black uppercase truncate">{t.name}</span>
                    </button>
                ))}
              </div>
              <div className="space-y-6">
                <input type="text" value={newChore.name} onChange={(e) => setNewChore({...newChore, name: e.target.value})} placeholder="Task Name" className="w-full bg-black/40 border border-white/10 rounded-2xl py-4 px-6 text-white font-black placeholder-slate-700 focus:outline-none focus:border-purple-500/50 transition-colors" />
                <div className="grid grid-cols-2 gap-4">
                  <select value={newChore.assignee} onChange={(e) => setNewChore({...newChore, assignee: e.target.value})} className="w-full bg-black/40 border border-white/10 rounded-2xl py-4 px-6 text-white font-black focus:outline-none appearance-none uppercase focus:border-purple-500/50"><option value="">Assign To</option><option value="u1">YOU</option>{tenants.map(t => (<option key={t.id} value={t.id}>{t.name.toUpperCase()}</option>))}</select>
                  <input type="time" value={newChore.time} onChange={(e) => setNewChore({...newChore, time: e.target.value})} className="w-full bg-black/40 border border-white/10 rounded-2xl py-4 px-6 text-white font-black focus:outline-none focus:border-purple-500/50" />
                </div>
                <button onClick={handleCreateChore} disabled={!newChore.name || !newChore.assignee} className="w-full py-5 rounded-[1.8rem] font-black text-xs uppercase tracking-[0.2em] shadow-2xl transition-all active:scale-95 disabled:opacity-50 bg-gradient-to-r from-blue-600 to-purple-600 text-white shadow-purple-500/30">Create Task</button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
