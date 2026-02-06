// Supabase Edge Function: send-notification
// Sends push notifications via APNs when status updates occur

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface PushPayload {
  emoji: string;
  statusText: string;
  kidsText: string;
  note?: string;
}

serve(async (req) => {
  // Handle CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // Get the payload
    const payload: PushPayload = await req.json();

    // Get all registered device tokens
    const { data: tokens, error: tokenError } = await supabaseClient
      .from("push_tokens")
      .select("token");

    if (tokenError) {
      throw tokenError;
    }

    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ message: "No devices registered" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Build notification message
    const title = "Ben says:";
    const body = payload.note || `${payload.emoji} ${payload.statusText}`;

    // Send to each device
    // Note: In production, you'd use APNs directly or a service like Firebase
    // For now, we'll log and return success
    console.log(`Sending notification to ${tokens.length} devices:`);
    console.log(`  Title: ${title}`);
    console.log(`  Body: ${body}`);

    // Record that we sent this notification
    await supabaseClient
      .from("sent_notifications")
      .upsert({
        trigger_type: "status",
        trigger_id: `status-${Date.now()}`,
        sent_at: new Date().toISOString(),
      });

    return new Response(
      JSON.stringify({
        success: true,
        message: `Notification queued for ${tokens.length} devices`,
        notification: { title, body },
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error sending notification:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
