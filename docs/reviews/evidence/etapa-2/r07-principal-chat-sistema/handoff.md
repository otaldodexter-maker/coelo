# Handoff R07 · Principal, Chat e Sistema

## Identificação

- Rodada: `E2-R07-20260911`
- Frente: `Etapa 2 -> apps/superadmin -> menu Coelo (Principal) -> Publicação, Cardápios, Perfil, Chat e páginas de erro`
- Branch publicada: `work/etapa2-r07-principal-chat-sistema`
- SHA publicado no início do fechamento: `244fed7b001e3128cd898642fe833de1b032daf4`
- Worktree: `C:/Users/adrie/Documents/Coelo.worktrees/e2-r07-principal-chat-sistema`
- JSON final da frente: `docs/reviews/etapa-2-operacao/comunicacao/principal-chat-sistema.json`

## Estado entregue

- Suítes locais de Cardápios, Perfil, erros, publicadores e idempotência: `97/97` verdes na regressão curta registrada na revisão 47.
- Repositories de Acontece, Momentos e Agora + idempotência: `16/16` verdes.
- Correção publicada em Momentos: o PUT para a URL assinada R2 reforça `content-type` com o MIME do rascunho.
- Erros 403/404/500/503: suíte local `14/14` verde; a expectativa obsoleta de `/profile` foi removida do loop de erro indisponível porque Perfil possui rota produtiva própria.
- Servidor estático local respondeu HTTP 200 em `127.0.0.1:3009`.

## Estado integrado e evidências

- Nenhum `verified-e2e` novo foi declarado nesta R07: o Chrome/CDP expirou antes de entregar snapshot/interação. Não há capturas de rota real nem CRUD/reload real nesta frente.
- `docs/reviews/evidence/etapa-2/r07-principal-chat-sistema/deltas-r07-pcs.json` permanece vazio (`[]`); não foi proposto delta de rastreador sem prova integrada.
- O JSON separa explicitamente testes locais verdes de E2E pendente e registra o bloqueio de ambiente.

## Pendências e primeiro gate

1. `acontece.create/publish`, `momentos.create/publish/remove`, `agora.create/publish/expire` com mídia: primeiro gate é recuperar uma sessão Chrome/CDP controlável, dirigir a rota normal, capturar prepare/PUT/finalize/read e validar reload; Stream continua exclusivo do Agora conforme contrato.
2. `meal-plans.create/edit/publish`: primeiro gate é executar a tela contra produção após o pacote `130500` estar aplicado/confirmado pelo coordenador.
3. `errors.403/409/500/503/retry`: primeiro gate é exercitar a rota normal; a suíte local não substitui a prova de produção.
4. `principal.profile-edit`: primeiro gate é abrir a rota produtiva, salvar e recarregar.
5. V-3 restante e V-1 condicionado à resposta Owner P54=A: primeiro gate é decisão/rota real correspondente.
6. `chat.create-group` e `chat.attach`: primeiro gate é a UI real; não foram iniciados.

O delta restante é um bloco de validação E2E condicionado à recuperação do Chrome/CDP, seguido apenas pelos gates independentes acima. Não há estimativa horária confiável enquanto o bloqueio de ambiente persistir.

## Dados sintéticos e segredos

- Arquivo de credencial usado: `C:/Users/adrie/Documents/Coelo-backups/qa-r06-principal.env`; nenhum valor foi impresso, versionado ou copiado para evidência.
- Dados sintéticos previamente existentes e reutilizados: modelo de Cardápio `d132698c`, rascunho de Momentos `b173843d`, instituição `d0c40000-0000-4000-8000-000000000001`.
- Assets sintéticos previamente preparados: `708456ae`, `24868396`; asset R2 finalizado por sonda: `8064d199`, no bucket privado `coelo-media-prod`.
- Nenhuma chave, segredo, bucket, Worker ou Edge Function novo foi criado nesta frente; nenhum deploy remoto foi executado.

## Retenção e integração

- Não há alterações locais fora dos commits publicados; não há stash.
- Não há candidato SQL R07 novo nesta frente.
- A frente não escreveu `dev`, inventário ou rastreadores.
- A worktree pode ser removida somente depois de o coordenador integrar/conferir a branch e preservar o SHA publicado; não há WIP local a perder.
- Busca no inventário de evidências encontrou handoffs de R03–R06 em outras frentes, o handoff R06 desta frente e nenhum handoff R01/R02/R07 anterior; este arquivo fecha o handoff R07 desta frente.
