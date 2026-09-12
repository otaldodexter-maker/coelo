---
fonte: chat_api_smoke.py; manifests Chat; preflight normal de identidades QA; autorizacao C0 R08
status: api-aprovada-ui-e2e-pendente
data: 2026-09-12
---

# Chat — grupo QA e PNG privado por binding

apps/superadmin → Chat → criar grupo / conversa / anexo →
chat.create-group e chat.attach. Prova API em producao, sem aceite UI/E2E.

O preflight confirmou por RPC de detalhe e service-person os dois atores QA
nominais (`chat-qa-directory-preflight.json`). O grupo tem somente essas duas
pessoas, instituicao d0c40000-0000-4000-8000-000000000001 e unit/group/activity
nulos, como o contrato da tela. Nenhum novo usuario ou papel foi criado.

A execucao inicial criou uma unica conversa e anexou um PNG sintetico
16×16/82bytes. Prepare retornou os headers exatos da assinatura; o PUT isolado,
sem redirect e sem credenciais da API, retornou200. Finalize correlacionou
attachment_id e message_id; read autorizado e GET recuperaram o mesmo SHA-256.

`chat-api-manifest.json`: **27 checks/operacoes aprovados, 1 falho**, exit1,
logout204. A falha era uma expectativa restrita a403 para o GET R2 sem query
de assinatura; o servidor retornou400. O resultado original foi preservado.

C0 autorizou continuar sobre os mesmos IDs. O script passou a aceitar400/401/403
somente quando a resposta nao contem assinatura de PNG; registrou o codigo
XML `InvalidArgument`, sem corpo ou URL. A continuacao nao executa create,
PUT nem finalize. `chat-api-resume-manifest.json`: **26 checks/operacoes
aprovados, 0 falhos**, exit0, logout204. Nao somar as duas tentativas como
54 testes distintos; os checks de leitura/identidade se sobrepoem.

A continuacao confirmou:

- os mesmos dois membros;
- leitura privada com bytes identicos;
- negativa sem assinatura400/InvalidArgument, anonimo401 e binding inexistente422;
- nova consulta da thread com uma mensagem e exatamente o mesmo attachment_id;
- prepare repetido com o mesmo request_id retorna replayed=true e mesmos IDs,
  seguido de nova autorizacao de leitura, sem segundo PUT;
- URL original retorna403 apos aguardar o TTL real de300segundos.

Recursos sinteticos preservados ate o encerramento formal da Etapa2:

- conversa: `39aa8f4a-33a0-4d4e-beb0-a9fd4c7fcf64`;
- anexo: `9ed2bcc3-dfb9-4f56-a67d-0e582593ca3e`;
- mensagem: `fcd0c6d4-f917-4c56-94e1-10805c734b50`.

Nao houve DELETE, revogacao ou cleanup fisico; master R2 privado preservado.
Os manifests nao guardam credenciais, URLs assinadas, nomes ou emails pessoais.
As duas contas QA sao Owner/platform: nao constituem prova negativa cross-tenant.
O proximo gate e exercitar a rota normal na UI, quando o runtime G0 permitir.
