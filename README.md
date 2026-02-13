# ProgresSVG

A Quarto extension for progressively revealing/hiding SVG elements in [reveal.js](https://revealjs.com/) presentations. Build up complex diagrams step by step using layer labels as element identifiers.

## Installation

`quarto add rodrigo-j-goncalves/progressvg`


## Usage

Add the filter to your document's YAML header:

```

---
title: "My Presentation"
format: revealjs
filters:
  - progressvg
---
```


Then use `.progressvg` divs to show or hide SVG elements.

I progressively reveal the objects using  `. . .` pauses:


```
## Dataviz & Narrative

::: {.progressvg file="diagram.svg" element="axes"}
:::

. . .

::: {.progressvg file="diagram.svg" element="data_points"}
:::

. . .

::: {.progressvg file="diagram.svg" element="trend_line_and_legend"}
:::
```


Each `. . .` creates a reveal.js fragment — pressing Space/Right advances through them one at a time.

## Attributes

`{.progressvg file="mydiagram.svg" element="red_square" action="hide"}`
<br>

| Attribute  | Required | Description |
|------------|----------|-------------|
| `file`     | Yes      | Path to the SVG file (relative to the QMD) |
| `element`  | Yes      | ID (or Inkscape label) of the element to show/hide |
| `action`   | No       | `show` (default) or `hide` |

### Hiding elements

You can also hide previously shown elements:

```markdown
::: {.progressvg file="diagram.svg" element="old_data" action="hide"}
:::
```

## How SVG Labels Work

ProgresSVG uses **Inkscape labels** (`inkscape:label` attributes) to identify elements in your SVG. In Inkscape:

1. Select an element (path, text, shape, etc.)
2. Open **Object Properties** (Object > Object Properties, or `Ctrl+Shift+O`)
3. Set the **Label** field to a descriptive name (e.g., `axes`, `trend_line`, `title_text`)

The label you set in Inkscape becomes the `element` value in your QMD file. Group elements (`<g>`) are also supported.

**Note:** All labeled elements start hidden (opacity 0) and are revealed by `.progressvg` divs. Elements without labels are always visible.

## Transitions

ProgresSVG respects the reveal.js `transition` and `transitionSpeed` settings from your YAML header:

```yaml
format:
  revealjs:
    transition: slide
    transition-speed: fast
```

- `transition: none` disables opacity animations
- `transition-speed: fast` uses 0.2s, `default` uses 0.4s, `slow` uses 0.8s

## Example

See the [`example/`](example/) directory for a working demo. To render it:

```bash
cd example
quarto render example.qmd
```

## License

MIT
