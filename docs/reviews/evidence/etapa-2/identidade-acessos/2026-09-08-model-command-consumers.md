---
title: "Modelos — regressão dos consumidores após envelopes"
source: "Continuação nominal do Coordenador após integração e20f2a3a como b3294c47; testes locais e revisão account_review/realm_audit"
status: "local-consumer-green; runtime-and-production-open"
generated_at: "2026-09-08"
---

## Recorte e resultado

Base local e20f2a3a. Nenhum código produtivo foi alterado nesta rodada.
Regressão dos consumidores existentes: **57/57 PASS**, exit0, nos oito arquivos:

- features/access_profiles/presentation/access_profile_pages_test.dart;
- presentation/access_profile_form_continuation_test.dart;
- presentation/access_profile_detail_context_test.dart;
- presentation/access_profile_view_model_test.dart;
- features/access_profiles/data/access_profile_model_repository_adapter_test.dart;
- app/router/access_profile_routes_test.dart;
- app/router/access_profile_editor_authorization_test.dart;
- app/router/access_profile_authorization_revision_test.dart.

Todos sob apps/superadmin/test; os três caminhos presentation abreviados
pertencem a features/access_profiles. Comando flutter test --no-pub seguido
dos oito caminhos, via RTK, cwd apps/superadmin. Nenhuma regressão produtiva
foi reproduzida nesse conjunto. Não somar aos testes de dados anteriores ou
aos 161 reportados pelo Coordenador na main: bases/conjuntos são distintos.

## Nova prova local de consumo

Arquivo presentation/model_command_consumer_test.dart: **9/9 PASS** em
execução final completa, exit0. São widgets reais de formulário/duplicação/
detalhe → AccessProfileModelRepositoryAdapter → SupabaseAccessProfileRepository
→ MockClient em memória, sem Supabase ou HTTP de rede.

| Ação | Asserção nova |
|---|---|
| Criar e editar | Cada envelope de sucesso chega ao callback uma vez, com ID/versão; negação não chama callback e mostra aviso local |
| Duplicar | Uma chamada nominal; sucesso chega ao callback, negação permanece erro visível sanitizado |
| Excluir | Uma chamada nominal; somente receipt válido aciona onDeleted; negação não aciona sucesso |
| Editar com conflito | SAI_CONCURRENT_CHANGE abre diálogo; recarregar faz segunda leitura sem novo write/callback |

Primeiras tentativas não foram REDs de produto: fixture tinha código/descrição
inválidos, criação tinha número errado de passos, ciclo SDK tinha timer no
fake-async e o teste tentava pumpAndSettle durante o diálogo com save pendente.
Corrigidos somente fixture, ciclo de teste e espera do diálogo. SDK criado e
destruído fora da zona fake-async, auto-refresh desabilitado no teste.
Não enfraquecer validação da UI ou remover guard produtivo para contornar isso.

Analyzer focal sem problemas. Review account_review sem bloqueantes,
confirmando a cadeia e os limites. Não prova payload dos comandos (coberto
na suite de dados anterior), draft preservado após reload, router, sessão,
autorização ou persistência real. Não é verified-e2e.

## Revisões paralelas e próximos gates

account_review não encontrou impacto do decoder em Conta/settings: consumidores
e controllers independentes. realm_audit não encontrou impacto em Usuários:
SupabasePlatformUserRepository usa RPCs/decoder próprios. São conclusões
estruturais restritas, sem nova certificação das duas superfícies.

Coordenador informou parecer Eng2: platform.read e agregações limitadas à
instituição autorizada; a visibilidade de definições globais não usadas nessa
instituição permanece aberta. Proposta de Perfis refinada sem inventar regra,
grant ou SQL. Runtime Users/Models continua aguardando janela/seed nominal
Eng1; Conta e hook de mídia mantêm suas dependências. Visual continua aberto.

Plano por tela atualizado neste turno. Nenhum rastreador oficial alterado.
Gate de memória no-op: testes de contratos existentes e proposta pendente,
sem nova decisão de produto capturada.
