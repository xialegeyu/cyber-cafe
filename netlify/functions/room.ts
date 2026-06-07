import { getStore } from "@netlify/blobs";
import type { Config, Context } from "@netlify/functions";

type Occupant = {
  client_id: string;
  seat_id: string;
  cat_id: string;
  name: string;
  updated_at: number;
};

type RoomState = {
  occupants: Record<string, Occupant>;
  updated_at: number;
};

const STALE_AFTER_MS = 90_000;
const STORE_NAME = "neko-cafe-rooms";

const jsonHeaders = {
  "Content-Type": "application/json",
  "Cache-Control": "no-store",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "Content-Type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

function response(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: jsonHeaders,
  });
}

function normalizeRoom(raw: string | null) {
  const room = (raw || "default").toLowerCase().replace(/[^a-z0-9_-]/g, "").slice(0, 48);
  return room || "default";
}

function prune(state: RoomState, now: number) {
  const occupants: Record<string, Occupant> = {};

  for (const [seatId, occupant] of Object.entries(state.occupants || {})) {
    if (now - occupant.updated_at <= STALE_AFTER_MS) {
      occupants[seatId] = occupant;
    }
  }

  return {
    occupants,
    updated_at: now,
  };
}

async function readRoom(room: string) {
  const store = getStore({ name: STORE_NAME, consistency: "strong" });
  const state = (await store.get(room, { type: "json" })) as RoomState | null;
  const now = Date.now();
  const pruned = prune(state || { occupants: {}, updated_at: now }, now);

  if (JSON.stringify(pruned) !== JSON.stringify(state)) {
    await store.setJSON(room, pruned);
  }

  return { store, state: pruned };
}

export default async (req: Request, context: Context) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: jsonHeaders });
  }

  const url = new URL(req.url);
  const room = normalizeRoom(url.searchParams.get("room"));

  if (req.method === "GET") {
    const { state } = await readRoom(room);
    return response({ room, ...state });
  }

  if (req.method !== "POST") {
    return response({ error: "Method not allowed" }, 405);
  }

  const body = await req.json().catch(() => ({}));
  const clientId = String(body.client_id || "").slice(0, 80);
  const action = String(body.action || "sit");
  const seatId = String(body.seat_id || "").slice(0, 40);
  const now = Date.now();

  if (!clientId) {
    return response({ error: "client_id is required" }, 400);
  }

  const { store, state } = await readRoom(room);

  for (const [id, occupant] of Object.entries(state.occupants)) {
    if (occupant.client_id === clientId && (action === "leave" || id !== seatId)) {
      delete state.occupants[id];
    }
  }

  if (action === "leave") {
    state.updated_at = now;
    await store.setJSON(room, state);
    return response({ room, ...state });
  }

  if (!seatId) {
    return response({ error: "seat_id is required" }, 400);
  }

  const existing = state.occupants[seatId];
  if (existing && existing.client_id !== clientId && now - existing.updated_at <= STALE_AFTER_MS) {
    return response({ error: "seat occupied", room, ...state }, 409);
  }

  state.occupants[seatId] = {
    client_id: clientId,
    seat_id: seatId,
    cat_id: String(body.cat_id || "calico").slice(0, 40),
    name: String(body.name || "Guest cat").slice(0, 32),
    updated_at: now,
  };
  state.updated_at = now;

  await store.setJSON(room, state);
  return response({ room, ...state });
};

export const config: Config = {
  method: ["GET", "POST", "OPTIONS"],
};
