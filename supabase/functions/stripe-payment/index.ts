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

    if (metodo !== "cartao_credito" && metodo !== "cartao_debito") {
      throw new Error(`Método inválido para esta função: ${metodo}`);
    }

    const valorNum = Number(valor);
    if (!Number.isFinite(valorNum) || valorNum <= 0) {
      throw new Error("Valor inválido");
    }

    const { data: usuario, error: usuarioError } = await supabase
      .from("usuarios")
      .select("empresa_id, nome")
      .eq("id", user.id)
      .single();

    if (usuarioError || !usuario) throw new Error("User not found");

    // Esta função roda com service_role e portanto ignora RLS: a checagem de
    // posse da venda tem de ser feita aqui, à mão.
    const { data: venda, error: vendaError } = await supabase
      .from("vendas")
      .select("id, empresa_id, valor_total, desconto, status")
      .eq("id", venda_id)
      .maybeSingle();

    if (vendaError) throw vendaError;
    if (!venda) throw new Error("Venda não encontrada");
    if (venda.empresa_id !== usuario.empresa_id) {
      throw new Error("Venda não pertence à sua empresa");
    }
    if (venda.status !== "pendente") {
      throw new Error(`Venda já está ${venda.status} e não aceita novo pagamento`);
    }

    // O valor cobrado não pode exceder o que falta pagar. Pendentes entram na
    // soma para reservar cartão/PIX em andamento e evitar cobrança dupla.
    const { data: pagamentosExistentes, error: pagError } = await supabase
      .from("pagamentos")
      .select("valor, status")
      .eq("venda_id", venda_id)
      .in("status", ["aprovado", "pendente"]);

    if (pagError) throw pagError;

    const liquido = Number(venda.valor_total) - Number(venda.desconto);
    const reservado = (pagamentosExistentes ?? [])
      .reduce((soma, p) => soma + Number(p.valor), 0);
    const restante = Number((liquido - reservado).toFixed(2));

    if (valorNum > restante) {
      throw new Error(
        `Valor ${valorNum.toFixed(2)} excede o restante da venda (${restante.toFixed(2)})`,
      );
    }

    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(valorNum * 100),
      currency: "brl",
      payment_method_types: ["card"],
      metadata: {
        venda_id,
        empresa_id: usuario.empresa_id,
        usuario_id: user.id,
        operador: usuario.nome,
      },
    });

    // Grava o pagamento como 'pendente'. É o stripe-webhook que promove para
    // 'aprovado' ao receber payment_intent.succeeded — o cliente nunca decide
    // que um pagamento foi aprovado.
    const { data: pagamento, error: insertError } = await supabase
      .from("pagamentos")
      .insert({
        venda_id,
        forma_pagamento: metodo,
        valor: valorNum,
        status: "pendente",
        stripe_payment_intent_id: paymentIntent.id,
      })
      .select("id")
      .single();

    if (insertError) {
      // Sem a linha no banco o webhook não tem o que atualizar, então o
      // pagamento ficaria órfão. Cancela a intenção e falha explicitamente.
      await stripe.paymentIntents.cancel(paymentIntent.id).catch(() => {});
      throw insertError;
    }

    await supabase.from("logs").insert({
      empresa_id: usuario.empresa_id,
      usuario_id: user.id,
      acao: "pagamento_iniciado",
      entidade: "vendas",
      entidade_id: venda_id,
      detalhes: { metodo, valor: valorNum, stripe_payment_intent_id: paymentIntent.id },
    });

    return new Response(
      JSON.stringify({
        client_secret: paymentIntent.client_secret,
        payment_intent_id: paymentIntent.id,
        pagamento_id: pagamento.id,
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
