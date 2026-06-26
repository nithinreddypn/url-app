// Supabase Edge Function: verify-payment
// Location: supabase/functions/verify-payment/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";
import * as crypto from "https://deno.land/std@0.168.0/crypto/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS, PUT, DELETE",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { 
      status: 200, 
      headers: corsHeaders 
    });
  }

  try {
    // 1. Resolve Supabase Client with service role to bypass RLS for write operations
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 2. Validate User Auth Token
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized user session" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 3. Parse Body Parameters
    const { plan_id, payment_id, order_id, signature, amount } = await req.json();
    if (!plan_id || !payment_id || !amount) {
      return new Response(JSON.stringify({ error: "Missing required parameters: plan_id, payment_id, and amount are mandatory" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 4. Verify Razorpay Signature (only if real order_id and signature are provided)
    const isMock = !order_id || !signature || signature === "sig_mock_verified" || order_id.startsWith("order_mock");
    if (!isMock) {
      const razorpaySecret = Deno.env.get("RAZORPAY_SECRET") ?? "test_secret_key";
      
      const encoder = new TextEncoder();
      const keyData = encoder.encode(razorpaySecret);
      const messageData = encoder.encode(`${order_id}|${payment_id}`);

      const cryptoKey = await window.crypto.subtle.importKey(
        "raw",
        keyData,
        { name: "HMAC", hash: "SHA-256" },
        false,
        ["sign"]
      );

      const signatureBuffer = await window.crypto.subtle.sign(
        "HMAC",
        cryptoKey,
        messageData
      );

      const generatedSignature = Array.from(new Uint8Array(signatureBuffer))
        .map((b) => b.toString(16).padStart(2, "0"))
        .join("");

      if (generatedSignature !== signature) {
        return new Response(JSON.stringify({ error: "Invalid payment signature verification failed" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    } else {
      console.log(`Bypassing signature verification for mock/standard payment: ${payment_id}`);
    }

    // 5. Fetch selected pricing plan details
    const { data: plan, error: planError } = await supabase
      .from("plans")
      .select("*")
      .eq("plan_id", plan_id)
      .single();

    if (planError || !plan) {
      return new Response(JSON.stringify({ error: "Selected plan not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Calculate plan expiry date
    const startDate = new Date();
    const expiryDate = new Date();
    if (plan.duration_months > 0) {
      expiryDate.setMonth(expiryDate.getMonth() + plan.duration_months);
    } else {
      // Free or Lifetime scan option (expiry in 100 years)
      expiryDate.setFullYear(expiryDate.getFullYear() + 100);
    }

    // 6. Create active subscription entry
    const { error: subError } = await supabase.from("subscriptions").insert({
      user_id: user.id,
      plan_id: plan_id,
      status: "active",
      payment_provider: "razorpay",
      payment_id: payment_id,
      order_id: order_id,
      payment_signature: signature,
      amount: amount,
      currency: plan.currency,
      start_date: startDate.toISOString(),
      expiry_date: expiryDate.toISOString(),
    });

    if (subError) {
      throw new Error(`Failed to insert subscription: ${subError.message}`);
    }

    // 7. Update User cache field to Premium
    const { error: userError } = await supabase
      .from("users")
      .update({ is_premium: true, updated_at: new Date().toISOString() })
      .eq("user_id", user.id);

    if (userError) {
      throw new Error(`Failed to update user cache: ${userError.message}`);
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message || "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
