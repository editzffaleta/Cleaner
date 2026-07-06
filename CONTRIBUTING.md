# Contribuindo com o Cleaner

Obrigado pelo seu interesse em contribuir! O Cleaner é um projeto mantido pela comunidade e recebe contribuições de todos os tipos — correções de bugs, novos recursos, melhorias na documentação e muito mais.

> O Cleaner é um fork de tradução (Português do Brasil) do projeto original [iliyami/MacSai](https://github.com/iliyami/MacSai). Melhorias no app em si também são muito bem-vindas no projeto original.

## Código de Conduta

Seja respeitoso, construtivo e inclusivo. Estamos construindo software juntos.

## Primeiros Passos

1. Faça um **fork** do repositório
2. **Clone** o seu fork: `git clone https://github.com/SEU_USUARIO/Cleaner.git`
3. **Compile**: `swift build`
4. **Rode os testes**: `swift test` (devem passar com 0 falhas)
5. **Crie um branch**: `git checkout -b feature/minha-melhoria`

## Diretrizes de Pull Request

### Antes de Enviar

- [ ] Seu código compila com `swift build` (zero erros)
- [ ] Todos os testes passam (`swift test`)
- [ ] Você adicionou testes para as novas funcionalidades (veja "Padrão de testes" abaixo)
- [ ] Nenhum novo aviso do compilador foi introduzido
- [ ] Você testou o recurso no app em execução (não só a compilação)
- [ ] Mudanças críticas de segurança (`SafetyGuard.swift`, `CleaningEngine.swift`, `PlistJunkFilter.swift`) vêm acompanhadas de casos de teste adversariais

### Formato do PR

```
## Resumo
Descrição breve do que este PR faz e por quê.

## Alterações
- Lista das mudanças específicas

## Plano de Testes
- Como você testou isso
- Casos extremos considerados

## Capturas de Tela
Se houver mudanças de interface, inclua capturas de antes/depois.
```

### Tamanho do PR

- Mantenha os PRs focados — um recurso ou correção por PR
- Recursos grandes devem ser divididos em partes menores e revisáveis
- Refatorações devem ficar separadas do trabalho de novos recursos

### Mensagens de Commit

- Use o tempo presente: "Adiciona recurso", não "Adicionado recurso"
- Primeira linha com menos de 72 caracteres
- Referencie issues quando fizer sentido: "Corrige #42: trata resultados de escaneamento vazios"

## Padrão de testes

Esta é a regra de arquitetura que todo PR deve seguir. É assim que o código
permanece testável sem depender do estado real do sistema de arquivos.

**Regra:** *a lógica de negócio vive no `MacCleanKit` como funções puras; as
dependências do sistema (`FileManager`, `NSWorkspace`, `Process`, APIs Mach)
são injetadas como closures na fronteira.* Os wrappers finos no alvo `MacClean`
são onde as implementações reais são conectadas.

### Exemplo: o padrão `PlistJunkFilter`

```swift
// ❌ Não faça isso — não testável, mistura lógica com chamadas ao FS
struct BrokenPreferencesCategory: JunkCategory {
    func filterBroken(_ items: [FileItem]) -> [FileItem] {
        items.filter { item in
            guard let data = try? Data(contentsOf: item.url) else { return true }
            // ... lógica de decisão misturada com estado do FS ...
        }
    }
}

// ✅ Faça assim — função pura no Kit, carregador injetado, totalmente testável
public enum PlistJunkFilter {
    public static func isLikelyBroken(
        at url: URL,
        loadData: (URL) -> Data?,                  // injetado
        appExistsForBundleID: (String) -> Bool     // injetado
    ) -> Bool {
        // lógica de decisão pura — sem I/O
    }
}

// E o wrapper fino no alvo MacClean
struct BrokenPreferencesCategory: JunkCategory {
    func filterBroken(_ items: [FileItem]) -> [FileItem] {
        items.filter { item in
            PlistJunkFilter.isLikelyBroken(
                at: item.url,
                loadData: { try? Data(contentsOf: $0) },
                appExistsForBundleID: { NSWorkspace.shared.urlForApplication(...) != nil }
            )
        }
    }
}
```

### Fixtures de teste disponíveis

Use estes ajudantes de `Tests/MacCleanTestSupport/` para que seus testes não
toquem na pasta pessoal real:

- `TestFixtures.withTempDir { dir in ... }` — diretório temporário, limpo automaticamente
- `TestFixtures.withTempHome { fakeHome in ... }` — árvore sintética `~/Library/...`
- `TestFixtures.writeFakeApp(at:bundleIdentifier:name:)` — bundle `.app` sintético
- `TestFixtures.writePlist(_:to:)` e `writeCorruptPlist(at:)` — plists sintéticos
- `TestFixtures.writeFile(at:size:modificationDate:contents:)` — arquivos sintéticos
- `MockClock` — relógio controlável para lógica baseada em datas

### Onde ficam os testes

- `Tests/MacCleanKitTests/` — testes unitários puros, apenas sobre o `MacCleanKit`
- `Tests/MacCleanTests/` — testes de integração que exercitam a camada `MacClean`
- `Tests/MacCleanTestSupport/` — ajudantes de fixture compartilhados (não adicione casos de teste aqui)

## Estilo de Código

### Convenções Swift

- **Swift 6** com concorrência estrita — use actors, `@Sendable`, `async/await`
- Use `@Observable` para view models (não `ObservableObject`)
- Prefira `async/await` a completion handlers
- Use `TaskGroup` para trabalho paralelo
- Sem force unwrapping (`!`), exceto em testes

### Arquitetura

- **Módulos** implementam o protocolo `ScanModule`
- **Telas** usam `ModuleContainerView` para um fluxo consistente de escaneamento/resultados/conclusão
- **Segurança em primeiro lugar** — todas as operações de arquivo passam por `SafetyGuard` e `CleaningEngine`
- Mantenha a lógica de escaneamento nos módulos, não nas telas

### Organização de Arquivos

```
Novo módulo? Siga esta estrutura:
Sources/MacClean/Modules/SeuModulo/
├── SeuModuloModule.swift      # Implementa ScanModule
└── (ajudantes opcionais)

Sources/MacClean/Views/SuaSecao/
└── SeuModuloView.swift        # Tela SwiftUI
```

### O que NÃO Fazer

- Não contorne o `SafetyGuard` em operações de arquivo
- Não adicione chamadas de rede sem discussão (o app é offline-first)
- Não adicione telemetria ou analytics
- Não adicione dependências de terceiros sem antes discutir em uma issue
- Não altere as listas de caminhos protegidos sem revisão de segurança

## Tipos de Contribuição

### Relatos de Bug

Abra uma issue com:
- Versão do macOS
- Passos para reproduzir
- Comportamento esperado vs. comportamento real
- Saída do Console (se relevante)

### Pedidos de Recurso

Abra uma issue descrevendo:
- O que o recurso faz
- Por que ele é útil
- Como ferramentas semelhantes lidam com isso (se aplicável)

### Novas Categorias de Escaneamento

Para adicionar uma nova categoria de Lixo do Sistema:
1. Crie um novo arquivo em `Sources/MacClean/Modules/SystemJunk/Categories/`
2. Implemente o protocolo `JunkCategory`
3. Adicione-a ao array de categorias do `SystemJunkModule`
4. Adicione um caso correspondente ao enum `ScanCategory`
5. Adicione testes em `Tests/`

### Novos Módulos

Para adicionar um novo módulo de escaneamento:
1. Crie `Sources/MacClean/Modules/SeuModulo/SeuModuloModule.swift`
2. Implemente o protocolo `ScanModule`
3. Crie a tela em `Sources/MacClean/Views/`
4. Adicione a entrada na barra lateral em `SidebarView.swift`
5. Conecte tudo em `ContentView.swift`
6. Registre em `AppState.swift`
7. Adicione testes

## Segurança

Se você descobrir uma vulnerabilidade de segurança, por favor **não** abra uma issue pública. Em vez disso, use o [Relato Privado de Vulnerabilidades do GitHub](https://github.com/editzffaleta/Cleaner/security/advisories/new). Levamos segurança a sério e responderemos rapidamente. Veja o arquivo [SECURITY.md](SECURITY.md).

### Revisão de Segurança Obrigatória Para

- Alterações em `SafetyGuard.swift`
- Alterações nos caminhos protegidos em `Constants.swift`
- Alterações em `CleaningEngine.swift`
- Alterações nas operações do helper XPC
- Qualquer nova lógica de exclusão de arquivos

## Dicas de Desenvolvimento

### Executando o App

```bash
# Instalação rápida para desenvolvimento (compila + cria o .app + abre)
./scripts/dev-install.sh
```

### Modo de Simulação (Dry-Run)

O motor de limpeza usa o modo `dryRun` por padrão durante o desenvolvimento. Para testar a limpeza de verdade:
1. Troque `.dryRun` por `.trash` no método `clean()` da tela correspondente
2. **Nunca** use `.permanent` durante o desenvolvimento
3. Reverta antes de fazer o commit

### Acesso Total ao Disco

Alguns módulos precisam de Acesso Total ao Disco para encontrar resultados. Se o seu escaneamento voltar vazio:
1. Compile o bundle do app (veja o README)
2. Conceda o Acesso Total ao Disco nos Ajustes do Sistema
3. Reinicie o app

## Dúvidas?

Abra uma discussão ou issue — teremos prazer em ajudar você a começar.
