# Pendentes (lista única — ADR 0045 §7 / CLAUDE.md "Modo de construção")

Uma linha por item: tela · o que falta · quem pediu · data. Apague a linha quando entregar.

- Assiduidade · r12-18 envio final "pessoa sem conta" pela tela; upload do documento depende do CORS (Etapa 4) · Owner · 18/09
- Conta · layout A+ "Meu acesso" (r12-46) · Owner · 18/09
- Segurança da criança · diretório contra a Table canônica (r12-10) · Owner · 18/09
- Perfis de cuidado · spec 065 (wizard Alimentos × Restrições, reordenar, o que fazer) · Owner · 18/09
- Instituições · spec 066 ciclo de vida + status; spec 067 Locais com mapa · Owner · 18/09
- Avisos · spec 069: CTA por tipo tem rota real no Principal só para circular; formulário/convite/aviso ficam na mensagem honesta até existir rota no Principal hospedado (Etapa 4) · Sessão ETAPA-3 · 19/09
- Principal · spec 068 perfis oficiais · Owner · 18/09
- Acessos · acesso contextual: a regra seg–sex 08–18 da "QA R15 Educadora Turma" ficou em produção como dado QA (criada pela tela na prova de 19/09; remover pela tela quando não servir mais) · Sessão ACESSO-CONTEXTUAL · 19/09
- Acessos · acesso contextual: prova da educadora na rota real exige conta de login para uma pessoa de equipe (Owner cria na Auth Admin; "QA R15 Educadora Turma" não tem login); popup/negação provados por pgTAP, widget test e com o espelho interno de qa-r06-principal · Sessão ACESSO-CONTEXTUAL · 19/09
- Acessos · acesso contextual: superfície declarada pelo cliente (`x-coelo-surface`, largura + user agent na inicialização; não muda ao redimensionar; servidor não verifica); app instalado só declara `installed_app` na Etapa 4 · Sessão ACESSO-CONTEXTUAL · 19/09
- Acessos · acesso contextual: sem regra padrão por instituição (só por vínculo); afastamento/regra só via UI de quem tem `staff_access.manage` (institution_admin); um admin pode restringir o próprio vínculo (quem está acima corrige); leitores que juntam `institution_memberships` sem passar por `has_context_permission` (chat/feeds legados) ficam para varredura · Sessão ACESSO-CONTEXTUAL · 19/09
- Acessos · acesso contextual: RPCs contextuais negam com 42501 genérico quando o vínculo está bloqueado (o código STAFF_ACCESS_DENIED sai só em `staff_access_check_v1` e em `list_my_principal_contexts`); sessão já aberta descobre o bloqueio na próxima chamada · Sessão ACESSO-CONTEXTUAL · 19/09
- Tour · textos dos 42 roteiros são propostas (rascunho `tour-telas-rascunho-20260918.md`, fonte executável em `apps/superadmin/lib/app/tour/screens/`): Owner revisa olhando a tela · Owner · 19/09
- Tour · balão "Mensagens" (launcher do chat) fica acima do escurecimento do tour em todas as telas; passos de elementos ausentes (estado vazio, paginação de 1 página, painel sem seleção) somem do tour da tela mas seguem contados no "N" do tour completo (282 declarados, 256 mostrados em 1440) · Sessão TOUR-TELAS · 19/09
- Tour · Planos (dev-only) sem tour por decisão; telas de editar/detalhe (`/…/:id`) e Permissões da Agenda não são destinos do menu e ficam sem tour · Sessão TOUR-TELAS · 19/09
- Fim da Etapa 3 · dez nomes para "Para você" + três instituições fictícias · Owner · 18/09
- Etapa 4 · publicação (host, Auth, CORS, SMTP), apps/admin, apps/principal + spec 064, push preparado, analytics, IA · Owner · ADR 0045
- Imagens · diretórios/cards e cabeçalhos de detalhe ainda mostram placeholder (has_logo/has_cover); mostrar a foto real (RPC em lote `superadmin_entity_images_list_v1` + cache) · Sessão IMAGENS · 19/09
- Imagens · Atividade só aceita foto/capa/ícone depois de criada (o id nasce no servidor via `ActivityFormSubmit` sem retorno); ícone é PNG 512 rasterizado (não SVG); Principal ainda não lê `entity_image_assets` · Sessão IMAGENS · 19/09
- Imagens · CORS do bucket R2 `coelo-media-prod` lista só localhost:3014/3000, 127.0.0.1:3014/3016 e superadmin.coelo.me; o token Cloudflare do wrangler não tem R2 (erro 10000) — não bloqueia mais (bytes passam pela Edge), mas Momentos/Agora/Circulares/Chat/Cardápios ainda fazem PUT/GET direto ao R2 e falham em outra porta · Sessão IMAGENS · 19/09
- Imagens · rascunhos `entity_image_assets` sem upload não têm limpeza (expiram em 30 min só logicamente); worker de expiração como no account-media · Sessão IMAGENS · 19/09
- Review UI · máscara de CEP (CoeloCepInputFormatter 00000-000) em Instituições, Unidades, Pessoas, Locais e Usuários internos: o controller de Instituições valida `^\d{8}$` e o payload vai em dígitos (teste do repositório), então a máscara exige `digits()` no submit/lookup de cada formulário; CNPJ (`CNPJ/documento` da instituição) e moeda/horário sem campo mapeado · Sessão REVIEW-UI r3 · 19/09
- Review UI · previews do Principal (Acontece/Momentos/Agora) com `Colors.white/black` sobre mídia e `fontSize` 7–10: token `CoeloOnMediaColors` em coelo_tokens + `labelSmall`; arquivos principal_* reservados pela MÍDIA-E2E nesta rodada · Sessão REVIEW-UI r3 · 19/09
- Review @ · backend: `set_activity_canonical_handle` monta `stem.unit.slug.institution.slug` (slugs com hífen) enquanto o @ da unidade/turma usa `structure_handle_segment` (sem hífen): o @ da atividade pode não bater com o @ da unidade que a criou; o stem aceita hífen e os outros @ não. Alinhar no servidor (migration + pgTAP) antes de mostrar prévia exata na tela · Sessão REVIEW-UI r3 · 19/09
- Review @ · turma: a prévia do @ padrão mostra `<@ da unidade>` porque `GroupDirectoryFilterOption` não traz o handle da unidade; atividade só mostra o stem (opção de instituição sem slug). Expor `handle`/`slug` nas opções dos formulários para prévia completa · Sessão REVIEW-UI r3 · 19/09
- Review UI · `shell_profile_summary` (avatar) e o hue wheel do seletor de cor (institution_form_sections) mantêm `Colors.white/black` por serem cor livre do usuário/mídia; `superadmin_chat_emoji_picker` fontSize 24 do emoji · Sessão REVIEW-UI r3 · 19/09
