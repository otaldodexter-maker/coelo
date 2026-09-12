---
source: G4 regression proposal; C0 execution; Owner avatar observation
status: chat-local-green; header-deferred-by-owner
generated_at: 2026-09-12
---

# Chat e pendência do cabeçalho

apps/superadmin -> Chat -> Criar grupo -> troca de instituição -> chat.create-group.
Integrados os dois testes propostos por G4. Corrigido o texto esperado que
chegou com caracteres `?`; primeiro ensaio tinha uma falha de fixture e uma
falha real. Com a expectativa correta, ambos reproduziram o defeito: um erro
antigo escondia os membros de B após trocar de A. RED1PASS/2FAIL, exit1.
C0 limpa o erro ao mudar contexto e ignora a falha tardia de outra instituição.
GREEN3PASS/0FAIL/0SKIP, exit0; sem nova RPC, permissão ou alteração visual.
Não certifica CRUD remoto ou E2E. Não repetir suites verdes sem outro delta.

## Avatar — correção posterior solicitada pelo Owner

apps/superadmin -> cabeçalho global (ao lado de bug e notificações) -> shell.load.
Owner observou avatar `OC` em vez das iniciais/foto do usuário autenticado e
pediu correção posteriormente. Inspeção focal confirmou `const CircleAvatar
(radius: 18, child: Text('OC'))` em superadmin_shell.dart:1786.
Portanto não é apenas hipótese visual: o texto está fixo nesse componente.
Nenhuma alteração do avatar nesta fatia. Responsável futuro C0/G7; primeiro
gate: consumir identidade autenticada/foto autorizada, fallback de iniciais e
prova com duas identidades/reload, sem reutilizar o nome de outro usuário.
Não muda denominadores nem desfaz provas anteriores de carregamento do shell;
o avatar não está certificado como dinâmico. Sem novo conhecimento de produto
aprovado para projeção: memória no-op, pendência registrada na fonte operacional.

WIP UI G1 preservado por recibo: grupo1043c165, v2 ativo, tentativa de adicionar
QA R04 Responsavel9f040000-0000-4000-8000-000000000062 como guardian recusada,
zero vínculo persistido. Captura active-member-rejected.png da frente e
location-ui-proof.md mantêm o ponto de retomada. Não reenviar guardian: não
existe no catálogo institution_roles; a cadeia familiar é um contrato separado.

Analise focal dos dois arquivos: No issues found, exit0. Os estados FE previamente
verificados preservam suas certificacoes historicas; nao contam como novos aceites.
