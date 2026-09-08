---
title: "Agora — descarte local após negação"
source: "invariantes AGENTS.md; revisão review_media_session; testes principal_now_publication"
status: "local-green; E2E aberto"
generated_at: "2026-09-07"
---

## Recorte

Controller e página de publicação Agora no Superadmin. Após resposta
NowPublicationUnauthorized, remover referências ao draft protegido e impedir
restauração por edições, comandos, pickers ou overlays anteriores. Nenhuma
mudança de permissão, contrato remoto, schema, provider ou layout.

## Causa e correção

Os catches alteravam apenas phase e preservavam draft. Setters podiam retornar
à edição depois da negativa; gerações de pickers/overlays eram invalidadas
somente em troca de contexto ou dispose.

Agora a negativa substitui o draft inteiro e ativa um bloqueio independente de
phase. Load autorizado pode recuperar o controller; load transitório falho não
libera comandos/edições. A tela negada continua sem botão novo de retry.
Página invalida pickers e overlays próprios, limpa legenda e volta à etapa 0.
O descarte remove referências do estado/UI: não promete zerar memória física,
cancelar I/O em andamento nem revogar URL no servidor.

## Verificação executada

- RED: 5 pontos de negação (load/save/uploadMedia/uploadAudio/publish)
  preservavam ID protegido; outro teste comprovou comando adicional após negar.
- RED de widget: picker pendente fazia desaparecer a tela de negação.
- RED com apenas a invalidação da página removida: mídia/áudio anteriores
  reapareciam após reload autorizado; Texto/Cortar permaneciam abertos mesmo
  quando a negativa ocorria antes do primeiro build do overlay.
- GREEN: 81/81 testes de `test/features/principal_now_publication`, incluindo
  goldens existentes. Foram acrescentados 11 testes; nenhum PNG foi atualizado.
- Comando: Flutter test --no-pub --dart-define=COELO_APP_ENV=local
  test/features/principal_now_publication.
- Analyzer dos quatro arquivos: sem problemas. Formatter, validador de
  contratos visuais e git diff --check passaram.
- Review independente estático de review_media_session: sem bloqueantes.

Dados são sintéticos. Nenhum teste Supabase/R2/Stream real foi executado nesta
fatia. Persistência, reautorização real, tickets e lifecycle compartilhado
permanecem gates E2E abertos. Gate de conhecimento: nenhuma regra de produto
nova; a correção aplica invariantes existentes, sem nova projeção de atividade.
