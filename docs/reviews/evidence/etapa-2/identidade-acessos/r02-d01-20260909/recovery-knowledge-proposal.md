---
source: "docs/superpowers/specs/2026-07-16-superadmin-supabase-auth-design.md; docs/superpowers/specs/2026-09-01-superadmin-auth-first-local-green-design.md; decisions/0019-superadmin-internal-identity.md; revisão local D01 R02"
status: "proposal-pending-canonical-consolidation"
generated_at: "2026-09-09"
---

# Proposta de memória: confinamento da recuperação do Superadmin

Recorte: Etapa 2 → `apps/superadmin` → Auth → Recuperação/Redefinição →
`auth.recover` e `auth.reset`, com dependências em `auth.login` e `auth.logout`.
Esta proposta não altera fontes canônicas nem `docs/knowledge`, não aprova
decisão nova e não certifica produção. D00 coordena a consolidação documental.

## Fontes e consulta realizada

- `Search-CoeloKnowledge.ps1 -Query 'recupera' -Audience team -Detailed`
  encontrou `docs/knowledge/team/superadmin-internal-users.md`.
- As consultas literais `recovery` e `sessão` na mesma audiência retornaram,
  respectivamente, nenhum artigo e artigos de sessão, incluindo esse artigo.
- A spec de 16/07 aprova login com e-mail/senha e persistência escolhida antes
  de autenticar; a exclusão de recovery daquela entrega é histórica.
- A spec Auth-first de 01/09 autoriza callback e redefinição locais, exige
  encerrar recovery depois da senha e voltar ao Login, com teto `local-green`.
- O aditivo de 01/09 da ADR 0019 adia MFA para o gate formal do MVP; AAL1 e
  AAL2 permanecem aceitos no realm interno. Exigir senha não significa exigir
  MFA e não autoriza alterar realms globais ou identidades do Owner.

## Delta proposto à fonte canônica

Destino sugerido: acrescentar à seção **Contrato funcional** de
`docs/superpowers/specs/2026-09-01-superadmin-auth-first-local-green-design.md`,
após a regra sobre sessão válida de recovery, mediante consolidação de D00:

> A sessão de recuperação fica confinada à redefinição e permanece somente
> em memória no cliente. Ao reconhecer essa sessão, o adapter desabilita sua
> persistência e remove eventual credencial já gravada, serializando remoção
> e escritas pendentes. Com o armazenamento operacional e a remoção concluída,
> reiniciar o app após o consumo do callback exige solicitar outro link; a
> credencial de recovery não pode ser restaurada como login normal nem iniciar
> bootstrap de contexto administrativo. Falha de remoção deve ser reportada
> sem segredo e não permite afirmar que o próximo reinício está protegido.
> A proteção cliente não substitui a recusa de contexto administrativo no
> servidor para sessões de recuperação, inclusive após refresh.

Esse texto explicita o comportamento da correção local; não declara a
aplicação remota de um controle novo. A recuperação em memória continua
permitindo trocar a senha e encerrar a sessão. A preferência de persistência
do login normal permanece preservada.

## Delta proposto à projeção team

Em `docs/knowledge/team/superadmin-internal-users.md`, substituir somente o
parágrafo final que começa com **O preview atual** pelo texto abaixo. Essa
correção resolve a generalização do preview sem promover Auth a produção:

> O preview de Usuários Internos descrito no contrato original é local e usa
> dados simulados; ele não prova envio de convite, enforcement, auditoria ou
> persistência produtiva. A especificação Auth-first de 01/09/2026 autorizou
> separadamente a implementação local de recuperação, callback e redefinição
> de senha do Superadmin, com teto `local-green`. Essa autorização não comprova
> execução em produção nem amplia o contrato de convite.

Adicionar depois, **somente após aceitar o delta na fonte canônica**:

> A recuperação mantém uma sessão restrita em memória para redefinir a senha.
> Com a remoção do armazenamento concluída, reiniciar depois do callback exige
> outro link. Recovery não deve virar login administrativo restaurado; falha
> de remoção permanece uma limitação explícita, e a autorização continua sendo
> responsabilidade do servidor. Após trocar a senha, o app encerra a sessão
> de recuperação e retorna ao Login.

Preservar `knowledge_id`, audiência `team`, `visibility: internal` e fonte
principal da ADR 0019. Incluir no corpo referência relativa à spec Auth-first
(`../../superpowers/specs/2026-09-01-superadmin-auth-first-local-green-design.md`)
para rastrear os parágrafos acrescentados. Atualizar `updated_at` apenas quando
a alteração for efetivamente consolidada; nenhum artigo `admin` ou `users`
é proposto antes de prova do comportamento disponível nessas audiências.

## Controle backend candidato: não projetar como disponível

A proposta técnica local `proposed-password-session-context.sql` acrescenta
ao helper interno a exigência de AMR `password`, consultada em
`auth.mfa_amr_claims` para a sessão validada. O ensaio local do provedor
identificou AMR `otp` no recovery implícito, inclusive após refresh. Por isso
uma condição positiva de senha é distinta de procurar apenas o rótulo
`recovery`. Trata-se de candidato ainda não aplicado remotamente nesta
proposta. Não inserir no artigo validado afirmações de que o backend já
implementa ou já comprovou esse controle.

D00 deve reconciliar o estado nominal da migration e suas provas antes de
qualquer promoção documental. Este arquivo não concede autorização de
migration, execução remota, envio de e-mail ou uso de conta do Owner.

## Trechos históricos que exigem leitura contextual

- O último parágrafo do artigo team está desatualizado quanto à autorização
  local de recovery/reset. Correção exata proposta acima; não há fundamento
  para declarar convite produtivo pronto.
- A spec de 16/07 exclui recovery e menciona MFA futuro: preservar como recorte
  histórico, interpretado com a spec de 01/09 e o aditivo vigente da ADR 0019.
- O corpo inicial da spec Auth-first mantém exigências AAL2, mas seu próprio
  aditivo as supersede. Não reativar MFA a partir desses trechos anteriores.
- A spec Auth-first cita `updateUser`; o adapter atual envia a atualização ao
  endpoint Auth com o token de recovery fixado para proteger troca de sessão
  concorrente. Se D00 atualizar esse detalhe de implementação, preservar o
  contrato observável de trocar a senha e só então encerrar a mesma sessão.

Não foi identificado conflito de decisão ainda sem resolução: há supersessões
expressas e uma projeção atrasada. Caso D00 entenda que a regra adicional de
persistência requer decisão de produto, registrá-la em `docs/open-questions.md`
antes de promovê-la; esta proposta não registra aprovação em nome do Owner.

## Gate de memória

Captura produzida: apenas este delta revisável. A projeção permanece sem
alterações até a fonte canônica ser consolidada. Os validadores da base
existente podem detectar problemas estruturais, mas não validam aprovação,
atualidade, execução remota ou ponta a ponta. Depois de aplicar fonte e
projeção, D00 deve executar os dois wrappers `Test-CoeloKnowledge.ps1` da
skill e relatar o resultado na base entregue.

Validação da base existente em 09/09/2026: wrapper de conteúdo **PASS, 54
artigos**; testes da ferramenta **12 PASS, 1 SKIP** (host sem criação de
symlink), zero falhas. Isso não certifica a proposta ainda não projetada e
não deve ser somado aos testes funcionais de Auth nem contado novamente como
novos casos únicos se D01 já registrou esses mesmos testes.
