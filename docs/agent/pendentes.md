# Pendentes (lista única — ADR 0045 §7 / CLAUDE.md "Modo de construção")

Uma linha por item: tela · o que falta · quem pediu · data. Apague a linha quando entregar.

- Assiduidade · r12-18 envio final "pessoa sem conta" pela tela; upload do documento depende do CORS (Etapa 4) · Owner · 18/09
- Conta · layout A+ "Meu acesso" (r12-46) · Owner · 18/09
- Segurança da criança · diretório contra a Table canônica (r12-10) · Owner · 18/09
- Perfis de cuidado · spec 065 (wizard Alimentos × Restrições, reordenar, o que fazer) · Owner · 18/09
- Instituições · spec 066 ciclo de vida + status; spec 067 Locais com mapa · Owner · 18/09
- Avisos · spec 069 duplicar/CTA/atualização · Owner · 18/09
- Principal · spec 068 perfis oficiais · Owner · 18/09
- Acessos · acesso contextual: prova da educadora na rota real exige conta de login para uma pessoa de equipe (Owner cria na Auth Admin; "QA R15 Educadora Turma" não tem login); popup/negação provados por pgTAP, widget test e com o espelho interno de qa-r06-principal · Sessão ACESSO-CONTEXTUAL · 19/09
- Acessos · acesso contextual: superfície declarada pelo cliente (`x-coelo-surface`, largura + user agent na inicialização; não muda ao redimensionar; servidor não verifica); app instalado só declara `installed_app` na Etapa 4 · Sessão ACESSO-CONTEXTUAL · 19/09
- Acessos · acesso contextual: sem regra padrão por instituição (só por vínculo); afastamento/regra só via UI de quem tem `staff_access.manage` (institution_admin); um admin pode restringir o próprio vínculo (quem está acima corrige); leitores que juntam `institution_memberships` sem passar por `has_context_permission` (chat/feeds legados) ficam para varredura · Sessão ACESSO-CONTEXTUAL · 19/09
- Acessos · acesso contextual: RPCs contextuais negam com 42501 genérico quando o vínculo está bloqueado (o código STAFF_ACCESS_DENIED sai só em `staff_access_check_v1` e em `list_my_principal_contexts`); sessão já aberta descobre o bloqueio na próxima chamada · Sessão ACESSO-CONTEXTUAL · 19/09
- Tour · textos dos 42 roteiros são propostas (rascunho `tour-telas-rascunho-20260918.md`, fonte executável em `apps/superadmin/lib/app/tour/screens/`): Owner revisa olhando a tela · Owner · 19/09
- Tour · balão "Mensagens" (launcher do chat) fica acima do escurecimento do tour em todas as telas; passos de elementos ausentes (estado vazio, paginação de 1 página, painel sem seleção) somem do tour da tela mas seguem contados no "N" do tour completo (282 declarados, 256 mostrados em 1440) · Sessão TOUR-TELAS · 19/09
- Tour · Planos (dev-only) sem tour por decisão; telas de editar/detalhe (`/…/:id`) e Permissões da Agenda não são destinos do menu e ficam sem tour · Sessão TOUR-TELAS · 19/09
- Fim da Etapa 3 · dez nomes para "Para você" + três instituições fictícias · Owner · 18/09
- Etapa 4 · publicação (host, Auth, CORS, SMTP), apps/admin, apps/principal + spec 064, push preparado, analytics, IA · Owner · ADR 0045
