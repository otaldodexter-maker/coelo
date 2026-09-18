---
title: "Rodada 6 — perguntas ao Owner (noite de 11/09/2026)"
source: "coordenacao.json revs 52-60; JSONs das sete frentes; R06-fechamento.md"
status: "open"
generated_at: "2026-09-11"
timezone: "America/Sao_Paulo"
---

# Perguntas ao Owner — Rodada 6

Responder em lista "Pnn - opção, observação". Nenhuma pergunta bloqueia a
R07: cada uma tem o caminho que o coordenador segue se não houver resposta.

| ID | Frente | Pergunta | Opções | Sem resposta |
| --- | --- | --- | --- | --- |
| P51 | acessos-pessoas | Criar usuário interno pela tela envia e-mail de definição de senha. O SMTP padrão do Supabase só entrega a membros do time do projeto. Configurar SMTP próprio (Resend/Brevo, nível gratuito) agora? | A) sim, o coordenador cria a conta gratuita e grava o segredo (sem custo); B) depois do MVP: o operador copia o link de definição de senha gerado pelo Auth Admin (`generate_link`) e entrega por outro canal | B |
| P52 | coordenação | O deploy da Edge Function `internal-user-create` foi bloqueado na sessão do coordenador (usa `service_role`/`auth.admin.createUser`). Quem faz? | A) o Owner roda `supabase functions deploy internal-user-create --project-ref evvbomzejfijozbtgvpt --workdir packages/coelo_database` depois de acrescentar `[functions.internal-user-create] verify_jwt = false` ao `config.toml`; B) o coordenador da R07 tenta de novo (pode ser bloqueado outra vez) | B, com A registrado na skill |
| P53 | estrutura | Os 9 goldens de `activity_golden_test` já falhavam antes da R05. A diferença é o launcher "Mensagens" inteiro no diretório de Atividades. Regravar com o launcher atual? | A) sim, o launcher atual é o aprovado; B) não, manter o golden e registrar | B (registrado) |
| P54 | principal-chat-sistema | V-1 restante: avatar do Perfil abre o Agora do perfil e ganha contorno em degradê laranja quando há Agora não visto. Fica na R07 ou depois do MVP? | A) R07; B) depois do MVP | B |
| — | encerramento do MVP | Lista de palavras proibidas como @ e lista de @ que só o Owner usa (pendência da R05). | definir no encerramento | mantém reservados `coelo` e `coelo.me` |

Sem página visual nesta rodada: as telas da família Publicação (Circular,
Evento, Acontece, Agora, Momentos) foram reconstruídas sobre as referências
aprovadas às 17:19 e a comparação R/A com o render real fica para a R07,
quando a prova de publicação com mídia existir.
