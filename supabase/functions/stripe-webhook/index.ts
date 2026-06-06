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

const endpointSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET")!;

serve(async (req) => {
  const signature = req.headers.get("stripe-signature");
  if (!signature) return new Response("Missing signature", { status: 400 });

  const body = await req.text();

  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(body, signature, endpointSecret);
  } catch (err) {
    return new Response(`Webhook Error: ${err.message}`, { status: 400 });
  }

  try {
    if (event.type === "payment_intent.succeeded") {
      const pi = event.data.object as Stripe.PaymentIntent;
      const vendaId = pi.metadata.venda_id;

      await supabase
        .from("pagamentos")
        .update({ status: "aprovado", processado_em: new Date().toISOString() })
        .eq("stripe_payment_intent_id", pi.id);

      await supabase
        .from("vendas")
        .update({ status: "confirmada" })
        .eq("id", vendaId);

      await supabase.from("logs").insert({
        empresa_id: pi.metadata.empresa_id,
        usuario_id: pi.metadata.usuario_id,
        acao: "pagamento_aprovado",
        entidade: "vendas",
        entidade_id: vendaId,
        detalhes: { stripe_payment_intent_id: pi.id, valor: pi.amount / 100 },
      });
    }

    if (event.type === "payment_intent.payment_failed") {
      const pi = event.data.object as Stripe.PaymentIntent;
      const vendaId = pi.metadata.venda_id;

      await supabase
        .from("pagamentos")
        .update({ status: "recusado" })
        .eq("stripe_payment_intent_id", pi.id);

      await supabase
        .from("vendas")
        .update({ status: "cancelada" })
        .eq("id", vendaId);
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});
