import React, { useState, useEffect, useRef } from 'react';
import { ArrowLeft, Trash2, Plus, RefreshCw, Percent, ChevronRight, Tag, X, Receipt } from 'lucide-react';

export interface ReceiptItem {
  id: string;
  name: string;
  quantity: number;
  price: number;
  type?: 'ITEM' | 'TAX';
  taxRate?: number;
}

interface EditReceiptProps {
  initialItems: ReceiptItem[];
  initialRestaurantName?: string;
  onBack: () => void;
  onConfirm: (items: ReceiptItem[]) => void;
}

export const EditReceipt: React.FC<EditReceiptProps> = ({ initialItems, initialRestaurantName, onBack, onConfirm }) => {
  const [items, setItems] = useState<ReceiptItem[]>(initialItems);
  const [restaurantName, setRestaurantName] = useState(initialRestaurantName || "New Receipt");
  
  // Modal State
  const [showChargeModal, setShowChargeModal] = useState(false);
  const [chargeName, setChargeName] = useState('Service Charge');
  const [chargeRate, setChargeRate] = useState('10');

  // Scroll ref
  const listEndRef = useRef<HTMLDivElement>(null);

  // Filter items for display
  const regularItems = items.filter(i => i.type !== 'TAX');
  const taxItems = items.filter(i => i.type === 'TAX');

  // Calculate subtotal (Sum of regular items)
  const calculateSubtotal = (currentItems: ReceiptItem[]) => {
    return currentItems.reduce((sum, item) => {
      if (item.type !== 'TAX') {
        return sum + (item.price * item.quantity);
      }
      return sum;
    }, 0);
  };

  const subtotal = calculateSubtotal(items);
  const totalCharges = taxItems.reduce((sum, item) => sum + item.price, 0);

  // Recalculate taxes whenever items change
  useEffect(() => {
    const currentSubtotal = calculateSubtotal(items);
    let hasChanges = false;

    // Map through items to check if tax amounts need updating based on subtotal
    const updatedItems = items.map(item => {
      if (item.type === 'TAX' && item.taxRate !== undefined) {
        const expectedAmount = Number((currentSubtotal * (item.taxRate / 100)).toFixed(2));
        
        if (Math.abs(item.price - expectedAmount) > 0.001) {
          hasChanges = true;
          return { ...item, price: expectedAmount };
        }
      }
      return item;
    });

    if (hasChanges) {
      setItems(updatedItems);
    }
  }, [items]);

  const updateItem = (id: string, field: keyof ReceiptItem, value: any) => {
    setItems(prev => prev.map(item => {
      if (item.id !== id) return item;

      if (field === 'taxRate') {
        return { ...item, taxRate: parseFloat(value) || 0 };
      }
      if (field === 'price') {
        if (item.type === 'TAX') return item;
        return { ...item, price: parseFloat(value) || 0 };
      }
      if (field === 'quantity') {
        return { ...item, quantity: Math.max(1, parseFloat(value) || 0) };
      }
      
      return { ...item, [field]: value };
    }));
  };

  const deleteItem = (id: string) => {
    setItems(items.filter(item => item.id !== id));
  };

  const addItem = () => {
    const newItem: ReceiptItem = {
      id: Date.now().toString(),
      name: 'New Item',
      quantity: 1,
      price: 0.00,
      type: 'ITEM'
    };
    setItems([...items, newItem]);
    
    // Auto-scroll to bottom
    setTimeout(() => {
        listEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    }, 100);
  };

  const handleAddCharge = () => {
    const rate = parseFloat(chargeRate) || 0;
    const newTax: ReceiptItem = {
      id: Date.now().toString(),
      name: chargeName || 'Additional Charge',
      quantity: 1, 
      price: 0.00,
      type: 'TAX',
      taxRate: rate
    };
    
    setItems([...items, newTax]);
    setChargeName('');
    setChargeRate('6');
  };
  
  const calculateGrandTotal = () => {
    return items.reduce((sum, item) => {
      if (item.type === 'TAX') {
        return sum + item.price;
      }
      return sum + (item.price * item.quantity);
    }, 0).toFixed(2);
  };

  return (
    // Fixed container to fill viewport exactly
    <div className="fixed inset-0 z-50 bg-[#020617] flex flex-col animate-in fade-in duration-300">
      <div className="w-full max-w-md mx-auto h-full flex flex-col relative">
          
        {/* Header */}
        <div className="flex-none flex items-center justify-between pt-6 pb-6 px-4 z-20 bg-[#020617] border-b border-white/5 animate-ios-slide-in-right">
            <button 
            onClick={onBack}
            className="h-10 w-10 rounded-full bg-slate-800/50 border border-white/10 flex items-center justify-center text-slate-300 hover:bg-white/10 hover:text-white transition-all duration-300 ease-ios active:scale-95 backdrop-blur-md"
            >
            <ArrowLeft size={20} />
            </button>
            <div className="text-center">
            <input 
                value={restaurantName}
                onChange={(e) => setRestaurantName(e.target.value)}
                className="bg-transparent text-white font-bold text-lg text-center focus:outline-none focus:border-b focus:border-cyan-500 transition-all w-48"
            />
            <p className="text-slate-400 text-xs">Tap to edit name</p>
            </div>
            <button 
            className="h-10 w-10 rounded-full bg-slate-800/50 border border-white/10 flex items-center justify-center text-slate-300 hover:bg-white/10 hover:text-white transition-all duration-300 ease-ios active:scale-95 backdrop-blur-md"
            >
            <RefreshCw size={18} />
            </button>
        </div>

        {/* Scrollable Items List */}
        <div className="flex-1 overflow-y-auto no-scrollbar px-4 pb-[240px] pt-4 space-y-3 animate-ios-fade-in">
            {regularItems.map((item, index) => (
            <div 
                key={item.id}
                className="backdrop-blur-xl rounded-2xl p-4 border shadow-lg transition-all duration-300 ease-ios group animate-in slide-in-from-bottom-4 bg-slate-800/60 border-white/10 hover:border-cyan-500/30 active:scale-[0.98]"
                style={{ animationDelay: `${index * 50}ms` }}
            >
                <div className="flex flex-col gap-3">
                {/* Top Row: Name and Delete */}
                <div className="flex justify-between items-start gap-3">
                    <div className="flex-1 relative">
                        <label className="text-[10px] font-bold uppercase tracking-wider mb-0.5 block text-slate-500">
                            Item Name
                        </label>
                        <input 
                            type="text"
                            value={item.name}
                            onChange={(e) => updateItem(item.id, 'name', e.target.value)}
                            className="w-full bg-transparent text-white font-semibold text-base focus:outline-none focus:ring-0 border-b border-transparent focus:border-cyan-500/50 pb-1 placeholder-slate-600 transition-all"
                            placeholder="Item Name"
                        />
                    </div>
                    <button 
                        onClick={() => deleteItem(item.id)}
                        className="p-2 rounded-lg text-slate-500 hover:text-red-400 hover:bg-red-500/10 transition-colors duration-300 active:scale-90"
                    >
                        <Trash2 size={16} />
                    </button>
                </div>

                {/* Bottom Row: Qty x Price */}
                <div className="flex items-end gap-4">
                    <div className="w-20">
                        <label className="text-[10px] text-slate-500 font-bold uppercase tracking-wider mb-0.5 block">Qty</label>
                        <div className="relative">
                            <input 
                                type="number"
                                min="1"
                                value={item.quantity}
                                onChange={(e) => updateItem(item.id, 'quantity', e.target.value)}
                                className="w-full bg-black/20 rounded-lg px-3 py-2 text-center text-white font-mono text-sm focus:outline-none focus:ring-1 focus:ring-cyan-500 border border-white/5 transition-all duration-300 focus:bg-black/40"
                            />
                        </div>
                    </div>

                    {/* Spacer / Multiply Icon */}
                    <div className="text-slate-500 pb-2 font-bold">×</div>

                    <div className="flex-1">
                        <label className="text-[10px] font-bold uppercase tracking-wider mb-0.5 block text-slate-500">
                            Price (RM)
                        </label>
                        <div className="relative">
                            <input 
                                type="number"
                                min="0"
                                step="0.01"
                                value={item.price}
                                onChange={(e) => updateItem(item.id, 'price', e.target.value)}
                                className="w-full rounded-lg px-3 py-2 text-right font-mono text-sm focus:outline-none focus:ring-1 focus:ring-cyan-500 border transition-colors bg-black/20 text-white border-white/5 focus:bg-black/40"
                            />
                            <span className="absolute left-3 top-2 text-sm text-slate-500">RM</span>
                        </div>
                    </div>
                </div>
                </div>
            </div>
            ))}
            
            {/* Scroll Anchor */}
            <div ref={listEndRef} className="h-4" />
        </div>

        {/* Fixed Bottom Controls Section */}
        <div className="absolute bottom-0 left-0 right-0 z-30">
            {/* Gradient Fade to seamless merge */}
            <div className="h-16 bg-gradient-to-b from-transparent to-[#020617]"></div>
            
            <div className="bg-[#020617] px-4 pb-8 pt-2 flex flex-col gap-4 animate-ios-slide-up">
                {/* Action Buttons */}
                <div className="flex gap-3">
                    <button 
                        onClick={addItem}
                        className="flex-1 py-4 rounded-2xl bg-slate-800 border border-white/10 text-white font-bold text-sm hover:border-cyan-500/50 hover:text-cyan-400 hover:bg-slate-700 transition-all duration-300 ease-ios active:scale-95 flex items-center justify-center gap-2 group shadow-lg shadow-black/50"
                    >
                        <Plus size={18} className="group-hover:scale-110 transition-transform duration-300 ease-ios" />
                        Add Item
                    </button>
                    <button 
                        onClick={() => {
                            setChargeName('Service Tax');
                            setChargeRate('6');
                            setShowChargeModal(true);
                        }}
                        className="flex-1 py-4 rounded-2xl bg-slate-800 border border-white/10 text-white font-bold text-sm hover:border-cyan-500/50 hover:text-cyan-400 hover:bg-slate-700 transition-all duration-300 ease-ios active:scale-95 flex items-center justify-center gap-2 group relative overflow-hidden shadow-lg shadow-black/50"
                    >
                        <div className="flex items-center gap-2 relative z-10">
                            <Tag size={18} className="group-hover:scale-110 transition-transform duration-300 ease-ios" />
                            <span>Additional Charges</span>
                        </div>
                        {taxItems.length > 0 && (
                            <span className="absolute top-2 right-2 flex h-5 w-5 items-center justify-center rounded-full bg-cyan-500 text-[10px] font-bold text-white shadow-lg z-10 animate-ios-pop-in">
                                {taxItems.length}
                            </span>
                        )}
                    </button>
                </div>

                {/* Summary Card */}
                <div className="bg-slate-800/90 backdrop-blur-md rounded-[20px] p-1 shadow-2xl border border-white/10 ring-1 ring-black/50 flex items-center justify-between pl-6 pr-1.5 py-2">
                    <div className="flex flex-col justify-center mr-4 min-w-[120px]">
                        {/* Subtotal Row */}
                        <div className="flex justify-between items-center text-slate-400 mb-0.5">
                            <span className="text-[10px] font-bold uppercase tracking-wider">Subtotal</span>
                            <span className="text-xs font-mono">RM {subtotal.toFixed(2)}</span>
                        </div>
                        
                        {/* Charges Row */}
                        {totalCharges > 0 && (
                            <div className="flex justify-between items-center text-slate-400 mb-1 animate-in fade-in slide-in-from-left-2">
                                <span className="text-[10px] font-bold uppercase tracking-wider">Charges</span>
                                <span className="text-xs font-mono">RM {totalCharges.toFixed(2)}</span>
                            </div>
                        )}
                        
                        {/* Divider */}
                        <div className="h-px bg-white/10 w-full mb-1"></div>

                        {/* Grand Total Row */}
                        <div className="flex justify-between items-end">
                            <span className="text-cyan-400 text-[10px] font-bold uppercase tracking-wider mb-1">Total</span>
                            <div className="text-white font-black text-2xl leading-none tracking-tight flex items-baseline gap-1">
                                <span className="text-sm text-slate-500 font-bold">RM</span>
                                {calculateGrandTotal()}
                            </div>
                        </div>
                    </div>

                    <button 
                        onClick={() => onConfirm(items)}
                        className="bg-gradient-to-r from-cyan-500 to-blue-600 text-white px-6 py-4 rounded-2xl font-bold text-sm shadow-lg shadow-cyan-500/20 hover:shadow-cyan-500/40 hover:scale-[1.02] active:scale-95 transition-all duration-300 ease-ios flex items-center gap-2"
                    >
                        Next
                        <ChevronRight size={18} strokeWidth={3} />
                    </button>
                </div>
            </div>
        </div>

      </div>

      {/* Additional Charge Manager Modal */}
      {showChargeModal && (
          <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/80 backdrop-blur-sm animate-in fade-in duration-300">
             <div className="bg-slate-800 border border-white/10 sm:rounded-3xl rounded-t-3xl w-full sm:w-[90%] max-w-sm shadow-2xl animate-ios-slide-up duration-500 max-h-[85vh] flex flex-col">
                {/* Header */}
                <div className="flex justify-between items-center p-6 pb-4 border-b border-white/5">
                    <h3 className="text-white font-bold text-lg">Additional Charges</h3>
                    <button 
                        onClick={() => setShowChargeModal(false)}
                        className="p-2 bg-white/5 rounded-full hover:bg-white/10 text-slate-400 hover:text-white transition-colors active:scale-90"
                    >
                        <X size={18} />
                    </button>
                </div>
                
                <div className="overflow-y-auto p-6 space-y-6">
                    {/* Section 1: Applied Charges List */}
                    <div>
                        <h4 className="text-xs text-slate-400 font-bold uppercase tracking-wider mb-3">Applied Charges</h4>
                        {taxItems.length === 0 ? (
                            <div className="flex flex-col items-center justify-center py-6 border border-dashed border-white/10 rounded-2xl bg-white/5 animate-in fade-in">
                                <Receipt size={24} className="text-slate-600 mb-2" />
                                <p className="text-slate-500 text-xs font-medium">No charges added yet.</p>
                            </div>
                        ) : (
                            <div className="space-y-2">
                                {taxItems.map((tax, idx) => (
                                    <div 
                                        key={tax.id} 
                                        className="flex items-center justify-between bg-white/5 p-4 rounded-2xl border border-white/5 hover:border-white/10 transition-colors animate-in slide-in-from-left-2"
                                        style={{ animationDelay: `${idx * 100}ms` }}
                                    >
                                        <div className="flex items-center gap-3">
                                            <div className="h-10 w-10 rounded-full bg-cyan-950/50 flex items-center justify-center text-cyan-400 border border-cyan-500/20">
                                                <Percent size={16} />
                                            </div>
                                            <div>
                                                <div className="text-white font-bold text-sm">{tax.name}</div>
                                                <div className="text-xs text-slate-400 flex items-center gap-1">
                                                    <span className="bg-white/10 px-1.5 rounded text-[10px] font-mono">{tax.taxRate}%</span>
                                                    <span>applied on subtotal</span>
                                                </div>
                                            </div>
                                        </div>
                                        <div className="flex items-center gap-4">
                                            <span className="text-white font-mono font-bold text-sm">
                                                RM {tax.price.toFixed(2)}
                                            </span>
                                            <button 
                                                onClick={() => deleteItem(tax.id)}
                                                className="p-2 rounded-lg text-slate-500 hover:text-red-400 hover:bg-red-500/10 transition-colors active:scale-90"
                                                title="Remove charge"
                                            >
                                                <Trash2 size={16} />
                                            </button>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        )}
                        
                        {taxItems.length > 0 && (
                            <div className="mt-3 flex justify-between items-center px-2 animate-in fade-in">
                                <span className="text-xs text-slate-500 font-medium">Total Charges</span>
                                <span className="text-sm font-bold text-cyan-400">
                                    RM {taxItems.reduce((sum, t) => sum + t.price, 0).toFixed(2)}
                                </span>
                            </div>
                        )}
                    </div>

                    {/* Divider */}
                    <div className="h-px w-full bg-white/10"></div>

                    {/* Section 2: Add New Form */}
                    <div className="space-y-4">
                        <h4 className="text-xs text-slate-400 font-bold uppercase tracking-wider">Add New Charge</h4>
                        
                        {/* Name Input */}
                        <div className="space-y-2">
                            <label className="text-[10px] text-slate-500 font-bold uppercase tracking-wider">Name</label>
                            <input 
                                type="text" 
                                value={chargeName}
                                onChange={(e) => setChargeName(e.target.value)}
                                placeholder="e.g. Service Charge, GST"
                                className="w-full bg-black/30 border border-white/10 rounded-xl px-4 py-3 text-white font-medium focus:outline-none focus:border-cyan-500/50 text-sm transition-all focus:bg-black/50"
                            />
                        </div>

                        {/* Percentage Input */}
                        <div className="space-y-2">
                            <label className="text-[10px] text-slate-500 font-bold uppercase tracking-wider">Rate (%)</label>
                            <div className="flex items-center gap-3">
                                <div className="relative flex-1">
                                    <input 
                                        type="number" 
                                        value={chargeRate}
                                        onChange={(e) => setChargeRate(e.target.value)}
                                        placeholder="0"
                                        className="w-full bg-black/30 border border-white/10 rounded-xl px-4 py-3 text-white font-medium focus:outline-none focus:border-cyan-500/50 pr-10 text-sm transition-all focus:bg-black/50"
                                    />
                                    <div className="absolute right-4 top-3.5 text-slate-500 pointer-events-none">
                                        <Percent size={14} />
                                    </div>
                                </div>
                                {/* Quick Presets */}
                                <div className="flex gap-1.5">
                                    {['6', '10', '16'].map(preset => (
                                        <button
                                            key={preset}
                                            onClick={() => setChargeRate(preset)}
                                            className={`px-3 py-3 rounded-xl text-xs font-bold border transition-all duration-300 ease-ios active:scale-95
                                                ${chargeRate === preset 
                                                    ? 'bg-cyan-500 text-white border-cyan-400 shadow-md shadow-cyan-900/20' 
                                                    : 'bg-white/5 text-slate-400 border-white/5 hover:bg-white/10'}`}
                                        >
                                            {preset}%
                                        </button>
                                    ))}
                                </div>
                            </div>
                        </div>

                        {/* Preview Amount */}
                        <div className="bg-slate-900/40 rounded-xl p-3 flex justify-between items-center border border-white/5 transition-all">
                            <span className="text-[10px] text-slate-500 uppercase tracking-wide">Estimated Amount</span>
                            <span className="text-white font-mono font-bold text-sm">
                                RM {((subtotal * (parseFloat(chargeRate) || 0)) / 100).toFixed(2)}
                            </span>
                        </div>
                    </div>
                </div>

                {/* Footer Buttons */}
                <div className="p-6 pt-2 pb-6 flex gap-3 bg-[#0f172a]">
                    <button 
                        onClick={() => setShowChargeModal(false)}
                        className="flex-1 py-3.5 rounded-xl font-bold text-slate-400 hover:text-white bg-slate-700/50 hover:bg-slate-700 transition-colors text-sm active:scale-95 duration-200"
                    >
                        Done
                    </button>
                    <button 
                        onClick={handleAddCharge}
                        disabled={!chargeName}
                        className="flex-[2] py-3.5 rounded-xl font-bold bg-gradient-to-r from-cyan-500 to-blue-600 text-white hover:shadow-lg hover:shadow-cyan-500/20 transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2 text-sm active:scale-95 duration-200"
                    >
                        <Plus size={16} strokeWidth={3} />
                        Add Charge
                    </button>
                </div>
             </div>
          </div>
      )}
    </div>
  );
};