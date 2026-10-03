import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0?target=deno";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceKey);

const ABACATEPAY_API_URL = "https://api.abacatepay.com/v1";
const ABACATEPAY_API_KEY = Deno.env.get("ABACATEPAY_API_KEY")!;

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

    const { venda_id, valor } = await req.json();
    if (!venda_id || !valor) throw new Error("Missing required fields");

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

    // service_role ignora RLS: posse da venda é verificada aqui.
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

    const pixResponse = await fetch(`${ABACATEPAY_API_URL}/cobranca/create`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${ABACATEPAY_API_KEY}`,
      },
      body: JSON.stringify({
        valor: valorNum,
        descricao: `Venda ${venda_id} - ${usuario.nome}`,
        expires_in: 3600,
      }),
    });

    if (!pixResponse.ok) {
      const errorText = await pixResponse.text();
      throw new Error(`AbacatePay error: ${errorText}`);
    }

    const pixData = await pixResponse.json();

    if (!pixData?.id) {
      throw new Error("AbacatePay não retornou id da cobrança");
    }

    // Pagamento nasce 'pendente'; o abacatepay-webhook promove para 'aprovado'
    // quando a AbacatePay confirmar o PIX.
    const { data: pagamento, error: insertError } = await supabase
      .from("pagamentos")
      .insert({
        venda_id,
        forma_pagamento: "pix",
        valor: valorNum,
        status: "pendente",
        abacatepay_cobranca_id: pixData.id,
        pix_qr_code: pixData.qr_code ?? null,
        pix_qr_code_texto: pixData.qr_code_text ?? null,
      })
      .select("id")
      .single();

    if (insertError) throw insertError;

    await supabase.from("logs").insert({
      empresa_id: usuario.empresa_id,
      usuario_id: user.id,
      acao: "pix_criado",
      entidade: "vendas",
      entidade_id: venda_id,
      detalhes: { cobranca_id: pixData.id, valor: valorNum },
    });

    return new Response(
      JSON.stringify({
        cobrancaId: pixData.id,
        pagamentoId: pagamento.id,
        qrCode: pixData.qr_code ?? null,
        qrCodeText: pixData.qr_code_text ?? null,
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
