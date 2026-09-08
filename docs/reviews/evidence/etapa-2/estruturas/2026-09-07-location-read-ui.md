---
title: "LOC-READUI01 — leitura local preparada, não E2E"
source: "reserva da coordenação; LOC-DTO01 9430a78d; design Locais; testes e inspeção local"
status: "prepared-local-with-shared-accessibility-gap"
generated_at: "2026-09-08"
---

# Recorte e limite

Lista cards/tabela e detalhe textual isolados em Superadmin/features/locations,
reader injetado indisponível por padrão, catálogo institution/unit explícito.
Sem rota normal, shell, DI, RPC, criação/edição, mapas/fotos, cópia, agenda ou
vínculos. Nenhum dos sete IDs exclusivos de Locais é encerrado E2E por esta fatia.
Instituições, Unidades, Turmas, Pessoas/Alunos e seus vínculos continuam no
escopo original; este preparo não reduz aquele denominador.

Sessão disponível é só gate local de renderização, nunca autorização. Backend
deve reautorizar toda chamada. API/DTO preparados não foram conectados aqui.

## Implementação

- Reader de detalhe/lista e query imutável sem transporte nem fixtures runtime.
- Controllers limpam dados imediatamente no reload/troca de sessão, owner,
  reader ou revisão; capturam inputs antes de notificar, invalidam reentrância
  e ignoram conclusão tardia/dispose. Resultado ID/owner divergente não aparece.
- Busca nominal com limite120, paginação1–100 e offset até10000. Total global
  preservado, janela limitada informada; redução de total recupera página0
  uma única vez, sem loop de retries.
- Cards/tabela e toolbar/paginação/arquivos usam componentes canônicos. Sem
  filtros/sorts que o SQL não suporta, métricas fictícias ou vínculos presumidos.
- Arquivos permanecem visíveis com “Disponível depois do MVP”, sem picker,
  parser, job, RPC ou geração de arquivo. Detalhe mostra endereço próprio com
  a chave canônica district; Voltar/Recarregar ficam fora do conteúdo rolável.

## Evidência executada

No diretório apps/superadmin, comandos precedidos por rtk proxy:

- Testes iniciais de controllers e painéis: RED de compilação por arquivos
  inexistentes, seguido de implementação e GREEN (não são REDs runtime).
- RED runtime da redução do total paginado: duas consultas em vez de três;
  corrigido com recuperação limitada. Controllers:20 PASS.
- Review readonly apontou district incorreto e mensagem de arquivos; dois
  REDs runtime reproduzidos e dois GREEN após correção.
- Inspeção visual detectou textos de tabela alinhados ao topo. Teste de caixas
  dos glifos reproduziu diferença44,5px; Align na composição das células
  corrigiu. Teste considera todas as linhas do texto, não só a primeira.
- Painéis:19 PASS — quatro larguras375/768/1024/1440, claro/escuro, texto200%,
  perda de sessão, troca reader/ID, callback antigo após revisão/reload/dispose,
  endereço completo, retorno e ausência de comandos de escrita.
- Goldens:20 PASS;30 PNGs candidatos novos, todos inspecionados pelo root.
  Incluem cards/tabela, foco/hover de card/linha, busca, menu arquivos,
  paginação, loading/empty/no-results/denied/unavailable e detalhe/rodapé.
- `flutter test --no-pub test/features/locations`:59 PASS, sem update-goldens.
- DNS pub.dev falhou antes de uma execução; não foi falha do produto.
  Dependências já resolvidas; execução sem pub passou.
- Validador visual administrativo: exit0, sem ampliar allowlist.
- Analyzer dos10 arquivos Dart nominais:0 issues. Dois gates de memória PASS.
- Revisões readonly Nash/Mencius: três P2 locais corrigidos; recheck sem novo
  achado nominal. Revisores não executaram Flutter nem aprovaram as imagens.

## Pendência visual compartilhada comprovada

`CoeloAdminExpandableStatusIndicator` conserva24px de altura e largura calculada
sem textScale. A imagem
`apps/superadmin/test/features/locations/goldens/location_directory_status_text200_diagnostic_light_375.png`
mostra “Suspenso” cortado (“Susp”) a200%. O teste diagnóstico documenta essa
limitação; PASS não significa acessibilidade aprovada. Sem mudança no Design
System fora da reserva. Coordenação informada para tratamento nominal.

Os outros29 candidatos foram inspecionados como preparo local: conteúdo legível,
foco visível, paginação sem sobreposição e tabela com scroll horizontal no
compacto. Não são baseline de produção aprovado nem prova de rota normal.

## Próximos gates E2E

Resolver pendência shared de status; integrar composição/rotas e transporte
nominais após backend aprovado; provar leitura/persistência/autorização real,
cross-scope/tenant, sessão expirada, reload e auditoria. Criação/edição, mapas,
cópia e vínculos continuam fora desta fatia e dentro do escopo original.

Memória: nenhum comportamento novo durável aprovado para usuário final;
contrato e evidência preparados atualizados, sem criar conhecimento promocional.
Ledger e três rastreadores continuam sob single-writer da coordenação.
