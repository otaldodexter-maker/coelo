---
source: "D01 R02; assignment D00 r8; cold reload and storage ordering RED/GREEN; independent auth_fix_review"
status: "local-green; integration-and-backend-open"
generated_at: "2026-09-09"
---

# Recuperação após reinício e corrida de persistência

Etapa2 → apps/superadmin → Autenticação → Redefinir senha → callback,
persistência e reinício → auth.reset. Reserva D00 r8 cobre somente gateway
Supabase e storage condicional compartilhados; nenhuma rota/scope mudou.

O SDK serializava a sessão de recuperação. Sem o evento original após reinício,
ela podia ser interpretada como sessão comum. RED válido:
`recovery-cold-reload-red-storage.txt`, preferência ligada, bootstrap1/contexto
presente/rota inicial. Transporte HTTP sintético: esta prova isolada não
demonstrava autorização no banco. O teste ligado e o desligado agora passam
com SDK e storage reais, mantendo recuperação apenas em memória.

A fila de mutações serializa gravação e remoção, incluindo recuperação da fila
após erro de gravação. RED anterior em `recovery-storage-ordering-red.txt`;
dois testes de ordenação mais dois cold reload PASS em
`recovery-cold-storage-green.txt`. Gateway reconhece recovery por session_id,
preserva sessão B diante de marcador A e comunica falhas de remoção por erro
sanitizado. Cinco casos adicionais PASS, detalhados no recibo
`recovery-persistence-gateway-review.md`.

Regressão28casos:25PASS/3FAIL inicialmente por fixtures que substituíam a
inicialização real Supabase sem inicializar o LocalStorage. Corrigidas as
quatro fixtures, seis casos afetados PASS (quatro scope e dois composição),
sem repetir os demais verdes. Logs `recovery-persistence-regression.txt` e
`recovery-persistence-fixtures-green.txt`. Os três OTP e os dois casos de
composição já pertenciam ao plano anterior; não contar novamente.

Análises Dart dos dois arquivos produtivos e cinco testes novos/alterados
sem diagnósticos, incluindo cold reload e ordering às14:27 BRT. Revisão fria
independente somente leitura aprovou o delta limitado ao armazenamento
operacional; não executou testes adicionais nem alterou arquivos.

Limite explícito: falha real ao remover o storage pode conservar a credencial
em disco. A recuperação fica confinada em memória e o erro é observável,
mas não se certifica cold reload seguro nesse cenário. A proteção backend
por sessão autenticada por senha permanece um gate separado, com RED real
local em `local-auth-recovery-boundary-receipt.md`. Nenhuma produção foi alterada.

Proposta D00: integrar a correção e revalidar o discriminante na base conjunta
para restaurar somente FE auth.reset. BE/E2E permanecem0/4. Browser B4 é
responsabilidade ativa D00. Conhecimento durável: a correção implementa o
confinamento existente; a precisão de reinício e proteção AMR será encaminhada
à fonte canônica e projeção de equipe após resolução do pacote conjunto.
