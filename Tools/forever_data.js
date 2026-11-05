// Builds Core/Forever.lua from WoW Forever DB2 tables on wago.tools: node Tools/forever_data.js [build]
// Every hand-picked ID below is checked against that build; one that is gone or renamed stops the run.
const fs = require("fs"), path = require("path"), os = require("os");
const BUILD = process.argv[2] || "1.60.1.70790";
const OUT = path.join(__dirname, "..", "Core", "Forever.lua");
const W = path.join(os.tmpdir(), "thingsui-wago-" + BUILD);
const TABLES = ["SpellName", "ItemSparse", "SkillLine", "SkillLineAbility"];

function csv(name) {
  const t = fs.readFileSync(path.join(W, name + ".csv"), "utf8");
  const rows = []; let i = 0, field = "", row = [], q = false;
  for (; i < t.length; i++) {
    const c = t[i];
    if (q) { if (c === '"') { if (t[i + 1] === '"') { field += '"'; i++; } else q = false; } else field += c; }
    else if (c === '"') q = true;
    else if (c === ",") { row.push(field); field = ""; }
    else if (c === "\n") { row.push(field.replace(/\r$/, "")); rows.push(row); row = []; field = ""; }
    else field += c;
  }
  if (field || row.length) { row.push(field); rows.push(row); }
  const head = rows.shift();
  return rows.map(r => Object.fromEntries(head.map((h, k) => [h, r[k]])));
}

async function main() {
  fs.mkdirSync(W, { recursive: true });
  for (const t of TABLES) {
    const file = path.join(W, t + ".csv");
    if (fs.existsSync(file)) continue;
    // wago.tools turns away requests without a browser user agent
    const res = await fetch(`https://wago.tools/db2/${t}/csv?build=${BUILD}`, { headers: { "User-Agent": "Mozilla/5.0" } });
    if (!res.ok) throw new Error(t + ": HTTP " + res.status);
    fs.writeFileSync(file, await res.text());
    console.log("fetched", t);
  }
  const spellName = new Map(csv("SpellName").map(r => [+r.ID, r.Name_lang]));
  const itemName = new Map(csv("ItemSparse").map(r => [+r.ID, r.Display_lang]));
  const skill = new Map(csv("SkillLine").map(r => [+r.ID, r]));
  const sla = csv("SkillLineAbility");

  let bad = 0;
  function S(id, want) {
    const n = spellName.get(id);
    if (!n) { console.log("MISSING spell", id, want); bad++; }
    else if (want && n !== want) { console.log("NAME spell", id, "is", n, "not", want); bad++; }
    return id;
  }
  function I(id, want) {
    const n = itemName.get(id);
    if (!n) { console.log("MISSING item", id, want); bad++; }
    else if (want && n !== want) { console.log("NAME item", id, "is", n, "not", want); bad++; }
    return id;
  }

  // ---------------------------------------------------------------- rank families
  // same name on the same class or pet skill line = ranks of one spell
  const byKey = new Map();
  for (const r of sla) {
    const s = skill.get(+r.SkillLine);
    if (!s || s.CategoryID !== "7") continue;
    const id = +r.Spell, nm = spellName.get(id);
    if (!nm) continue;
    const key = r.SkillLine + "|" + nm;
    if (!byKey.has(key)) byKey.set(key, new Set());
    byKey.get(key).add(id);
  }
  // a spell on two lines joins their families
  const parent = new Map();
  const find = x => { while (parent.get(x) !== x) { parent.set(x, parent.get(parent.get(x))); x = parent.get(x); } return x; };
  for (const set of byKey.values()) {
    if (set.size < 2) continue;
    const ids = [...set];
    for (const id of ids) if (!parent.has(id)) parent.set(id, id);
    for (let i = 1; i < ids.length; i++) { const a = find(ids[0]), b = find(ids[i]); if (a !== b) parent.set(b, a); }
  }
  const fams = new Map();
  for (const id of parent.keys()) { const r = find(id); if (!fams.has(r)) fams.set(r, []); fams.get(r).push(id); }
  const families = [...fams.values()].map(f => f.sort((a, b) => a - b))
    .sort((a, b) => (spellName.get(a[0]) || "").localeCompare(spellName.get(b[0]) || "") || a[0] - b[0]);

  // ---------------------------------------------------------------- hand-picked data, every ID checked above
  const KICKS = {
    DRUID: [[S(410176, "Skull Bash"), 10], [S(1238122, "Feral Charge"), 15, "node"]],
    MAGE: [[S(2139, "Counterspell"), 30]],
    PALADIN: [[S(425609, "Rebuke"), 15]],
    PRIEST: [[S(15487, "Silence"), 45, "node"]],
    ROGUE: [[S(1766, "Kick"), 10]],
    SHAMAN: [[S(8042, "Earth Shock"), 6]],
    WARRIOR: [[S(6552, "Pummel"), 10, "dps"], [S(72, "Shield Bash"), 12]],
  };
  S(19647, "Spell Lock"); S(19244, "Spell Lock");

  const PREVIEW = [["WARRIOR", S(6552), 0], ["MAGE", S(2139), 9], ["ROGUE", S(1766), 0], ["SHAMAN", S(8042), 4], ["PALADIN", S(425609), 12]];

  const POTIONS = [
    ["Healthstone", [[19013, "Major Healthstone"], [19012, "Major Healthstone"], [9421, "Major Healthstone"],
      [19011, "Greater Healthstone"], [19010, "Greater Healthstone"], [5510, "Greater Healthstone"],
      [19009, "Healthstone"], [19008, "Healthstone"], [5509, "Healthstone"],
      [19007, "Lesser Healthstone"], [19006, "Lesser Healthstone"], [5511, "Lesser Healthstone"],
      [19005, "Minor Healthstone"], [19004, "Minor Healthstone"], [5512, "Minor Healthstone"]]],
    ["Healing Potion", [[13446, "Major Healing Potion"], [223913, "Major Healing Potion"], [3928, "Superior Healing Potion"],
      [288896, "Superior Healing Potion"], [1710, "Greater Healing Potion"], [223914, "Greater Healing Potion"],
      [287977, "Greater Healing Potion"], [929, "Healing Potion"], [858, "Lesser Healing Potion"],
      [287967, "Lesser Healing Potion"], [118, "Minor Healing Potion"], [287966, "Minor Healing Potion"]]],
    ["Mana Potion", [[13444, "Major Mana Potion"], [13443, "Superior Mana Potion"], [288897, "Superior Mana Potion"],
      [6149, "Greater Mana Potion"], [3827, "Mana Potion"], [3385, "Lesser Mana Potion"], [287969, "Lesser Mana Potion"],
      [2455, "Minor Mana Potion"], [287968, "Minor Mana Potion"]]],
    ["Rejuvenation Potion", [[18253, "Major Rejuvenation Potion"], [2456, "Minor Rejuvenation Potion"]]],
    ["Rage Potion", [[13442, "Mighty Rage Potion"], [5633, "Great Rage Potion"], [5631, "Rage Potion"]]],
  ];
  for (const [, g] of POTIONS) for (const [id, n] of g) I(id, n);
  const CURATED_ITEMS = [[5512, "Minor Healthstone"], [13446, "Major Healing Potion"], [13444, "Major Mana Potion"],
    [18253, "Major Rejuvenation Potion"], [13442, "Mighty Rage Potion"], [5634, "Free Action Potion"],
    [3387, "Limited Invulnerability Potion"], [2459, "Swiftness Potion"], [9030, "Restorative Potion"],
    [13455, "Greater Stoneshield Potion"], [20520, "Dark Rune"], [12662, "Demonic Rune"]];
  for (const [id, n] of CURATED_ITEMS) I(id, n);

  const SAMPLES = { BIG_DEFENSIVE: [642, "Divine Shield"], EXTERNAL_DEFENSIVE: [1022, "Blessing of Protection"], IMPORTANT: [10060, "Power Infusion"] };
  for (const k in SAMPLES) S(...SAMPLES[k]);

  const RACIALS = [
    [1259718, "Will to Survive", "Human"], [20600, "Perception", "Human"],
    [20594, "Stoneform", "Dwarf"],
    [20580, "Shadowmeld", "Night Elf"], [1259799, "Elune's Light", "Night Elf"],
    [20589, "Escape Artist", "Gnome"], [1259812, "Eureka!", "Gnome"], [1259813, "Eureka!", "Gnome"],
    [1259817, "Eureka!", "Gnome"], [1259821, "Eureka!", "Gnome"], [1259823, "Eureka!", "Gnome"],
    [20572, "Blood Fury", "Orc"], [1299026, "Shatter Curse", "Orc"],
    [7744, "Will of the Forsaken", "Undead"], [20577, "Cannibalize", "Undead"],
    [20549, "War Stomp", "Tauren"],
    [20554, "Berserking", "Troll"], [1260270, "Rapid Regeneration", "Troll"],
    [1259705, "Read Leyline", "Skyborne"], [1259686, "Skysight", "Skyborne"], [1259416, "Walk on Air", "Skyborne"],
  ];
  for (const [id, n] of RACIALS) S(id, n);

  const AURA_COMMON = [[10060, "Power Infusion"], [29166, "Innervate"], [6940, "Blessing of Sacrifice"],
    [1022, "Blessing of Protection"], [1044, "Blessing of Freedom"], [402004, "Pain Suppression"], [6346, "Fear Ward"]];
  for (const [id, n] of AURA_COMMON) S(id, n);
  const PRESETS = [
    { key: "defensives", name: "Defensives", max: 10, filter: "BIG_DEFENSIVE", spells: [] },
    { key: "externals", name: "Externals", max: 10, spells: [[6940, "Blessing of Sacrifice"], [1022, "Blessing of Protection"],
      [402004, "Pain Suppression"], [6346, "Fear Ward"]] },
    { key: "movement", name: "Movement Speed", max: 10, spells: [[1044, "Blessing of Freedom"], [13159, "Aspect of the Pack"],
      [5118, "Aspect of the Cheetah"], [2983, "Sprint"], [1850, "Dash"]] },
  ];
  for (const p of PRESETS) for (const [id, n] of p.spells) S(id, n);

  const CLASS_SPELLS = {
    WARRIOR: [[6673, "Battle Shout"], [871, "Shield Wall"], [1719, "Recklessness"], [20230, "Retaliation"], [12975, "Last Stand"],
      [12328, "Death Wish"], [18499, "Berserker Rage"], [2687, "Bloodrage"], [5246, "Intimidating Shout"], [426490, "Rallying Cry"],
      [6552, "Pummel"], [72, "Shield Bash"], [100, "Charge"], [20252, "Intercept"], [2565, "Shield Block"], [1161, "Challenging Shout"]],
    PALADIN: [[642, "Divine Shield"], [498, "Divine Protection"], [633, "Lay on Hands"], [1022, "Blessing of Protection"],
      [6940, "Blessing of Sacrifice"], [1044, "Blessing of Freedom"], [407788, "Avenging Wrath"], [853, "Hammer of Justice"],
      [425609, "Rebuke"], [20216, "Divine Favor"], [20473, "Holy Shock"], [20066, "Repentance"], [19752, "Divine Intervention"]],
    HUNTER: [[3045, "Rapid Fire"], [19574, "Bestial Wrath"], [409379, "Kill Command"], [19263, "Deterrence"], [5384, "Feign Death"],
      [781, "Disengage"], [5118, "Aspect of the Cheetah"], [13159, "Aspect of the Pack"], [1499, "Freezing Trap"], [19503, "Scatter Shot"]],
    ROGUE: [[5277, "Evasion"], [2983, "Sprint"], [1856, "Vanish"], [1766, "Kick"], [408, "Kidney Shot"], [2094, "Blind"],
      [1776, "Gouge"], [14177, "Cold Blood"], [13750, "Adrenaline Rush"], [13877, "Blade Flurry"], [14185, "Preparation"]],
    PRIEST: [[10060, "Power Infusion"], [402004, "Pain Suppression"], [6346, "Fear Ward"], [8122, "Psychic Scream"],
      [14751, "Inner Focus"], [15487, "Silence"], [13908, "Desperate Prayer"], [401977, "Shadowfiend"], [425294, "Dispersion"],
      [425207, "Power Word: Barrier"]],
    SHAMAN: [[8042, "Earth Shock"], [16190, "Mana Tide Totem"], [16188, "Nature's Swiftness"], [409324, "Ancestral Guidance"],
      [8177, "Grounding Totem"], [2645, "Ghost Wolf"], [408521, "Riptide"]],
    MAGE: [[2139, "Counterspell"], [11958, "Ice Block"], [122, "Frost Nova"], [1953, "Blink"], [12042, "Arcane Power"],
      [12043, "Presence of Mind"], [11129, "Combustion"], [425121, "Icy Veins"], [12472, "Cold Snap"], [12051, "Evocation"],
      [11426, "Ice Barrier"]],
    WARLOCK: [[6789, "Death Coil"], [5484, "Howl of Terror"], [18288, "Amplify Curse"], [403789, "Metamorphosis"],
      [425463, "Demonic Grace"], [19647, "Spell Lock"]],
    DRUID: [[22812, "Barkskin"], [29166, "Innervate"], [740, "Tranquility"], [1850, "Dash"], [22842, "Frenzied Regeneration"],
      [5211, "Bash"], [17116, "Nature's Swiftness"], [18562, "Swiftmend"], [410176, "Skull Bash"], [1238122, "Feral Charge"],
      [408024, "Survival Instincts"], [417141, "Berserk"], [5217, "Tiger's Fury"], [439748, "Starfall"], [5209, "Challenging Roar"]],
  };
  for (const c in CLASS_SPELLS) for (const [id, n] of CLASS_SPELLS[c]) S(id, n);

  if (bad) { console.log(bad + " bad IDs, nothing written"); process.exitCode = 1; return; }

  // ---------------------------------------------------------------- write
  const L = [];
  const q = s => s.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
  L.push("local _, ns = ...");
  L.push("");
  L.push(`-- WoW Forever only (TOC). Spell and item IDs from its ${BUILD} DB2 tables (wago.tools).`);
  L.push("ns.FV = {}");
  L.push("local FV = ns.FV");
  L.push("");
  L.push("-- every rank of a spell, one per line: same name on the same class or pet skill line");
  L.push("FV.RANKS = {");
  for (const f of families) L.push(`    { ${f.join(", ")} }, -- ${spellName.get(f[0])}`);
  L.push("}");
  L.push("");
  L.push("-- [1] = spell, [2] = cooldown; node = only with the talent, roles = the roles that use it");
  L.push("FV.KICKS = {");
  for (const c of Object.keys(KICKS).sort()) {
    const parts = KICKS[c].map(([id, cd, flag]) => {
      const extra = flag === "node" ? ", node = true" : flag === "dps" ? ", roles = { DAMAGER = true, HEALER = true }" : "";
      return `{ ${id}, ${cd}${extra} }`;
    });
    L.push(`    ${c} = { ${parts.join(", ")} }, -- ${KICKS[c].map(k => spellName.get(k[0])).join(", ")}`);
  }
  L.push("}");
  L.push("FV.SPELL_LOCK_CD = 30");
  L.push("");
  L.push("-- class, kick, seconds left");
  L.push("FV.KICK_PREVIEW = {");
  for (const [c, id, s] of PREVIEW) L.push(`    { "${c}", ${id}, ${s} },`);
  L.push("}");
  L.push("");
  L.push("-- a slot shows the best one owned, first first");
  L.push("FV.POTION_GROUPS = {");
  for (const [n, g] of POTIONS) L.push(`    { ${g.map(x => x[0]).join(", ")} }, -- ${n}`);
  L.push("}");
  L.push("FV.CURATED_ITEMS = {");
  L.push("    " + CURATED_ITEMS.map(x => x[0]).join(", ") + ",");
  L.push("}");
  L.push("");
  L.push("-- preview icons of the Blizzard aura filters");
  L.push("FV.FILTER_SAMPLES = { " + Object.keys(SAMPLES).map(k => `${k} = ${SAMPLES[k][0]}`).join(", ") + " }");
  L.push("");
  L.push("ns.Racials = {");
  for (const [id, n, race] of RACIALS) L.push(`    ${(id + ",").padEnd(8)} -- ${n} (${race})`);
  L.push("}");
  L.push("ns.RacialSet = {}");
  L.push("for _, id in ipairs(ns.Racials) do ns.RacialSet[id] = true end");
  L.push("");
  L.push("ns.AURA_COMMON = {");
  for (const [id, n] of AURA_COMMON) L.push(`    ${(id + ",").padEnd(7)} -- ${n}`);
  L.push("}");
  L.push("");
  L.push("ns.AURA_PRESETS = {");
  for (const p of PRESETS) {
    L.push("    {");
    L.push(`        key = "${p.key}", name = "${q(p.name)}", kind = "HELPFUL", unit = "player", max = ${p.max},`);
    if (p.filter) L.push(`        filter = "${p.filter}", spells = {},`);
    else {
      L.push("        spells = {");
      for (const [id, n] of p.spells) L.push(`            ${(id + ",").padEnd(7)} -- ${n}`);
      L.push("        },");
    }
    L.push("    },");
  }
  L.push("}");
  L.push("");
  L.push("-- one spec per class here: the whole list sits on the class");
  L.push("ns.ClassSpells = {");
  for (const c of Object.keys(CLASS_SPELLS)) {
    L.push(`    ${c} = {`);
    L.push("        class = {");
    for (const [id, n] of CLASS_SPELLS[c]) L.push(`            ${(id + ",").padEnd(8)} -- ${n}`);
    L.push("        },");
    L.push("        specs = {},");
    L.push("    },");
  }
  L.push("}");
  L.push("");
  fs.writeFileSync(OUT, L.join("\r\n"), "utf8");
  console.log("families", families.length, "ids", families.reduce((a, f) => a + f.length, 0), "->", OUT, fs.statSync(OUT).size, "bytes");

}

main().catch(e => { console.error(e.message); process.exitCode = 1; });
