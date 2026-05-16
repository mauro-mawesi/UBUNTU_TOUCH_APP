# Audit del knowledge base en Chroma — feedback para el pipeline de ingesta

**Autor:** Mauricio (mantenedor de RAG Assistant)
**Fecha:** 2026-05-16
**Audiencia:** equipo responsable del pipeline de ingesta y la parametrización de Chroma

## Contexto

Estoy integrando RAG Assistant (app Lomiri/Ubuntu Touch que consume Chroma vía API v2) y validé qué hay almacenado en las colecciones `ssp-docs` y `ssp-docs__gemini__gemini-embedding-2__768` en `172.28.18.200:8000`. La calidad de las respuestas que ve el usuario final depende casi por completo de cómo se troceó y enriqueció la información que ustedes ingestaron. Encontré cosas muy bien hechas y un par de gaps que vale la pena cerrar antes de pasar el producto a un piloto real.

Audit hecho con GETs read-only sobre la API v2 (`/get` con `limit:500`), sin modificar nada.

---

## ✅ Lo que está bien hecho (pipeline `.md`)

281 de 322 chunks en `ssp-docs` vienen del pipeline Markdown y siguen las mejores prácticas:

- **Chunking estructural por jerarquía de headings** (no ventana fija). Distribución sana: min 90 / median 407 / p90 2430 / max 2656 chars.
- **Breadcrumb prependido al texto** del chunk — el embedding captura la jerarquía:
  ```
  [06 — Business Logic > Estados relevantes > Causal y grupo causal]

  - `ACTIVO` / inactivo.
  ```
- **Metadatos ricos por chunk**: `section_title`, `doc_type`, `project_id`, `storage`, `storage_ref`, `kind`, `source_id`, `chunk_index`.
- **IDs idempotentes con hash de contenido**: formato `<source_id>#<chunk_index>#<hash10>` — re-ingest con contenido idéntico no duplica.
- **Tablas preservadas íntegras** (verificado en `00-index.md`).

**No cambien este pipeline.** Es el patrón a replicar para los demás formatos.

---

## ❌ Problema 1 — Pipeline `.docx` (SharePoint) no está al mismo estándar

41 chunks del `REGLAMENTO INTERNO DE TRABAJO - MAWESI.docx` muestran un pipeline distinto, claramente fixed-window:

| Aspecto | Pipeline MD | Pipeline DOCX |
|---|---|---|
| Tipo de chunking | Estructural por heading | Ventana fija (~2300 chars uniformes) |
| Breadcrumb en el texto | ✓ | ✗ — chunks empiezan mid-frase |
| `section_title` en metadata | ✓ | ✗ |
| `doc_type`, `project_id`, `storage*` | ✓ | ✗ |
| Tablas | preservadas | troceadas |

**Evidencia (chunk 5 del Reglamento):**
```
'seis (36) horas semanales prevista en el inciso segundo parágrafo 1º de
este reglamento. 2. El trabajo extra diurno se remunera con un recargo
del veinticinco por ciento (25%)...'
```

Sin breadcrumb ni section_title, este chunk **no responde** preguntas como "¿qué horario tengo?" — no hay señal léxica ni semántica que conecte la pregunta del usuario con el contenido. El embedding cae en ruido.

### Pedido

Llevar el pipeline `.docx` (y por extensión `.pdf`, `.xlsx`) al mismo estándar que el MD:

- Usar `python-docx` (estilos nativos detectan H1/H2/H3) o `unstructured.io` (cubre docx + pdf + html + xlsx con estructura uniforme).
- **Output schema idéntico al MD pipeline**: misma forma de breadcrumb prependido, mismos campos de metadata.
- Tablas: extraer como bloque + caption sintética (1 línea generada por LLM al ingestar describiendo de qué es la tabla).

---

## ❌ Problema 2 — Duplicación en la colección Gemini

`ssp-docs__gemini__gemini-embedding-2__768` (2177 chunks) y `ssp-docs` (322 chunks) cubren los **mismos source docs** pero con counts inconsistentes. Más grave: dentro de la colección gemini, **el mismo `file_name` aparece con dos sequences distintas de `chunk_index`**, indicando re-ingestas sin cleanup:

| Documento | chunks nomic | chunks gemini |
|---|---|---|
| `REGLAMENTO INTERNO - MAWESI.docx` | 41 | 68 |
| `03a-api-endpoints-auth-planning.md` | 64 | 64 |
| `01-project-overview.md` | 16 | **16 + 21** ← duplicado dentro de la misma colección |
| `02-backend-architecture.md` | 15 | **15 + 10** ← duplicado |
| `03d1-workflows-endpoints.md` | (no existe) | 47 |

Esto significa que un retrieval puede traer fragmentos de la versión vieja Y la nueva del mismo documento como "fuentes", y el LLM puede citar información contradictoria sin que el usuario lo note.

### Pedido

1. Auditoría: para cada `(file_name, source_id)`, listar los rangos de `chunk_index` distintos. Donde haya múltiples, marcar como duplicado.
2. Definir política de cleanup:
   - **Recomendado**: borrar el set viejo (el que no coincide con el sha256 del source actual).
   - Alternativa: hard-delete por `source_id` antes de cada re-ingest del documento → re-ingest siempre limpio.
3. Re-correr el pipeline tras la limpieza y verificar que `count distinct (file_name, run)` == `count distinct (file_name)`.

---

## ❌ Problema 3 — Dos colecciones para el mismo corpus

Tenemos dos colecciones que indexan esencialmente los mismos documentos con embedders diferentes (nomic vs gemini-embedding-2). Esto es deuda:

- El cliente (la app) solo puede consultar una a la vez, así que la otra está consumiendo storage sin uso real.
- Cuando re-ingesten, tienen que correr el pipeline dos veces para mantener paridad.
- Ningún usuario va a saber cuál colección tiene "la respuesta más reciente".

### Pedido — Decisión de arquitectura

Elegir **una sola colección canónica** y deprecar la otra. Propuesta:

- **Opción A (recomendada)**: migrar todo a una colección nueva con **`bge-m3`** vía Ollama. Es multilingüe nativo (ES/EN/NL), 1024d, on-prem, sin dependencia de API externa. Mejor recall cross-lingual que nomic.
- **Opción B**: quedarse con gemini si está pagada y midiendo bien, pero borrar `ssp-docs` (nomic).
- **Opción C**: solo si justificable — mantener ambas pero con **scope estrictamente disjunto por `source_id`** (ej. una para públicos, otra para confidenciales) y documentar la regla.

Si eligen migrar, el cliente (la app) necesita saber el nuevo `collection_id` para actualizar settings.

---

## ❌ Problema 4 — Metadatos transversales que faltan

Independiente del formato, faltan campos clave para el caso de uso "cerebro corporativo":

| Campo | Uso | Estado |
|---|---|---|
| `chunk_total` | Mostrar "chunk 3 of 47" en citas; saber si trajimos una porción razonable | ✗ falta en todos |
| `lang` (ej. "es", "en") | Filtrar/scorear por idioma; clave si mezclan ES/EN/NL | ✗ falta en todos |
| `content_sha256` (doc-level) | Detectar si el source cambió desde la última indexación → re-ingest diferencial | ✗ (existe a nivel chunk dentro del ID pero no como campo legible) |
| `indexed_at` (epoch o ISO) | Auditoría, debug, freshness scoring | ✗ |
| `last_modified` | Ya existe pero **solo en 41/322 chunks de nomic y 68/500 de gemini** — inconsistente entre pipelines | parcial |
| `acl` o `confidentiality` | Filtrado por permisos cuando pasen a multi-departamento | ✗ (diferible) |

### Pedido

Agregar `chunk_total`, `lang`, `content_sha256`, `indexed_at` a los **dos** pipelines (MD y DOCX). `last_modified` ya está en MD pero no en DOCX — homologar. `acl` se puede dejar para más adelante.

---

## ❌ Problema 5 — No hay log de ingesta auditable

Cuando alguien diga "el bot no encuentra el documento Z que subí el martes", hoy no tenemos forma de saber si Z se indexó, con qué versión, con qué embedder. **Cualquier debug es adivinanza.**

### Pedido

Log append-only (JSONL es suficiente) por cada ingesta:

```jsonl
{"ts":"2026-05-16T13:00:00Z","action":"index","file":"...","source_id":"...","sha256":"...","embedder":"bge-m3","chunks":47,"collection":"company-brain","run_id":"abc123"}
{"ts":"2026-05-16T13:00:01Z","action":"skip-unchanged","file":"...","sha256":"..."}
{"ts":"2026-05-16T13:00:02Z","action":"delete","source_id":"...","reason":"source-removed"}
```

Esto + un endpoint `/ingest/log?file=X` resuelven el 80 % de los debugs futuros.

---

## ⚙️ Problema 6 — Tuning bajo (low priority)

Config HNSW actual de las colecciones:

```json
{"ef_construction":100, "ef_search":100, "max_neighbors":16, "space":"cosine"}
```

Con `topK=5` y ~2k records, `ef_search=100` es exceso (explora 100 candidatos para devolver 5). Bajarlo a **50** mantiene recall y reduce latencia.

A partir de >10k records: re-evaluar. >100k: subir `max_neighbors` a 32.

### Pedido

Cambio trivial — al crear la colección nueva (post-migración), usar `ef_search=50` en `metadata.hnsw:search_ef`.

---

## Resumen accionable (lo mínimo para piloto)

| # | Item | Prioridad | Owner sugerido |
|---|---|---|---|
| 1 | Pipeline DOCX al mismo estándar del MD (breadcrumb + section_title + metadata) | **P0** | equipo ingesta |
| 2 | Audit + dedupe de la colección gemini | **P0** | equipo ingesta |
| 3 | Decisión: una sola colección canónica (recomiendo `bge-m3` on-prem) | **P0** (decisión esta semana) | equipo ingesta + arquitectura |
| 4 | Agregar `chunk_total`, `lang`, `content_sha256`, `indexed_at` a todos los pipelines | P1 | equipo ingesta |
| 5 | Log de ingesta append-only | P1 | equipo ingesta |
| 6 | Bajar `ef_search` a 50 al crear colección nueva | P2 | equipo ingesta |
| 7 | ACL por documento | P3 — diferir | arquitectura |

---

## Preguntas abiertas

1. ¿El pipeline MD es código propio o usan un framework? Si es propio, ¿está en un repo donde podamos colaborar para extenderlo al DOCX?
2. ¿La colección gemini está en uso por alguien hoy, o es un experimento paralelo? Esto define si podemos borrarla agresivamente.
3. ¿Existe ya una fuente de verdad versionada (git, NextCloud con histórico, S3 con versioning) de los documentos, o el pipeline lee directo de SharePoint sin snapshot? El segundo caso hace imposible reproducir un estado pasado del índice.
4. ¿Quién es el dueño funcional de cada topic (RRHH, ops, security)? Necesario para el golden set de evaluación cuando pasemos a piloto.

---

## Apéndice — metodología del audit

Reproducible con curl + python sin tocar datos:

```bash
# 1. Listar colecciones
curl -s 'http://172.28.18.200:8000/api/v2/tenants/default_tenant/databases/default_database/collections'

# 2. Sample de una colección (500 records, sin embeddings)
curl -s -X POST 'http://172.28.18.200:8000/api/v2/tenants/default_tenant/databases/default_database/collections/<ID>/get' \
  -H 'Content-Type: application/json' \
  -d '{"limit": 500, "include": ["documents","metadatas"]}' > dump.json

# 3. Analizar (chunks por doc, distribución de tamaños, cobertura de metadata)
python3 -c "
import json, collections, statistics
d = json.load(open('dump.json'))
by_src = collections.Counter([m.get('source_id') for m in d['metadatas']])
sizes = [len(t) for t in d['documents']]
print('Unique source_ids:', len(by_src))
print('Top docs:', by_src.most_common(10))
print('Chunk len p50/p90:', int(statistics.median(sizes)), int(statistics.quantiles(sizes,n=10)[8]))
"
```

Si quieren, puedo armar un script Python read-only que reproduzca este audit y un script de cleanup con flag `--apply` para los duplicados (P0 #2). Avísenme.
