import React from 'react';
import { Flame, Shield, Sparkles, Swords, Wand2, Zap } from 'lucide-react';
import type { CardDefinition, CardLanguage } from '../types';
import cardBackImg from '../assets/images/poc_card_back_1795363413051.jpg';

interface CardVisualProps {
  card?: CardDefinition;
  faceDown?: boolean;
  defensePosition?: boolean;
  bonusAtk?: number;
  language: CardLanguage;
  selected?: boolean;
  playable?: boolean;
  attacking?: boolean;
  compact?: boolean;
  onClick?: () => void;
  onInspect?: () => void;
}

function getFrameStyle(card: CardDefinition): { border: string; surface: string; header: string } {
  if (card.kind === 'spell') {
    return {
      border: 'border-[#25806E]',
      surface: 'bg-gradient-to-b from-[#133A34] to-[#0D2522]',
      header: 'text-[#86EFAC]',
    };
  }
  if (card.kind === 'trap') {
    return {
      border: 'border-[#9F2B68]',
      surface: 'bg-gradient-to-b from-[#3E142D] to-[#230B19]',
      header: 'text-[#F9A8D4]',
    };
  }
  if ((card.level ?? 0) >= 7) {
    return {
      border: 'border-[#D4A442]',
      surface: 'bg-gradient-to-b from-[#3C2B14] to-[#1D150B]',
      header: 'text-[#FDE68A]',
    };
  }
  return {
    border: 'border-[#9C7A3C]',
    surface: 'bg-gradient-to-b from-[#2B2318] to-[#17130E]',
    header: 'text-[#F3DFB1]',
  };
}

function renderCardEmblem(card: CardDefinition, sizeClass: string) {
  if (card.kind === 'spell') return <Wand2 className={`${sizeClass} text-[#6EE7B7]`} />;
  if (card.kind === 'trap') return <Zap className={`${sizeClass} text-[#F472B6]`} />;
  if (card.attribute === 'LIGHT') return <Sparkles className={`${sizeClass} text-[#FDE68A]`} />;
  if (card.attribute === 'FIRE') return <Flame className={`${sizeClass} text-[#FB923C]`} />;
  if ((card.def ?? 0) > (card.atk ?? 0)) return <Shield className={`${sizeClass} text-[#93C5FD]`} />;
  return <Swords className={`${sizeClass} text-[#E5B857]`} />;
}

export const CardVisual: React.FC<CardVisualProps> = ({
  card,
  faceDown = false,
  defensePosition = false,
  bonusAtk = 0,
  language,
  selected = false,
  playable = false,
  attacking = false,
  compact = false,
  onClick,
  onInspect,
}) => {
  const sizeClasses = compact ? 'w-[86px] h-[122px] p-1.5' : 'w-[108px] h-[154px] p-2';

  if (faceDown || !card) {
    return (
      <button
        type="button"
        onClick={onClick}
        onMouseEnter={onInspect}
        className={`relative ${sizeClasses} rounded-lg border border-[#8C6D3B]/70 overflow-hidden bg-[#1A1510] shadow-md transition-transform duration-150 focus-visible:outline-2 focus-visible:outline-[#D4A442] ${
          defensePosition ? 'rotate-90' : ''
        } ${selected ? 'ring-2 ring-[#E5B857] -translate-y-1' : 'hover:-translate-y-0.5'} ${
          onClick ? 'cursor-pointer' : 'cursor-default'
        }`}
        aria-label={defensePosition ? 'Face-down Defense Card' : 'Face-down Card'}
      >
        <img
          src={cardBackImg}
          alt="Face-down trading card"
          referrerPolicy="no-referrer"
          className="absolute inset-0 w-full h-full object-cover"
        />
        <div className="absolute inset-0 bg-black/15" />
      </button>
    );
  }

  const frame = getFrameStyle(card);
  const title = language === 'es' ? card.nameEs : card.name;
  const totalAtk = (card.atk ?? 0) + bonusAtk;

  return (
    <button
      type="button"
      onClick={onClick}
      onMouseEnter={onInspect}
      className={`relative flex flex-col justify-between text-left ${sizeClasses} rounded-lg border ${frame.border} ${frame.surface} shadow-md transition-transform duration-150 animate-card-enter focus-visible:outline-2 focus-visible:outline-[#D4A442] ${
        defensePosition ? 'rotate-90' : ''
      } ${selected ? 'ring-2 ring-[#E5B857] -translate-y-1.5 z-10' : ''} ${
        playable && !selected ? 'hover:-translate-y-1.5 ring-1 ring-[#D4A442]/50' : ''
      } ${attacking ? 'animate-attack-lunge' : ''} ${onClick ? 'cursor-pointer' : 'cursor-default'}`}
      aria-label={title}
    >
      <div className="w-full">
        <div className={`text-[10px] font-semibold leading-tight truncate ${frame.header}`}>{title}</div>
        <div className="mt-0.5 flex items-center justify-between text-[9px] text-[#CBD5E1]/80 tabular-nums">
          <span>{card.kind === 'monster' ? `Lv.${card.level}` : card.kind === 'spell' ? 'Spell' : 'Trap'}</span>
          {card.attribute ? <span>{card.attribute}</span> : null}
        </div>
      </div>

      <div className="my-1 flex-1 w-full rounded bg-black/35 border border-white/10 flex flex-col items-center justify-center px-1">
        {renderCardEmblem(card, compact ? 'w-5 h-5' : 'w-6 h-6')}
        {card.race ? (
          <span className="mt-1 text-[8px] text-[#CBD5E1]/75 truncate max-w-full">{card.race}</span>
        ) : null}
      </div>

      {card.kind === 'monster' ? (
        <div className="w-full flex items-center justify-between text-[9px] font-mono tabular-nums pt-0.5 border-t border-white/10">
          <span className={bonusAtk > 0 ? 'text-[#86EFAC] font-semibold' : 'text-[#FDE68A]'}>
            {totalAtk}
          </span>
          <span className="text-[#94A3B8]">/</span>
          <span className="text-[#CBD5E1]">{card.def}</span>
        </div>
      ) : (
        <div className="w-full text-[8px] text-[#CBD5E1]/80 truncate pt-0.5 border-t border-white/10">
          {card.kind === 'spell' ? 'Activate' : 'Set Trap'}
        </div>
      )}
    </button>
  );
};
