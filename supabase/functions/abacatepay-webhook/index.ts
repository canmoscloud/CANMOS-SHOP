import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0?target=deno";
import { crypto } from "https://deno.land/std@0.208.0/crypto/mod.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceKey);

const ABACATEPAY_WEBHOOK_SECRET = Deno.env.get("ABACATEPAY_WEBHOOK_SECRET") || "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, X-Abacatepay-Signature",
};

async function verifyWebhookSignature(
  payload: string,
  signature: string | null,
  secret: string
): Promise<boolean> {
  // Nunca aceitar sem assinatura válida: como este webhook confirma pagamentos,
  // um "dev mode" permissivo deixaria qualquer um marcar vendas como pagas.
  if (!secret || !signature) return false;

  try {
    const encoder = new TextEncoder();
    const key = await crypto.subtle.importKey(
      "raw",
      encoder.encode(secret),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"]
    );
    const signatureBytes = await crypto.subtle.sign("HMAC", key, encoder.encode(payload));
    const expectedSignature = Array.from(new Uint8Array(signatureBytes))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");
    return expectedSignature === signature;
  } catch {
    return false;
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.text();
    const signature = req.headers.get("X-Abacatepay-Signature");

    if (!ABACATEPAY_WEBHOOK_SECRET) {
      console.error("ABACATEPAY_WEBHOOK_SECRET não configurado — recusando webhook");
      return new Response(
        JSON.stringify({ error: "Webhook secret not configured" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
      );
    }

    const isValid = await verifyWebhookSignature(body, signature, ABACATEPAY_WEBHOOK_SECRET);
    if (!isValid) {
      console.error("Invalid AbacatePay webhook signature");
      return new Response(
        JSON.stringify({ error: "Invalid signature" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 401 }
      );
    }

    const payload = JSON.parse(body);

    if (payload.event === "cobranca.paid") {
      const cobrancaId = payload.data?.id;
      const valor = payload.data?.valor;

      if (!cobrancaId) {
        throw new Error("Missing cobranca_id in webhook payload");
      }

      // Find the payment record
      const { data: pagamento, error: selectError } = await supabase
        .from("pagamentos")
        .select("venda_id, valor, status")
        .eq("abacatepay_cobranca_id", cobrancaId)
        .single();

      if (selectError) {
        console.error("Error finding payment:", selectError.message);
        throw new Error(`Payment not found for cobranca_id: ${cobrancaId}`);
      }

      if (!pagamento) {
        console.warn(`No payment found for cobranca_id: ${cobrancaId}`);
        return new Response(JSON.stringify({ received: true, skipped: true }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        });
      }

      // Idempotência: webhook pode ser reenviado — se já aprovado, não repete
      if (pagamento.status === "aprovado") {
        return new Response(JSON.stringify({ received: true, alreadyProcessed: true }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        });
      }

      // Update payment status
      const { error: updatePaymentError } = await supabase
        .from("pagamentos")
        .update({ status: "aprovado", processado_em: new Date().toISOString() })
        .eq("abacatepay_cobranca_id", cobrancaId);

      if (updatePaymentError) {
        console.error("Error updating payment:", updatePaymentError.message);
        throw updatePaymentError;
      }

      // Update venda status
      const { error: updateVendaError } = await supabase
        .from("vendas")
        .update({ status: "confirmada" })
        .eq("id", pagamento.venda_id);

      if (updateVendaError) {
        console.error("Error updating venda:", updateVendaError.message);
        throw updateVendaError;
      }

      // Log the successful payment
      const { data: venda } = await supabase
        .from("vendas")
        .select("empresa_id")
        .eq("id", pagamento.venda_id)
        .single();

      if (venda) {
        await supabase.from("logs").insert({
          empresa_id: venda.empresa_id,
          acao: "pagamento_pix_aprovado",
          entidade: "pagamentos",
          entidade_id: cobrancaId,
          detalhes: { cobranca_id: cobrancaId, valor: valor || pagamento.valor },
        });
      }
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err) {
    console.error("AbacatePay webhook error:", err.message);
    return new Response(
      JSON.stringify({ error: err.message }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
    );
  }
});
