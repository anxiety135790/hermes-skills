---
name: hermes-obsidian-plugin
description: "使用 Hermes API Server 为 Obsidian 构建远程 AI 助手插件"
version: 1.0.0
author: Nous Research
---

# Hermes Obsidian Plugin 制作指南

通过 Hermes 内置的 OpenAI 兼容 API Server（端口 8642）为 Obsidian 开发远程 AI 助手插件。

## 架构

```
Obsidian vault  ──HTTP──>  Hermes API Server (port 8642)
   (TypeScript)              (aiohttp, OpenAI-compatible)
```

Hermes API Server 端点：
- `POST /v1/chat/completions` — 同步请求 + 流式输出
- `GET /v1/models` — 获取可用模型
- `POST /v1/runs` — 异步运行
- `GET /health` — 健康检查

认证：`Authorization: Bearer <API_SERVER_KEY>` 或空（仅本地）

## 插件文件结构

```
hermes-obsidian-plugin/
├── manifest.json         # Obsidian 插件清单
├── package.json          # npm 依赖
├── tsconfig.json         # TypeScript 配置
├── esbuild.config.mjs    # esbuild 构建（CJS 格式）
├── styles.css            # 样式
├── src/
│   ├── main.ts           # 插件入口
│   ├── api.ts            # Hermes API 客户端
│   ├── modals.ts         # 对话/结果弹窗
│   └── settings.ts       # 设置面板
└── README.md
```

## 关键实现细节

### 1. API 客户端 (`api.ts`)

```typescript
export class HermesApi {
  constructor(private config: { serverUrl: string; apiKey: string; model: string }) {}

  // 同步请求
  async chat(messages: ChatMessage[], signal?: AbortSignal): Promise<HermesResponse>
  
  // 流式请求 — onChunk 回调接收每个 content 增量
  async chatStream(messages: ChatMessage[], onChunk: (text: string) => void, signal?: AbortSignal): Promise<HermesResponse>
  
  // 连接测试
  async testConnection(): Promise<boolean>
}
```

流式实现要点：读取 `Response.body.getReader()`，按 `data: {...}\n\n` 格式解析 SSE 流。

### 2. 命令注册 (`main.ts`)

```typescript
// 编辑器上下文命令（有选区才工作）
this.addCommand({
  id: "hermes-send-selection",
  name: "选中文本 → 问 Hermes",
  editorCallback: (editor: Editor) => {
    const selected = editor.getSelection();
    this.askHermes(selected, (result) => editor.replaceSelection(result));
  },
});

// 全局命令（无编辑器也可执行）
this.addCommand({
  id: "hermes-open-chat",
  name: "打开对话窗口",
  callback: () => new HermesChatModal(this.app, this.api).open(),
});
```

### 3. 右键菜单

```typescript
this.registerEvent(
  this.app.workspace.on("editor-menu", (menu: Menu, editor: Editor) => {
    const selected = editor.getSelection();
    if (!selected) return;
    menu.addItem((item) => {
      item.setTitle("🤖 问 Hermes").onClick(() => { /* ... */ });
    });
  }),
);
```

### 4. 弹窗渲染 Markdown

使用 Obsidian 内置的 MarkdownRenderer 以获得原生渲染效果：

```typescript
import { MarkdownRenderer, Component } from "obsidian";

const component = new Component();
MarkdownRenderer.render(app, markdownText, containerEl, "", component);

// 记得在 onClose 时释放：
onClose() { this.component.unload(); }
```

### 5. esbuild 配置注意

- **format: "cjs"** — Obsidian 插件必须用 CommonJS 格式
- **external: ["obsidian", "electron", ...]** — 这些包由 Obsidian 运行时提供
- **target: "es2018"** — 兼容 Obsidian 内置的 Electron

```javascript
// esbuild.config.mjs
import esbuild from "esbuild";
import builtins from "builtin-modules";

await esbuild.context({
  entryPoints: ["src/main.ts"],
  bundle: true,
  external: ["obsidian", "electron", ...builtins],
  format: "cjs",
  target: "es2018",
  outfile: "main.js",
}).then(ctx => {
  ctx.rebuild();
});
```

## 已知问题和规避

1. **`AbortSignal.timeout()` 不可用** — Obsidian 的 Electron 版本较旧，ES2018 target 不支持。使用 `AbortController + setTimeout` 替代：
   ```typescript
   const controller = new AbortController();
   const timer = setTimeout(() => controller.abort(), 5000);
   const resp = await fetch(url, { signal: controller.signal });
   clearTimeout(timer);
   ```

2. **外部模块不可 require** — 不能使用动态 `require("obsidian")`。所有 Obsidian API 必须在文件顶部静态 import。

3. **流式输出性能** — SSE 流每收到一块就重新渲染 Markdown 会导致闪烁。对策：每 50-100ms 节流渲染。

## Hermes API Server 启动

```bash
echo "API_SERVER_ENABLED=true" >> ~/.hermes/.env
echo 'API_SERVER_KEY="my-secret-key"' >> ~/.hermes/.env
echo "API_SERVER_HOST=0.0.0.0" >> ~/.hermes/.env   # 远程访问
echo "API_SERVER_CORS_ORIGINS=*" >> ~/.hermes/.env   # CORS（远程必需）
hermes gateway restart
```

端口默认 8642，可在 `.env` 中通过 `API_SERVER_PORT` 修改。

## 插件安装

用户将 `main.js` + `manifest.json` + `styles.css` 放入 `.obsidian/plugins/hermes-agent/` 并在 O
