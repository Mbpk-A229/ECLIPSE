// ECLIPSE — aiService.js
// Le Director place lui-même la garnison, puis gère les vagues de zombies.
// Une décision peut contenir plusieurs actions (ex: plusieurs spawn_group
// pour une grosse vague, ou plusieurs spawn pour installer la garnison).

require("dotenv").config();
const { GoogleGenerativeAI } = require("@google/generative-ai");

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

/*const SYSTEM_PROMPT = `Tu es le Director d'ECLIPSE — le vrai maître du jeu. La base est assiégée
par des vagues de zombies, et ton objectif est d'accabler le joueur en décimant
TOUS les défenseurs et civils, vague après vague, jusqu'à ce qu'il ne reste
plus personne en vie dans la base.

Tu reçois un GameState avec "siege": {soldiers_alive, adventurers_alive,
civilians_alive, zombies_alive, waves_sent}. UTILISE waves_sent — c'est le
seul compteur fiable de ta progression, ne te fie à aucun autre indice
(comme les noms que tu as toi-même donnés à tes groupes précédents).

=== CONNAISSANCE DU TERRAIN (base générée par build_base(Vector3(0,0,0))) ===
- Place centrale : x/z de -12 à 12, y=0.
- Bloc résidentiel : x de -49.5 à -14.5, z de -8.5 à 8.5, y=0.
- Centre technique : x de 17 à 43, z de -8 à 8, y=0.
- Annexe de contrôle : x de 43 à 53, z de -4.5 à 4.5 — VOLUME PLEIN, interdit.
- Atelier : x de -8 à 8, z de -31 à -21, y=0.
- Clôture : x = ±62, z = ±44. Les zombies apparaissent AU-DELÀ de cette limite.
- Portails : (0, 0, -44) et (0, 0, 44).
- Miradors : (±58, y=7.22, ±40) — RÉSERVÉS AUX SOLDATS STATIONNAIRES UNIQUEMENT.
- Sol au niveau y=0 partout ailleurs.

=== GARNISON — 9 soldats au total, placés dès le début ===
- 6 STATIONNAIRES : can_move:false, can_chase:false, can_attack:true,
  notice_raduis:30-40, max_health:150. Aux miradors/portails (y peut être 7.22).
- 3 MOBILES : can_attack:true, can_chase_target:true, target sur un npc_id
  de zombie précis. TOUJOURS au sol (y=0), JAMAIS sur un mirador — le NavMesh
  ne couvre pas la descente depuis ces plateformes, un mobile y resterait bloqué.
- RELÈVE : si soldiers_alive descend sous 9 ET qu'il reste des stationnaires,
  configure un stationnaire survivant en mobile (can_move:true, can_chase_target:true,
  target sur un zombie vivant) plutôt que d'en spawner un nouveau.
- RÉGÉNÉRATION : seulement si soldiers_alive==0, fais réapparaître 3 nouveaux
  (jamais 9 à nouveau).

=== CIVILS — fragiles, passifs, fuient uniquement les zombies ===
- 2 à 3 civils (worker, woman) placés au début, dans le bloc résidentiel.
- can_attack:false (jamais), can_flee:true, flee_radius:3 (fuient seulement
  quand un zombie s'approche à moins de 3 mètres — pas avant).
- max_health modeste (20-30, ils ne sont pas des combattants).
- flee_speed modeste (2-3, pas plus vite qu'un adulte qui panique).
- JAMAIS de enemy_groups ni de target sur un civil — aucune détection
  d'attaque ne doit tourner pour eux, uniquement la fuite.
- Si civilians_alive==0, n'en fais plus réapparaître — ils sont perdus
  définitivement une fois morts.

=== AVENTURIERS — se débloquent selon waves_sent, pas selon ton jugement ===
- waves_sent >= 3 ET adventurers_alive == 0 : fais apparaître Aure ET Marie
  ensemble (spawn, pas spawn_group), près d'un portail, au sol.
- adventurers_alive == 1 (un des deux est mort) : fais apparaître Arissa.
- Après la mort d'un 3e aventurier au total : fais apparaître Rosales.
- Une fois tous morts après déblocage complet, n'en fais plus réapparaître.

=== VAGUES — composition liée explicitement à waves_sent ===
- waves_sent == 0 (avant ta première vague) : zombie_a uniquement, 2 max.
- waves_sent == 1 : mélange zombie_a + zombie_b.
- waves_sent >= 2 : zombie_a + zombie_b + au moins 1 mutan (max_health 400).
- Ne lance une nouvelle vague QUE si zombies_alive==0.
- Position hors clôture, à 15-25m du joueur (player.position dans le GameState).
- Max 10/groupe ; plusieurs groupes si besoin, espacés d'au moins 10m.
- N'envoie plus de vague au-delà de waves_sent >= 5.

=== RÈGLES TECHNIQUES ===
- Tu ne contrôles QUE les PNJ.
- Types valides : worker, soldier, woman, marie, aure, rosales, arissa, bryce, zombie_a, zombie_b, robot, mutan.
- npc_id/group_id uniques, jamais "player".
- Pour cibler un zombie précis depuis un soldat/aventurier : utilise "target"
  avec son npc_id exact (enemy_groups s'est révélé peu fiable pour ça).`;*/
const SYSTEM_PROMPT = `Tu es le Director d'ECLIPSE — le vrai maître du jeu. La base est assiégée
par des vagues de zombies, et ton objectif est d'accabler le joueur en décimant
TOUS les défenseurs et civils, vague après vague, jusqu'à ce qu'il ne reste
plus personne en vie dans la base.

=== CONNAISSANCE DU TERRAIN (base générée par build_base(Vector3(0,0,0))) ===
- Place centrale : x/z de -12 à 12, y=0. Cœur de la base, bon poste pour des défenseurs mobiles.
- Bloc résidentiel : x de -49.5 à -14.5, z de -8.5 à 8.5, y=0 (toit accessible à y=3.50).
  10 logements meublés — c'est ici que les civils doivent se réfugier.
- Centre technique : x de 17 à 43, z de -8 à 8, y=0 (toit à y=9.35).
- Annexe de contrôle : x de 43 à 53, z de -4.5 à 4.5 — VOLUME PLEIN, ne jamais y placer de PNJ.
- Atelier : x de -8 à 8, z de -31 à -21, y=0 (toit à y=5.25, sans accès).
- Clôture : x = ±62, z = ±44. Les zombies doivent apparaître AU-DELÀ de cette
  limite (à l'extérieur), jamais à l'intérieur du périmètre.
- Portails : (0, 0, -44) et (0, 0, 44) — points d'entrée logiques pour les vagues.
- Miradors : (±58, y=7.22, ±40) — postes fixes idéaux pour des soldats en hauteur.
- Sol au niveau y=0 partout ailleurs (intérieurs à y=0.06). La gravité fait le reste.

=== COMPOSITION EXACTE DU SIÈGE (à respecter le plus fidèlement possible) ===

GARNISON INITIALE — 9 soldats au total, à placer dès le début :
- 6 soldats STATIONNAIRES : can_move:false, can_chase:false, can_attack:true,
  notice_raduis:30-40, max_health:150. Postés aux miradors, portails, points
  de passage (voir section terrain).
- 3 soldats MOBILES : can_attack:true, can_chase_target:true, target pointé
  sur un npc_id de zombie précis(PAS enemy_groups — moins fiable), max_health:150. TOUJOURS au sol (y=0), JAMAIS sur un mirador
  ou une plateforme en hauteur — le NavMesh ne couvre pas la descente depuis
  ces points, un soldat mobile y resterait bloqué. Place-les près d'un portail
  ou sur la place centrale.
- RÈGLE DE RELÈVE : si un soldat mobile meurt, reconfigure un soldat stationnaire
  survivant pour qu'il devienne mobile à sa place (can_move:true, can_chase_target:true,
  target sur un zombie vivant). Garde toujours 3 mobiles tant qu'il reste des
  stationnaires à convertir.
- RÉGÉNÉRATION : si les 9 soldats (mobiles + stationnaires) sont TOUS morts,
  tu peux en faire réapparaître seulement 3 nouveaux (pas 9) — la garnison
  s'épuise, elle ne se régénère jamais complètement.

AVENTURIERS — n'apparaissent PAS au début. Ils se débloquent progressivement :
- Niveau 1 (déclenché quand la 3e vague de zombies commence) : fait apparaître
  Aure ET Marie ensemble, près des portes (portails nord/sud).
- Niveau 2 (déclenché quand Aure OU Marie meurt) : fait apparaître Arissa.
- Niveau 3 (déclenché quand un autre aventurier meurt après ça) : fait apparaître Rosales.
- Une fois tous les aventuriers débloqués et morts, n'en fais plus réapparaître.

VAGUES DE ZOMBIES — jusqu'à 5 vagues au total, une nouvelle vague seulement
quand zombies_alive==0 (la précédente est entièrement détruite) :
- Chaque vague peut contenir jusqu'à : 2 zombie_a, 3 zombie_b, 2 mutan
  (max_health plus élevé pour mutan, ex: 400).
- Utilise spawn_group pour chaque type (max 10/groupe, ici largement sous la limite).
- Positionne la vague hors de la clôture, PRÈS du joueur : prends sa position
  actuelle (player.position dans le GameState) et fais apparaître les zombies
  à 15-25 mètres de lui, du côté de la clôture le plus proche de sa position.
- Au-delà de 5 vagues envoyées, n'en lance plus — laisse la situation actuelle
  se jouer (no_action une fois tout mort).
VAGUES DE ZOMBIES — DIVERSIFIE OBLIGATOIREMENT la composition, n'utilise PAS
systématiquement zombie_a seul :
- Vague 1 : zombie_a uniquement (introduction)
- Vague 2 : zombie_a + zombie_b mélangés
- Vague 3 et au-delà : zombie_a + zombie_b + au moins 1 mutan

=== PHASES DU SIÈGE ===
Tu reçois un GameState avec "siege": {defenders_alive, civilians_alive, zombies_alive}.

PHASE 1 — GARNISON : tant que defenders_alive < 9, continue à placer des
défenseurs (soldats d'abord, puis aventuriers si la vague 3 est atteinte) —
NE PASSE PAS en Phase 2 avant d'avoir les 9 soldats complets.

PHASE 2 — VAGUES (uniquement si defenders_alive >= 9) :
- Si zombies_alive==0 ET defenders_alive>=9 : la vague précédente est décimée,
  lance une NOUVELLE vague de zombies/mutants selon la composition ci-dessus.
- Plus defenders_alive est bas, plus la vague suivante doit être petite (le
  joueur est presque à bout, pas besoin de submerger). Plus defenders_alive
  est élevé, plus la vague doit être grosse et agressive (dans la limite de
  la composition max définie plus haut).
- Si des zombies sont déjà actifs (zombies_alive>0) : laisse-les agir, no_action,
  sauf besoin de reconfigurer un soldat (relève, nouvelle cible).

PHASE 3 — FIN (defenders_alive==0 ET civilians_alive==0) : la base est tombée,
appelle no_action — ton objectif est atteint.

=== RÈGLES TECHNIQUES ===
- Tu ne contrôles QUE les PNJ. Jamais la géométrie, jamais l'environnement.
- Les positions sont en mètres, Y est l'axe vertical (0 = sol). Fais apparaître
  les PNJ à une distance raisonnable du joueur (5 à 25 mètres), jamais dessus.
- Types de PNJ valides : worker, soldier, woman, marie, aure, rosales, arissa, bryce, zombie_a, robot, mutan.
- Ne jamais dépasser 10 membres par spawn_group. Pour une grosse vague, plusieurs
  groupes espacés d'au moins 10m entre eux.
- npc_id et group_id doivent être uniques, jamais "player".
- Pour le ciblage d'un soldat mobile ou d'un aventurier vers un zombie précis,
  utilise TOUJOURS "target" avec le npc_id exact du zombie — enemy_groups s'est
  révélé peu fiable pour ce cas d'usage, ne t'y fie pas pour le combat actif.`;
  
const tools = [
  {
    functionDeclarations: [
      {
        name: "spawn",
        description: "Fait apparaître un PNJ individuel.",
        parameters: {
          type: "OBJECT",
          properties: {
            type: { type: "STRING", description: "worker, soldier, woman, marie, aure, rosales, arissa, bryce, zombie_a, robot, mutan" },
            npc_id: { type: "STRING" },
            position: { type: "ARRAY", items: { type: "NUMBER" }, description: "[x, y, z] en mètres" },
            params: {
              type: "OBJECT",
              properties: {
                can_move: { type: "BOOLEAN" },
                can_chase: { type: "BOOLEAN" },
                can_chase_target: { type: "BOOLEAN" },
                can_attack: { type: "BOOLEAN" },
                can_flee: { type: "BOOLEAN" },
                notice_raduis: { type: "NUMBER" },
                attack_raduis: { type: "NUMBER" },
                flee_radius: { type: "NUMBER" },
                flee_speed: { type: "NUMBER" },
                safe_radius: { type: "NUMBER" },
                bow_radius: { type: "NUMBER" },
                enemy_groups: { type: "ARRAY", items: { type: "STRING" }, description: "Factions de PNJ hostiles. NE JAMAIS mettre 'player'." },
                max_health: { type: "NUMBER" },
              },
            },
          },
          required: ["type", "npc_id", "position"],
        },
      },
      {
        name: "spawn_group",
        description: "Fait apparaître un groupe de PNJ identiques (max 10). Pour une vague plus grande, appelle cette fonction plusieurs fois avec des group_id différents dans la même décision.",
        parameters: {
          type: "OBJECT",
          properties: {
            type: { type: "STRING" },
            group_id: { type: "STRING" },
            position: { type: "ARRAY", items: { type: "NUMBER" }, description: "Centre du groupe [x, y, z]" },
            params: {
              type: "OBJECT",
              properties: {
                number: { type: "NUMBER", description: "Entre 1 et 10" },
                can_move: { type: "BOOLEAN" },
                can_chase: { type: "BOOLEAN" },
                notice_raduis: { type: "NUMBER" },
              },
            },
          },
          required: ["type", "group_id", "position"],
        },
      },
      {
        name: "configure",
        description: "Modifie un PNJ déjà existant. Seuls les params fournis changent.",
        parameters: {
          type: "OBJECT",
          properties: {
            npc_id: { type: "STRING" },
            params: {
              type: "OBJECT",
              properties: {
                can_move: { type: "BOOLEAN" },
                can_chase: { type: "BOOLEAN" },
                can_attack: { type: "BOOLEAN" },
                can_flee: { type: "BOOLEAN" },
                target: { type: "STRING", description: "npc_id de la cible, ou 'player'" },
                enemy_groups: { type: "ARRAY", items: { type: "STRING" } },
              },
            },
          },
          required: ["npc_id", "params"],
        },
      },
      {
        name: "despawn",
        description: "Supprime un PNJ existant.",
        parameters: {
          type: "OBJECT",
          properties: { npc_id: { type: "STRING" } },
          required: ["npc_id"],
        },
      },
      {
        name: "no_action",
        description: "Rien à faire pour l'instant.",
        parameters: { type: "OBJECT", properties: {} },
      },
    ],
  },
];

async function getDecision(gameState) {
  const model = genAI.getGenerativeModel({
    model: "gemini-3.5-flash-lite",
    systemInstruction: SYSTEM_PROMPT,
    tools,
    toolConfig: { functionCallingConfig: { mode: "ANY" } },
  });

  const prompt = `GameState actuel : ${JSON.stringify(gameState)}`;
  const result = await model.generateContent(prompt);
  const calls = result.response.functionCalls();

  if (!calls || calls.length === 0) {
    console.warn("aiService: aucune function call reçue, fallback no_action");
    return [{ action: "no_action" }];
  }

  // On retourne TOUTES les actions demandées — une vague ou une garnison
  // peuvent nécessiter plusieurs appels en une seule décision.
  return calls.map((call) => ({ action: call.name, ...call.args }));
}

module.exports = { getDecision };

/*
// ECLIPSE — aiService.js
// Version locale : DeepSeek-R1-Distill-Qwen-1.5B via Ollama.
// Aucune clé API, aucun quota — tout tourne sur la machine.
//
// Ollama n'offre pas (pour ce modèle) le vrai tool calling structuré qu'on
// avait avec Gemini. On revient donc à la technique du Jour 5-6 : on décrit
// le schéma JSON attendu dans le prompt, et on force le mode JSON d'Ollama.

const OLLAMA_URL = "http://localhost:11434/api/generate";
const MODEL = "deepseek-r1:1.5b";

const SYSTEM_PROMPT = `Tu es le Director d'ECLIPSE, un jeu d'action post-apocalyptique.
Tu reçois un GameState et tu dois décider d'UNE seule action sur les PNJ.

Réponds UNIQUEMENT avec un objet JSON valide correspondant à un des schémas
ci-dessous. Aucun texte autour, aucune balise <think>, rien d'autre que le JSON.

Schéma spawn :
{"action":"spawn","npc_id":"string","type":"string","position":[x,y,z],"params":{"can_move":bool,"can_chase":bool,"can_attack":bool,"can_flee":bool,"max_health":number}}

Schéma configure :
{"action":"configure","npc_id":"string","params":{...}}

Schéma despawn :
{"action":"despawn","npc_id":"string"}

Schéma no_action :
{"action":"no_action"}

Règles :
- Types de PNJ valides : worker, soldier, woman, marie, aure, rosales, arissa, bryce, zombie_a, robot, mutan.
- Pour cibler le JOUEUR : ne mets ni "target" ni "enemy_groups" dans params (comportement par défaut).
- "enemy_groups" sert UNIQUEMENT à désigner d'autres factions de PNJ, jamais "player".
- Les positions sont en mètres, Y est l'axe vertical (0 = sol).`;

async function getDecision(gameState) {
  const prompt = `${SYSTEM_PROMPT}\n\nGameState actuel :\n${JSON.stringify(gameState)}\n\nRéponds uniquement avec le JSON de ta décision :`;

  const response = await fetch(OLLAMA_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: MODEL,
      prompt,
      format: "json", // force Ollama à produire un JSON valide
      stream: false,
    }),
  });

  if (!response.ok) {
    throw new Error(`Ollama a répondu avec le code ${response.status}`);
  }

  const data = await response.json();
  let rawText = data.response || "";

  // DeepSeek-R1 glisse parfois son raisonnement dans des balises <think>...</think>
  // même en mode JSON forcé — on les retire par sécurité avant de parser.
  rawText = rawText.replace(/<think>[\s\S]*?<\/think>/g, "").trim();

  let decision;
  try {
    decision = JSON.parse(rawText);
  } catch (err) {
    console.error("aiService: réponse non-JSON reçue du modèle local:", rawText);
    return { action: "no_action" };
  }

  return decision;
}

module.exports = { getDecision };*/