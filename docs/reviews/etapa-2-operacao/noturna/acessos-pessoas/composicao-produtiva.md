---
source: "coordenacao r11 PERGUNTA-DE-COMPOSICAO-PRODUTIVA; dev f6859fbcad74104632ac53962f317d45e57a8b98, leitura somente; branch acessos c8c8b0fba"
status: "respostas estaticas; sem promocao de estado ou prova runtime"
generated_at: "2026-09-09"
---

# Tres respostas sobre a composicao de Acessos e Pessoas

Recorte exclusivo apps/superadmin. Leitura focal da base integrada em resposta
ao requisito coordenado; nao e auditoria nova nem execucao da aplicacao.
`main.dart:51-74` passa os providers de authScope ao SuperadminApp; o app repassa
ao router e cria ChildSafetyController com o repository recebido.

| Tela / action_ids | main compoe? | Router monta pagina produtiva? | Implementacao real existe? |
| --- | --- | --- | --- |
| Pessoas:people.list/create/edit/links/reload | Sim:directory e detail; identity lookup recebe Unavailable | Diretorio normal montado com onCreate/onEdit nulos; detalhe normal usa reader. Criar/editar ficam bloqueados pelo gate de mutacao | SupabasePersonDirectoryRepository legado e SupabasePersonDetailReader existem. PersonIdentityRepository produtivo nao composto. Diretoria/escrita nao se tornam qualificadas pela consulta v2 da spec046 |
| Perfis:access-profiles.list/create/detail/edit/assign/delete | Sim:SupabaseAccessProfileRepository | Diretorio, formulario e detalhe normais existem. O guard geral exclui /profiles; formulario renderizado nao e prova de comando autorizado | Adapter real existe, com contratos mistos/legados. Visibilidade institucional, comandos internos, persistencia e personas continuam gates. Os testes de formulario usam FakeAccessProfileRepository |
| Modelos:access-models.list/filter/create/detail/edit/duplicate | Sim:pelo mesmo SupabaseAccessProfileRepository, que implementa AccessProfileModelRepository | Adapter de telas produtivo montado quando interface real existe; duplicar exige dominio/capacidade e recusa demo. /profile-models tambem esta fora do gate geral | Adapter real existe e pacote nominal foi qualificado localmente95+6P; fundacao remota continua ausente/sem autorizacao. Existencia do adapter nao prova RPC nominal remota |
| Convites:invites.list/create/detail/resend/revoke | Sim:SupabaseInviteRepository | Rotas normais e comandos permitidos somente com provider nao Unavailable; confinamento R02 preservado | Implementacao real existe. Personas, envio SMTP, persistencia/recarga e negativas reais permanecem sem prova nominal; nenhum convite foi enviado por este grupo |
| Usuarios internos:internal-users.list/create/edit/suspend/mfa | Sim:SupabasePlatformUserRepository | Lista/detalhe normais exigem provider nao demo e platform.member.read. Criar/editar retornam indisponibilidade; nenhuma escrita normal liberada | Repository real de leitura existe. Criacao/convite/suspensao interna nao qualificados. MFA permanece gate adiado conforme ADR0019 |
| Safety:child-safety.list/child/create/edit/suspend | Sim, mas ainda SupabaseChildSafetyRepository LEGADO | Lista/detalhe normais usam esse controller; onCreate/onExport nulos. Guard de rota e suporte explicito bloqueiam mutacoes reais | Adapter legado existe. SupabaseInternalChildSafetyRepository candidato v2 existe, mas NAO e composto em authScope.41P HTTP e89P de composicao nao comprovam v2 em producao |
| Arquivos:profile-files.import/preview/confirm/status/export/download | Nao ha pipeline produtivo de arquivos de perfil; tela herda composicao de Perfis | Acoes visiveis Importar/Exportar CSV/Exportar XLSX com callbacks nulos; nao ha picker/job/persistencia | Indisponibilidade e politica pos-MVP, nao trabalho de backend certificado. Nao implementar pipeline por inferencia |

Fontes precisas na base observada:

- `apps/superadmin/lib/core/config/superadmin_auth_scope.dart:278,362-389`: providers Supabase e identidade indisponivel; Safety usa classe legada.
- `apps/superadmin/lib/app/superadmin_app.dart:270,291-320`: controller e repasse ao router.
- `apps/superadmin/lib/app/router/superadmin_router.dart:2535-2602`: Pessoas/Safety, callbacks nulos e controller resolvido.
- Mesmo router:2612-2672 Usuarios internos;2678-2755 Pessoas criar/editar/detalhe;2765-2958 Perfis/Modelos, incluindo guarda propria da duplicacao;4740-4778 Convites.
- Mesmo router:722 e5496-5501: gate geral e excecao de Perfis/Modelos. Nao confundir formulario que abre com contrato de escrita qualificado.
- `apps/superadmin/lib/features/access_profiles/presentation/access_profile_directory_page.dart:425-449`: acoes de arquivo sem callback.
- `apps/superadmin/lib/features/safety/data/supabase_child_safety_repository.dart:16-95`: RPCs legadas; adapter v2 em arquivo separado nao e usado por authScope.

Conclusao do recorte: implementacoes reais existem em varias telas, mas
composicao, contrato interno, provedor remoto e prova de persistencia sao gates
distintos. Nenhuma das31 acoes ativas e promovida. Propostas permanecem
pending-verification ou blocked-environment;6 adiamentos e1 gate MFA preservados.
Nao houve mudanca em main/router, replay, backend remoto, skills ou politica.
