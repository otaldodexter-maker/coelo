---
source: Owner 2026-09-13; R11-prompt-unico.md; Git e quota reais
status: execução R11 em andamento
generated_at: 2026-09-13
---

# R11 — checkpoint C0

T0 real: 2026-09-13T10:47:39-03:00. Base HEAD=origin/dev 1d2f95b5942f5aab23439151b57853dd3180b041 após fetch. Destino e única worktree: C:/Users/adrie/Documents/Coelo, dev. Escritor/integrador C0 /root; execução serial, sem auxiliares. Status inicial limpo; stash vazio. Refs históricas preservadas conforme R10-consolidacao, sem reabrir R10.

Quota U0=87% usados, indicador codex primary, janela 10080 minutos, reset epoch 1789820315 (2026-09-19T12:18:35+00:00). Teto min(87+12,98)=98%; congelar novas fatias em95%; alvo fechar até97%. Medir a cada10min, entrega e antes de build. Limite execução13:47:39BRT, fechamento14:17:39BRT; cota prevalece, reset não estende rodada.

Runtime preservado: PID17204, Python serve.py, build apps/superadmin/build/principal-pos-r10, origem http://127.0.0.1:3000. Código build01833e90b, hash a conferir antes de prova. Chrome Owner PID18924 preservado; slot Chrome QA C0 reservado, ainda sem PID. Slot flutter test C0 reservado e ocioso; dart17780 é MCP, não teste. Nenhum processo encerrado.

## Contrato e pendências

Objetivo: maior conjunto coerente no corte, apps/superadmin > Conta/Meu perfil (família Perfil/Configurações, rodapé Criar/Editar Instituição), Auth e Estrutura > Atividades/Avaliações/Turmas. Ordem A0 account.profile; A auth.recover/auth.reset (inspeção até20min sem evidência nova); B activities.assessment/activities.publish; C assessments.entry/gradebook/detail/close/reopen; D groups.list independente pode antecipar. Só uma vizinha institutions.status ou institutions.locations-map se tudo fechar com margem.

Conta: foto no editor/header com sigla relatados; nome suspeito e cor relatada, ainda sem reprodução após Save/reload. Rodapé e Meu acesso longos requerem correção focal. Auth: SMTP/link real/nova sessão/expiração e uso único sem certificado. Atividade UPDATE draft b04c879e retorna SAI_INTERNAL_ERROR; diário d2c945d8 sem participantes apesar de vínculos; Turmas contadores0. Reutilizar IDs completos das evidências; não recriar nem reaplicarSQL61/62/63.

Provas: rota normal, salvar e reload no mesmo recurso, negação RLS pertinente, testes focais causais; FE/BE/E2E separados. Nenhum aceite novo na abertura. Estimativa do delta ainda não calculável antes de reprodução; janela é limite, não estimativa. Primeiro gate C0: reproduzir Conta no build preservado, inspecionar controller/repository/header e catálogo de capacidades. WIP inicial nenhum; leituras e inventário focal em andamento.

Fora: R12, Etapa3, auditoria231ações, redesign Chat. Preservar direção/anexos via docs/design/chat-media-composer-owner-reference-20260913.md; preservar Principal-pos-R10 e pendências próprias. SQL somente forward, pgTAP/ordem/PITR conforme pedido atual; nenhum remoto alterado na abertura.
