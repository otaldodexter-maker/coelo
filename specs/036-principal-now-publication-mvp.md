---
source: "referência visual aprovada call_Xf4KknVH3c3XUaOk6VWaITXM.png; plano aprovado Publicação do Agora; docs/product/prd-app.md; docs/design/design-system.md"
status: approved
generated_at: 2026-08-20
---

# Publicação do Agora no MVP

## Objetivo e problema

Entregar um composer rápido e leve para publicar uma mídia vertical no Agora. A superfície é de criação, não a lista nem a visualização do conteúdo temporário.

## Escopo

- Preview executável isolado em `apps/superadmin`, representando o futuro app Principal.
- Uma imagem ou um vídeo vertical, texto opcional de até 60 caracteres, overlay simples, áudio próprio, enquadramento, capa, público/contexto, rascunho e agendamento.
- Vídeo de até 30 segundos no plano-base; planos podem conceder limite superior informado e revalidado pelo backend.
- Supabase Storage privado temporário no MVP conforme ADR 0026.

## Fora de escopo

- Viewer ou lista do Agora, timeline, catálogo comercial de músicas, múltiplas mídias, editor profissional e migração para R2.

## Superfícies e UX

- Mobile 375 px: mídia dominante, ferramentas compactas, uma rolagem e ações em largura total.
- Tablet 768 px: mídia/ferramentas e dados editoriais em duas zonas.
- Desktop 1440 px: shell do Principal, mídia vertical ampla, ferramentas adjacentes e coluna editorial enxuta.
- A base usa `colorScheme.surface`, tokens Coelo, Nunito Sans e uma única ação laranja preenchida: `Publicar agora`.
- Cópias obrigatórias: `Publicar no Agora`, `Público e contexto`, `Agendar publicação`, `Salvar rascunho` e `Publicar agora`.

## Dados, permissões e segurança

- O backend resolve ator, tenant, instituição, unidade, grupo, públicos permitidos e capacidade do plano; IDs do cliente são não confiáveis.
- Bucket privado, RLS deny-by-default, comandos autenticados, versão otimista, idempotência e auditoria são obrigatórios.
- MIME real, tamanho de até 25 MB no upload transitório do MVP e duração são validados server-side. Áudio próprio exige confirmação de direitos.
- Unidade e grupo são revalidados contra a instituição; receipts de comando preservam idempotência e retries não reenviam assets já finalizados.
- Conteúdo publicado expira em 24 horas; URLs públicas permanentes e `service_role` no cliente são proibidos.

## Estados e critérios de aceite

- Estados: inicial, carregando, editando, enviando, salvando, salvo, publicando, sucesso, conflito, falha e não autorizado.
- Imagem e vídeo válidos podem ser pré-visualizados e editados; vídeo acima da capacidade é rejeitado.
- Publicar exige mídia e público/contexto válidos; agendamento exige instante futuro.
- Texto, música, corte e capa possuem fluxo funcional e feedback acessível.
- Layout não apresenta overflow em 375, 768 ou 1440 px, com escala de texto de 200%.

## Testes exigidos

- Unidade para domínio/controller; widgets e goldens responsivos; rota separada do viewer; pgTAP para RLS, grants, cross-tenant, duração, versão e auditoria; análise estática e gates do catálogo/memória.

## Riscos

- Processamento real de vídeo/extração de frame depende de pipeline futuro; o MVP persiste parâmetros de edição e capa escolhida sem criar editor avançado.
- Supabase Storage é exceção temporária e deve permanecer atrás do contrato do repositório.
