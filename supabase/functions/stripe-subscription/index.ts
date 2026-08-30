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

    const { action, price_id, empresa_id } = await req.json();
    if (!action || !empresa_id) throw new Error("Missing required fields");

    const usuario = await supabase
      .from("usuarios")
      .select("empresa_id, nome, email")
      .eq("id", user.id)
      .single();

    if (usuario.error) throw new Error("User not found");
    if (usuario.data.empresa_id !== empresa_id) throw new Error("Unauthorized for this company");

    // Get or create Stripe customer
    const { data: assinatura } = await supabase
      .from("assinaturas")
      .select("stripe_subscription_id")
      .eq("empresa_id", empresa_id)
      .eq("status", "active")
      .single();

    let customerId: string;

    // Check if company already has a Stripe customer via metadata
    const existingCustomers = await stripe.customers.list({
      email: usuario.data.email,
      limit: 1,
    });

    if (existingCustomers.data.length > 0) {
      customerId = existingCustomers.data[0].id;
    } else {
      const customer = await stripe.customers.create({
        email: usuario.data.email,
        name: `${usuario.data.nome} - ${empresa_id}`,
        metadata: {
          empresa_id,
          usuario_id: user.id,
        },
      });
      customerId = customer.id;
    }

    if (action === "create_checkout") {
      // Create a Checkout Session for subscription
      const session = await stripe.checkout.sessions.create({
        customer: customerId,
        payment_method_types: ["card"],
        mode: "subscription",
        line_items: [
          {
            price: price_id,
            quantity: 1,
          },
        ],
        metadata: {
          empresa_id,
          usuario_id: user.id,
        },
        // A metadata da sessão NÃO é copiada para a assinatura, e o
        // stripe-webhook lê subscription.metadata.empresa_id — sem isto,
        // nenhuma assinatura seria ativada.
        subscription_data: {
          metadata: {
            empresa_id,
            usuario_id: user.id,
          },
        },
        success_url: `${Deno.env.get("SITE_URL") || "http://localhost:3000"}/success?session_id={CHECKOUT_SESSION_ID}`,
        cancel_url: `${Deno.env.get("SITE_URL") || "http://localhost:3000"}/cancel`,
      });

      await supabase.from("logs").insert({
        empresa_id,
        usuario_id: user.id,
        acao: "checkout_criado",
        entidade: "assinaturas",
        detalhes: { session_id: session.id, price_id },
      });

      return new Response(
        JSON.stringify({ sessionId: session.id, url: session.url }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 },
      );
    }

    if (action === "create_portal") {
      // Create customer portal session for managing subscription
      const { data: sub } = await supabase
        .from("assinaturas")
        .select("stripe_subscription_id")
        .eq("empresa_id", empresa_id)
        .eq("status", "active")
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      if (!sub?.stripe_subscription_id) {
        throw new Error("No active subscription found");
      }

      const portalSession = await stripe.billingPortal.sessions.create({
        customer: customerId,
        return_url: `${Deno.env.get("SITE_URL") || "http://localhost:3000"}/profile`,
      });

      return new Response(
        JSON.stringify({ url: portalSession.url }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 },
      );
    }

    throw new Error("Invalid action");
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 },
    );
  }
});
