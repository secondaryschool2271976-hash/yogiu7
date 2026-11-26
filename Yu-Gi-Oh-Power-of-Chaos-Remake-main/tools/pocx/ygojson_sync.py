"""Sync extra_cards.json metadata, subtypes, abilities, card shapes, and bitfields
from the iconmaster5326/YGOJSON (v1) card dataset while clearing stolen native aliases.
"""
from __future__ import annotations

import argparse
import json
import urllib.request
from pathlib import Path
from typing import Any

YGOJSON_V1_URL = "https://raw.githubusercontent.com/iconmaster5326/YGOJSON/v1/cards.json"

TYPE_ID_BY_NAME: dict[str, int] = {
    "dragon": 1,
    "zombie": 2,
    "fiend": 3,
    "pyro": 4,
    "sea serpent": 5,
    "rock": 6,
    "machine": 7,
    "fish": 8,
    "dinosaur": 9,
    "insect": 10,
    "beast": 11,
    "beast-warrior": 12,
    "plant": 13,
    "aqua": 14,
    "warrior": 15,
    "winged beast": 16,
    "fairy": 17,
    "spellcaster": 18,
    "thunder": 19,
    "reptile": 20,
}

ATTRIBUTE_ID_BY_NAME: dict[str, int] = {
    "none": 0,
    "light": 1,
    "dark": 2,
    "water": 3,
    "fire": 4,
    "earth": 5,
    "wind": 6,
    "divine": 7,
}

SUBCATEGORY_CODE: dict[str, int] = {
    "normal": 0,
    "counter": 1,
    "field": 2,
    "equip": 3,
    "continuous": 4,
    "quickplay": 5,
    "ritual": 6,
}

# Only the 5 Ritual Spells intentionally share native Ritual Summon row 0x2d0,
# which ExtraCardEffects.sync_ritual_table_* dynamically reconfigures on activation.
PRESERVED_NATIVE_ALIASES: dict[int, int] = {
    2904: 720,  # White Dragon Ritual
    3018: 720,  # Incandescent Ordeal
    3047: 720,  # Shinato's Ark
    3053: 720,  # Contract with the Abyss
    3083: 720,  # Contract with the Dark Master
}

TEXT_LANG_MAP: dict[str, str] = {
    "eng": "en",
    "spa": "es",
    "fra": "fr",
    "ger": "de",
    "ita": "it",
    "jpn": "ja",
}

DIVINE_TYPE_NAMES = {"divine-beast", "divinebeast", "creator god", "creatorgod"}

# Special Divine God card frame styles matching card IDs & classic anime frames.
SLIFER_IDS = {2502, 2658, 2666}
OBELISK_IDS = {2500, 2579, 2650, 2653}
RA_IDS = {2501, 2503, 2504, 2507, 2517, 2652, 2664}


def _norm_token(value: str) -> str:
    return "".join(ch for ch in value.lower() if ch.isalnum())


def build_ygojson_index(records: list[dict[str, Any]]) -> tuple[dict[str, dict[str, Any]], dict[str, dict[str, Any]]]:
    by_pass: dict[str, dict[str, Any]] = {}
    by_name: dict[str, dict[str, Any]] = {}
    for entry in records:
        for pw in entry.get("passwords") or ():
            pw_str = str(pw).strip()
            if pw_str.isdigit():
                by_pass.setdefault(pw_str.zfill(8), entry)
        en = (entry.get("text") or {}).get("en") or {}
        name = str(en.get("name") or "").strip()
        if name:
            by_name.setdefault(name.lower(), entry)
    return by_pass, by_name


def match_ygojson(
    card: dict[str, Any],
    by_pass: dict[str, dict[str, Any]],
    by_name: dict[str, dict[str, Any]],
) -> dict[str, Any] | None:
    pw = str(card.get("password") or "").strip()
    if pw.isdigit():
        found = by_pass.get(pw.zfill(8))
        if found is not None:
            return found
    eng_name = str((card.get("names") or {}).get("eng") or "").strip().lower()
    if eng_name:
        return by_name.get(eng_name)
    return None


def encode_prop(card: dict[str, Any]) -> int:
    category = str(card.get("category") or "monster")
    if category in ("spell", "trap"):
        type_id = 22 if category == "spell" else 21
        sub = str(card.get("subcategory") or "normal").lower()
        csub = SUBCATEGORY_CODE.get(sub, 0)
        return (type_id << 20) | ((csub & 0x7) << 17)

    atk = max(0, int(card.get("atk") or 0))
    defense = max(0, int(card.get("defense") or 0))
    level = max(0, min(15, int(card.get("level") or 0)))
    type_id = max(1, min(20, int(card.get("type_id") or 1)))
    kind_bits = max(0, min(3, int(card.get("kind_bits") or 0)))
    attr_name = str(card.get("attribute") or "none").strip().lower()
    if card.get("divine"):
        attr_name = "divine"
    attr_id = ATTRIBUTE_ID_BY_NAME.get(attr_name, 0)
    def_enc = min(0x1FF, defense // 10)
    atk_enc = min(0x1FF, atk // 10)
    return (
        (attr_id << 29)
        | (level << 25)
        | (type_id << 20)
        | (kind_bits << 18)
        | (atk_enc << 9)
        | def_enc
    )


def compute_frame_and_shape(card: dict[str, Any]) -> tuple[str, str]:
    iid = int(card.get("internal_id") or 0)
    category = str(card.get("category") or "monster")
    if category == "spell":
        sub = str(card.get("subcategory") or "normal").lower()
        return "spell", f"spell_{sub}"
    if category == "trap":
        sub = str(card.get("subcategory") or "normal").lower()
        return "trap", f"trap_{sub}"

    if card.get("divine"):
        if iid == 2502:
            return "slifer", "god_red"
        if iid == 2500:
            return "obelisk", "god_blue"
        if iid in (2501, 2503, 2504, 2664):
            return "ra", "god_gold"
        if iid == 2505:
            return "creator_god", "god_gold"
        return "divine_beast", "god_gold"

    mk = str(card.get("monster_kind") or "normal")
    if mk in ("fusion", "ritual", "effect", "normal"):
        return mk, mk
    return "normal", "normal"


def _resolve_monster_kind(yentry: dict[str, Any], fallback: str) -> tuple[str, int]:
    mct = [str(x).lower() for x in (yentry.get("monsterCardTypes") or [])]
    cls = [str(x).lower() for x in (yentry.get("classifications") or [])]
    abil = [str(x).lower() for x in (yentry.get("abilities") or [])]
    if "fusion" in mct:
        return "fusion", 2
    if "ritual" in mct:
        return "ritual", 3
    if "effect" in cls or abil:
        return "effect", 1
    if "normal" in cls:
        return "normal", 0
    return fallback, {"normal": 0, "effect": 1, "fusion": 2, "ritual": 3}.get(fallback, 0)


def sync_card(
    raw: dict[str, Any],
    yentry: dict[str, Any] | None,
) -> tuple[dict[str, Any], bool]:
    card = dict(raw)
    names = dict(card.get("names") or {})
    descriptions = dict(card.get("descriptions") or {})
    iid = int(card.get("internal_id") or 0)

    if yentry is not None:
        card["ygojson_id"] = yentry.get("id")
        ytext = yentry.get("text") or {}
        for poc_lang, ygo_lang in TEXT_LANG_MAP.items():
            block = ytext.get(ygo_lang) or {}
            if block.get("name"):
                names[poc_lang] = str(block["name"]).strip()
            if block.get("effect"):
                descriptions[poc_lang] = str(block["effect"]).strip()

        ycat = str(yentry.get("cardType") or card.get("category") or "monster").lower()
        if ycat in ("spell", "trap"):
            card["category"] = ycat
            ysub = str(yentry.get("subcategory") or "normal").lower()
            if ysub not in SUBCATEGORY_CODE:
                ysub = "normal"
            card["subcategory"] = ysub
            card["abilities"] = []
            card["classifications"] = []
            card["monster_card_types"] = []
            card["type_id"] = 22 if ycat == "spell" else 21
            card["attribute"] = ycat
            card["divine"] = False
        else:
            card["category"] = "monster"
            abil = [str(x).lower() for x in (yentry.get("abilities") or [])]
            cls = [str(x).lower() for x in (yentry.get("classifications") or [])]
            mct = [str(x).lower() for x in (yentry.get("monsterCardTypes") or [])]
            card["abilities"] = abil
            card["classifications"] = cls
            card["monster_card_types"] = mct
            if "flip" in abil:
                card["subcategory"] = "flip"
            elif abil:
                card["subcategory"] = abil[0]
            else:
                card["subcategory"] = "normal"
            mk, kbits = _resolve_monster_kind(yentry, str(card.get("monster_kind") or "normal"))
            card["monster_kind"] = mk
            card["kind_bits"] = kbits

            yatk = yentry.get("atk")
            ydef = yentry.get("def")
            ylv = yentry.get("level")
            if isinstance(yatk, int):
                card["atk"] = yatk
            if isinstance(ydef, int):
                card["defense"] = ydef
            if isinstance(ylv, int):
                card["level"] = ylv

            ytype = str(yentry.get("type") or "").strip()
            ynorm = ytype.lower()
            if ynorm in DIVINE_TYPE_NAMES:
                card["divine"] = True
                card["attribute"] = "divine"
                # Keep native Monster type_id <= 20 so engine < 0x15 monster checks stay sound.
                if int(card.get("type_id") or 0) < 1 or int(card.get("type_id") or 0) > 20:
                    card["type_id"] = 1 if iid in (2501, 2502, 2503, 2504) else 15
            else:
                card["divine"] = bool(card.get("divine", False))
                yattr = str(yentry.get("attribute") or "").strip().lower()
                if yattr in ATTRIBUTE_ID_BY_NAME:
                    card["attribute"] = yattr
                tid = TYPE_ID_BY_NAME.get(ynorm)
                if tid is not None:
                    card["type_id"] = tid

        if yentry.get("series"):
            card["series"] = list(yentry["series"])
    else:
        # Preserve custom cards cleanly and infer missing subtype/shape metadata.
        cat = str(card.get("category") or "monster")
        if cat in ("spell", "trap"):
            csub = (int(card.get("prop") or 0) >> 17) & 0x7
            rev = {v: k for k, v in SUBCATEGORY_CODE.items()}
            card.setdefault("subcategory", rev.get(csub, "normal"))
            card.setdefault("abilities", [])
        else:
            card.setdefault("abilities", [])
            card.setdefault("subcategory", "normal")
            if card.get("divine"):
                card["attribute"] = "divine"

    card["names"] = names
    card["descriptions"] = descriptions
    card["prop"] = encode_prop(card)
    frame_type, card_shape = compute_frame_and_shape(card)
    card["frame_type"] = frame_type
    card["card_shape"] = card_shape

    # Remove stolen native effect aliases; keep only intentional Ritual row 0x2d0 links.
    card["effect_alias"] = PRESERVED_NATIVE_ALIASES.get(iid, 0)
    is_effect_card = card.get("category") != "monster" or card.get("monster_kind", "normal") != "normal"
    card["custom_effect"] = bool(is_effect_card)
    return card, (yentry is not None)


def sync_extra_cards_payload(
    extra_payload: dict[str, Any],
    ygojson_records: list[dict[str, Any]],
) -> tuple[dict[str, Any], dict[str, int]]:
    by_pass, by_name = build_ygojson_index(ygojson_records)
    updated_cards: list[dict[str, Any]] = []
    matched = 0
    unmatched = 0
    preserved_aliases = 0
    for raw in extra_payload.get("cards", []):
        yentry = match_ygojson(raw, by_pass, by_name)
        synced, was_matched = sync_card(raw, yentry)
        if was_matched:
            matched += 1
        else:
            unmatched += 1
        if int(synced.get("effect_alias") or 0) > 0:
            preserved_aliases += 1
        updated_cards.append(synced)

    out = dict(extra_payload)
    out["ygojson_source"] = "iconmaster5326/YGOJSON (v1)"
    out["cards"] = updated_cards
    stats = {
        "total": len(updated_cards),
        "matched": matched,
        "unmatched": unmatched,
        "preserved_aliases": preserved_aliases,
    }
    return out, stats


def fetch_ygojson(url: str = YGOJSON_V1_URL) -> list[dict[str, Any]]:
    with urllib.request.urlopen(url, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--extra-cards",
        type=Path,
        default=Path("game/assets/cards/extra_cards.json"),
    )
    parser.add_argument("--ygojson", type=Path, help="Path to local YGOJSON cards.json")
    parser.add_argument("--fetch", action="store_true", help="Download YGOJSON v1 cards.json from GitHub")
    parser.add_argument("--write", action="store_true", help="Write synced output back to --extra-cards")
    args = parser.parse_args()

    if args.ygojson:
        records = json.loads(args.ygojson.read_text(encoding="utf-8"))
    elif args.fetch:
        records = fetch_ygojson()
    else:
        raise SystemExit("Provide either --ygojson PATH or --fetch")

    payload = json.loads(args.extra_cards.read_text(encoding="utf-8"))
    out, stats = sync_extra_cards_payload(payload, records)
    if args.write:
        args.extra_cards.write_bytes((json.dumps(out, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))
    print(
        f"YGOJSON sync: {stats['total']} total, {stats['matched']} matched, "
        f"{stats['unmatched']} custom/unmatched, {stats['preserved_aliases']} ritual aliases kept"
    )


if __name__ == "__main__":
    main()
