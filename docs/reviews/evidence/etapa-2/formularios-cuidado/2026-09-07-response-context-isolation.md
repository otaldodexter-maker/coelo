---
title: "Formulários — isolamento do lifecycle da resposta"
source: "Prompt 5 Etapa 2; forms.respond; testes e diff locais"
status: "local-green-partial"
generated_at: "2026-09-07"
---

# Contrato e causa

Superadmin, `forms.respond`: preservar isolamento ao trocar API ou occurrenceId
no mesmo State. O carregamento partia somente de initState e os awaits
verificavam apenas mounted. Isso conservava texto antigo, permitia abrir draft
após desmontagem e aplicar recibos/erros antigos no contexto seguinte.

Incluído: lifecycle do componente produtivo, lookup/open draft, saves e picker
de data. Fora: composição de router, backend, layout, autorização e autosave
produtivo completo. Estimativa inicial da fatia: 45–75 min; não é estimativa E2E.

## Correção e evidências

- Geração invalidada em troca de API/ocorrência e recarga; estado antigo limpo
  antes da consulta. Guarda antes de abrir draft e após cada await relevante.
- Sete casos RED reproduzidos antes das respectivas correções: API, ocorrência,
  consulta tardia após troca, consulta após dispose, save com sucesso antigo,
  save com erro antigo, picker antigo.
- Foco: 12/12. Regressão comportamental dos três arquivos de response: 23/23.
- Analyzer dos dois arquivos: sem issues; validador administrativo: exit 0.
- Review independente read-only: aprovado no recorte, sem falha concreta.
- Nenhum componente, token, layout, golden, router ou contrato público alterado.

## Golden preexistente aberto

Suíte completa de response: 23 passaram, um teste golden falhou no primeiro
cenário DEV light 375, diferença 12,78% / 47.929 pixels. Diagnóstico A/B:
retirado temporariamente apenas o patch do arquivo produtivo via apply_patch,
confirmado diff vazio contra HEAD ff06b26d nesse arquivo, executado o golden
isolado: mesma diferença exata. Patch reaplicado e regressão comportamental
executada novamente. Não foi atualizado nenhum golden. Os demais cenários do
loop golden não foram certificados porque ele interrompe no primeiro erro.

## Estado e próximo gate

`forms.respond`: Front-end local-green parcial; Back-end fail-closed;
E2E blocked-supabase, sem promoção. Router produtivo continua sem API/ocorrência
autorizada; não habilitado nesta fatia. Test doubles comprovam comportamento do
widget, não tenant A/B, autorização real ou persistência remota. É necessário
resolver ator/contrato nominal e composição produtiva com o Coordenador, além
da pendência visual acima. Nenhuma escrita remota ou dado real.

Gate de memória: no-op; isolamento já exigido pelas fontes aprovadas, sem regra
nova de produto. Rastreadores oficiais permanecem sob escrita do Coordenador.
