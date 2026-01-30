import React, { useState, useRef } from 'react';
import { Send, AtSign, MessageCircle } from 'lucide-react';
import { User } from '../types';

interface Comment {
  id: string;
  userId: string;
  text: string;
  timestamp: string;
}

const INITIAL_COMMENTS = [
  { id: 'c1', userId: 'u2', text: 'Thanks for sorting this out! @Ali', timestamp: '5m ago' },
  { id: 'c2', userId: 'u3', text: 'Paid via DuitNow just now 👍', timestamp: '2m ago' },
];

interface CommentSectionProps {
  currentUser: User;
  participants: User[];
  billId?: string;
}

export const CommentSection: React.FC<CommentSectionProps> = ({ currentUser, participants }) => {
  const [comments, setComments] = useState<Comment[]>(INITIAL_COMMENTS);
  const [newComment, setNewComment] = useState('');
  const [showMentions, setShowMentions] = useState(false);
  const commentsEndRef = useRef<HTMLDivElement>(null);

  const handleSendComment = () => {
      if (!newComment.trim()) return;

      const comment: Comment = {
          id: `c-${Date.now()}`,
          userId: currentUser.id,
          text: newComment,
          timestamp: 'Just now'
      };

      setComments(prev => [...prev, comment]);
      setNewComment('');
      setShowMentions(false);
      
      // Scroll to bottom
      setTimeout(() => {
          commentsEndRef.current?.scrollIntoView({ behavior: 'smooth' });
      }, 100);
  };

  const handleMentionClick = (userName: string) => {
      setNewComment(prev => prev + `@${userName.split(' ')[0]} `);
      setShowMentions(false);
  };

  const renderCommentText = (text: string) => {
      const parts = text.split(/(@\w+)/g);
      return parts.map((part, index) => {
          if (part.startsWith('@')) {
              return <span key={index} className="text-cyan-400 font-bold">{part}</span>;
          }
          return part;
      });
  };

  const getUserDetails = (userId: string) => {
      if (userId === currentUser.id) return currentUser;
      return participants.find(p => p.id === userId) || { ...currentUser, name: 'Unknown', avatarInitials: '??', color: 'bg-slate-600' };
  };

  return (
    <div className="mb-6 pt-6 border-t border-white/5">
        <h3 className="text-white font-bold text-sm flex items-center gap-2 mb-4">
            <MessageCircle size={16} className="text-cyan-400" />
            Comments & Activity
        </h3>
        
        <div className="space-y-4 mb-4">
            {comments.map((comment, index) => {
                const user = getUserDetails(comment.userId);
                const isMe = user.id === currentUser.id;
                
                return (
                    <div key={comment.id} className={`flex gap-3 animate-in slide-in-from-bottom-2 duration-300 ${isMe ? 'flex-row-reverse' : ''}`} style={{ animationDelay: `${index * 50}ms` }}>
                        <div className={`h-8 w-8 rounded-full flex items-center justify-center text-[10px] font-bold text-white shadow-sm flex-shrink-0 ${user.color || 'bg-slate-600'}`}>
                            {user.avatarInitials}
                        </div>
                        <div className={`flex flex-col max-w-[80%] ${isMe ? 'items-end' : 'items-start'}`}>
                            <div className={`px-4 py-2.5 rounded-2xl text-sm ${isMe ? 'bg-cyan-600 text-white rounded-tr-none' : 'bg-slate-800 text-slate-200 rounded-tl-none'}`}>
                                {renderCommentText(comment.text)}
                            </div>
                            <span className="text-[10px] text-slate-500 mt-1 px-1">{comment.timestamp}</span>
                        </div>
                    </div>
                );
            })}
            <div ref={commentsEndRef} />
        </div>

        {/* Input Area */}
        <div className="relative">
            {/* Mention Popup */}
            {showMentions && (
                <div className="absolute bottom-full mb-2 left-0 right-0 bg-slate-800 rounded-2xl border border-white/10 shadow-xl p-2 animate-in slide-in-from-bottom-2 z-10">
                    <p className="text-[10px] text-slate-400 font-bold uppercase tracking-wider mb-2 px-2">Mention someone</p>
                    <div className="flex gap-2 overflow-x-auto no-scrollbar pb-1">
                        {participants.filter(p => p.id !== currentUser.id).map(p => (
                            <button
                                key={p.id}
                                onClick={() => handleMentionClick(p.name)}
                                className="flex items-center gap-2 bg-white/5 hover:bg-white/10 border border-white/5 rounded-full pl-1 pr-3 py-1 transition-colors flex-shrink-0"
                            >
                                <div className={`h-6 w-6 rounded-full flex items-center justify-center text-[8px] font-bold text-white ${p.color}`}>
                                    {p.avatarInitials}
                                </div>
                                <span className="text-xs text-slate-300 font-medium whitespace-nowrap">{p.name.split(' ')[0]}</span>
                            </button>
                        ))}
                    </div>
                </div>
            )}

            <div className="flex items-center gap-2 bg-slate-900/50 border border-white/10 rounded-2xl p-1.5 focus-within:border-cyan-500/50 focus-within:bg-slate-900 transition-all">
                <button 
                    onClick={() => setShowMentions(!showMentions)}
                    className={`p-2 rounded-xl transition-colors ${showMentions ? 'bg-cyan-500/20 text-cyan-400' : 'text-slate-400 hover:bg-white/5 hover:text-white'}`}
                    title="Mention someone"
                >
                    <AtSign size={18} />
                </button>
                <input
                    type="text"
                    value={newComment}
                    onChange={(e) => {
                        setNewComment(e.target.value);
                        if (e.target.value.endsWith('@')) setShowMentions(true);
                    }}
                    onKeyDown={(e) => e.key === 'Enter' && handleSendComment()}
                    placeholder="Type a comment..."
                    className="flex-1 bg-transparent text-sm text-white placeholder-slate-500 focus:outline-none py-2"
                />
                <button 
                    onClick={handleSendComment}
                    disabled={!newComment.trim()}
                    className="p-2 bg-cyan-500 text-white rounded-xl hover:bg-cyan-400 transition-colors disabled:opacity-50 disabled:bg-slate-800 disabled:text-slate-500"
                >
                    <Send size={16} />
                </button>
            </div>
        </div>
    </div>
  );
};