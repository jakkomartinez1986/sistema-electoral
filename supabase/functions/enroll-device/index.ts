// =============================================================================
//  Edge Function: enroll-device
// -----------------------------------------------------------------------------
//  Canjea un código de emparejamiento de un solo uso (creado por un admin vía
//  RPC create_enrollment_code) y entrega al dispositivo credenciales propias de
//  Supabase Auth. La secret key NUNCA sale del servidor.
//
//  Entrada (POST JSON):
//    { enrollment_code: string, device_uid: string, app_version?: string }
//  Salida:
//    { device_id, access_token, refresh_token, expires_at, user_id }
//  Errores: { error: <codigo> } con el status HTTP correspondiente.
// =============================================================================

import { createClient } from "npm:@supabase/supabase-js@2";

// En la plataforma hosted, Supabase inyecta las claves como diccionarios JSON
// con nombre en PLURAL (SUPABASE_PUBLISHABLE_KEYS / SUPABASE_SECRET_KEYS). Las
// singulares solo existen en self-hosted o si se exportan a mano; se aceptan
// como respaldo.
function resolveKey(pluralName: string, singularName: string): string {
  const plural = Deno.env.get(pluralName);
  if (plural) {
    try {
      const dict = JSON.parse(plural) as Record<string, string>;
      if (dict && typeof dict === "object" && dict.default) return dict.default;
    } catch {
      // Si no es JSON válido, se ignora y se prueba la forma singular.
    }
  }
  const single = Deno.env.get(singularName);
  if (single) return single;
  throw new Error(`Missing required secret: ${singularName}`);
}

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const PUBLISHABLE_KEY = resolveKey("SUPABASE_PUBLISHABLE_KEYS", "SUPABASE_PUBLISHABLE_KEY");
const SECRET_KEY = resolveKey("SUPABASE_SECRET_KEYS", "SUPABASE_SECRET_KEY");

const admin = createClient(SUPABASE_URL, SECRET_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(text),
  );
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  let payload: { enrollment_code?: string; device_uid?: string; app_version?: string };
  try {
    payload = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const { enrollment_code, device_uid, app_version } = payload;
  if (!enrollment_code || !device_uid) {
    return json({ error: "missing_fields" }, 400);
  }

  // 1. Buscar el código por su hash (nunca se guarda en claro).
  const { data: code } = await admin
    .from("device_enrollment_codes")
    .select("id, device_id, expires_at, used_at")
    .eq("code_hash", await sha256Hex(enrollment_code))
    .maybeSingle();

  if (!code) return json({ error: "invalid_code" }, 400);
  if (code.used_at) return json({ error: "code_used" }, 409);
  if (new Date(code.expires_at).getTime() < Date.now()) {
    return json({ error: "code_expired" }, 410);
  }

  // 2. Cargar y verificar el dispositivo.
  const { data: device } = await admin
    .from("voting_devices")
    .select("id, device_uid, auth_user_id, status")
    .eq("id", code.device_id)
    .maybeSingle();

  if (!device) return json({ error: "device_not_found" }, 404);
  if (device.device_uid !== device_uid) {
    return json({ error: "device_mismatch" }, 409);
  }

  // 3. Re-enrolamiento: liberar el usuario de Auth anterior del dispositivo.
  if (device.auth_user_id) {
    await admin.auth.admin.deleteUser(device.auth_user_id).catch(() => {});
  }

  // 4. Crear el usuario de Auth del dispositivo.
  const email = `device-${device.id}@devices.local`;
  const password = `${crypto.randomUUID()}${crypto.randomUUID()}`;
  const { data: created, error: createErr } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });
  if (createErr || !created.user) {
    return json({ error: "auth_user_creation_failed" }, 500);
  }

  // 5. Vincular el usuario al dispositivo y marcarlo autorizado.
  const { error: linkErr } = await admin
    .from("voting_devices")
    .update({
      auth_user_id: created.user.id,
      status: "authorized",
      app_version: app_version ?? null,
      last_seen_at: new Date().toISOString(),
    })
    .eq("id", device.id);
  if (linkErr) return json({ error: "device_link_failed" }, 500);

  // 6. Consumir el código.
  await admin
    .from("device_enrollment_codes")
    .update({ used_at: new Date().toISOString() })
    .eq("id", code.id);

  // 7. Iniciar sesión para obtener la sesión del dispositivo.
  const anon = createClient(SUPABASE_URL, PUBLISHABLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: signIn, error: signErr } = await anon.auth.signInWithPassword({
    email,
    password,
  });
  if (signErr || !signIn.session) {
    return json({ error: "session_grant_failed" }, 500);
  }

  // 8. Auditar (sin secretos).
  await admin.from("audit_logs").insert({
    action: "device_enrolled",
    target_type: "voting_device",
    target_id: device.id,
    detail: { app_version: app_version ?? null },
  });

  return json({
    device_id: device.id,
    user_id: created.user.id,
    access_token: signIn.session.access_token,
    refresh_token: signIn.session.refresh_token,
    expires_at: signIn.session.expires_at,
  });
});
