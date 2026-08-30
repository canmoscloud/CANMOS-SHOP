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
    console.error("Webhook signature verification failed:", err.message);
    return new Response(`Webhook Error: ${err.message}`, { status: 400 });
  }

  try {
    if (event.type === "payment_intent.succeeded") {
      const pi = event.data.object as Stripe.PaymentIntent;
      const vendaId = pi.metadata?.venda_id;
      const empresaId = pi.metadata?.empresa_id;
      const usuarioId = pi.metadata?.usuario_id;

      if (!vendaId || !empresaId) {
        console.error("Missing metadata in payment_intent.succeeded:", pi.id);
        return new Response(JSON.stringify({ received: true, skipped: true }), {
          headers: { "Content-Type": "application/json" },
          status: 200,
        });
      }

      // Idempotência: o Stripe reenvia eventos — se já processado, não repete
      const { data: pagamentoAtual } = await supabase
        .from("pagamentos")
        .select("id, status")
        .eq("stripe_payment_intent_id", pi.id)
        .limit(1)
        .maybeSingle();

      if (pagamentoAtual?.status === "aprovado") {
        return new Response(JSON.stringify({ received: true, alreadyProcessed: true }), {
          headers: { "Content-Type": "application/json" },
          status: 200,
        });
      }

      const { error: updatePaymentError } = await supabase
        .from("pagamentos")
        .update({ status: "aprovado", processado_em: new Date().toISOString() })
        .eq("stripe_payment_intent_id", pi.id);

      if (updatePaymentError) {
        console.error("Error updating payment:", updatePaymentError.message);
        throw updatePaymentError;
      }

      const { error: updateVendaError } = await supabase
        .from("vendas")
        .update({ status: "confirmada" })
        .eq("id", vendaId);

      if (updateVendaError) {
        console.error("Error updating venda:", updateVendaError.message);
        throw updateVendaError;
      }

      const { error: logError } = await supabase.from("logs").insert({
        empresa_id: empresaId,
        usuario_id: usuarioId,
        acao: "pagamento_aprovado",
        entidade: "vendas",
        entidade_id: vendaId,
        detalhes: { stripe_payment_intent_id: pi.id, valor: pi.amount / 100 },
      });

      if (logError) {
        console.error("Error inserting log:", logError.message);
      }
    }

    if (event.type === "payment_intent.payment_failed") {
      const pi = event.data.object as Stripe.PaymentIntent;
      const vendaId = pi.metadata?.venda_id;
      const empresaId = pi.metadata?.empresa_id;
      const usuarioId = pi.metadata?.usuario_id;

      if (!vendaId || !empresaId) {
        console.error("Missing metadata in payment_intent.payment_failed:", pi.id);
        return new Response(JSON.stringify({ received: true, skipped: true }), {
          headers: { "Content-Type": "application/json" },
          status: 200,
        });
      }

      // Marca só o pagamento como recusado (se ainda pendente). A venda
      // permanece 'pendente': uma recusa de cartão é recuperável — o cliente
      // pode tentar outro cartão ou outra forma de pagamento.
      const { error: updatePaymentError } = await supabase
        .from("pagamentos")
        .update({ status: "recusado" })
        .eq("stripe_payment_intent_id", pi.id)
        .eq("status", "pendente");

      if (updatePaymentError) {
        console.error("Error updating payment:", updatePaymentError.message);
        throw updatePaymentError;
      }

      const { error: logError } = await supabase.from("logs").insert({
        empresa_id: empresaId,
        usuario_id: usuarioId,
        acao: "pagamento_recusado",
        entidade: "vendas",
        entidade_id: vendaId,
        detalhes: { stripe_payment_intent_id: pi.id, error: pi.last_payment_error?.message },
      });

      if (logError) {
        console.error("Error inserting log:", logError.message);
      }
    }

    // Handle subscription events
    if (event.type === "customer.subscription.created" || event.type === "customer.subscription.updated") {
      const subscription = event.data.object as Stripe.Subscription;
      const empresaId = subscription.metadata?.empresa_id;

      if (!empresaId) {
        console.error("Missing empresa_id in subscription metadata:", subscription.id);
        return new Response(JSON.stringify({ received: true, skipped: true }), {
          headers: { "Content-Type": "application/json" },
          status: 200,
        });
      }

      const status = subscription.status === "active" ? "active" :
                     subscription.status === "canceled" ? "canceled" :
                     subscription.status === "past_due" ? "past_due" : "active";

      // Find the Premium plan
      const { data: premiumPlan, error: planError } = await supabase
        .from("planos")
        .select("id")
        .eq("nome", "Premium")
        .single();

      if (planError || !premiumPlan) {
        console.error("Premium plan not found:", planError?.message);
        throw new Error("Premium plan not found");
      }

      // Update or insert assinatura (maybeSingle: não quebra se houver
      // duplicatas ou nenhuma ativa)
      const { data: existing } = await supabase
        .from("assinaturas")
        .select("id")
        .eq("empresa_id", empresaId)
        .eq("status", "active")
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      if (existing) {
        const { error } = await supabase
          .from("assinaturas")
          .update({
            plano_id: premiumPlan.id,
            stripe_subscription_id: subscription.id,
            status,
            fim_periodo: new Date(subscription.current_period_end * 1000).toISOString(),
          })
          .eq("id", existing.id);

        if (error) {
          console.error("Error updating assinatura:", error.message);
          throw error;
        }
      } else {
        const { error } = await supabase.from("assinaturas").insert({
          empresa_id: empresaId,
          plano_id: premiumPlan.id,
          stripe_subscription_id: subscription.id,
          status,
          fim_periodo: new Date(subscription.current_period_end * 1000).toISOString(),
        });

        if (error) {
          console.error("Error inserting assinatura:", error.message);
          throw error;
        }
      }

      const { error: logError } = await supabase.from("logs").insert({
        empresa_id: empresaId,
        acao: "assinatura_atualizada",
        entidade: "assinaturas",
        detalhes: { stripe_subscription_id: subscription.id, status },
      });

      if (logError) {
        console.error("Error inserting log:", logError.message);
      }
    }

    if (event.type === "customer.subscription.deleted") {
      const subscription = event.data.object as Stripe.Subscription;
      const empresaId = subscription.metadata?.empresa_id;

      if (!empresaId) {
        console.error("Missing empresa_id in subscription metadata:", subscription.id);
        return new Response(JSON.stringify({ received: true, skipped: true }), {
          headers: { "Content-Type": "application/json" },
          status: 200,
        });
      }

      const { error: cancelError } = await supabase
        .from("assinaturas")
        .update({ status: "canceled" })
        .eq("stripe_subscription_id", subscription.id);

      if (cancelError) {
        console.error("Error canceling assinatura:", cancelError.message);
        throw cancelError;
      }

      // Downgrade to Free plan — só se não houver outra assinatura ativa
      // (evita duplicatas quando o Stripe reenvia o evento)
      const { data: ativaExistente } = await supabase
        .from("assinaturas")
        .select("id")
        .eq("empresa_id", empresaId)
        .eq("status", "active")
        .limit(1)
        .maybeSingle();

      if (!ativaExistente) {
        const { data: freePlan } = await supabase
          .from("planos")
          .select("id")
          .eq("nome", "Free")
          .single();

        if (freePlan) {
          const { error } = await supabase.from("assinaturas").insert({
            empresa_id: empresaId,
            plano_id: freePlan.id,
            status: "active",
          });

          if (error) {
            console.error("Error inserting free assinatura:", error.message);
            throw error;
          }
        }
      }

      const { error: logError } = await supabase.from("logs").insert({
        empresa_id: empresaId,
        acao: "assinatura_cancelada",
        entidade: "assinaturas",
        detalhes: { stripe_subscription_id: subscription.id },
      });

      if (logError) {
        console.error("Error inserting log:", logError.message);
      }
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err) {
    console.error("Stripe webhook error:", err.message);
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});
