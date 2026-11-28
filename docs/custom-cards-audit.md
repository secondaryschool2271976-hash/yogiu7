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

### 2930 Kaiser Colosseum
Text: "If there is 1 or more monster(s) on the field of the controller of this card, his/her opponent
cannot place a monster on the field if his/her number of monsters would exceed the number of monsters
on the field of this card's controller."
Done: nothing. Why: placing a monster is done by the original engine, which has no hook to refuse a
Summon based on the current monster counts. The custom layer can only act after a monster has landed.

### 2949 Kishido Spirit
Text: "Monsters on your side of the field cannot be destroyed in a battle if the monsters' ATK are equal."
Done: nothing. Why: the destruction itself is reachable, but only the identity of the card being
destroyed is passed in. The ATK of the monster it fought is not carried into the destruction, so the
equal-ATK condition cannot be evaluated there.

### 2956 Continuous Destruction Punch
Text: "If the DEF of the attacked Defense Position monster on your side of the field is higher than the
ATK of the attacking monster on your opponent's side of the field: Destroy the attacking monster at the
end of the Damage Step."
Done: nothing. Why: same as Kishido Spirit - the end of the Damage Step is handled by the original
engine and both monsters' stats are not available where the custom layer can act.

### 3051 Precious Cards from Beyond
Text: "When you Tribute Summon a monster using 2 or more Tributes: Draw 2 cards."
Done: nothing. Why: nothing in the custom layer records how many monsters a Tribute Summon used. The
summon arrives as a single "tribute" event, so "2 or more" cannot be told apart from a single Tribute.

### 2753 Convulsion of Nature
Text: "As long as this card remains face-up on the field, both players must turn their respective Decks
upside down and proceed with the current Duel."
Done: nothing. Why: this only changes how the Deck is displayed. Deck order and drawing are handled by
the original engine and there is no presentation hook for it.

### 2755 Smoke Grenade of the Thief
Text: "When this card is destroyed by a card effect while equipped to a monster: Look at your opponent's
hand and discard 1 card from their hand."
Done: nothing. Why: the custom layer only sees destruction of monsters. A Spell or Trap leaving the
field is not reported to it, so "destroyed while equipped" cannot be detected.

### 2897 Raregold Armor
Text: "As long as you control the monster equipped with this card, your opponent cannot attack other
monsters other than the equipped monster."
Done: nothing. Why: the same reason as Marshmallon Glasses - attack declaration is handled by the
original engine, which has no hook to redirect an attack.

### 3105 Spatial Collapse
Text: "You can only activate this card if both you and your opponent each have 5 or less cards on the
field. The maximum number of cards each player can control is 5."
Done: nothing. Why: the game cannot refuse a card being placed on the field, so a five-card ceiling
cannot be enforced from the custom layer.

### 2832 Ordeal of a Traveler
Text: "Once per battle, when an opponent's monster declares an attack: You can activate this effect; Your
opponent chooses 1 random card in your hand and calls the card type (Monster, Spell, or Trap), and if
they call it wrong, return the attacking monster to the hand."
Done: nothing. Why: the effect has to run when an attack is declared, and attack declaration belongs to
the original engine with no hook, the same reason Raregold Armor and Marshmallon Glasses are listed.

### 2790 Lava Golem
Text: "...You cannot Normal Summon/Set the turn you Special Summon this card."
Done: the Special Summon by Tributing two of the opponent's monsters. Missing: the Normal Summon lock.
Why: the game only asks the custom layer whether a summon is allowed when the card being summoned is
itself a custom card. A lock that applies to every card in the hand cannot be enforced that way.

### 2869 Non Aggression Area
Text: "Discard 1 card. Your opponent cannot Summon or Set a monster during their next turn."
Done: the discard. Missing: the Summon lock.
Why: same reason as Lava Golem - the summon gate only covers custom cards.

## State flags written but never read

These are places where a card's code records something in the duel state and nothing ever looks at it.
The card looks implemented in the source and does nothing in play, which makes this the easiest kind of
defect to miss. Every flag below was checked against the whole repository, not just the effect files.

| Flag | Card | What the text needs | Status |
|---|---|---|---|
| union_equipped | Union monsters (2690, 2692, 2914, 2915, 2939, 2941, 2947, 2959, 2974, 2975, 2989) | the Union card is destroyed instead of the equipped monster | fixed |
| dice_reroll_turn | 3068 Dice Re-Roll | repeat a die roll once per turn | fixed |
| only_attacker_zone_turn | 2977 Diffusion Wave-Motion | only the chosen monster may attack | fixed |
| must_attack_zone_turn | 3075 Staunch Defender | the opponent must attack the chosen monster | fixed |
| poisonous_snake_token | 2882 Cobra Jar | 500 damage when the token dies in battle | fixed |
| cannot_normal_summon_turn | 2790 Lava Golem | no Normal Summon that turn | needs an engine hook (see below) |
| cannot_summon_until_turn | 2608, 2869 | no Summon for a turn | needs an engine hook |
| extra_tribute_summon_turn | 2507 Ancient Chant | a second Tribute Summon that turn | needs an engine hook |
| force_ep_turn | 2908 Neko Mane King | end the turn immediately | needs an engine hook |
| skip_mp1_turn | 2843 Timeater | skip the opponent's next Main Phase 1 | needs an engine hook |
| max_attackers_turn | 2666 Thunderforce Attack | limit how many monsters may attack | needs an engine hook |
| must_attack_turn | 2955 Amazoness Archers | force the opponent's monsters to attack | needs an engine hook |
| can_activate_set_turn | 2626 Reactor Slime | the Set card may be activated that turn | needs an engine hook |
| maharaghi_scry_turn | 2735 Maharaghi | look at the top card in the next Standby Phase | open (the scry is a presentation-only step) |
| blaze_cannon_turn | 2517 Blaze Cannon | the extra effect granted to Ra for the turn | open (needs the Ra effect list read) |
| reborn_ra_turn | 2610 Millennium Revelation | Special Summon Ra with Monster Reborn that turn | open |
| capsule_card_id | 2809 Different Dimension Capsule | the banished card returns later | redundant: the card id is already passed in the scheduled effect |
| pharaoh_treasure_armed | 2856 Pharaoh's Treasure | recognise the drawn copy | redundant: the draw is recognised from the effect context |
| name_is_dmg | 2543 Dark Magician Girl the Magician's Apprentice | the name becomes "Dark Magician Girl" | redundant: 2543 is already in the Dark Magician id list |
| last_turn_active | 2718 Last Turn | resolve the end-of-turn judgement | redundant: a scheduled effect does the work |

The "needs an engine hook" rows share one cause: the original engine decides whether a Summon, a phase
or an attack may happen, and the custom layer is only consulted for cards it owns. Locks that apply to
every card in a hand, or that change the turn structure, cannot be enforced from GDScript alone.

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
| 2632 Sengenjin | its "always treated as a Millennium card" line was ignored by Millennium support |
| 2633 Sengenjin Wakes | could be destroyed by monster effects |
| 2634 Shield of the Millennium Dynasty | could be destroyed by Spell/Trap effects |
| 2651 Spirit Reaper | could be destroyed by battle |
| 2660 The Unstoppable Exodia Incarnate | no protection from the opponent's card effects |
| 2676 Tyrant Burst Dragon | the equipped monster got no ATK/DEF and no extra attacks |
| 2680 Wedju Temple | the destroyed-Millennium-monster replacement effect was missing |
| 2690, 2692, 2914, 2915, 2939, 2941, 2947, 2959, 2974, 2975, 2989 (Union monsters) | the equipped monster died instead of the Union card |
| 2726 Second Coin Toss | the coin-toss code checked the wrong card id, so it never triggered |
| 2729 Fusion Sword Murasame Blade | could be destroyed by card effects while equipped |
| 2745 Dragon's Rage | was a no-op; Dragon monsters now get piercing while it is up |
| 2750 Ominous Fortunetelling | a stray block biased every die roll to 5 or 6 while it was face-up |
| 2756 Heart of Clear Water | no protection for the equipped monster, and no self-destruct at 1300 ATK |
| 2784 Spring of Rebirth | no LP gain when a monster returned to the hand |
| 2788 Spiritual Energy Settle Machine | Spirit monsters still returned to the hand |
| 2880 Dark Room of Nightmare | was a no-op; the extra 300 damage now applies |
| 2882 Cobra Jar | the Poisonous Snake Token did not inflict 500 damage when destroyed in battle |
| 2964 Demotion | the equipped monster's Level was not lowered |
| 2977 Diffusion Wave-Motion | every monster could still attack, not only the chosen one |
| 2993 Guardian Kay'est | was not unaffected by Spell effects |
| 3004 Non-Spellcasting Area | Normal Monsters were still destroyed by Spell effects |
| 3068 Dice Re-Roll | the flag it set was never read, so no re-roll ever happened |
| 3075 Staunch Defender | the opponent's monsters could attack anything |
| 3076 Morale Boost | no LP gain on equipping and no damage when the Equip Spell left |
| 3079 Rod of the Mind's Eye | battle damage from the equipped monster was not set to 1000 |
| 3103 Begone, Knave! | was a no-op; the monster that dealt battle damage is now returned to the hand |
| 3119 Stumbling | was a no-op; Summoned monsters now go to Defense Position |
| 3120 Heart of the Underdog | no extra draw for a Normal Monster drawn in the Draw Phase |

## Choices the engine cannot present yet

These cards need the player to pick between named options (not a card on the field), and the custom layer has no way to ask for that. The effect itself works; only the pick is made for the player.

| Card | What is picked for the player |
| --- | --- |
| 2750 Ominous Fortunetelling | The Standby Phase call of Monster, Spell or Trap is rolled at random instead of being chosen. The 700 damage on a correct call is applied normally. |

A multi-option prompt in the custom layer would close this. Until then, treat the call as a coin flip rather than a decision.
