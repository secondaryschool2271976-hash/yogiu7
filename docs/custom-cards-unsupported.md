# Custom cards that cannot be done as written

Every card below was checked against its printed text. The parts listed as missing cannot be implemented
from the custom-effect layer in its current shape; the rest of each card works. Card ids are internal ids
from `game/assets/cards/extra_cards.json`.

## Blocked by the engine (the engine decides, the custom layer is only consulted for its own cards)

| Id | Card | What is missing | Why |
|---|---|---|---|
| 2790 | Lava Golem | "You cannot Normal Summon/Set the turn you Special Summon this card" | the summon gate only covers cards the custom layer owns |
| 2608 | Millennium Ankh | the no-Summon restriction | same |
| 2869 | Non Aggression Area | "your opponent cannot Summon or Set during their next turn" | same |
| 2507 | Ancient Chant | the second Tribute Summon | same |
| 2908 | Neko Mane King | ending the turn immediately | the turn structure belongs to the engine |
| 2843 | Timeater | skipping the opponent's next Main Phase 1 | same |
| 2666 | Thunderforce Attack | limiting how many monsters may attack | same |
| 2955 | Amazoness Archers | forcing the opponent's monsters to attack | same |
| 2626 | Reactor Slime | activating the Set card that turn | same |
| 2608 | Millennium Ankh | shuffling itself back into the Deck instead of the GY | where a resolved Spell goes is decided by the engine |
| 2930 | Kaiser Colosseum | the monster-count ceiling | the engine places monsters without asking |
| 3105 | Spatial Collapse | the five-card ceiling | same |
| 3051 | Precious Cards from Beyond | "using 2 or more Tributes" | the summon arrives as one event without a Tribute count |
| 2589 | Hamon, Lord of Striking Thunder | "only this monster can be attacked" | attack declaration has no hook for this |
| 2702 | Marauding Captain | Warriors cannot be attacked | same |
| 2993 | Guardian Kay'est | cannot be targeted for attacks | same |
| 2897 | Raregold Armor | redirecting the opponent's attacks | same |
| 2832 | Ordeal of a Traveler | the whole effect (it triggers on attack declaration) | same |
| 2610 | Millennium Revelation | Special Summoning Ra with Monster Reborn | Monster Reborn is a native card, its resolution never reaches the custom layer |

## Blocked by missing information or missing presentation

| Id | Card | What is missing | Why |
|---|---|---|---|
| 2603 | Marshmallon | the 1000 damage when attacked face-down | nothing records how a monster was positioned when the Damage Step began |
| 2651 | Spirit Reaper | destroying itself after being targeted | the state marks that something was targeted, not which card |
| 2753 | Convulsion of Nature | flipping the Decks face-up | presentation only, no hook |
| 2755 | Smoke Grenade of the Thief | the discard when it is destroyed while equipped | destruction of Spells and Traps is not reported to the custom layer |
| 2649 | Soul Crossing | one activation per turn | no per-turn activation counter exists |
| 2622 | Obliterate!!! Blaze | no other effects for the rest of the turn | same |
| 2577 | Fallen Paradise of the Sacred Beasts | the thrice-per-turn send-and-summon | needs a card-type choice plus three cards from two places |

## Blocked by missing player choice

| Id | Card | What is chosen for the player | Why |
|---|---|---|---|
| 2750 | Ominous Fortunetelling | the Monster/Spell/Trap call is rolled at random | there is no multi-option prompt |
| 2984 | Spellbook Organization | nothing, the top 3 stay in order | there is no way to reorder cards |

## Approximation worth knowing

| Id | Card | What is approximate |
|---|---|---|
| 2543 | Dark Magician Girl the Magician's Apprentice | it counts as "Dark Magician Girl" even when it was not Special Summoned by its own effect, because its id sits in the Dark Magician list unconditionally |

Everything else in the set of 643 custom cards matches its text. The full audit, including what was fixed
and how, is in `docs/custom-cards-audit.md`.
