---
source: "recovery-knowledge-proposal.md; ADR 0019; spec Auth-first 2026-09-01; D00 r18; browser-b4-static-receipt.md; integrated-auth-boundary-46-pass.log"
status: "evidence-only-proposed-patch; pending-D00-reservation-review-and-application"
generated_at: "2026-09-09"
---

# Consolidação proposta de memória Auth

[Patch revisável](recovery-knowledge-consolidation-proposed.patch), gerado contra os dois arquivos atuais do checkout D00. Nenhuma fonte canônica ou projeção foi alterada. Aplicar primeiro o aditivo da spec e depois o artigo, somente após reserva/revisão D00. O texto documenta comportamento e evidência locais; não registra aprovação nova. Ajustar updated_at se a aplicação ocorrer em outra data.

Bases RAW SHA256:

- `docs/superpowers/specs/2026-09-01-superadmin-auth-first-local-green-design.md`: `B56E1198079166123C145E55D6ED7687E39C6CEB01DBBBA33A9AA02233F2F394`.
- `docs/knowledge/team/superadmin-internal-users.md`: `A4422972FC103A2E495030F88736DEC8193BC1F264A7303FE2388D92DAD5C70E`.

A projeção ainda generaliza o preview histórico e exclui recovery/reset do contrato aprovado, apesar da autorização local expressa de 01/09. O patch reutiliza o delta anterior e qualifica a prova atual de armazenamento falho e backend local. Separa contenção em memória, falha de remoção, autorização backend e disponibilidade produtiva. Não confunde reinicialização em teste Flutter com reinício do sistema operacional ou falha real no navegador; B4 usa HTTP sintético.

Somente um aditivo Auth na spec e o parágrafo Auth final do artigo, mais updated_at, mudam. O conteúdo D04 anterior, knowledge_id, audiência, visibilidade e fonte principal ADR 0019 permanecem preservados. A projeção referencia a spec complementar por caminho relativo. Não amplia convite, outros apps, MFA ou autorização remota.

Skill coelo-knowledge lida. A busca somente leitura com `.agents/skills/coelo-knowledge/scripts/Search-CoeloKnowledge.ps1 -Query 'recupera' -Audience team -Detailed` encontrou o artigo vigente. Uma tentativa anterior usou incorretamente scripts/ na raiz; o caminho foi corrigido sem instalar dependências. Fontes e projeção foram comparadas diretamente.

Nenhum validador foi executado contra o patch não aplicado; nenhum teste, SQL ou comando remoto foi executado. Após aplicar fonte e projeção, D00 executa os wrappers scripts/Test-CoeloKnowledge.ps1 e tests/Test-CoeloKnowledge.ps1 da skill na base entregue. Esses gates validam conteúdo estruturado e ferramenta, não produção. Captura neste turno: apenas o delta proposto; memória efetiva pendente.

Revisão primária 16:43 BRT: motivo auditado corrigido para SAI_SESSION_INVALID e reinicialização descrita como SDK/scope/rotas, preservando os limites da prova. git apply --check contra a raiz D00 retornou exit0; patch permanece NÃO APLICADO. Isso comprova aplicabilidade textual, não validação da memória final.
