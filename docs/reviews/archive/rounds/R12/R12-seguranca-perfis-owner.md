---
source: Owner e dez anexos na conversa de 2026-09-13; specs/030-superadmin-child-safety-production.md; specs/018-profiles-permissions-superadmin.md; decisions/0032-mvp-private-media-r2.md
status: backlog R12; requisitos registrados; sem implementação
generated_at: 2026-09-13
---

# R12 — Segurança da criança e Perfis e permissões

Complemento de R12-apontamentos-owner.md, fora da execução R11 por determinação
do Owner. Host apps/superadmin, família administrativa. Referência de wizard:
Criar/Editar Instituição. Dez anexos vistos na conversa, numerados abaixo; binários
não exportados ao repositório. Registro sem PII das imagens. Responsável: C0 R12.

| ID / anexo | Superfície e action_ids | Observação e requisito | Primeiro gate |
|---|---|---|---|
| R12-09 / 1 | Segurança da criança > Diretório; child-safety.list | Cards precisam de informações mais úteis para operação. | Propor conteúdo com dados reais e minimizados: identificação/contexto, situação escrita, autorizações vigentes, solicitações pendentes e restrição/alerta quando existente; proposta ainda sujeita à decisão do Owner. Não inferir liberação de retirada por contagem ou cor. |
| R12-10 / 2 | Segurança da criança > Diretório > Tabela; child-safety.list | Tabela quebrada: largura/composição não acompanha diretório, pintura de linha/célula inconsistente. | Reproduzir e aplicar Table canônica, largura, alinhamento, seleção/hover, responsividade e paginação padrão. |
| R12-11 / 3 | Acessos > Perfis e permissões > Cards; diretório sem action_id específico confirmado | Melhorar conceito do conteúdo interno, tentar dois indicadores em cima e dois embaixo (2×2 dentro do card). | Propor quatro informações úteis sem inventar métricas: escopo máximo, vínculos, tipo e situação são candidatos. Não interpretar como apenas quatro cards por página; adaptar no compacto. Mapear diretório no inventário antes de delta, sem atribuir artificialmente ao CRUD. |
| R12-12 / 4 | Segurança da criança > Criança > Autorizações > Tabela; child-safety.child | Tabela quebrada, validade truncada e status fora do padrão. | Table canônica; status textual no componente padrão de tabela, sem depender apenas do círculo colorido. Distinguir decisão, ciclo de vida e validade. |
| R12-13 / 5 e 10 | Segurança da criança > Criar/Editar > Criança / Pessoa autorizada; child-safety.create, child-safety.edit | Contêiner dentro de contêiner destoa de Editar Instituição. | Reutilizar composição canônica do wizard, retirando molduras redundantes e preservando grupos de campos, espaçamento e rodapé. Texto técnico como server-side não pertence à instrução de produto. |
| R12-14 / 6 | Segurança da criança > Criança > Relação; child-safety.child | Relação mostra mother/father, não português. | Mapear códigos para rótulos localizados como Mãe/Pai; usar locale suportado pelo app e fallback definido, sem traduzir enums no banco. Confirmar política de seguir idioma do navegador. |
| R12-15 / 7 e 8 | Segurança da criança > Gerenciar autorização; child-safety.child, child-safety.edit, child-safety.suspend | Popups pobres em contexto e hierarquia. Anexo 7 mostra círculo verde junto a Situação: Suspensa; verificar incoerência de apresentação. | Propor identidade/contexto, relação, situação explícita, validade, capacidades e motivo relevante; ações coerentes com estado/capacidade. Separar Fechar de ações que alteram registro; Aprovar/Rejeitar/Editar não podem sugerir autorização já válida. Sem causa backend confirmada. |
| R12-16 / 9 | Segurança da criança > Criar > Navegação de etapas; child-safety.create | Só avançar por Continuar; clicar Pessoa autorizada ou outra etapa futura não avança. | Validar etapa antes da transição. Bloquear salto pelo stepper, inclusive teclado; definir retorno às etapas concluídas sem perder dados. Aplicar também ao editar se usa mesmo wizard. |
| R12-17 / 10 + relato | Criar/Editar > Pessoa autorizada; child-safety.create, child-safety.edit | UUID não é busca de pessoa. Buscar por @, CPF, e-mail, celular, nome e sobrenome. UUID pode ser consulta técnica oculta do Superadmin. | Reutilizar busca autorizada existente, normalizar entradas, evitar duplicidade e minimizar resultados. UUID técnico nunca dispensa autorização. Ao selecionar, consultar vínculo real e pré-selecionar relação existente no contexto criança/unidade. Não presumir aprovação ou reativar vínculo suspenso. |
| R12-18 / relato | Criar autorização > Pessoa não encontrada; child-safety.create | Cadastro básico de pessoa sem conta: nome, sobrenome, CPF, RG, profissão, imagem de documento e tipo (RG, CPF, passaporte, CNH), celular e e-mail. Owner diz não obrigatórios ao final da lista. | Confirmar se a opcionalidade vale só para celular/e-mail ou também documentos/demais campos. Desenhar pessoa global sem exigir conta/login, evitar duplicação e manter autorização pendente de revisão. Reconciliar contrato de identificação/verificação antes de implementar. |

## Limites e decisões de domínio

A spec 030 separa pessoa global de autorização contextual; solicitação nova nasce
pending + inactive. Selecionar uma relação preexistente facilita preenchimento,
mas não concede retirada, restaura suspensão ou substitui aprovação da unidade.
Se houver autorização já existente, mostrar o estado e oferecer o fluxo permitido,
sem criar uma segunda autorização silenciosamente. Relação e autorização são
conceitos distintos e precisam ser conferidos separadamente.

Busca por identificadores deve respeitar alcance real de cada ator no servidor;
um resultado não autoriza leitura de todos os dados pessoais. Não transformar a
busca em diretório público. Cadastro sem conta é requisito futuro e não convite,
criação automática de login ou envio de mensagem autorizado.

Documento segue R2 privado, catálogo/permissões no Supabase, tipo declarado e MIME
real validados; não incluir CPF/RG/documentos reais em Git, logs ou evidência de QA.
Não presumir que CPF e RG sejam ambos obrigatórios nem que passaporte substitua
CPF sem confirmar os critérios do cadastro. Reusar pessoa e vínculo exige resolver
homônimos/duplicatas pelo contrato existente, nunca fusão automática por nome.

## FE, BE e E2E

- FE R12: cards/tabelas/status/locale/popups/wizard/busca e cadastro a implementar
  após proposta focal. O conteúdo específico dos cards e popups ainda é proposta.
- BE R12: verificar busca existente, minimização, vínculo contextual, deduplicação,
  cadastro sem conta, documento privado e estados de autorização. Nenhum defeito
  novo de backend foi diagnosticado por estes anexos.
- E2E R12: futura prova pela rota normal com pessoa existente/vínculo existente,
  pessoa sem conta, submissão pendente, ações permitidas, persistência/reload e
  negação cross-tenant/criança. Nenhum novo certificado neste registro.

## Handoff documental

R11 mantém escritor central e WIP de código na mesma worktree. Este complemento
não altera código, runtime, inventário ou três matrizes. R12-seguranca-perfis-delta.json
contém deltas propostos, NÃO aplicados: rebasear notas atuais por camada antes de
apply-tracker-delta.cjs, preservando avanços/certificações R11. Incorporar itens
R12-09 a R12-18 ao manifesto central. Diretório Perfis e permissões precisa primeiro
ser mapeado; não inventar action_id nem alterar denominador para este registro.
Integração documental central é pendência do C0 integrador. Nenhuma R12 iniciada.
