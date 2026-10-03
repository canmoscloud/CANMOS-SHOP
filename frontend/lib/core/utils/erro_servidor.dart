import 'package:supabase_flutter/supabase_flutter.dart';

/// Traduz erros do backend para texto exibível ao operador.
///
/// As Edge Functions respondem `{"error": "..."}` e as RPCs usam
/// `RAISE EXCEPTION` com mensagens já escritas para quem está no balcão
/// ("Valor excede o restante da venda"). Sem desembrulhar, a tela mostraria
/// o dump da exceção.
String mensagemDeErro(Object e) {
  if (e is FunctionException) {
    final details = e.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    if (details is String && details.isNotEmpty) return details;
    return e.reasonPhrase ?? 'Falha ao chamar o servidor';
  }
  if (e is PostgrestException) return e.message;
  if (e is AuthException) return e.message;
  return e.toString();
}
