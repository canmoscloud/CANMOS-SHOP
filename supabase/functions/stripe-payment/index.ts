import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0?target=deno";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2024-11-20.acacia",
  httpClient: Stripe.createFetchHttpClient(),
});

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceKey);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) throw new Error("Missing Authorization header");

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) throw new Error("Unauthorized");

    const { venda_id, valor, metodo } = await req.json();
    if (!venda_id || !valor || !metodo) throw new Error("Missing required fields");

    const usuario = await supabase
      .from("usuarios")
      .select("empresa_id, nome")
      .eq("id", user.id)
      .single();

    if (usuario.error) throw new Error("User not found");

    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(valor * 100),
      currency: "brl",
      payment_method_types: metodo === "cartao_credito" ? ["card"] : ["card"],
      metadata: {
        venda_id,
        empresa_id: usuario.data.empresa_id,
        usuario_id: user.id,
        operador: usuario.data.nome,
      },
    });

    await supabase.from("pagamentos").insert({
      venda_id,
      forma_pagamento: metodo,
      valor,
      status: "pendente",
      stripe_payment_intent_id: paymentIntent.id,
    });

    await supabase.from("logs").insert({
      empresa_id: usuario.data.empresa_id,
      usuario_id: user.id,
      acao: "pagamento_iniciado",
      entidade: "vendas",
      entidade_id: venda_id,
      detalhes: { metodo, valor, stripe_payment_intent_id: paymentIntent.id },
    });

    return new Response(
      JSON.stringify({
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 },
    );
  }
});
