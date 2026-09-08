---
title: "E2E 3 — handoff de lifecycle Chat, Momentos e Acontece"
source: "Recorte nominal do Coordenador após 4132c0aa; testes root e revisões independentes"
status: "local-green; gates produtivos abertos; not-e2e-complete"
generated_at: "2026-09-08"
---

# Recorte e resultado

Somente consumidores existentes no Superadmin e dependências. Conferidos
resultados tardios, troca A→B, negação, URLs e cache decodificado. Corrigidas
lacunas reproduzidas: Momentos em `7cb636ef`, Acontece em `76a14d73`.
Chat já tinha cobertura equivalente local; nenhum teste duplicado foi criado.
Não foram repetidos os 898 testes do checkpoint anterior.

Os caminhos abaixo são relativos a `apps/superadmin/test/`, exceto o pacote
explicitamente identificado. Os nomes dos arquivos identificam os cenários
mesmo se linhas mudarem em integração posterior.

| Superfície / caso | Evidência existente ou nova | Limite |
| --- | --- | --- |
| Chat: invalidação, imagem presente e cache removido | `features/chat/presentation/superadmin_chat_image_dialog_test.dart:123`; diálogo ativo em :195; ticket expira em :303 | Invalidação local, não logout Auth produtivo |
| Chat: A→B e resposta tardia | Mesmo arquivo :162, :181 e :267; positivo de leitura canônica única em :233 | Fixtures de transporte |
| Chat: callbacks e rotas pendentes | `features/chat/presentation/superadmin_chat_attachment_tile_test.dart:183`, :245, :266 e :288; retry capturado no teste do diálogo :17 | Não há picker/player produtivo novo |
| Chat: composição e sessão | `app/router/superadmin_chat_media_composition_test.dart:17`; `packages/coelo_api/test/media/media_session_test.dart` cobre logout, contexto, purge e falhas | API local de sessão não prova wiring Auth/gateway real |
| Momentos: A→B, load/save/publish tardios | `features/principal_moments_publication/presentation/principal_moments_publication_page_test.dart:78`, :105, :128 e :190 | Controller injetado |
| Momentos: negação de load/save/publish | `features/principal_moments_publication/application/moments_publication_controller_test.dart`; três REDs agora purgam draft e bloqueiam comandos; load autorizado recupera edição | Substituição de referências, não zeroização externa |
| Momentos: bytes/URL já decodificados | `features/principal_moments_publication/presentation/moments_media_cache_lifecycle_test.dart:14`; oito combinações de origem × contexto/dispose/substituição/negação | Cache Flutter sintético, eviction assíncrona |
| Momentos: porta de mídia | Teste da página :359 e :388; callback externo e ausência honesta de integração | Não prova cancelamento de picker real; preview de vídeo indisponível |
| Acontece: A→B e galeria pendente | `features/principal_happens/presentation/principal_happens_productive_feed_test.dart:75`, :115 e :157; leitura positiva :211 | Galeria própria; resposta antiga ignorada |
| Acontece: URL resolvida, TTL e cache | Mesmo arquivo :27; três transições com imagem/cache inicialmente presentes, depois ausentes; nenhuma releitura implícita | Deadline calculada da resposta; não prova expiração server-side |
| Acontece: duração inutilizável | `features/principal_happens/data/supabase_principal_happens_feed_repository_test.dart`; três REDs de expires_in 0/-1/0.5 | Contrato HTTP sintético, sem máximo inventado |
| Acontece: picker tardio e negação | `features/principal_happens_publication/presentation/principal_happens_publication_page_test.dart`; `features/principal_happens_publication/application/happens_publication_controller_test.dart` | Cobertura anterior de callbacks A→B e seis estágios de negação; não reexecutada nesta fatia |

# Verificação desta fatia

- Chat: 73/73 nos testes de diálogo, attachment tile e composição de mídia.
- Momentos: 79/79 publicação, incluindo goldens existentes.
- Acontece: 56/56 funcionais e 10/10 goldens de galeria/vídeo indisponível.
- Analyzer, format, diff e validador visual passaram para os deltas.
- Reviews independentes read-only sem P1/P2. Nenhum PNG atualizado.
- Detalhes das reproduções e limitações nos documentos irmãos
  `2026-09-08-moments-media-lifecycle.md` e
  `2026-09-08-happens-ticket-cache-lifecycle.md`.

# Handoff dos gates exatos

1. M03 continua dependendo de catálogo/gateway e composição nominal, guard
   server-side de AMR/proveniência E1, decoder/entitlement, credenciais e lease
   aprovados. O máximo de imagens por batch Chat ainda exige decisão do Owner.
   Não houve SQL, Scope, decoder, entitlement, R2/Stream real ou novo limite.
2. Logout/revogação produtivos devem conectar Auth, sessão, consumidores e
   reautorização real. Estes testes não provam cache HTTP/browser, download ou
   decode pendente, purge aguardável nem zeroização de cópias externas.
3. Vídeos seguem indisponíveis nos consumidores inspecionados, sem novo player.
   Resume após suspensão real não foi exercitado. Não promover timer local a
   garantia remota ou fixture a upload/reprodução E2E.
4. N01 e demais superfícies originais não foram substituídos por este recorte.
   Replay nominal é exclusivo Eng1; rastreadores e integração são do Coordenador.
   Persistem gates de produção e baselines visuais listados em `plano-visivel.md`.

Esta fatia local está concluída; a vertical original não está entregue E2E.
Memória: correções restaurativas sem decisão nova durável; projeção no-op.
