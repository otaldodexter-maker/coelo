---
title: "Auth R07 — recovery no SDK e ownership de eventos"
source: "Reserva R07 e extensão focal do Coordenador; gotrue 2.26.0 instalado; revisão account_review"
status: "local-green-sdk-http-mock; production-e2e-open"
generated_at: "2026-09-07"
---

## Implementação

O adapter concreto acompanha eventos SDK em subscription própria. Mantém
somente a marca de `session_id` de recovery, sem reter o token inicial.
Getter e stream preservam recovery após refresh da mesma sessão e removem a
marca no encerramento/troca. Estado inicial não observado permanece fechado;
uma marca de A nunca classifica B como autenticação produtiva.

O stream existente preserva replay do estado conhecido. O scope aguarda seu
primeiro estado antes de decidir pelo bootstrap interno. Nenhuma interface
abstrata, getter público de prontidão, API SDK `@internal`, dependência ou
contrato remoto foi adicionado.

`dispose` no gateway concreto cancela somente recursos próprios e fecha o
stream. Não faz logout nem fecha o SupabaseClient externo. O callback de
descarte do scope preserva a limpeza de cache; falha de inicialização também
libera gateway/sessão criados pela composição.

## REDs e regressão

REDs observados e corrigidos:

- callback recovery posterior à construção: getter retornava authenticated;
- construção após recovery já no SDK: getter permitia autenticação antes do
  replay; fechamento inicial sem sincronização também quebrava restauração;
- token inicial A e sessão B: exceção indevida ao fechamento inicial;
- falha de inicialização após criar gateway: subscription permanecia aberta.

Com SDK gotrue 2.26.0 e HTTP simulado: 9/9. Inclui recovery com/sem assinante
externo, refresh, atualização de senha e logout, troca para sessão normal,
negação de reset fora de recovery, restauração normal versus recovery,
descarte e falha de inicialização. As respostas e credenciais são sintéticas.

Regressão consolidada: **74/74** (SDK 9, auth scope 14, login 13, logout 3,
sessão 12 e pacote coelo_auth 23). Analyzer do adapter e três arquivos do
Superadmin sem diagnósticos. Configuração local do pacote foi resolvida com
`flutter pub get --offline`; nenhum arquivo de dependência rastreado mudou.
Ambos os package configs apontam para gotrue 2.26.0.

Revisão estática `account_review` aprovou replay, ownership e o guard final
após a correção da marca A versus sessão B, sem bloqueios no recorte.

A fixture de cache do scope passou a injetar lifecycle controlado: ela
autoriza sessões diretamente sem sessão SDK. SDK real é exercitado pela suíte
separada, evitando confundir esse teste de cache com autenticação real.

## Limites

HTTP é simulado: nenhum Supabase remoto, SMTP, banco, usuário produtivo ou
revogação real foi exercitado. Recriar o processo sem contexto recovery
persistido, corridas de duas tentativas de login e resultados de comandos de
senha concorrentes com troca de sessão continuam recortes separados.
Não declarar Auth ou Identidade e Acessos verified-e2e.

Knowledge: nenhuma decisão nova; preserva separação canônica de recovery e
autorização interna. Evidências técnicas não viram regra de produto nova.
