export type GameEdition = 'yugi' | 'kaiba' | 'joey';

export type CardKind = 'monster' | 'spell' | 'trap';

export type MonsterAttribute = 'DARK' | 'LIGHT' | 'EARTH' | 'FIRE' | 'WATER' | 'WIND';

export type CardEffectId =
  | 'none'
  | 'pot_of_greed'
  | 'dark_hole'
  | 'monster_reborn'
  | 'fissure'
  | 'dian_keto'
  | 'swords_light'
  | 'sword_dark_boost'
  | 'mirror_force'
  | 'trap_hole'
  | 'waboku'
  | 'kuriboh_guard'
  | 'man_eater_flip';

export interface CardDefinition {
  id: string;
  name: string;
  nameEs: string;
  kind: CardKind;
  edition: GameEdition;
  level?: number;
  atk?: number;
  def?: number;
  attribute?: MonsterAttribute;
  race?: string;
  description: string;
  descriptionEs: string;
  effectId: CardEffectId;
}

export type AspectMode = 'overlay' | 'original' | 'stretched';
export type FpsLimit = '30' | '60' | 'display';
export type SimSpeed = 1 | 2;
export type CardLanguage = 'en' | 'es';

export interface LauncherSettings {
  aspect: AspectMode;
  fps: FpsLimit;
  simSpeed: SimSpeed;
  quickPlay: boolean;
  cardLanguage: CardLanguage;
  muted: boolean;
}

export interface ReleaseEntry {
  version: string;
  dateLabel: string;
  highlights: string[];
}
