# RAG Assistant — Ubuntu Touch app (handoff)

A Lomiri/Ubuntu Touch app that chats with a knowledge base via RAG.
LLM = OpenRouter (default Gemini 2.5 Pro), retrieval = Chroma + Ollama embeddings,
voice in/out = self-hosted Whisper + Kokoro TTS.

## What works today

- **Chat with streaming**: OpenRouter SSE → token-by-token rendering, multi-turn history.
- **RAG flow**: embed query (Ollama `nomic-embed-text`, 768d) → top-K from Chroma → inject as system context → stream answer in the user's language. Sources shown as clickable chips that expand the chunk.
- **Persistence (SQLite via `Qt.LocalStorage`)**: conversations + messages survive restart. Sidebar with list, switch, rename, delete.
- **Sidebar**: pinned on wide screens (≥ `gu(80)`), slide-in drawer on narrow. Toggle via `navigation-menu` icon.
- **Theme system (`AppTheme.qml`)**: dark/light + 6 accent palettes (indigo, cyan, emerald, violet, rose, sunset). Gradient backgrounds, gradient user bubbles. Live switching from Settings.
- **i18n (`AppI18n.qml`)**: en / es / nl with reactive runtime switching. **Custom QtObject, NOT gettext** — gettext can't be live-switched without restarting in Qt 5.12.
- **Markdown rendering** for assistant bubbles (`js/Markdown.js`) → `Text.RichText`. Qt 5.12 has no native `Text.MarkdownText`.
- **STT**: push-to-talk mic button → `QAudioRecorder` (C++) → POST to Whisper → transcription populates input.
- **TTS**: speaker button on each assistant bubble → POST to Kokoro → MP3 saved → `MediaPlayer` plays. Auto-speak toggle in Settings.
- **Splash screen**, **conversation search**, **connectivity test panel** in Settings, **typing-indicator wave animation**, **copy button on bubbles**, **phase tracking** ("retrieving" / "thinking") while streaming.

## Server infrastructure (172.28.18.200)

SSH access as user `mauricio`. All services are Docker containers.

| Service | Port | API style | Notes |
|---|---|---|---|
| Chroma | 8000 | v2 API | Tenant `default_tenant`, DB `default_database`. Collection `ssp-docs` id `7e001a88-467b-45bc-8bf0-169042f7b943` (322 docs, client-side embeddings = nomic). Also `ssp-docs__gemini__gemini-embedding-2__768` (2177 docs, **needs Gemini API to query**). |
| Ollama | 11434 | `/api/embeddings` | `nomic-embed-text` available, 768d. Also has many local LLMs (gpt-oss:20b, deepseek-r1, llama3.1, gemma4, etc.) — unused right now but **viable fallback if OpenRouter fails**. |
| faster-whisper-server | 3011 | OpenAI `/v1/audio/transcriptions` | CPU. Multilingual. |
| Kokoro-FastAPI | 8880 | OpenAI `/v1/audio/speech` | CPU. Voices: `af_bella` (en F), `am_michael` (en M), `ef_dora` (es F), `em_alex` (es M), `bf_emma` (en UK F), etc. **No nl voice** — Dutch falls back to English. |

## Build & run

```bash
cd ~/Projects/CODEFEST/ragassistant
clickable desktop                       # build + run locally (audio DOES NOT WORK in this mode, see "Gotchas")
clickable install --arch arm64          # deploy to a connected UT phone
clickable launch                        # launch on phone after install
```

Before any build, **clear the QML cache** if you changed singletons / pragma-anything:
```bash
rm -rf /home/mauricio/.clickable/home/.cache/ragassistant.ragassistant/qmlcache
```

## Architecture

```
qml/
├── Main.qml              PageStack + Settings + AppTheme + AppI18n instances
├── ChatPage.qml          Chat surface, sidebar, mic + send + tts wiring
├── SettingsPage.qml      Grouped cards (Appearance, Interface, LLM, Chroma, Embeddings, Voice, Connectivity)
├── SplashScreen.qml      Brief splash on app open
├── AppI18n.qml           QtObject with reactive `language` + `tr(key)`
├── AppTheme.qml          QtObject with all colors derived from {mode, presetIndex}
├── components/
│   ├── Card.qml              Section-titled rounded card (Settings)
│   ├── ConversationList.qml  Sidebar (list + new chat + rename/delete actions)
│   ├── FieldLabel.qml        Small bold label above inputs
│   ├── MessageBubble.qml     User/assistant/system bubble with copy+speaker actions
│   ├── StyledField.qml       Themed TextInput-in-Rectangle (Settings forms)
│   ├── SuggestionCard.qml    Tappable prompt suggestion on empty state
│   └── TypingIndicator.qml   3-dot wave animation
└── js/
    ├── ChromaClient.js       Embed via Ollama + query Chroma v2
    ├── I18nData.js           Translation dictionaries (en/es/nl)
    ├── Markdown.js           Minimal MD → RichText (Qt 5.12 has no MarkdownText)
    ├── OpenRouterClient.js   SSE streaming chat completions
    ├── RagOrchestrator.js    Retrieve → build context → stream chat
    └── Store.js              SQLite CRUD for conversations + messages

src/                              # Qt 5.12 C++ (cmake builder)
├── main.cpp                  QQuickView (NOT QQmlApplicationEngine — see Gotchas)
├── audiorecorder.{h,cpp}     QAudioRecorder wrapper, format auto-detect
├── whisperclient.{h,cpp}     QHttpMultiPart upload to /v1/audio/transcriptions
└── ttsclient.{h,cpp}         POST JSON to /v1/audio/speech, save MP3, emit filePath
```

Types registered in main.cpp under `Ragassistant.Audio 1.0`:
`AudioRecorder`, `WhisperClient`, `TtsClient`.

## Gotchas (every one of these cost time — internalize before touching code)

1. **UT runs Qt 5.12.** No `Text.MarkdownText`, no inline `component Foo : ...`, no `qsTr` runtime swap.
2. **`MainView` (Lomiri.Components) inherits `Item`, not `Window`.** Must use `QQuickView` in main.cpp; `QQmlApplicationEngine` loads QML but never shows a window.
3. **`I18n` is a reserved type in Lomiri.Components.** Our singleton is named `AppI18n.qml` (capital A, different).
4. **`pragma Singleton` with `import "." 1.0` is unreliable in Qt 5.12.** Tried it — looked fine, but the type resolved to `undefined` at runtime, breaking every `I18n.tr(...)` binding. We use **plain QtObject instances + property injection** instead. Pages get `i18nApp` and `appTheme` props from Main.qml.
5. **`ThinDivider` is not in `Lomiri.Components 1.3`** (moved to `Lomiri.Components.ListItems`). Use plain `Rectangle`.
6. **QML disk cache is sticky.** A file that was once `pragma Singleton` still resolves as singleton from cache even after you remove the pragma. Always:  
   `rm -rf ~/.clickable/home/.cache/ragassistant.ragassistant/qmlcache` before rebuild.
7. **Bindings track property reads at the binding's evaluation site, not inside called functions.** Putting `i18nApp.tr("X")` in a binding works because inside `tr()` we read `language` *during* the binding evaluation. But `JS-module-level state changes don't propagate to bindings* — that's why we use QtObject for the language, not just a JS variable.
8. **`anchors.centerIn: parent` on a `ColumnLayout` triggers binding loops.** Use `anchors.horizontalCenter` + `anchors.verticalCenter` explicitly.
9. **clickable desktop's Docker has no audio device.** Mic + TTS playback only work on a real UT phone, or by running the compiled binary natively (`build/.../install/ragassistant`).
10. **`XDG_RUNTIME_DIR` is unset in clickable's Docker** → PulseAudio init logs errors and can hang `MediaPlayer`. We set it to `/tmp/runtime-<user>` in main.cpp before constructing `QGuiApplication`.
11. **Builder is `cmake`** (not `pure-qml-cmake`) because we have C++. `clickable.yaml` and `ragassistant.desktop.in` reflect that — Exec is the binary name, not `qmlscene`.
12. **apparmor policy groups**: `networking`, `audio`, `microphone`. Missing any one breaks the feature silently on device.
13. **`Store.addMessage` etc. are wrapped in try/catch** in ChatPage so a DB hiccup never blocks the LLM call. Persistence is best-effort; chat flow is the contract.
14. **QML's `Qt.LocalStorage` parameter binding turns JS `""` into SQL `NULL`.** A column declared `TEXT NOT NULL DEFAULT ''` will reject the bound `""` because the NOT NULL check happens before DEFAULT kicks in. Either drop NOT NULL on optional text columns or omit them from the INSERT to let DEFAULT apply. Reads should coerce NULL back to `""`.
15. **`property var foo` auto-generates a `fooChanged()` signal.** Declaring your own `signal fooChanged()` triggers `Duplicate signal name: invalid override of property change signal or superclass signal`. Pick a different verb (e.g. `fooModified`) or drop the explicit signal and listen via the property-change one.
16. **`Component.onCompleted` order between sibling Items is not strictly guaranteed.** If page A calls `Store.init()` and sibling page B reads from the DB on its own `onCompleted`, B can fire first and hit "no such table". Make `init` idempotent and call it defensively from any page that touches the DB at startup.

## Roadmap — agreed direction

The user wants this to become a **company "brain"** with topic-segmented RAG and tool execution capabilities.

### Phase 1 — Multi-topic RAG (next session — agreed but not yet started)
- Local SQLite table `topics(id, name, collection_id, color, icon, system_prompt_addon)`
- UI: topic chip in the chat header; tap → switcher
- Each `conversations` row stores its topic_id (already has `collection_id` column we can repurpose)
- Optional **Auto mode**: small classifier LLM call picks the topic per query (or query-all + re-rank — RAG fusion)
- Settings: CRUD over topics

### Phase 2a — Tool harness POC ✅ shipped
- `qml/js/tools/registry.js` + `builtins.js` expose tools in OpenAI's `tools` schema. Two POC builtins: `get_current_time` and `calculator` (sandboxed math eval).
- `OpenRouterClient.streamChat` accumulates streamed `delta.tool_calls[i]` chunks keyed by index, parses arguments JSON at finish, returns them to `onDone(text, usage, toolCalls)`.
- `RagOrchestrator.runWithTools(settings, messages, callbacks, depth)` drives the loop: stream → if tool_calls, append the assistant message with `tool_calls`, execute each via `settings.toolRegistry`, append one `role:"tool"` reply per call with `tool_call_id`, recurse. Capped at `MAX_TOOL_DEPTH = 5`.
- Callbacks ChatPage hooks into: `onPreTools(text, calls)` (finalize/clean current assistant placeholder), `onToolDone(call, result)` (append a tool bubble), `onRoundStart(depth)` (append a fresh assistant placeholder for the next round).
- `streamingIdx` in ChatPage tracks the index of the currently-streaming assistant bubble so tool bubbles slotted in mid-turn don't corrupt content updates.
- Tool turns are NOT persisted to SQLite — only `user` and `assistant` messages are. Tool context lives only inside one user turn.
- Toggle: `appSettings.toolsEnabled` (Language model card in Settings). When off, `streamChat` body omits `tools` entirely.

### Phase 2b — Real tools via FastAPI backend on 172.28.18.200
- `/tools/sql` — configurable DB connections, sandboxed `SELECT`-only by default
- `/tools/csv` — read/query CSV (DuckDB or pandas)
- `/tools/excel` — openpyxl, return sheet/range as JSON
- `/tools/web` — search + scrape (optional)
- Tool registry on the QML side: `js/tools/registry.js` with name, description, JSON schema, execute function
- Each tool entry can either run locally (JS) or POST to the backend

### Phase 3 — MCP (optional, longer term)
- Migrate the tool layer to **Model Context Protocol** (Anthropic, open standard). One client, many independent tool servers. Better for when there are 3+ tools and the team wants to add more without touching the app.

## What NOT to do

- Don't go back to `pure-qml-cmake`. We need C++ for audio.
- Don't use `pragma Singleton`. Property injection works, is debuggable.
- Don't replace `AppI18n` with gettext + restart-required. Live language switch was a hard requirement.
- Don't assume `clickable desktop` reflects device behavior for audio. Always test mic / TTS on the phone.
- Don't add MD files unless explicitly asked. This file is the exception (it's the handoff).
- Don't `--no-verify` past pre-commit hooks if a future user adds them.

## Quick reference — useful files when picking up

- **Where chat logic lives**: `qml/ChatPage.qml` (the orchestrator: sendQuery, persist, stream)
- **Where settings live**: `qml/Main.qml` (the `Settings {}` block — defaults + persisted properties)
- **Where colors live**: `qml/AppTheme.qml`
- **Where translations live**: `qml/js/I18nData.js`
- **Where RAG flow lives**: `qml/js/RagOrchestrator.js`
- **Where C++ types are registered**: `src/main.cpp`

When in doubt about Qt/Lomiri behavior, check `Gotchas` first — half the answers are there.
