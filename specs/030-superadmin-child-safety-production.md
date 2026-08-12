---
title: "Segurança da criança produtiva"
source: "decisão do produto em 2026-08-12; decisions/0015-contextual-people-authorizations-attendance.md; decisions/0020-backend-authorization-application-security.md; decisions/0024-child-safety-private-evidence-storage.md"
status: approved-for-implementation
generated_at: "2026-08-12"
---

# Segurança da criança produtiva

## Objetivo e escopo

Administrar autorizações de retirada, pessoas autorizadas, restrições, alertas,
validade, motivo, evidência e histórico sem confiar no frontend. Pessoa é global;
a autorização é um vínculo contextual com a criança e a unidade.

Inclui diretório, busca server-side, detalhe, criação e edição pendente, decisão,
ciclo de vida, restrição, alerta, evidência privada e exportação por job. Não
inclui importação em lote, perfil público, descoberta ou herança individual.
Somente políticas gerais podem herdar; autorização individual nunca herda.

## Estados e segmentação

Decisão usa `pending`, `approved` ou `rejected`. Ciclo de vida usa `inactive`,
`active`, `suspended` ou `archived`; expiração é derivada da validade. Toda nova
solicitação nasce `pending` + `inactive`.

Cada criança pertence a uma única tab, nesta precedência:

1. `awaiting_approval`: existe solicitação pendente;
2. `attention`: existe restrição vigente ou alerta aberto/reconhecido;
3. `authorized`: existe autorização aprovada, ativa e vigente;
4. `without_authorization`: nenhuma condição anterior.

`all` é a soma exclusiva. Rejeições aparecem somente no histórico da criança.

## Permissões e comandos

Leitura Superadmin exige `child_safety.read` e AAL2. As tabelas sensíveis não
concedem `SELECT` ao navegador; leitura ocorre somente pelos agregados minimizados.
Criação administrativa pode reutilizar uma pessoa adulta global existente e
valida o contexto instituição/unidade/criança. Responsável não pode vincular um
UUID global arbitrário: reutiliza apenas identidade adulta já verificada e sob
seu ownership na instituição, ou segue o fluxo separado de convite/verificação.
Responsável com capability pode solicitar, mas não aprovar. Aprovação/rejeição é
exclusiva de membership ativa com `authorized_people.manage` no escopo exato da
unidade e exige AAL2. Instituição observa e audita; eventos contêm apenas IDs e
status mínimos, e destinatários são resolvidos por capability no servidor.
Responsável edita somente a própria solicitação pendente. Suspensão, revogação,
restauração, restrições e reconhecimento de alertas exigem autoridade
administrativa no contexto; um responsável não pode desfazer a decisão da unidade.

Todos os comandos usam idempotency key, lock de linha, versão otimista, motivo,
auditoria before/after minimizada e falham fechados sem diferenciar inexistência
de falta de acesso. O cliente não escreve tabelas diretamente.

## Dados, mídia e exportação

Autorização guarda relação, capabilities `pickup`, `emergency_contact` e
`transport`, validade e motivos. Relação Outros exige detalhe. Evidências seguem
a ADR 0024. Exportação cria job server-side `child-safety-export-v1`, aplica os
filtros autorizados e exige escape contra CSV formula injection.

## Critérios de aceite e testes

- listagem e contagens são server-side, exclusivas e usam cursor estável;
- reads e comandos revalidam ator, escopo e hierarquia a cada requisição;
- RLS é forçada; grants são mínimos e policies são separadas por operação;
- nenhuma leitura direta das tabelas de segurança é concedida a `authenticated`;
- testes cobrem anon, AAL ausente, unidade errada, criança/parent trocados,
  versão obsoleta, replay divergente, MIME/path malicioso e export não autorizado;
- nenhuma chave secreta, PII ou payload infantil entra em log, bundle ou Git.
