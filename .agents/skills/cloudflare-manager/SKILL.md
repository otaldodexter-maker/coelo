---
name: cloudflare-manager
description: Use when a Coelo task manages or deploys Cloudflare Workers, R2, Stream, Pages, KV, DNS, or routes, especially when several services or account resources participate.
license: MIT
metadata:
  source: "AGENTS.md; decisions/0032-mvp-private-media-r2.md; official Cloudflare MCP and Wrangler documentation"
  status: "active"
  generated_at: "2026-09-09"
---

# Cloudflare Manager para Coelo

Usar as ferramentas instaladas e a configuração real do repositório para
preparar, aplicar e verificar o recurso solicitado. Esta skill coordena
operações; as regras de domínio e autorização continuam em
[coelo-backend](../coelo-supabase/SKILL.md), AGENTS.md e ADR 0032.

## Ferramenta adequada à operação

1. Carregar a skill oficial `cloudflare` do plugin instalado, ou a equivalente
   explicitamente indicada pelo usuário. Ler somente o produto afetado. Usar
   `cloudflare:wrangler` para CLI/configuração/build/deploy e a skill de Workers
   quando alterar seu código. Reutilizar leituras; não carregar duplicatas.
2. Descobrir os MCPs disponíveis antes de declarar falta de ferramenta.
   O servidor `cloudflare_api`, quando conectado, oferece `docs` para documentação
   atual, `search` para schema e `execute` para chamadas de API. Inspecionar a
   assinatura/endpoints encontrados; não inventar nomes, parâmetros ou permissões.
3. MCP atende consultas e operações de conta/recursos. Para publicar código,
   preferir Wrangler ou o script de deploy existente no projeto, com o build e
   a configuração reais. Conferir versão/comandos disponíveis e documentação
   oficial antes de usar flags. Não criar transporte alternativo se o fluxo
   existente já atende.
4. Ferramenta presente ou consulta de schema bem-sucedida não comprova acesso à
   conta nem permissão de escrita. Verificar apenas identidade/conta e recurso
   necessários, sem listar dados privados alheios ao pedido. Autenticação da CLI
   e do MCP podem diferir. Se faltar acesso, identificar a operação bloqueada
   e o mecanismo de autenticação existente; não pedir tokens em conversa.

Este pacote local não fornece `workers.ts`, `r2-storage.ts`, `pages.ts` ou
`validate-api-key.ts`. Não executar esses caminhos nem supor instalação em
`~/.claude/skills/cloudflare-manager`. Bun, chave global e um arquivo `.env`
na raiz não são pré-requisitos desta skill. O instalador shell legado não é
executado automaticamente e não substitui a descoberta das ferramentas reais.

## Executar até o resultado verificável

- Identificar Etapa 2, tela/subtela/action_id, provedor e recurso nominal.
  Localizar configuração, Worker/gateway e scripts existentes; conferir conta,
  bindings e nomes reais. Não criar recursos duplicados por worktree ou app.
- Preparar diff/pacote, build e testes pertinentes, com sequência e recuperação.
  Registrar o que muda no recurso existente e o resultado esperado.
- Todo recurso remoto Coelo é produção. Respeitar autorização nominal vigente,
  ownership e aplicação serializada; não presumir staging. Se o mesmo pacote
  já foi autorizado, executar sem repetir a pergunta. Se faltar autorização,
  deixar o pacote revisável antes de solicitar a decisão e continuar o trabalho
  independente.
- Aplicar pela ferramenta adequada, conferir versão implantada e provar o
  comportamento da ação nos provedores envolvidos. Em falha, diagnosticar
  antes de repetir; timeout não autoriza apagar/recriar projeto ou bucket.
- Registrar recurso/versão, operação, resultado, evidência minimizada,
  recuperação e cleanup. Build/teste local e push não são deploy; deploy
  confirmado ainda precisa dos aceites da ação. Não repetir suítes verdes
  para substituir uma implantação ou verificação remota pendente.

## Invariantes do projeto

- R2 privado é o master da mídia nova. Supabase guarda o catálogo, permissões,
  ownership e auditoria; gateway reautoriza o ator em cada operação.
- Usar a topologia e os limites da ADR 0032. Stream é apenas cópia HOT privada
  quando aplicável. Site usa assets públicos de build, sem mídia privada.
- Segredos permanecem nos mecanismos de autenticação/secret store apropriados,
  nunca em frontend, Git, logs, URLs ou evidências. Não imprimir `.env`,
  tokens, credenciais R2 ou URLs assinadas para comprovar autenticação.
- Remoção de recurso/dados exige escopo explícito; não é troubleshooting padrão.
  Não aplicar migrations, configuração ou recursos alheios ao pacote nominal.

## Documentação primária

- [MCPs oficiais Cloudflare](https://developers.cloudflare.com/agents/model-context-protocol/cloudflare/servers-for-cloudflare/)
- [Comandos Wrangler](https://developers.cloudflare.com/workers/wrangler/commands/)
- [R2 em Workers](https://developers.cloudflare.com/r2/get-started/workers-api/)

Consultar a documentação atual da operação efetivamente usada; exemplos locais
e disponibilidade do MCP não substituem verificação do ambiente alvo.
