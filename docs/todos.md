# AI Contract Analyzer — Implementation checklist

Use this list in order. Check items off as you complete them (`[ ]` → `[x]`).

**How to work:** **Backend first**, then **frontend in thin vertical slices** (one API feature → one UI screen → test end-to-end). The frontend depends on real endpoints; quote verification and extraction only live on the server, so building UI before those APIs exist leads to rework.

**Parallel work (optional):** After Phase 2, you can scaffold the React app (routing, API client, layout) while finishing backend chat—but still **implement backend before wiring each feature in the UI**.

**Reference:** [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

---

## Phase 0 — Repo and tooling (both sides, no features yet)

- [ ] Create monorepo layout: `backend/` and `frontend/` at project root
- [ ] Add root `.gitignore` (`.env`, `__pycache__`, `node_modules`, `.venv`, local DB dumps)
- [ ] Add `backend/.env.example` and `frontend/.env.example` (no secrets)
- [ ] Initialize git; ensure **no API keys** are committed
- [ ] Write a short `README.md` (how to run backend + frontend locally)

---

## Phase 1 — Supabase and backend skeleton (**start here**)

**Goal:** FastAPI runs and talks to Postgres; health check works.

- [ ] Create Supabase project (note region)
- [ ] Copy **Database connection string** → `backend/.env` as `DATABASE_URL`
- [ ] Create private Storage bucket `contracts` (can wire upload in Phase 3)
- [ ] Scaffold FastAPI: `main.py`, `config.py`, CORS from `FRONTEND_URL`
- [ ] SQLAlchemy: engine, `SessionLocal`, `get_db` dependency
- [ ] Add `GET /health` (returns OK; optional DB ping)
- [ ] Run locally with Uvicorn; confirm health from browser or curl

---

## Phase 2 — Data model and migrations

**Goal:** Tables exist in Supabase for documents and messages (chunks later).

- [ ] Define ORM models: `Document`, `Message` (fields per architecture doc)
- [ ] Add Alembic **or** documented one-time `create_all` for take-home
- [ ] Run migration against Supabase; verify tables in Table Editor
- [ ] Pydantic schemas for document list/detail responses

---

## Phase 3 — Part A.1: Upload, extract, library API

**Goal:** PDF/DOCX only; text stored; scanned PDF fails clearly; list/delete works.

- [ ] `POST /documents`: validate file type (reject others with clear `code` + message)
- [ ] Upload file to Supabase Storage; save `storage_path` on row
- [ ] Status flow: `extracting` → `chunking` (optional skip) → `ready` or `failed`
- [ ] PDF extraction service (text layer)
- [ ] DOCX extraction service
- [ ] Scanned PDF rule: minimal text → `failed`, `error_code=scanned_pdf`, user-facing message
- [ ] Persist `extracted_text`, `char_count`, `status=ready`
- [ ] `GET /documents` — library list
- [ ] `GET /documents/{id}` — metadata + status (for polling)
- [ ] `GET /documents/{id}/text` — extracted text for viewer
- [ ] `DELETE /documents/{id}` — DB row + Storage object + messages
- [ ] Test with curl/Postman: good PDF, good DOCX, bad type, scanned PDF

---

## Phase 4 — Frontend shell + document library (first UI slice)

**Goal:** User can upload, see status, list, open, delete—no chat yet.

- [ ] Scaffold Vite + React + TypeScript
- [ ] Set `VITE_API_URL`; shared `api` client with error handling
- [ ] App layout + routes: `/`, `/documents/:id` (chat placeholder)
- [ ] Upload component with visible states (uploading / processing / ready / error)
- [ ] Poll `GET /documents/{id}` until `ready` or `failed`
- [ ] Document library page: list, delete, navigate to detail
- [ ] CORS verified (frontend origin allowed on backend)

---

## Phase 5 — Quote verification (backend only, before trusting chat)

**Goal:** Core assignment requirement implemented and unit-tested.

- [ ] `services/quote_verify.py`: normalize whitespace (collapse spaces/newlines)
- [ ] Locate quote in `extracted_text`; compute `start_char`, `end_char` yourself
- [ ] Ignore model page/offset; handle “not found” → unverified
- [ ] Unit tests: exact match, extra whitespace, fake quote rejected, duplicate phrase policy
- [ ] Pydantic type for verified `Citation` returned to UI

---

## Phase 6 — Part A.2: Chat API (single document)

**Goal:** Stream answers, save history, stop keeps partial text.

- [ ] LLM client from env: `OPENAI_API_KEY`, `OPENAI_BASE_URL`, `MODEL_NAME`
- [ ] System prompt: answer only from context; say if not found; provide quotable strings
- [ ] `GET /documents/{id}/messages` — history
- [ ] `POST /documents/{id}/chat` — SSE (token events + final `done` with citations)
- [ ] For **short docs**: send full `extracted_text` in prompt (dev shortcut OK initially)
- [ ] Parse model output (JSON citations preferred)
- [ ] Run **quote_verify** on every candidate; only verified in `done` + DB
- [ ] Save user + assistant messages; `citations` jsonb on assistant rows
- [ ] Client disconnect / abort → stop LLM read; persist partial assistant content
- [ ] Test streaming with curl or a minimal HTML page before polishing React

---

## Phase 7 — Part A.2 UI: Chat screen

**Goal:** Chat with streaming, stop, history reload.

- [ ] Chat panel on `/documents/:id`
- [ ] SSE consumer (`fetch` stream or EventSource) with **Stop** (`AbortController`)
- [ ] Render streaming markdown/text; append verified citations on `done`
- [ ] Reload history on page open
- [ ] Empty/error states (doc not ready, LLM failure)

---

## Phase 8 — Part A.4: Large documents (chunk + retrieve)

**Goal:** ~150 pages works; no false “clause does not exist” claims.

- [ ] ORM `DocumentChunk` + migration
- [ ] `services/chunking.py`: split by paragraph/size with overlap; store `start_char`/`end_char`
- [ ] Run chunking after extraction (`status=chunking` → `ready`)
- [ ] `services/retrieval.py`: top-K chunks for user question (keyword/BM25 first; embeddings optional)
- [ ] Chat uses retrieved chunks only; prompt includes **honesty rule** for partial coverage
- [ ] Manual test with a long PDF/DOCX

---

## Phase 9 — Part B.5: Citation → document (MVP then hard)

**Goal:** Click quote → scroll + highlight.

- [ ] Text viewer component showing `GET .../text`
- [ ] Highlight range from verified `start_char`/`end_char`
- [ ] Click citation in chat → scroll viewer to highlight
- [ ] (Stretch) PDF preview + PDF.js text-layer mapping for highlights
- [ ] (Stretch) Multi-line / page-break / duplicate occurrence handling

---

## Phase 10 — Part B.6: Multi-document chat

**Goal:** One question, comparative answer, per-doc verified quotes.

- [ ] DB: `conversations` + `conversation_documents` **or** request body with `document_ids[]`
- [ ] `POST /chat/multi` SSE: retrieve per doc; single comparative prompt
- [ ] Each citation includes `document_id` / filename; verify against **that** doc’s text
- [ ] Frontend: multi-select in library → multi chat route
- [ ] Click citation opens correct document + highlight

---

## Phase 11 — Part B.7: Document comparison

**Goal:** Two versions, clause-level diff, substance summary, sort/filter by significance.

- [ ] `POST /compare` with `doc_a_id`, `doc_b_id`
- [ ] Split both texts into blocks (paragraphs / clauses)
- [ ] Align blocks (similarity); classify added / removed / modified
- [ ] LLM summaries focused on **substantive** changes (caps, dates, liability)
- [ ] Significance score for filter/sort
- [ ] Optional: `compare_runs` table + poll for slow jobs
- [ ] Frontend `/compare`: pick two docs, results list + summary

---

## Phase 12 — Part C (pick one)

Document choice in README note.

**Option 1 — Tracked-change redlining**

- [ ] Research DOCX OOXML revision markup
- [ ] Map plain-language edit request → locate runs in DOCX (not plain string replace)
- [ ] Apply real tracked changes; preserve formatting
- [ ] Download endpoint; verify in Word/LibreOffice

**Option 2 — Agentic document research**

- [ ] Tools: `search_document`, `get_section`, `list_clauses` (implement atop chunks)
- [ ] Multi-round agent loop with hard max rounds
- [ ] Stream status lines (“Searching for termination…”)
- [ ] Handle malformed tool calls without 500
- [ ] Final answer still uses quote verification

---

## Phase 13 — Deploy and polish

**Goal:** Grader can use a public URL; app feels complete.

- [ ] Deploy FastAPI (Railway / Render / Fly): env vars set on host
- [ ] Deploy React (Vercel / Netlify): `VITE_API_URL` → production API
- [ ] Production `FRONTEND_URL` in backend CORS
- [ ] Confirm Storage + Postgres work in prod (upload, chat, persistence)
- [ ] Test SSE streaming through production host (no buffering break)
- [ ] README: architecture summary, env vars, deploy links, Part C choice + limitations
- [ ] End-to-end smoke test: upload → chat → verified quote → highlight → (multi/compare if done)

---

## Quick reference: assignment ↔ phases

| Requirement | Phase |
|-------------|--------|
| Upload PDF/DOCX, reject others | 3 |
| Processing status, scanned PDF | 3, 4 |
| Document library | 3, 4 |
| Chat stream + stop + history | 6, 7 |
| Verified quotes | 5, 6 |
| Large documents | 8 |
| Citation highlighting | 9 |
| Multi-document Q&A | 10 |
| Version comparison | 11 |
| Part C | 12 |
| Deploy | 13 |

---

## Suggested weekly rhythm (adjust to your schedule)

| Week focus | Phases |
|------------|--------|
| 1 | 0–3 (backend upload pipeline solid) |
| 2 | 4–7 (library + chat working E2E) |
| 3 | 8–9 (long docs + highlights) |
| 4 | 10–11 (advanced B) |
| 5 | 12–13 (Part C attempt + deploy) |

---

## Definition of “done” for Part A + B (before Part C)

- [ ] All Part A rows in table above checked
- [ ] All Part B rows in table above checked
- [ ] At least one real contract tested end-to-end on deployed URL
- [ ] Known limitations documented honestly in README
