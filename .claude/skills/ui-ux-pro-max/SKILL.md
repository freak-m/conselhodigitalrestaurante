# UI/UX Pro Max — Design Intelligence Skill v2.5

> Skill instalada a partir de: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill

## Quando usar esta skill

Ative esta skill para TODAS as tarefas que envolvam:
- Criar ou refatorar páginas HTML/CSS
- Escolher paletas de cor, tipografia ou espaçamento
- Revisar acessibilidade e consistência visual
- Implementar layouts, animações ou comportamento responsivo
- Melhorar clareza e usabilidade de interfaces

Ignore esta skill para lógica de backend puro, design de API ou infraestrutura.

---

## Design System deste Projeto (Restaurante)

### Stack
`html-tailwind` — HTML5 + Tailwind CSS via CDN + Vanilla JS ES6+

### Paleta de Cores (Restaurante/Food Service — Palette #34)

| Token | Hex | Uso |
|---|---|---|
| `primary` | `#DC2626` | Botões CTA, badges, destaques |
| `primary-hover` | `#B91C1C` | Hover de botões |
| `primary-light` | `#F87171` | Ícones, bordas suaves |
| `accent` | `#A16207` | Detalhes dourados, preços |
| `accent-light` | `#D97706` | Hover de accent |
| `background` | `#FEF2F2` | Fundo light |
| `surface` | `#FFFFFF` | Cards, modais |
| `dark` | `#0A0A0A` | Fundo escuro (hero, footer) |
| `dark-card` | `#1A0A0A` | Cards em fundo escuro |
| `foreground-dark` | `#450A0A` | Texto em fundo escuro |
| `muted` | `#64748B` | Texto secundário |
| `border` | `#FECACA` | Bordas suaves |

### Tipografia (Pairing #33 — Restaurant Menu)

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Karla:wght@300;400;500;600;700&family=Playfair+Display+SC:wght@400;700&display=swap" rel="stylesheet">
```

| Uso | Fonte | Peso |
|---|---|---|
| Títulos H1/H2 | `Playfair Display SC` | 700 |
| Subtítulos H3/H4 | `Playfair Display SC` | 400 |
| Corpo / UI | `Karla` | 400/500 |
| Labels / Botões | `Karla` | 600/700 |

```css
:root {
  --font-heading: 'Playfair Display SC', serif;
  --font-body: 'Karla', sans-serif;
}
```

### Estilo Visual: Hero-Centric + Bold Statement

- **Mood:** Dramático, apetitoso, premium-acessível
- **Hero:** Fullscreen com overlay escuro, tipografia grande em branco
- **Cards:** Sombras profundas, bordas com accent dourado
- **CTAs:** Vermelho sólido `#DC2626`, hover `#B91C1C`, texto branco
- **Ícones:** SVG inline apenas — nunca emojis em controles estruturais
- **Imagens:** WebP preferido, lazy loading, dimensões fixas para evitar CLS

---

## Regras de Prioridade (aplicar nesta ordem)

### CRÍTICO — Acessibilidade
- Contraste mínimo 4.5:1 para texto normal, 3:1 para texto grande
- Todo campo de formulário tem `<label>` visível
- Todos os botões têm `aria-label` quando só têm ícone
- Navegação por teclado funcional (Tab, Enter, Escape)
- Imagens têm `alt` descritivo (nunca vazio em imagens de conteúdo)

### CRÍTICO — Touch & Interação
- Tamanho mínimo de toque: **44×44px**
- Espaçamento entre alvos clicáveis: **8px mínimo**
- Feedback visual em **80–150ms** após clique/tap
- Estados: default → hover → active → disabled (nunca pular estados)

### ALTO — Performance
- Imagens em WebP/AVIF
- Lazy loading em imagens abaixo do fold (`loading="lazy"`)
- Reservar espaço para imagens (CLS < 0.1)
- Fontes com `display=swap`

### ALTO — Layout & Responsivo
- **Mobile-first** sempre: escrever base para mobile, sobrescrever para desktop
- Sem scroll horizontal em nenhum breakpoint
- Breakpoints Tailwind: `sm` (640px), `md` (768px), `lg` (1024px), `xl` (1280px)
- Grid: `grid-cols-1 sm:grid-cols-2 lg:grid-cols-3` como padrão

### MÉDIO — Tipografia & Cor
- Tamanho base: **16px** (`text-base`)
- Line-height: **1.5** para corpo, **1.2** para títulos
- Hierarquia de cor: `primary` → `accent` → `muted` (nunca inverter)
- Nunca usar mais de **3 pesos** de fonte numa mesma página

### MÉDIO — Animações
- Duração: **150–300ms** para micro-interações, **300–500ms** para transições de página
- Easing: `ease-out` para elementos que entram, `ease-in` para saída
- `transition-colors duration-200` é o padrão para hover de botões
- Respeitar `prefers-reduced-motion`

### MÉDIO — Formulários & Feedback
- Labels visíveis acima do campo (nunca só placeholder)
- Erros exibidos próximos ao campo, em vermelho com ícone
- Loading state em botões de submit (spinner + texto "Enviando...")
- Mensagem de sucesso em verde, persistente por 3s

---

## Checklist Pré-Entrega

- [ ] Contraste de texto verificado em todos os fundos
- [ ] Nenhum emoji usado como ícone de controle
- [ ] Todos os botões CTA têm hover e active state
- [ ] Formulários têm labels, validação e feedback de erro
- [ ] Layout testado em 375px (mobile), 768px (tablet), 1280px (desktop)
- [ ] Imagens têm `alt`, `width`, `height` e `loading="lazy"`
- [ ] Fontes carregadas com `preconnect` e `display=swap`
- [ ] Cores seguem a paleta definida (sem hardcode fora do padrão)
- [ ] Animações respeitam `prefers-reduced-motion`
- [ ] Semântica HTML correta (nav, main, section, article, aside, footer)
