---
title: "Convites produtivos do Superadmin"
knowledge_id: "superadmin-invites-production"
source: "specs/026-superadmin-invites-production.md"
status: "validated"
generated_at: "2026-08-11"
audience: "team"
surfaces: [superadmin, invites, supabase, authorization]
visibility: "internal"
review_owner: "Coelo Product e Segurança"
---

# Convites produtivos do Superadmin

Convite é uma entidade própria e não cria uma Pessoa duplicada. Ele referencia
uma Pessoa adulta global ou um e-mail normalizado e combina instituição, unidade
e Turma compatíveis com um perfil ativo daquele contexto. Representante,
administrador e profissional continuam sendo vínculos contextuais; o convite
não substitui membership, assignment ou capacidade.

Os estados do convite são **Pendente**, **Aceito**, **Expirado** e **Revogado**.
Falha pertence à entrega de e-mail, não ao ciclo de vida do convite. Reenvio
invalida o link anterior, renova a validade e incrementa a versão. Revogação é
uma ação negativa confirmada e terminal para aquele link.

Os únicos canais são **E-mail** e **Link copiável**, selecionáveis em conjunto.
Não existe SMS. O link completo é retornado somente na resposta inicial de
emitir ou reenviar; replay idempotente devolve o registro sem reconstruí-lo. O
banco persiste somente o hash. Enquanto não houver worker/provedor aprovado, a
entrega de e-mail permanece pendente e a interface não afirma envio concluído.

Contexto, destinatário e perfil são pesquisáveis e carregados do backend. A
hierarquia instituição → unidade → Turma e a compatibilidade do perfil são
recalculadas no banco. Busca, filtros, ordenação, contagem e paginação do
diretório também são server-side.

Leitura exige `platform.invites.read`. Emitir, reenviar e revogar exigem
`platform.invites.manage` e MFA AAL2. Comandos usam UUID de idempotência, versão
otimista, lock e auditoria minimizada. RLS, grants e RPCs falham fechados; rota,
botão oculto, cache ou validação Flutter nunca autorizam a operação.

O diretório é exclusivamente tabular e segue Instituições. O formulário usa o
frame sequencial aprovado, seleções hierárquicas pesquisáveis e múltipla escolha
de canal. Expirados expõem reenvio de forma clara; revogação usa vermelho
semântico e confirmação. Estados reais incluem loading, vazio, sem resultados,
falha, unauthorized, not-found, submitting, replay e resultado parcial.

Este artigo substitui, somente para Convites, as regras locais/fictícias do
artigo de protótipos operacionais. Fixtures permanecem restritas a testes
isolados. A aplicação remota depende dos gates SQL, de segurança e de build.
