# Política de Segurança

O Cleaner exclui arquivos no seu Mac (com o nível de privilégio do seu usuário) e pode executar alguns comandos de manutenção através do prompt padrão de administrador do macOS. Por isso, segurança importa aqui mais do que na maioria dos apps.

> O Cleaner é um fork de tradução do projeto original [iliyami/MacSai](https://github.com/iliyami/MacSai). Falhas no comportamento do app (não relacionadas à tradução) geralmente também existem no projeto original e vale relatá-las lá.

## Relatando uma vulnerabilidade

**Por favor, não abra issues públicas no GitHub para vulnerabilidades de segurança.**

Relate-as de forma privada pelo [Relato Privado de Vulnerabilidades do GitHub](https://github.com/editzffaleta/Cleaner/security/advisories/new):

1. Abra a [aba Security](https://github.com/editzffaleta/Cleaner/security) do repositório
2. Clique em **Report a vulnerability**
3. Inclua: o arquivo ou recurso afetado, os passos para reproduzir, o comportamento esperado vs. o real e uma sugestão de correção, se você tiver uma

## Versões suportadas

Apenas a última versão no branch `main` é suportada. Por favor, atualize em vez de pedir correções para versões antigas.

| Versão | Suportada |
|--------|-----------|
| `main` (última versão) | ✅ |
| Versões antigas | ❌ |

## Dentro do escopo

Relatos sobre as seguintes áreas têm prioridade:

- **`Sources/MacCleanKit/SafetyGuard.swift`**: burlas da lista de bloqueio de caminhos protegidos, do limite de 10.000 arquivos ou da re-resolução de symlinks (TOCTOU)
- **`Sources/MacClean/Core/Cleaner/CleaningEngine.swift`**: qualquer coisa que cause perda de dados fora dos resultados de escaneamento pretendidos
- **`Sources/MacClean/Modules/Maintenance/MaintenanceModule.swift`**: qualquer coisa que transforme os comandos de manutenção (executados via prompt de administrador) em execução arbitrária de comandos
- **Verificações de atualização**: um feed de atualização de terceiros adulterado que leve o usuário a um download malicioso
- **Exfiltração pela rede**: as únicas chamadas de saída do Cleaner são a própria verificação de atualização (a API de releases do GitHub) e a leitura dos feeds de atualização de apps de terceiros; relate qualquer outra atividade de rede que você observar
- **TCC / Acesso Total ao Disco**: qualquer caminho para obter ou abusar do Acesso Total ao Disco silenciosamente

## Fora do escopo

- Bugs gerais do macOS que não sejam específicos do Cleaner
- Achados que exijam uma máquina já com acesso root ou já comprometida
- Engenharia social ou acesso físico a um Mac desbloqueado

## O que pedimos a você

- Dê-nos um prazo razoável para corrigir antes da divulgação pública: **14 dias para problemas não críticos**, **coordenação imediata para qualquer coisa que arrisque dados do usuário**
- Não teste contra máquinas de outras pessoas
- Não use uma vulnerabilidade encontrada para acessar dados de usuários

## O que você recebe

- Crédito nas notas de versão (ou anonimato, se preferir)
- Reconhecimento neste arquivo por achados significativos
- Nossos sinceros agradecimentos. O Cleaner fica mais seguro por sua causa

## Verificando que uma cópia é confiável

O Cleaner é distribuído como **código-fonte** e compilado localmente pelo próprio usuário (assinatura ad-hoc), então a melhor forma de confiar no que roda no seu Mac é **compilar a partir do código-fonte** e ler o código, que é aberto:

```bash
git clone https://github.com/editzffaleta/Cleaner.git
cd Cleaner
swift build
swift test            # a suíte de testes deve passar sem falhas
./scripts/dev-install.sh
```

Como todo o código-fonte é público, você não precisa confiar na nossa palavra: pode ler cada linha, rodar os testes e compilar você mesmo.

> Observação: o projeto original [iliyami/MacSai](https://github.com/iliyami/MacSai) distribui versões assinadas com **Developer ID da Apple** e **notarizadas pela Apple**. As compilações locais deste fork **não** são notarizadas, então o macOS pode pedir para você reautorizar o Acesso Total ao Disco a cada nova compilação.

## Avisos anteriores

Nenhum até o momento. Serão listados aqui quando aplicável.
