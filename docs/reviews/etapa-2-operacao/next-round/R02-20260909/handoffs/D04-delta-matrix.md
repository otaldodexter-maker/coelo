---
source: "R02 escopo.json D04; inspeção e evidências nos handoffs D04"
status: "proposed-to-D00; not-integrated; no-new-certification"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Delta nominal D04 para o escritor central

Base56eb3f19, revisão3 de16:10 BRT; HEAD publicado4bfbbddfe. App único: apps/superadmin.
Menu Acessos para todas as linhas exceto invites.*, em Comunicação.
As provas locais não encerram FE/BE/E2E de nenhum dos31IDs ativos.
Patches de rotas são propostas não aplicadas, sem reserva D00.

| action_id | Subtela/estado; delta local | Primeiro critério aberto |
| --- | --- | --- |
| people.list | Diretório: descarte de busca anterior/dispose comprovado | Contrato interno de listagem e filtros server-side |
| people.create | Formulário: nome legal opcional;recibo impede segunda criação se navegação falha | Write interno aprovado e identity repository |
| people.edit | Formulário: nome legal opcional;recibo preservado no retry;capturas375 claro/1440 escuro | Write interno e persistência/recarga real |
| people.links | Vínculos: sem delta funcional | Contrato interno de vínculos e negações |
| people.reload | Diretório: lifecycle comprovado | Leitura interna real com filtros e reautorização |
| access-profiles.list | Catálogo: busca preserva loading/failure e termo vigente na resposta | Decisão sobre visibilidade global institucional e ACL/helpers |
| access-profiles.create | Sem delta próprio certificado | Contrato de gravação e provas por ator |
| access-profiles.detail | Sem delta próprio certificado | Reader autorizado do perfil real |
| access-profiles.edit | Formulário compartilhado preservado | Write e recarga autorizados por ator |
| access-profiles.assign | Sem delta funcional | Contrato de atribuição e escopo real |
| access-profiles.delete | Sem delta funcional | Negações, dependências e delete autorizado |
| access-models.list | Adapter preserva domínio e contexto | Runtime real e aplicação nominal do pacote |
| access-models.filter | CSV union antes cursor, allowlist;15SQL P | Aplicar SQL nominal antes de publicar cliente CSV |
| access-models.create | Principal mapeia group para child_context; menu limitado | Composição e persistência real |
| access-models.detail | Capabilities não viram contagem de vínculos | Runtime autorizado e visual |
| access-models.edit | Escopo Principal e contagem corrigidos | Persistência/recarga real por ator |
| access-models.duplicate | Adapter corrigido; rota proposta separada | Reserva D00 para callback/rota e teste de composição |
| invites.list | Debounce invalida retorno anterior;negação de leitura descarta comandos/overlays | Runtime do diretório com persona qualificada |
| invites.create | Wizard invalida contexto e preserva seleção | Persona/SMTP e envio real nominal |
| invites.detail | Link HTTPS/origem/token restritos | Reserva D00 para allowCommands da rota normal |
| invites.resend | Receipt tardio após negação descartado;callback antigo não reenvia | Composição normal e envio nominal autorizado |
| invites.revoke | Comando existente; nenhuma mutação remota | Composição normal, revogação e recarga reais |
| child-safety.list | Candidato held-golden adc902eaf: epochs/count;SQLv2 candidato48141c195 U43;adapter963796ddf 34P inativo | Revisar golden;replay/decisão nominal SQL interno;FEv2 não ativado |
| child-safety.child | Contexto ausente não usa unidade alheia;read interno candidato U43;adapter estrito34P sem ativação | Replay/decisão nominal SQL interno;runtime/FEv2 não ativado |
| child-safety.create | Candidato held-golden adc902eaf: erros e lookup assíncrono protegidos | Lookup adulto minimizado autorizado e realm interno |
| child-safety.edit | Candidato held-golden adc902eaf: somente pending; identidades imutáveis | Contrato interno e recarga real |
| child-safety.suspend | Candidato held-golden adc902eaf: falha de refresh não repete comando | Realm interno e prova de suspensão real |
| profile-files.import | Adiado; certificado FE anterior preservado | Decisão pós-MVP |
| profile-files.preview | Adiado; sem implementação real | Decisão pós-MVP |
| profile-files.confirm | Adiado; sem implementação real | Decisão pós-MVP |
| profile-files.status | Adiado; sem implementação real | Decisão pós-MVP |
| profile-files.export | Adiado; certificado FE anterior preservado | Decisão pós-MVP |
| profile-files.download | Adiado; sem implementação real | Decisão pós-MVP |
| internal-users.list | Parser rejeita status desconhecido; navegação proposta | Reserva D00 para entrada normal e runtime |
| internal-users.create | Receipt impede duplicação;catálogo real ausente não usa instituições fictícias | Contrato nominal de criação/convite |
| internal-users.edit | Negação limpa editor;receipt protegido;catálogo ausente preserva escopo;capturas375/1440 | Rota normal de escrita bloqueada |
| internal-users.suspend | Confirmação honesta, releitura e negações comprovadas localmente | Rota normal read-only e prova real |
| internal-users.mfa | Gate adiado; AAL1 preservado | Decisão formal de MFA; nenhum AAL2 criado |

Conhecimento: nenhuma regra nova aprovada nesta execução. Correção documental
proposta a D00: projeção team/superadmin-access-profiles.md ainda restringe
Principal ao catálogo e exige MFA, divergindo do aditivo spec018 de01/09 e
política AAL1 vigente. Atualizar fonte/projeção pelo writer central; não
interpretar esta observação como nova decisão de produto.
