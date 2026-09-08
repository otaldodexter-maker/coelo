---
title: "Circulares no menu Coelo (Principal) — isolamento de contexto"
source: "Prompt 4 Etapa 2 E2E; AGENTS.md; testes e revisão independente da frente E2E 3"
status: "local-green; gates de produção e E2E abertos"
generated_at: "2026-09-08"
---

# Recorte e contrato

Somente o detalhe, leitor e editor de Circulares em `apps/superadmin`, no menu
Coelo (Principal). Não altera `apps/principal`, rotas, Auth, contratos de RPC,
SQL, Cloudflare ou rastreadores oficiais. Objetivo: resultados de um contexto
anterior não devem iniciar comandos, alterar respostas ou navegar no atual.
Ordem: detalhe/respostas, leitor, editor, regressão e revisão. Critério de parada
desta fatia: negativos e regressão locais verdes; não equivale a entrega E2E.

# Evidência RED → GREEN

Oito novos casos falharam antes das respectivas correções:

- `saveDraft` pendente continuava com `submit` após troca do responseRepository,
  chegando a usar o repository novo com a sessão de resposta antiga.
- A mesma continuação ocorria após desmontar a página.
- Troca de repository não carregava o novo detalhe, enquanto a leitura antiga
  permanecia pendente.
- Mudança de revisão conservava respostas antigas no leitor, em dois casos
  com conclusão posterior de sucesso/erro.
- Publicação pendente executava callback após troca de controller ou dispose.
- Data escolhida para A era aplicada ao rascunho de B.

Correção: geração invalidada nas mudanças relevantes, dependências/callbacks
capturados antes do await, verificação de mounted/geração após cada etapa e
limpeza do estado anterior. O detalhe recria o leitor por geração. O leitor
isolado reconhece id/revisão/sessão/versão; rebuild equivalente preserva edição.
O editor reinicia data/prévia e rejeita picker antigo, inclusive fora de ordem.

Quatro testes complementares cobrem troca isolada de criança, troca isolada de
ID, negação tardia de leitura e submit já iniciado que retorna versão 99 depois
da troca; a próxima gravação conserva a versão 4 do novo contexto.

# Verificação executada

- 108 testes não-golden de `test/features/circulars` e
  `test/features/principal_circulars`: GREEN.
- Analyzer dos seis arquivos alterados: sem problemas.
- Format dos seis arquivos; `git diff --check` e validador de contratos visuais.
- Reviews read-only independentes: detalhe/leitor e editor sem bloqueantes.
  Cobertura complementar de dois pickers concorrentes/dispose permanece melhoria
  não bloqueante; guard revisado por inspeção.
- Nenhum golden ou baseline alterado; nenhum segredo necessário ou introduzido.

# Limites e memória

Não prova autorização server-side, revogação remota, persistência ou entrega de
mídia. Não muda o resultado de writes já enviados ao servidor antes da troca;
impede continuação/feedback no contexto errado. `onPickFiles` mantém ownership
externo. Produção, composição real e os gates completos de Circulares permanecem
abertos. Esta correção restaura o contrato de isolamento existente: não cria
decisão de produto nem conhecimento novo reutilizável; gate de memória sem novo
artigo. Handoff ao Coordenador para rastreadores, sem promovê-los a E2E.
