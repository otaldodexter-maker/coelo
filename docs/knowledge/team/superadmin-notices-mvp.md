---
title: Comunicações do app no Superadmin
knowledge_id: superadmin-notices-mvp
source: docs/superpowers/specs/2026-08-05-superadmin-notices-mvp-design.md
status: validated
generated_at: 2026-08-20
updated_at: 2026-09-03
audience: team
surfaces: [superadmin, notices]
visibility: internal
review_owner: Coelo Product
---

# Comunicações do app no Superadmin

O módulo visualmente chamado `Comunicações do app` evolui a tela de Avisos sem
substituí-la por um CMS. Ele gerencia quatro tipos fechados: `Aviso`,
`Conteúdo`, `Destaque` e `Para você`. Prioridade, público, vigência e
recorrência são comuns; comportamento, tamanho, inset e aparência de popup são
exclusivos de Aviso. Valores legados de popup/notice continuam sendo lidos como
Aviso e `content_card` como Conteúdo.

O operador pode mudar o tipo enquanto o item estiver editável (rascunho,
agendado ou pausado). Sair de Aviso remove configurações exclusivas de popup;
voltar para Aviso exige configuração válida antes da publicação.

Avisos oficiais da plataforma são diferentes dos avisos familiares de
assiduidade. O módulo permite que equipe Coelo autorizada escolha `Todos` ou
uma variação controlada de instituição, unidade, turma ou pessoa. A variação
aceita múltiplos recursos ou todos os resultados de um filtro autorizado, com
papel opcional. Audiência e autorização produtivas são sempre resolvidas e
congeladas server-side.

O MVP usa um construtor controlado em cinco etapas: identidade; conteúdo e
aparência; público e dispositivos; exibição e recorrência; revisão e
publicação. A composição de texto configura fundo, texto e CTA, contraste,
tamanho compacto/padrão/expandido/tela cheia e inset externo. A prévia Web,
Tablet e Mobile usa a mesma superfície do popup entregue.

O destino é uma escolha única entre web, mobile, tablet ou todos. A vigência
pode ter início e fim, com recorrência única, diária, semanal, mensal por dia do
mês ou por intervalo inteiro de dias. Os estados são
rascunho, agendado, ativo, pausado, expirado e inativo.

O aviso pode ser dispensável, exigir confirmação ou exigir checkbox de ciência
seguido de confirmação. Aviso obrigatório reaparece até o aceite e pode
bloquear a navegação, mas nunca impede a saída do app. Conteúdo crítico é
separado de conteúdo opcional silenciável.

No diretório e na revisão, Aviso mantém a prévia real de popup. Conteúdo,
Destaque e Para você usam card administrativo neutro e tipado; essa prévia não
define nem simula a futura superfície do app Principal.

O diretório não oferece uma escolha entre Cards e Tabela. Tablet e desktop
usam a tabela administrativa de Instituições; no mobile, os mesmos registros
se reorganizam automaticamente em uma lista vertical compacta. Essa adaptação
responsiva não cria um segundo modo selecionável pelo operador.

No mobile, a criação aparece como tile e os registros como cards compactos. Em
tablet e desktop, a criação ocupa uma faixa própria acima da tabela, sem botão
laranja isolado no topo. Toolbar, filtros, respiro, tabela, status e paginação
reutilizam literalmente Instituições. Tipos usam badges uniformes e alinhados.
No desktop, o preview ocupa um contêiner auxiliar único, com hierarquia,
paddings, raios e gaps tokenizados, sem competir com a tabela.

Métricas básicas agregam alcance, entrega, visualização e aceite. Auditoria
registra apenas resumos minimizados das mutações, sem PII, destinatários, mídia
ou mensagem integral.

Produção usa Supabase por interface assíncrona, RLS deny-by-default, comandos
idempotentes e auditados e publicação em lotes. Fakes e métricas inventadas
ficam apenas em testes isolados. Imagem usa Cloudflare R2 privado durante o MVP
e permanece bloqueada somente até existir o Media Gateway autorizado;
Supabase guarda metadados, autorização e auditoria. Não há placeholder
demonstrativo.
Também não se autoriza editor livre, HTML, carrossel, jornadas, gatilhos
comportamentais, regras booleanas livres, A/B testing, personalização,
localização ou analytics avançado.

Publicar não ativa o item diretamente: congela a audiência e cria um job. Um
cron versionado chama o worker server-side, que resolve destinatários em lotes
e ativa a comunicação somente após a materialização completa. Leases expiradas
são recuperáveis; versões obsoletas e itens pausados falham fechados. O receipt
nasce sem `delivered_at`, preenchido apenas quando houver entrega real.

Cada materialização fica vinculada ao job e à versão publicados. A comunicação
aponta para sua publicação corrente, e alcance, entrega, visualização e aceite
consideram somente os receipts dessa geração. Republicar mantém as gerações
anteriores como histórico, sem misturar audiência ou métricas; vigência já
encerrada falha antes de materializar ou ativar.
