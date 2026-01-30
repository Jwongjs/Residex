import React from 'react';
import { FilterType } from '../types';
import { Home, Users, Clock, CheckCircle, UserPlus } from 'lucide-react';

interface FilterSectionProps {
  activeFilter: FilterType;
  onFilterChange: (filter: FilterType) => void;
}

export const FilterSection: React.FC<FilterSectionProps> = ({ activeFilter, onFilterChange }) => {
  const filters = [
    { type: FilterType.ALL, icon: <Home size={16} />, label: 'All' },
    { type: FilterType.FRIENDS, icon: <UserPlus size={16} />, label: 'Friends' },
    { type: FilterType.GROUPS, icon: <Users size={16} />, label: 'Groups' },
    { type: FilterType.PENDING, icon: <Clock size={16} />, label: 'Pending' },
    { type: FilterType.SETTLED, icon: <CheckCircle size={16} />, label: 'Settled' }
  ];

  return (
    <div className="flex gap-3 overflow-x-auto no-scrollbar pb-4 mb-2 px-1">
      {filters.map((filter) => {
        const isActive = activeFilter === filter.type;
        return (
          <button
            key={filter.type}
            onClick={() => onFilterChange(filter.type)}
            className={`
              flex items-center gap-2 px-5 py-3 rounded-full whitespace-nowrap text-sm font-bold border transform will-change-transform
              transition-all duration-300 ease-ios
              ${isActive 
                ? 'bg-cyan-500 border-cyan-400 text-white shadow-[0_0_20px_-5px_rgba(6,182,212,0.6)] scale-105' 
                : 'bg-slate-800/60 border-white/10 text-slate-400 hover:bg-slate-700/80 hover:text-white hover:border-white/20 active:scale-95'}
            `}
          >
            <div className={`transition-transform duration-300 ease-ios ${isActive ? 'scale-110' : 'scale-100'}`}>
                {filter.icon}
            </div>
            {filter.label}
          </button>
        );
      })}
    </div>
  );
};