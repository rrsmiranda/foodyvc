# Design System no Claude Design — App 18+ VerificaIdade

> **Alternativa recomendada p/ este projeto:** pular o Claude Design e construir o DS **direto em Dart via CLI** (Claude Code) — ver módulo **M-DS** em `specs-e-prompts-ide.md`. Isso elimina a tradução HTML/CSS→Flutter. Use o Claude Design abaixo só se quiser explorar o visual num canvas antes.

Como usar o Claude Design para construir o sistema visual do app, e como isso volta para o Flutter.

---

## Limitação-chave (leia antes)

- Claude Design gera **HTML/CSS** (protótipo web), não widgets Flutter.
- Use-o para **definir/visualizar o sistema** (tokens + aparência + protótipo das telas) e **prototipar rápido**.
- Depois, **traduza os tokens para `ThemeData` no Flutter** (cores, tipografia, espaçamento, raio, motion). Os componentes Flutter são reconstruídos na IDE a partir desses tokens.

---

## Pipeline

```
ds-architect (entrevista → ds-checkpoint.md: brief + tokens)
      ↓  (brief vira prompt do Claude Design)
Claude Design (sistema visual + protótipo das telas em HTML/CSS)
      ↓  (export tokens: cores, type scale, spacing, radius)
Flutter ThemeData (na IDE)  →  widgets (Claude Code / IDE via API)
```

---

## Passos no Claude Design

1. Acesse `claude.ai/design` (ou ícone de paleta na barra lateral).
2. No setup de design system: suba referências (imagens, PDF/PPTX) e/ou aponte para o repo. Como o scaffold ainda é inicial, **dirija pelo brief** (seed abaixo) em vez do codebase.
3. Cole o seed. Deixe ele fazer as perguntas de esclarecimento (paleta, tom, tipografia) — responda com o brief do `ds-architect`.
4. Refine por chat, comentários inline, sliders de ajuste e desenho no canvas.
5. Exporte os tokens (e, se quiser, HTML/PDF/PPTX). Guarde os tokens para o passo Flutter.

---

## Seed para colar no Claude Design

```
Quero um design system para um app mobile (iOS + Android) de verificação de
idade 18+. O app tem duas partes: (1) uma casca de simulação de compra e (2) o
núcleo, que é o fluxo de verificação de idade por credencial digital (padrão
governamental brasileiro, ligado a ECA Digital e LGPD).

Personalidade desejada: confiável, institucional e acessível. Precisa transmitir
segurança e conformidade — não é varejo "divertido", é verificação séria.
Público: pessoas adultas comprando produtos restritos.

Requisitos:
- Tema claro e escuro.
- Acessibilidade WCAG AA; alvo de toque mínimo 48px.
- Antes de gerar, me faça as perguntas de esclarecimento sobre paleta e
  tipografia e proponha 2 opções de cor primária adequadas a govtech/confiança.

Telas a prototipar:
1. Loja: lista de produtos; um item com selo "18+"; rodapé com total e botão
   "Finalizar compra".
2. Verificação de idade — TODOS os estados (é o mais importante):
   - Inicial: explica que vai abrir a carteira digital + botão "Verificar idade".
   - Abrindo a carteira (transição).
   - Aguardando resposta (loading/polling).
   - Verificando credencial.
   - Sucesso: idade confirmada, compra liberada.
   - Menor de idade: bloqueio da compra, tom respeitoso.
   - Sessão expirada: opção de tentar de novo.
   - Erro / sem carteira: CTA para instalar a carteira (Inji Wallet).
3. Compra concluída.

Entregue:
- Tokens: cores (com estados semânticos success/warning/error/info), tipografia
  (heading/body), espaçamento (grid 8px), raio, e motion.
- Componentes: AppButton (primary/secondary/disabled/loading), ProductCard
  (com selo 18+), StatusView (usado nos estados da verificação),
  Banner/Alert (sucesso/erro/aviso).
```

---

## Componentes-núcleo do DS (prioridade)

| Componente | Por que é central |
|---|---|
| **StatusView** | Renderiza os 8 estados da verificação — é o coração do app |
| **AppButton** | primary / secondary / disabled / **loading** (o loading aparece muito no polling) |
| **ProductCard** | com **selo 18+** que marca o gatilho da verificação |
| **Banner/Alert** | sucesso / erro / aviso (sem carteira, expirado) |

---

## Tokens a decidir (deixar o Claude Design propor, depois confirmar no ds-checkpoint)

- Cor primária + acento; estados semânticos success/warning/error/info.
- Tipografia heading/body (sugestão: fontes com boa legibilidade e disponíveis no Flutter via `google_fonts`).
- Grid base 8px; raio; tokens de motion (respeitar `prefers-reduced-motion` / reduzir animação).
- Contraste WCAG AA em ambos os temas.

---

## Volta para o Flutter (o que fazer com o export)

- Traduza os tokens para `lib/core/theme/`:
  - `app_colors.dart` (light/dark), `app_typography.dart` (TextTheme), `app_spacing.dart`, `app_radius.dart`.
  - Monte um `ThemeData` claro e escuro a partir desses tokens.
- Fontes: mapeie a tipografia via pacote `google_fonts` (ou fontes empacotadas).
- Os visuais de cada estado da verificação viram a UI da `AgeCheckPage` (módulo M3 do specs-e-prompts-ide.md).
- Registre marca/tokens/decisões no `ds-checkpoint.md` (separado do `code-checkpoint.md`, como manda o fluxo).
