<!-- Source: better-auth/better-icons (MIT License) -->
<!-- Upstream: https://github.com/better-auth/better-icons -->
<!-- Glen customization: frontmatter only (user_invocable, 한글 description) -->
---
name: better-icons
description: "200,000+ 아이콘 검색 및 SVG 가져오기 (Iconify 기반 150+ 컬렉션). /better-icons search <쿼리> — 아이콘 검색, /better-icons get <id> — SVG 가져오기. 아이콘 필요 시 항상 사용."
user_invocable: true
argument-hint: <search|get|setup> [query|icon-id] [options]
allowed-tools:
  - "Bash"
  - "Read"
  - "Write"
  - "WebFetch"
---

# Better Icons

Search and retrieve icons from 200+ libraries via Iconify.

## Installation

Before using any `better-icons` commands, ensure the tool is available in the environment.

**Option 1 — Install globally (recommended, matches all examples below):**

```bash
# Using npm
npm install -g better-icons

# Using Bun (faster)
bun add -g better-icons
```

**Option 2 — Run without installing (prefix every command with `npx` or `bunx`):**

```bash
# Using npx (npm)
npx better-icons search arrow --limit 10
npx better-icons get lucide:home > icon.svg

# Using bunx (Bun — faster)
bunx better-icons search arrow --limit 10
bunx better-icons get lucide:home > icon.svg
```

> **For AI agents:** Prefer the global install so that `better-icons` is on `$PATH` and the commands below work as-is. Run the install step once during environment setup, then use the commands without `npx`/`bunx`.

## CLI

```bash
# Search icons
better-icons search <query> [--prefix <prefix>] [--limit <n>] [--json]

# Search and download all found icons as SVG files
better-icons search <query> -d [dir] [--color <color>] [--size <px>]

# Get icon SVG (outputs to stdout)
better-icons get <icon-id> [--color <color>] [--size <px>] [--json]

# Setup MCP server for AI agents
better-icons setup [-a cursor,claude-code] [-s global|project]
```

## Examples

```bash
better-icons search arrow --limit 10
better-icons search home --json | jq '.icons[0]'
better-icons get lucide:home > icon.svg
better-icons get mdi:home --color '#333' --json

# Batch download all search results
better-icons search arrow -d              # saves to ./icons/
better-icons search check -d ./my-icons   # saves to ./my-icons/
better-icons search star -d -c '#000' -s 24 --limit 64
```

## Icon ID Format

`prefix:name` - e.g., `lucide:home`, `mdi:arrow-right`, `heroicons:check`

## Popular Collections

`lucide`, `mdi`, `heroicons`, `tabler`, `ph`, `ri`, `solar`, `iconamoon`

---

## MCP Tools (for AI agents)

| Tool | Description |
|------|-------------|
| `search_icons` | Search across all libraries |
| `get_icon` | Get single icon SVG |
| `get_icons` | Batch retrieve multiple icons |
| `list_collections` | Browse available icon sets |
| `recommend_icons` | Smart recommendations for use cases |
| `find_similar_icons` | Find variations across collections |
| `sync_icon` | Add icon to project file |
| `scan_project_icons` | List icons in project |

## TypeScript Interfaces

```typescript
interface SearchIcons {
  query: string
  limit?: number        // 1-999, default 32
  prefix?: string       // e.g., 'mdi', 'lucide'
  category?: string     // e.g., 'General', 'Emoji'
}

interface GetIcon {
  icon_id: string       // 'prefix:name' format
  color?: string        // e.g., '#ff0000', 'currentColor'
  size?: number         // pixels
}

interface GetIcons {
  icon_ids: string[]    // max 20
  color?: string
  size?: number
}

interface RecommendIcons {
  use_case: string      // e.g., 'navigation menu'
  style?: 'solid' | 'outline' | 'any'
  limit?: number        // default 10
}

interface SyncIcon {
  icons_file: string    // absolute path
  framework: 'react' | 'vue' | 'svelte' | 'solid' | 'svg'
  icon_id: string
  component_name?: string
}
```

## API

All icons from `https://api.iconify.design`

## Gotchas

> **필수**: 오류 발생 시 우회 전에 여기 기록.

1. **CLI 미설치** — `better-icons` 명령이 없으면 위 Installation 절차로 먼저 설치. `npx`/`bunx`는 느리니 글로벌 설치 권장.
2. **MCP 설정 중복** — `better-icons setup`은 기존 MCP 설정을 덮어쓸 수 있음. `-s project` 플래그로 프로젝트 scope 한정.
3. **이모지 아이콘 사용 금지** — `glen-design/taste-rules.md`의 안티패턴 #1. UI 아이콘은 반드시 Iconify 컬렉션에서 가져올 것.
