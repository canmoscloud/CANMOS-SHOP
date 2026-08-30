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

    const usuario = await supabase
      .from("usuarios")
      .select("empresa_id, nome")
      .eq("id", user.id)
      .single();

    if (usuario.error) throw new Error("User not found");

    const pixResponse = await fetch(`${ABACATEPAY_API_URL}/cobranca/create`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${ABACATEPAY_API_KEY}`,
      },
      body: JSON.stringify({
        valor: valor,
        descricao: `Venda ${venda_id} - ${usuario.data.nome}`,
        expires_in: 3600,
      }),
    });

    if (!pixResponse.ok) {
      const errorText = await pixResponse.text();
      throw new Error(`AbacatePay error: ${errorText}`);
    }

    const pixData = await pixResponse.json();

    await supabase.from("logs").insert({
      empresa_id: usuario.data.empresa_id,
      usuario_id: user.id,
      acao: "pix_criado",
      entidade: "vendas",
      entidade_id: venda_id,
      detalhes: { cobranca_id: pixData.id, valor },
    });

    return new Response(
      JSON.stringify({
        cobrancaId: pixData.id,
        qrCode: pixData.qr_code,
        qrCodeText: pixData.qr_code_text,
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
