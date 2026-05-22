## Project Overview

AI-native PPT writing workflow — generates PowerPoint presentations from natural language input using AI.

## Architecture

Four-stage pipeline:
1. **Research** — Perplexity Sonar Pro API (web search + citations)
2. **Drafting** — Claude API (outline + slide content, structured output)
3. **Charts** — see tool selection below
4. **Assembly** — `office-powerpoint-mcp-server` (python-pptx based MCP server)

### Chart Tool Selection

| Content type | Tool | Output |
|---|---|---|
| Data charts (market share, cost, Gantt) | **Plotly** + `kaleido` → `fig.write_image()` | High-res PNG |
| Architecture / flow / sequence diagrams | **Mermaid** (`mmdc` CLI or `mermaid-py`) | PNG/SVG |
| Complex free-form architecture diagrams | **Draw.io** (native `drawio` MCP server) | PNG/SVG |

All chart outputs are PNG files inserted into PPTX via `manage_image` tool.

### Fonts

Default font: **Microsoft YaHei (微软雅黑)** for all charts and slides.

```python
# Matplotlib — always set both before any plot code
import matplotlib
matplotlib.rcParams['font.family'] = 'Microsoft YaHei'
matplotlib.rcParams['figure.dpi'] = 300  # prevents font blur when scaled in PPT

# python-pptx
from pptx.util import Pt
run.font.name = 'Microsoft YaHei'
```

### MCP Servers

`office-powerpoint-mcp-server` 

**RULE: Always use the PowerPoint MCP server for all PPTX operations.** Do NOT use html2pptx, python-pptx scripts, or ooxml XML editing. All slide creation, editing, and assembly must go through the `powerpoint` MCP tools.

`drawio` MCP server is configured in `.claude/settings.json` (command: `drawio-mcp`).

**RULE: Always use the Draw.io MCP server for all Draw.io diagram operations.** Do NOT use the `drawio` CLI or manual XML editing.

## Commands

```bash
# Install core deps
pip install office-powerpoint-mcp-server plotly kaleido mermaid-py anthropic

# Mermaid CLI (requires Node)
npm install -g @mermaid-js/mermaid-cli

# Render a Mermaid diagram
mmdc -i diagram.mmd -o output.png

# Export Plotly chart
python -c "import plotly.graph_objects as go; fig=go.Figure(); fig.write_image('out.png')"
```
