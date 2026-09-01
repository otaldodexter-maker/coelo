---
title: Atividades privilegiadas no Superadmin e storage de identidade
source: plano de Atividades aprovado pelo fundador em 2026-08-11
status: approved
generated_at: 2026-08-11
---

# ADR 0022 - Atividades privilegiadas e identidade

> **Complemento supersedente para o MVP:** a ADR 0030 substitui a divisão de
> provedores abaixo: toda mídia privada do MVP usa Supabase Storage, inclusive
> conteúdo operacional. A ADR 0031 também adia toda importação/exportação real
> para depois do MVP; no MVP permanecem apenas os botões com indisponibilidade
> honesta. Capabilities aqui descritas continuam como desenho futuro e não
> autorizam backend, arquivo ou job de importação/exportação agora.

## Decisao

O Superadmin pode criar, editar, vincular, importar e exportar Atividades quando
o usuario interno possuir a capability de plataforma correspondente. Owner recebe
o conjunto completo; Operations recebe governanca de taxonomia; outros usuarios
internos dependem do perfil de acesso. O Flutter apenas coleta intencao: RPCs, RLS
e funcoes server-side recalculam ator, MFA, capability, tenant e hierarquia.

Fotos de perfil e identidade, incluindo a identidade de Atividades, usam bucket
privado do Supabase Storage. Conteudo operacional de Now, Happens e Moments
continua no Cloudflare R2. Postgres permanece fonte de verdade para ownership,
escopo, metadados, auditoria e retencao em ambos os casos.

## Controles obrigatorios

- Capabilities de leitura, criacao, gestao, vinculos, pessoas, permissoes,
  taxonomia, modelos, importacao e exportacao sao independentes e opt-in.
- Policies e RPCs falham fechado e impedem IDOR/BOLA por tenant, instituicao,
  unidade, turma, crianca, profissional, handle e caminho de arquivo.
- Upload de identidade usa caminho gerado no servidor, MIME/tamanho allowlisted,
  bucket privado e URL assinada curta; nenhuma chave privilegiada entra no app.
- Alteracoes sensiveis exigem MFA quando aplicavel e auditoria before/after.
- O handle canonico da Atividade e global, editavel e preserva aliases historicos.

## Consequencias

As specs antigas que descreviam Atividades no Superadmin como somente leitura
ficam substituidas por esta decisao. Criar/editar jamais pode ser apresentado se
o backend nao oferecer o comando autorizado correspondente.

## Complemento cross-app aprovado em 2026-08-31

Entidades e invariantes de Activities sao compartilhadas, mas gateways de ator
nao sao. O Superadmin interno usa RPCs nominais baseadas na identidade e sessao
internas; o Admin people-based preserva seu gateway proprio; o Principal nao
recebe endpoint ou grant novo sem contrato familiar posterior. Reutilizacao de
dominio nunca autoriza misturar realms, fabricar pessoa para identidade interna
ou compartilhar uma RPC privilegiada entre aplicativos.
