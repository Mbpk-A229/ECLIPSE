// ECLIPSE — validator.js
// "Le LLM propose, ton moteur dispose." — on ne fait confiance à AUCUNE
// décision venant du modèle avant de l'avoir vérifiée ici.

const MAX_ACTIVE_NPCS = 30; // quota fixé dans le README ECLIPSE
const MAX_GROUP_SIZE = 10;

const VALID_NPC_TYPES = [
  "worker", "soldier", "woman", "marie", "aure",
  "rosales", "arissa", "bryce", "zombie_a", "robot", "mutan",
];

function isValidPosition(position) {
  return (
    Array.isArray(position) &&
    position.length === 3 &&
    position.every((n) => typeof n === "number" && Number.isFinite(n))
  );
}

function knownNpcIds(gameState) {
  const npcs = gameState?.npcs || [];
  return new Set(npcs.map((npc) => npc.id));
}

// gameState.npcs peut être un tableau réel OU un tableau "factice" de la
// bonne longueur (utilisé par server.js pour suivre un quota qui évolue au
// fil de plusieurs actions dans une même décision) — on ne s'appuie donc que
// sur .length ici pour le quota, jamais sur le contenu des éléments.
function validateDecision(decision, gameState) {
  if (!decision || typeof decision.action !== "string") {
    return { valid: false, reason: "decision malformée ou action manquante" };
  }

  switch (decision.action) {
    case "no_action":
      return { valid: true };

    case "spawn": {
      const currentCount = (gameState?.npcs || []).length;
      if (currentCount >= MAX_ACTIVE_NPCS) {
        return { valid: false, reason: `quota dépassé (${currentCount}/${MAX_ACTIVE_NPCS} PNJ actifs)` };
      }
      if (!VALID_NPC_TYPES.includes(decision.type)) {
        return { valid: false, reason: `type de PNJ invalide: '${decision.type}'` };
      }
      if (typeof decision.npc_id !== "string" || decision.npc_id.trim() === "") {
        return { valid: false, reason: "npc_id manquant ou vide" };
      }
      if (decision.npc_id === "player" || decision.npc_id === "Player") {
        return { valid: false, reason: "npc_id ne peut pas être 'player'" };
      }
      if (knownNpcIds(gameState).has(decision.npc_id)) {
        return { valid: false, reason: `npc_id '${decision.npc_id}' déjà utilisé` };
      }
      if (!isValidPosition(decision.position)) {
        return { valid: false, reason: "position invalide, doit être [x, y, z] numérique" };
      }
      if (decision.params && typeof decision.params !== "object") {
        return { valid: false, reason: "params doit être un objet" };
      }
      if (decision.params?.enemy_groups?.includes("player")) {
        return { valid: false, reason: "enemy_groups ne doit jamais contenir 'player'" };
      }
      return { valid: true };
    }

    case "spawn_group": {
      const currentCount = (gameState?.npcs || []).length;
      const groupSize = decision.params?.number || 1;

      if (!Number.isInteger(groupSize) || groupSize < 1 || groupSize > MAX_GROUP_SIZE) {
        return { valid: false, reason: `taille de groupe invalide: ${groupSize} (1 à ${MAX_GROUP_SIZE})` };
      }
      if (currentCount + groupSize > MAX_ACTIVE_NPCS) {
        return { valid: false, reason: `spawn_group dépasserait le quota (${currentCount}+${groupSize} > ${MAX_ACTIVE_NPCS})` };
      }
      if (!VALID_NPC_TYPES.includes(decision.type)) {
        return { valid: false, reason: `type de PNJ invalide: '${decision.type}'` };
      }
      if (typeof decision.group_id !== "string" || decision.group_id.trim() === "") {
        return { valid: false, reason: "group_id manquant" };
      }
      if (!isValidPosition(decision.position)) {
        return { valid: false, reason: "position invalide" };
      }
      return { valid: true };
    }

    case "configure": {
      if (typeof decision.npc_id !== "string" || decision.npc_id.trim() === "") {
        return { valid: false, reason: "npc_id manquant ou vide" };
      }
      if (!knownNpcIds(gameState).has(decision.npc_id)) {
        return { valid: false, reason: `configure refusé — npc_id '${decision.npc_id}' inconnu` };
      }
      if (!decision.params || typeof decision.params !== "object") {
        return { valid: false, reason: "params manquant ou invalide" };
      }
      if (decision.params?.enemy_groups?.includes("player")) {
        return { valid: false, reason: "enemy_groups ne doit jamais contenir 'player'" };
      }
      return { valid: true };
    }

    case "despawn": {
      if (typeof decision.npc_id !== "string" || decision.npc_id.trim() === "") {
        return { valid: false, reason: "npc_id manquant ou vide" };
      }
      if (!knownNpcIds(gameState).has(decision.npc_id)) {
        return { valid: false, reason: `despawn refusé — npc_id '${decision.npc_id}' inconnu` };
      }
      return { valid: true };
    }

    default:
      return { valid: false, reason: `action inconnue: '${decision.action}'` };
  }
}

module.exports = { validateDecision, MAX_ACTIVE_NPCS, MAX_GROUP_SIZE };