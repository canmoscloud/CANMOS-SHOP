import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0?target=deno";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceKey);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json();

    if (body.event === "cobranca.paid") {
      const cobrancaId = body.data.id;
      const valor = body.data.valor;

      const { data: pagamento } = await supabase
        .from("pagamentos")
        .select("venda_id")
        .eq("abacatepay_cobranca_id", cobrancaId)
        .single();

      if (pagamento) {
        await supabase
          .from("pagamentos")
          .update({ status: "aprovado", processado_em: new Date().toISOString() })
          .eq("abacatepay_cobranca_id", cobrancaId);

        await supabase
          .from("vendas")
          .update({ status: "confirmada" })
          .eq("id", pagamento.venda_id);
      }
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});
