---
title: "Cuidado — comandos após dispose negados"
source: "HealthCareController; plano e revisão read-only; testes locais"
status: "local-verified-integration-and-e2e-open"
generated_at: "2026-09-08"
---

Cinco callbacks retidos podiam iniciar escrita após descarte do controller.
Agora create/correct medication, create/inactivate allergy e update profile
validam ciclo de vida antes de ator/repository. Rejeitam com StateError: não
retornam sucesso sem executar uma operação. Escritas iniciadas antes do
descarte não são canceladas; seu refresh continua protegido separadamente.

Cinco REDs reproduzidos antes do guard. Após correção: **182/182** testes em
17 arquivos funcionais de Cuidado, incluindo controles de operações ativas,
concorrentes e em trânsito. Analyzer dos dois arquivos: sem achados. Review
independente estático sem bloqueante. Nenhuma UI/golden ou regra clínica mudou.

Uma primeira invocação teve expansão incorreta da lista de testes no shell e
iniciou a suíte geral; foi interrompida e não é prova deste recorte. Exibiu
falhas de escala da fixture DEV e golden de menu fora desta frente, não
investigadas aqui. A execução nominal acima usou os 17 caminhos explícitos.

Sem SQL, Docker, rota, deploy, dado real ou política clínica. E2E/produção
continuam abertos. Invariante de ciclo de vida existente restaurada: nenhuma
projeção de conhecimento por atividade. Trackers e integração do Coordenador.
