---
title: "Coelo PRD LGPD Seguranca e Midia Oficial v1"
source_file: "Coelo PRD LGPD Seguranca e Midia Oficial v1.docx"
source_copy: "docs/source/originals/docx/Coelo PRD LGPD Seguranca e Midia Oficial v1.docx"
original_path: "C:/Users/adrie/Desktop/Coelo/PRD/Coelo PRD LGPD Seguranca e Midia Oficial v1.docx"
status: "derived-from-official-docx"
version: "v1"
generated_at: "2026-06-22"
---

<!-- Documento derivado de fonte oficial. Edite a fonte DOCX ou registre uma decisao antes de alterar conteudo normativo. -->
| Coluna 1 | COELO<br>PRD LGPD, Segurança e Mídia Oficial v1<br>Proteção infantil · privacidade por padrão · segurança verificável |
| --- | --- |

Versão: v1.0 | Data: 21/06/2026 | Status: Draft para validação

| Requisitos transversais para dados pessoais, mídia infantil, suporte, incidentes e controles técnicos em todos os ambientes Coelo. |
| --- |

Simples como Airbnb Visual como Instagram Confiável como escola

Documento derivado do Product Vision Oficial v1 e do PRD Master Oficial v1 do Coelo.

# Sumário executivo do documento

| # | Seção |
| --- | --- |
| 1 | Capa e controle de versão |
| 2 | Resumo executivo |
| 3 | Status jurídico |
| 4 | Princípios |
| 5 | Escopo e classificação de risco |
| 6 | Mapa de dados e finalidades |
| 7 | Crianças e adolescentes |
| 8 | Bases legais e papéis |
| 9 | Consentimentos e termos |
| 10 | Mídia infantil |
| 11 | Download e compartilhamento |
| 12 | Retenção e exclusão |
| 13 | Direitos dos titulares |
| 14 | Acesso e autorização |
| 15 | Suporte interno |
| 16 | Segurança técnica |
| 17 | Incidentes |
| 18 | Analytics e notificações |
| 19 | Terceiros e integrações |
| 20 | Requisitos funcionais |
| 21 | Requisitos não funcionais |
| 22 | Critérios de aceite |
| 23 | Riscos e mitigação |
| 24 | Decisões oficiais |
| 25 | Perguntas em aberto |
| 26 | Próximas specs |
| 27 | Fontes e referências |

# 1. Capa e controle de versão

| Campo | Valor |
| --- | --- |
| Documento | PRD LGPD, Segurança e Mídia Oficial v1 — Coelo |
| Owner | Produto + Segurança + Jurídico Coelo |
| Público interno | Produto, design, engenharia, dados, segurança, jurídico, operações e agentes de coding. |
| Status | Draft para revisão e versionamento. |
| Base interna | Product Vision Oficial v1; PRD Master Oficial v1; História da Logo e Marca Oficial v1; mapa competitivo e decisões do fundador. |
| Escopo | Requisitos de privacidade infantil, mídia, acesso, incidentes e controles transversais. Não substitui parecer jurídico. |

| Versão | Data | Mudança | Responsável |
| --- | --- | --- | --- |
| v1.0 | 21/06/2026 | Criação do PRD específico alinhado ao PRD Master e às decisões oficiais do fundador. | Produto Coelo |
| v1.1 | A definir | Revisão após specs técnicas, protótipo e validação do piloto. | Produto + Engenharia |
| v2.0 | A definir | Atualização após piloto real e priorização da próxima fase. | Produto + Negócio |

# 2. Resumo executivo

O Coelo trata dados de crianças, responsáveis e equipes, incluindo rotina, mídia e comunicação privada. Por isso, privacidade e segurança são requisitos de produto. Este PRD estabelece controles mínimos e registra claramente as decisões ainda não tomadas.

A definição jurídica entre Coelo e instituição — controlador, operador ou arranjo específico — permanecerá aberta para validação jurídica. Da mesma forma, prazos de retenção de mídia, rotina e chat não serão fixados nesta versão. O download de fotos e vídeos será bloqueado por padrão.

| Princípio obrigatório<br>Em operações envolvendo crianças e adolescentes, o melhor interesse deve orientar a finalidade, necessidade, transparência, segurança e desenho da experiência. |
| --- |

# 3. Status jurídico

| Tema | Status v1 |
| --- | --- |
| Papel da instituição | A definir em validação jurídica. |
| Papel do Coelo | A definir em validação jurídica. |
| DPA/contrato | Obrigatório antes da operação comercial; conteúdo jurídico pendente. |
| Encarregado/DPO | Responsável e canal ainda não definidos. |
| Bases legais por finalidade | Devem ser mapeadas antes do piloto com dados reais. |
| Retenção | Prazos ainda não definidos. |

Este documento define requisitos de produto e segurança. Ele não é parecer jurídico e não deve ser usado como única base para iniciar tratamento real de dados infantis.

# 4. Princípios

| Princípio | Aplicação |
| --- | --- |
| Melhor interesse | Avaliar benefício, necessidade e risco para a criança. |
| Finalidade | Separar cadastro, comunicação, rotina, segurança, suporte, analytics e marketing institucional. |
| Necessidade/minimização | Coletar apenas o que sustenta a finalidade. |
| Privacidade por padrão | Conteúdo e mídia privados, download bloqueado e busca infantil restrita. |
| Transparência | Textos claros para responsáveis e instituições. |
| Segurança | RLS, storage privado, auditoria, testes e resposta a incidentes. |
| Responsabilização | Decisões, acessos e consentimentos demonstráveis. |

# 5. Escopo e classificação de risco

O Coelo deve ser tratado internamente como produto de risco moderado-alto/elevado por combinar dados infantis, rotina, imagens, comunicação e múltiplos tenants. Essa classificação de projeto exige revisão jurídica, threat modeling, testes de isolamento e controle de acessos antes do piloto.

| Incluído | Exemplos |
| --- | --- |
| Dados cadastrais | Nome, contatos, CPF de adultos, vínculos e instituições. |
| Dados infantis | Identidade, grupos, rotina, ocorrências e imagem. |
| Comunicação | Posts, leitura, chat, agenda e autorizações. |
| Mídia | Fotos, vídeos, anexos, thumbnails e metadados. |
| Técnicos | Logs, dispositivos, IP quando necessário e eventos. |
| Operacionais | Planos, suporte e auditoria. |

# 6. Mapa de dados e finalidades

| Finalidade | Dados necessários | Controles |
| --- | --- | --- |
| Cadastro e acesso | Pessoa, contato, CPF adulto, username, vínculos. | Minimização, dedupe protegido e acesso contextual. |
| Comunicação | Posts, leitura, audiência e notificações. | Privado, confirmação e payload mínimo. |
| Rotina | Itens diários, observações e ocorrências. | Acesso por criança e auditoria. |
| Mídia | Arquivo, contexto, autorização e classificação. | Bucket privado, URL assinada e download bloqueado. |
| Chat | Membros, mensagens, recibos e histórico. | Canal autorizado, soft delete e auditoria. |
| Agenda | Evento, resposta e autorização. | Contexto e responsável válido. |
| Suporte | Sessão, motivo, ator e ações. | Cargo interno e log. |
| Analytics | Eventos mínimos e agregados. | Pseudonimização e sem conteúdo desnecessário. |

# 7. Crianças e adolescentes

- Nenhuma funcionalidade deve depender de perfil público infantil.

- @username infantil é global por decisão do produto, mas a pesquisa é restrita a instituições autorizadas.

- A autorização institucional para pesquisa/vínculo deve ser definida e testada antes do piloto.

- Mídia deve respeitar autorização/restrição de imagem por criança e contexto.

- Conteúdo global Coelo não pode usar perfilamento comportamental infantil nem publicidade dirigida a crianças.

- Campos de saúde e ocorrências exigem minimização, acesso restrito e auditoria.

# 8. Bases legais e papéis

A ANPD admite que diferentes hipóteses legais da LGPD podem ser aplicáveis ao tratamento de dados de crianças e adolescentes, desde que o melhor interesse prevaleça. O Coelo não escolherá uma base legal única neste PRD: cada finalidade deverá ser mapeada com jurídico, instituição piloto e contrato.

| Tema | Decisão |
| --- | --- |
| Controlador/operador | Em aberto. |
| Base legal por finalidade | Em aberto para mapeamento jurídico. |
| Consentimento | Coletar quando aplicável, de forma específica, destacada e demonstrável. |
| Obrigação legal/proteção | Avaliar conforme a operação real da instituição. |
| Legítimo interesse | Somente após teste e avaliação do melhor interesse quando aplicável. |

# 9. Consentimentos e termos

| Registro | Requisito |
| --- | --- |
| Termos de uso | Versão, data, usuário e aceite. |
| Política de privacidade | Versão, canal e disponibilidade. |
| Imagem | Autorização/restrição por criança, contexto e finalidade. |
| Comunicação | Preferências por tipo, sem bloquear mensagens de segurança. |
| Revogação | Histórico e efeito futuro conforme lei/contrato. |
| Responsável autorizado | Relação, contexto e escopo. |
| DPA/contrato | Responsabilidades entre Coelo e instituição após validação jurídica. |

# 10. Mídia infantil

| Controle | Requisito |
| --- | --- |
| Storage | Buckets privados; nenhuma mídia infantil em bucket público. |
| Acesso | RLS/policies por tenant, grupo, criança e objeto. |
| Entrega | URL assinada/temporária e tela autenticada. |
| Upload | Validação de tipo, tamanho, compressão e status. |
| Metadados | Remover ou limitar metadados desnecessários quando aplicável. |
| Consentimento | Verificar política de imagem antes da publicação. |
| Classificação | Privada interna, por grupo, por criança ou sensível. |
| Moderação | Fluxo de denúncia/ocultação e ação institucional a definir. |
| Auditoria | Upload, publicação, acesso administrativo e exclusão sensível. |

# 11. Download e compartilhamento

| Decisão oficial<br>Download de fotos e vídeos será bloqueado por padrão no MVP. |
| --- |

- Não exibir botão de download.

- Não fornecer URL pública permanente.

- Aplicar headers e controles compatíveis com a plataforma, sem prometer impossibilidade absoluta de captura.

- Screenshots e gravação de tela não podem ser totalmente impedidos em todos os dispositivos; comunicar responsabilidade de uso.

- Qualquer futura liberação de download deve ser decisão institucional explícita e auditável.

# 12. Retenção e exclusão

| Decisão oficial<br>Os prazos de retenção de mídia, rotina e chat não serão definidos nesta versão. Devem constar como pendência bloqueadora para operação comercial sem validação jurídica. |
| --- |

| Tipo | Prazos | Preparação necessária |
| --- | --- | --- |
| Mídia | A definir | created_at, expires_at opcional, deleted_at, classificação e vínculo. |
| Rotina | A definir | Histórico, correções e estado de exclusão/anonymização. |
| Chat | A definir | Soft delete, auditoria e política por contrato. |
| Importações | A definir | Excluir arquivos temporários após período aprovado. |
| Logs | A definir | Separar segurança, auditoria e analytics. |
| Backups | A definir | Incluir no mapa de retenção e exclusão. |

# 13. Direitos dos titulares

- Canal para confirmação, acesso, correção e solicitações aplicáveis.

- Exportação de dados próprios deve ser preparada, respeitando dados de terceiros.

- Correção de vínculos e dados de criança deve exigir autorização adequada.

- Exclusão/anonymização depende de finalidade, contrato, obrigação e retenção aprovada.

- Solicitações devem ser registradas, autenticadas e auditadas.

- Papel de resposta entre Coelo e instituição depende da definição jurídica pendente.

# 14. Acesso e autorização

| Ator | Regra |
| --- | --- |
| Responsável | Somente crianças/contextos autorizados. |
| Professor | Somente grupos e crianças vinculados. |
| Coordenador | Unidades/grupos autorizados. |
| Admin | Tenant e escopo delegado. |
| Diretor/Owner | Instituição inteira. |
| Equipe Coelo | Conforme cargo interno e auditoria. |
| Instituição autorizada | Pesquisa username infantil somente dentro do fluxo autorizado. |

# 15. Suporte interno

Por decisão do fundador, usuários internos poderão acessar dados privados conforme o cargo. Para reduzir risco, o produto deve registrar motivo, ator, tenant, escopo, início/fim e ações sensíveis da sessão de suporte.

- Não usar login/senha do usuário final.

- Não usar service role no navegador.

- Minimizar conteúdo exibido ao que é necessário para resolver o chamado.

- Permissões internas devem ser revisáveis e revogáveis.

- Acesso de conteúdo/marketing não inclui dados privados de crianças.

# 16. Segurança técnica

| Controle | Requisito |
| --- | --- |
| RLS | Obrigatória em dados expostos; negar por padrão. |
| Storage policies | Mesma lógica de autorização dos objetos de negócio. |
| Realtime | Canais protegidos por autorização. |
| Secrets | Somente servidor/Edge Functions; nunca no cliente. |
| Criptografia | Usar controles da plataforma e transporte seguro; detalhes na arquitetura. |
| Rate limiting | Login, OTP, convite, upload e endpoints sensíveis. |
| Logs | Sem segredos, tokens ou conteúdo infantil desnecessário. |
| Backups | Habilitados e testados conforme plano de operação. |
| CI/CD | Migrations, testes de RLS e revisão de mudanças sensíveis. |
| Checklists | OWASP ASVS para web/API e MASVS para mobile. |

# 17. Incidentes

A ANPD estabelece processo para comunicação de incidentes que possam causar risco ou dano relevante. A obrigação formal depende do papel de controlador, que ainda será definido; independentemente disso, o Coelo precisa ter processo de detecção, contenção, evidência, avaliação e cooperação.

| Etapa | Requisito |
| --- | --- |
| Detecção | Alertas de acesso, erro, vazamento e comportamento anômalo. |
| Contenção | Revogar sessões/chaves, bloquear acesso e preservar evidências. |
| Classificação | Dados, titulares, tenants, impacto e risco. |
| Notificação interna | Acionar responsáveis de produto, segurança, jurídico e operação. |
| Comunicação externa | Seguir papel jurídico e orientação da ANPD. |
| Correção | Patch, revisão de policies e testes de regressão. |
| Pós-incidente | Relatório, lições, ações e acompanhamento. |

# 18. Analytics e notificações

- Analytics usa identificadores pseudonimizados e propriedades mínimas.

- Não enviar nome, rotina, mensagem ou dado de saúde para ferramentas de analytics quando não necessário.

- Push usa texto genérico e abre conteúdo autenticado.

- Tokens de dispositivo são dados operacionais protegidos.

- Conteúdo opcional e marketing institucional respeitam preferências; segurança e termos seguem base própria.

# 19. Terceiros e integrações

| Terceiro/camada | Requisito |
| --- | --- |
| Supabase | Contrato, região/infra, controles, RLS, storage e logs avaliados. |
| Push FCM/APNs/serviço | Payload mínimo e contrato de tratamento. |
| E-mail/SMS | Somente dados necessários ao envio. |
| n8n | Fluxos não críticos; segredos e dados minimizados. |
| Cloudflare | DNS/WAF/CDN e proteção; não tornar mídia privada pública. |
| Futuros gateways | DPA, finalidade, minimização e revisão antes de integração. |

# 20. Requisitos funcionais

| ID | Área | Requisito |
| --- | --- | --- |
| LG-RF-001 | Consentimentos | Versionar termos e autorizações. |
| LG-RF-002 | Mídia | Manter bucket privado e acesso contextual. |
| LG-RF-003 | Download | Bloquear download por padrão. |
| LG-RF-004 | Imagem | Verificar autorização antes de publicação. |
| LG-RF-005 | Acesso | Aplicar RLS e permissions em dados e storage. |
| LG-RF-006 | Suporte | Registrar sessões e ações internas sensíveis. |
| LG-RF-007 | Titulares | Registrar solicitações e respostas. |
| LG-RF-008 | Incidentes | Manter fluxo de registro, contenção e comunicação. |
| LG-RF-009 | Retenção | Suportar estados e timestamps, sem prazos definidos. |
| LG-RF-010 | Analytics | Minimizar e pseudonimizar eventos. |
| LG-RF-011 | Username infantil | Restringir pesquisa a instituições autorizadas. |
| LG-RF-012 | Auditoria | Registrar permissão, vínculo, mídia e acesso sensível. |

# 21. Requisitos não funcionais

| Categoria | Requisito |
| --- | --- |
| Confidencialidade | Somente atores autorizados acessam dados. |
| Integridade | Alterações sensíveis registradas e atribuíveis. |
| Disponibilidade | Monitoramento, backup e recuperação. |
| Privacidade | Minimização, finalidade e default privado. |
| Verificabilidade | Testes de RLS, ASVS/MASVS e auditoria. |
| Resiliência | Rate limits, retry seguro e resposta a incidentes. |
| Transparência | Políticas e consentimentos claros. |
| Manutenibilidade | Controles versionados e documentação atualizada. |

# 22. Critérios de aceite

- Nenhuma mídia infantil usa bucket público.

- Usuário sem vínculo não acessa mídia por URL direta.

- App não oferece download de fotos/vídeos no MVP.

- Push não contém conteúdo sensível.

- Acesso de suporte gera sessão e audit logs.

- Instituição não autorizada não pesquisa username infantil.

- Consentimento/autorização de imagem é consultável antes de publicar.

- Prazos de retenção aparecem como pendentes, não como valores inventados.

- Service role/secret não existe no bundle cliente.

- Teste com dois tenants impede vazamento cruzado.

# 23. Riscos e mitigação

| Risco | Impacto | Mitigação |
| --- | --- | --- |
| Papel jurídico indefinido | Crítico | Revisão jurídica antes do piloto real. |
| Retenção indefinida | Alto | Decisão bloqueadora e modelo preparado. |
| Username infantil expor criança | Crítico | Busca restrita, não indexação e autorização. |
| Suporte interno excessivo | Crítico | Cargo, auditoria, minimização e revisão. |
| Mídia compartilhada fora do app | Alto | Download bloqueado, termos e educação; não prometer impedir screenshot. |
| Vazamento entre tenants | Crítico | RLS, testes, threat modeling e logs. |
| Dados sensíveis em analytics | Alto | Schema mínimo, revisão e pseudonimização. |

# 24. Decisões oficiais

| Decisão | Valor oficial v1 |
| --- | --- |
| Papel jurídico Coelo/instituição | Em aberto para validação jurídica. |
| Download de mídia | Bloqueado por padrão. |
| Retenção de mídia | Prazo não definido. |
| Retenção de rotina | Prazo não definido. |
| Retenção de chat | Prazo não definido. |
| Acesso interno | Permitido conforme cargo, com auditoria. |
| Melhor interesse | Princípio obrigatório. |
| Buckets de mídia | Privados. |
| Publicidade infantil/perfilamento | Não permitido. |

# 25. Perguntas em aberto

- Qual papel jurídico de cada parte por finalidade?

- Quem será o encarregado/DPO e qual canal?

- Quais bases legais por cadastro, rotina, mídia, chat, analytics e suporte?

- Quais prazos de retenção e critérios de exclusão?

- Qual fluxo prova autorização institucional para username infantil?

- Quais cargos internos acessam quais classes de dados?

- Qual processo de revisão de autorização de imagem?

# 26. Próximas specs

- Data Processing Map e ROPA por finalidade.

- DPIA/RIPD e threat model antes do piloto.

- Política de privacidade, termos, política de imagem e DPA com jurídico.

- Technical Spec de buckets, policies, URLs assinadas e logs.

- Plano de resposta a incidentes.

- Test Plan ASVS/MASVS, RLS e storage isolation.

# Fontes e referências

## Fontes internas

- Coelo — Product Vision Oficial v1.

- Coelo — PRD Master Oficial v1.

- Coelo — História da Logo e Marca Oficial v1.

- Mapa competitivo de apps de agenda e comunicação escolar no Brasil.

- Decisões do fundador registradas em 21/06/2026 para os seis PRDs.

## Fontes externas oficiais

- Supabase — Row Level Security: https://supabase.com/docs/guides/database/postgres/row-level-security

- Supabase — Auth: https://supabase.com/docs/guides/auth

- Supabase — Storage Access Control: https://supabase.com/docs/guides/storage/security/access-control

- Supabase — Realtime Authorization: https://supabase.com/docs/guides/realtime/authorization

- Supabase — Edge Functions e secrets: https://supabase.com/docs/guides/functions e https://supabase.com/docs/guides/functions/secrets

- Flutter — App architecture: https://docs.flutter.dev/app-architecture

- ANPD — Enunciado sobre dados de crianças e adolescentes: https://www.gov.br/anpd/pt-br/assuntos/noticias/anpd-divulga-enunciado-sobre-o-tratamento-de-dados-pessoais-de-criancas-e-adolescentes

- ANPD — Comunicação de incidentes de segurança: https://www.gov.br/anpd/pt-br/assuntos/comunicacao-de-incidentes-de-seguranca-cis

- OWASP — ASVS: https://owasp.org/www-project-application-security-verification-standard/

- OWASP — MASVS: https://mas.owasp.org/MASVS/

- ANPD — Guia de legítimo interesse: https://www.gov.br/anpd/pt-br/documentos-e-publicacoes/guia_legitimo_interesse.pdf

Acesso às fontes externas: 21/06/2026. As referências jurídicas não substituem revisão por profissional habilitado.
