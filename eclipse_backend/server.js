const express = require("express");
const { getDecision } = require("./aiService");
const { validateDecision } = require("./validator");
const app = express();

process.on("unhandledRejection", (reason) => {
  console.error("!!! UNHANDLED REJECTION !!!:", reason);
});
process.on("uncaughtException", (err) => {
  console.error("!!! UNCAUGHT EXCEPTION !!!:", err);
});

app.use(express.json());

const PORT = 3000;

app.post("/game-state", (req, res) => {
  const gameState = req.body;
  console.log("--- GameState received ---");
  console.log("Player:", gameState?.player);
  console.log("Siege:", gameState?.siege);
  res.json({ status: "received", message: "GameState received" });
});

app.get("/health", (req, res) => {
  res.json({ status: "ok" });
});


const HOSTILE_TYPES = ["zombie_a", "zombie_b", "mutan"];
const CIVILIAN_TYPES = ["worker", "woman"];

// Ne fait jamais confiance au modèle pour ce champ critique : on l'impose
// nous-mêmes selon le type, quoi que le modèle ait mis (ou oublié).
function enforceFaction(decision) {
  if (decision.action !== "spawn" && decision.action !== "spawn_group") return decision;

  decision.params = decision.params || {};

  if (CIVILIAN_TYPES.includes(decision.type)) {
    delete decision.params.enemy_groups; // un civil ne doit jamais se battre
  } else if (HOSTILE_TYPES.includes(decision.type)) {
    decision.params.enemy_groups = ["F_BASE"];
  } else {
    decision.params.enemy_groups = ["F_HORDE"];
  }

  return decision;
}

app.post("/ai/decision", async (req, res) => {
  const gameState = req.body;

  console.log("--- AI decision requested ---");
  console.log("Input:", gameState);

  try {
    const decisions = await getDecision(gameState);
    console.log("Decisions (brutes, avant validation):", decisions);

    const enforced = decisions.map(enforceFaction);

    const accepted = [];
    // Compteur cumulatif : empêche le modèle de dépasser le quota en
    // enchaînant plusieurs spawn/spawn_group dans la même décision.
    let runningNpcCount = (gameState?.npcs || []).length;
    const usedIds = new Set((gameState?.npcs || []).map((n) => n.id));

    for (const decision of decisions) {
      const fakeState = {
        ...gameState,
        npcs: Array.from(usedIds).map((id) => ({ id })),
      };
      const verdict = validateDecision(decision, fakeState);

      if (!verdict.valid) {
        console.warn(`Decision REJETÉE — ${verdict.reason}`, decision);
        continue;
      }

      accepted.push(decision);

      if (decision.action === "spawn") {
        runningNpcCount += 1;
        usedIds.add(decision.npc_id);
      }
      if (decision.action === "spawn_group") {
        const size = decision.params?.number || 1;
        runningNpcCount += size;
        for (let i = 0; i < size; i++) {
          usedIds.add(`${decision.group_id}_${i}`);
        }
      }
      if (decision.action === "despawn") {
        usedIds.delete(decision.npc_id);
      }
    }

    console.log("Decisions ACCEPTÉES, envoyées à Godot:", accepted);
    res.json({ decisions: accepted.length > 0 ? accepted : [{ action: "no_action" }] });
  } catch (err) {
    console.error("aiService error:", err.message);
    res.status(500).json({ decisions: [{ action: "no_action" }] });
  }
});

app.listen(PORT, () => {
  console.log(`ECLIPSE backend listening on http://localhost:${PORT}`);
});