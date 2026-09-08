---
title: "E2E3 — regressão agrupada do escopo original"
source: "Pedido do Owner; execução local root em e8bbad3c e investigação visual"
status: "local-green nos lotes descritos; E2E e baselines visuais abertos"
generated_at: "2026-09-08"
---

# Resultado e reprodução

Somente Superadmin e dependências. Nenhum teste remoto, acesso a mídia privada,
Docker ou SQL foi executado por esta frente. Não há autorização para promover
M03/decoder, Scope ou N01 a produção. Recortes prévios permanecem históricos.

- 846/846: Flutter não-golden em chat, notices, invites, circulars,
  principal_circulars, principal_for_you, principal_happens,
  principal_happens_publication, principal_moments,
  principal_moments_publication, principal_now, principal_now_publication,
  principal_profile, principal_shared e app/shell.
  Seleção via `rg --files` com `*test.dart`, excluindo nomes `golden`.
  Comando: flutter test --no-pub --dart-define=COELO_APP_ENV=local [arquivos].
- 55/55: app/router selecionado por nomes principal/chat/circular/notice/invite/
  header com o mesmo comando e define. Não é navegação manual em browser nem
  prova de credencial/servidor real, mesmo quando nomes dos testes dizem real.
- 45/45: `dart test test/media` em packages/coelo_api.
  O pubspec.lock não-versionado gerado foi removido após a execução.
- 40/40: `deno test --no-config --no-lock` nos arquivos
  `_shared/media_image_contract_test.ts`, `_shared/r2_s3_test.ts` e
  `moments-media/r2_s3_test.ts`. São métricas/contratos/fakes; não decoder,
  cálculo de hash de arquivo real ou transação R2 de produção.

# Perfil — causa das divergências visuais

Root e revisor compararam as imagens light375 e o histórico. A referência
completa contém Acompanhar, Seguidores/Seguindo e seis métricas. O commit
`b9c75c7e44f1d524976cb863048e65cdd8ad1074`, de 01/09, removeu seguir e substituiu
as métricas por Publicações, Momentos e Circulares, sem atualizar os PNGs.
A redução de duas linhas para uma desloca Destaques, Vínculos e seções seguintes.
Os dois cenários editoriais rolados passam; os dez completos falham também na
contraprova anterior documentada em `2026-09-08-profile-circular-context.md`.

Spec 050, seção Perfil, proíbe seguidores públicos; teste funcional atual
preserva essa ausência. Portanto, não restaurar Acompanhar/seguidores para
satisfazer imagens antigas. A especificação tampouco aprova automaticamente
as três métricas ou toda geometria atual. Conciliação/revisão visual nominal
foi solicitada à coordenação; nenhum PNG foi alterado ou promovido nesta análise.

# Gates preservados

## Reexecução após as correções locais

Em7115a6f7, root repetiu o mesmo lote Flutter:880/880 não-golden do escopo
original + shell e55/55 rotas. Sem regressões nos deltas de Avisos, ContextPanel,
Chatimage e ParaVocê. Aumento de34 testes sobre o checkpoint846 anterior.
Validadores da base de conhecimento e seus cenários passaram, sem nova projeção.
Diff desdee8bbad3c:22arquivos,zero apps/admin|principal|site,zero trackers oficiais,
zero migrations ezeroPNG. Diff check passou. Esses resultados não resolvem os
gates abaixo. Evidência browser local separada em2026-09-08-browser-local-smoke.md.

M03: máximo de lote Chat pelo Owner, contrato AMR/proveniência server-side E1,
decoder/entitlement, catálogo/locks e lease nominal. N01: diagnóstico local
50+2 sob Eng1 não é ponte/green/aplicação remota. Convites mantém OQ039/spec047.
Baselines históricos de Chat/Avisos/Acontece/Perfil e demais provas E2E permanecem
abertos. A quantidade de testes/commits não substitui nenhuma dessas evidências.
Memória no-op: nenhuma nova regra aprovada. Coordenador recebe o checkpoint
para atualização dos rastreadores oficiais sob sua escrita exclusiva.

## Reexecução após ownership do Agora

Em `f353fee2`, 893/893 não-golden dos mesmos 14 domínios e shell passaram
com `flutter test --no-pub`; 55/55 rotas passaram novamente com o define local.
Publicação Agora separadamente: 91/91 incluindo goldens em `1a14784d`;
prévia Agora: 54/54 incluindo goldens em `f353fee2`. Nenhuma referência atualizada.
Diff desde `e8bbad3c`: 28 arquivos, zero apps proibidos, trackers oficiais,
migrations e PNG. Varredura heurística do diff por chave secret Supabase,
private key, access key AWS e JWT longo: zero ocorrências; não substitui um
scanner completo de segredos. `.env` e `.env.local` continuam ignorados.
