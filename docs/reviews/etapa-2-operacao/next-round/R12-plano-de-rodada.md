---
source: Owner 2026-09-13 — consolidar R12/R13 como R12, Luna médio, commits e pendências
status: pronto para início manual; execução não iniciada nesta consolidação
generated_at: 2026-09-13
---

# R12 — Plano único para Luna médio

Fonte: R12-consolidacao.md e catálogo53 itens. Entregues07/41/43 não devem ser
refeitos. Cinquenta abertos, incluindo52 parcialmente implementado; R13 é nome
histórico. Apps/superadmin, Etapa2; Coelo (Principal) é menu, não outro app.

1. Confirmar checkout dev/remoto, ausência de outro executor, cota e slots reais.
2. Primeiro trabalho: R12-52/chat.attach; preservar código e29 testes válidos, comparar referência aprovada e construir/provar rota normal. Fechar o primeiro aceite faltante, sem envio a terceiros.
3. Se bloqueado, seguir imediatamente a item independente, como R12-44 (Convites somente tabela, sem depender de SMTP), ou outro primeiro gate do catálogo por dependência real.
4. Gate51: conferir regra vigente/PITR/backup/ordem sem contornar. Só seus dependentes46/48/49/50 esperam. Auth47/reenvio45 dependem de entrega real; não simular SMTP com Admin API.
5. Continuar rotina/assiduidade, segurança/cadastro, perfis/permissões, saúde/medicação, cardápios, editor de formulários/Agenda e demais aceites. Não implementar decisões não aprovadas.
6. Após tudo viável da lista, seguir primeiros gates independentes conhecidos da Etapa2 até o corte. Condição do item53 continua valendo; não expandir Etapa3.

Cada fatia termina em mudança/prova concreta, atualização de MDs/matrizes,
commit/push. Bloqueio isolado não encerra a rodada. Reusar testes válidos,
repetir só por impacto material. Ao aproximar da cota, atualizar pendências,
skills, memória e gate antes de fechar. R14 Claude Opus médio fica preparada
conforme o pedido anterior, sem execução automática. Estimativa Claude12%
de utilização é informação do Owner, a medir na futura abertura.
