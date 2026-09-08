---
title: "Cuidado — reload pós-mutação respeita a vista atual"
source: "Escopo E2E 4; continuação da revisão de isolamento; HealthCareController"
status: "local-green-not-e2e"
generated_at: "2026-09-08"
---

# Recorte e contrato

Objetivo: impedir refresh de mutação antiga de substituir outra criança após
navegação. Inclui cinco comandos existentes do controller e testes locais.
Fora: conteúdo/autorização das mutações, política clínica, backend e produção.
Ordem: reproduzir os cinco comandos, separar geração da vista da geração da
leitura, regressão e review. Critério local: navegação prevalece, mas mutações
da mesma vista continuam atualizando-a. Estimativa: 20 minutos.

Cinco REDs confirmados: criar/corrigir medicação, criar/inativar alergia e
atualizar perfil recarregavam A após B já estar pronta. A correção captura a
geração da vista antes da escrita; refresh privado não incrementa essa geração.
Assim duas escritas da mesma vista podem atualizar sequencialmente, enquanto
leitura/navegação explícita e dispose impedem refresh obsoleto. Geração das
leituras continua protegendo resultado atrasado durante um refresh.

# Evidência

- 12 testes novos, cinco REDs e sete controles; 20/20 com a suíte de detalhe.
- Regressão final: 177/177 nos 17 arquivos funcionais de health_care.
- Analyzer dos dois arquivos de código/teste: sem problemas.
- Review independente: sem bloqueante; ator, payloads e erros do repositório
  preservados. Falhas de mutação continuam propagando, sem sucesso artificial.
- Sem mudança de layout. Goldens continuam abertos conforme a evidência da
  fatia anterior; nenhuma imagem atualizada e nenhum claim visual verde.

Somente fixtures/repositório local; não autoriza nem comprova política clínica
ou persistência real. Regras reutilizáveis não mudaram; nenhuma projeção de
conhecimento criada apenas para registrar atividade. Delta ao Coordenador,
sem edição de trackers centrais. Escopo original E2E permanece aberto.
