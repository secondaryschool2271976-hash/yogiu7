# Custom card audit

Scope: the 643 custom cards added to the game (ids 2500-3142, card text from `game/assets/cards/extra_cards.json`).
Each card's text is compared against the code that implements it (`game/duel/core/custom_effects_*.gd`,
`custom_card_effects.gd`, `custom_duel_ops.gd`, `extra_card_effects.gd`).

This file lists the cards that could **not** be brought fully in line with their printed text, and why.
Cards that were wrong and are now fixed are listed at the end for reference.

## Not implemented as written

Each entry says what the card text asks for, what the game does instead, and what the engine would need
before it can be done properly.

### 2603 Marshmallon
Text: "Cannot be destroyed by battle. After damage calculation, if this card was attacked, and was
face-down at the start of the Damage Step: The attacking player takes 1000 damage."
Done: the battle protection. Missing: the 1000 damage.
Why: the damage only applies when the card was face-down when the Damage Step began. Nothing in the
duel state records how a monster was positioned at the start of the Damage Step, so the condition cannot
be evaluated after the fact.

### 2651 Spirit Reaper
Text: "Cannot be destroyed by battle. After resolving a card effect that targets this face-up card,
destroy this card. If this card inflicts battle damage to your opponent by a direct attack: Discard 1
random card from their hand."
Done: the battle protection and the discard. Missing: destroying itself after being targeted.
Why: the game marks that an effect was targeted (`effect_targeted`) but not which card was targeted, and
the mark is cleared when the chain link resolves. There is no per-card record to check afterwards.

### 3038 Kaiser Glider
Text: "Cannot be destroyed by battle with a monster that has the same ATK. If this card is destroyed and
sent to the GY: Target 1 monster on the field; return that target to the hand."
Done: the return-to-hand effect. Missing: the battle protection against an equal-ATK attacker.
Why: destruction is resolved from the defending side only, without the attacking monster's ATK in scope.

### 2589 Hamon, Lord of Striking Thunder / 2702 Marauding Captain / 2993 Guardian Kay'est
Text: restrictions on which monsters the opponent may **attack** (Hamon in Defense Position: only it can
be attacked; Marauding Captain: Warrior monsters cannot be attacked, except it; Kay'est: cannot be
targeted for attacks).
Missing: all three attack restrictions.
Why: attack declaration is handled by the original engine, which has no hook for "only this monster may
be attacked this turn". Only effect targeting (`choose_zone`) is under the custom layer's control.

### 2577 Fallen Paradise of the Sacred Beasts
Text: "Thrice per turn: You can send 3 other cards of the same type (Monster, Spell, or Trap) from your
hand and/or face-up field to the GY, then you can Special Summon 1 'Sacred Beast' monster from your hand,
Deck, GY, or banishment, and if you do, it is unaffected by your opponent's activated Spell/Trap effects.
If you control a 'Sacred Beast' monster whose original Level is 10: You can draw 2 cards."
Done: the draw 2. Missing: the thrice-per-turn send-and-summon effect.
Why: it needs a player choice of card type plus a three-card selection from two different places, and
the game's choice helpers pick a single card at a time. Left out rather than guessed at.

### 2649 Soul Crossing
Text: "...Until the end of the next turn after this card resolves, you can only activate 1 card or effect
per turn, not counting the effects of Divine-Beast monsters."
Done: the Tribute Summon of a Divine-Beast using the opponent's monsters. Missing: the activation limit.
Why: there is no per-turn activation counter for a player, only per-card "once per turn" markers.

### 2622 Obliterate!!! Blaze
Text: "...also you cannot activate other cards' effects for the rest of this turn."
Done: paying half the LP, destroying the Spell/Trap Zones, equipping five "Forbidden One" monsters at
2000 ATK each, and the piercing damage. Missing: the no-other-effects lock for the rest of the turn.
Why: same reason as Soul Crossing - no per-turn activation counter exists.

### 2608 Millennium Ankh
Text: "After activation, shuffle this card into the Deck instead of sending it to the GY."
Done: everything else (showing five "Forbidden One" cards, Special Summoning "The Unstoppable Exodia
Incarnate", spinning back the other monsters, the no-Summon restriction).
Missing: the card returning to the Deck instead of the Graveyard.
Why: where a resolved Spell goes is decided by the original engine after the custom effect returns; the
custom layer cannot redirect that destination.

## Fixed during this audit

| Card | What was wrong |
| --- | --- |
| 2500 Obelisk the Tormentor | the opponent could target it with card effects |
| 2501 The Winged Dragon of Ra | the LP payment for the ATK boost was forced; it is now optional |
| 2503 Sphere Mode | the opponent could target it with card effects |
| 2519 Blue-Eyes Ultimate Dragon, the God-Surpassing Servant | could be destroyed by card effects |
| 2521 Bottomless Trap Hole | banished without destroying, so "when destroyed" effects never fired |
| 2554 Egyptian God Slime | no battle protection, and the opponent could target other monsters |
| 2573 Exodia Necross | could be destroyed by battle and by Spell/Trap effects |
| 2576 Fallen Paradise | the Sacred Beast protection was missing |
| 2588 Guardian Slime | never summoned itself from the hand after damage |
| 2601 Maiden of the Millennium Moon | was destroyed by the battle it fought |
| 2603 Marshmallon | could be destroyed by battle |
| 2618 Moremarshmallon | the Shining Sarcophagus battle protection was never applied |
| 2619 Mound of the Bound Creator | Level 10+ monsters were neither protected nor untargetable |
| 2633 Sengenjin Wakes | could be destroyed by monster effects |
| 2634 Shield of the Millennium Dynasty | could be destroyed by Spell/Trap effects |
| 2651 Spirit Reaper | could be destroyed by battle |
| 2660 The Unstoppable Exodia Incarnate | no protection from the opponent's card effects |
| 2676 Tyrant Burst Dragon | the equipped monster got no ATK/DEF and no extra attacks |
| 2680 Wedju Temple | the destroyed-Millennium-monster replacement effect was missing |
| 2729 Fusion Sword Murasame Blade | could be destroyed by card effects while equipped |
| 2756 Heart of Clear Water | no protection for the equipped monster, and no self-destruct at 1300 ATK |
| 2788 Spiritual Energy Settle Machine | Spirit monsters still returned to the hand |
| 2993 Guardian Kay'est | was not unaffected by Spell effects |
