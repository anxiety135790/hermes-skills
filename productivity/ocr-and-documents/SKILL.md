---
name: ocr-and-documents
description: "Extract text from PDFs/scans (pymupdf, marker-pdf)."
version: 2.3.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [PDF, Documents, Research, Arxiv, Text-Extraction, OCR]
    related_skills: [powerpoint]
---

# PDF & Document Extraction

For DOCX: use `python-docx` (parses actual document structure, far better than OCR).
For PPTX: see the `powerpoint` skill (uses `python-pptx` with full slide/notes support).
This skill covers **PDFs and scanned documents**.

## Step 1: Remote URL Available?

If the document has a URL, **always try `web_extract` first**:

```
web_extract(urls=["https://arxiv.org/pdf/2402.03300"])
web_extract(urls=["https://example.com/report.pdf"])
```

This handles PDF-to-markdown conversion via Firecrawl with no local dependencies.

Only use local extraction when: the file is local, web_extract fails, or you need batch processing.

## Step 2: Choose Local Extractor

| Feature | pymupdf (~25MB) | marker-pdf (~3-5GB) |
|---------|-----------------|---------------------|
| **Text-based PDF** | ✅ | ✅ |
| **Scanned PDF (OCR)** | ❌ | ✅ (90+ languages) |
| **Tables** | ✅ (basic) | ✅ (high accuracy) |
| **Equations / LaTeX** | ❌ | ✅ |
| **Code blocks** | ❌ | ✅ |
| **Forms** | ❌ | ✅ |
| **Headers/footers removal** | ❌ | ✅ |
| **Reading order detection** | ❌ | ✅ |
| **Images extraction** | ✅ (embedded) | ✅ (with context) |
| **Images → text (OCR)** | ❌ | ✅ |
| **EPUB** | ✅ | ✅ |
| **Markdown output** | ✅ (via pymupdf4llm) | ✅ (native, higher quality) |
| **Install size** | ~25MB | ~3-5GB (PyTorch + models) |
| **Speed** | Instant | ~1-14s/page (CPU), ~0.2s/page (GPU) |

**Decision**: Use pymupdf unless you need OCR, equations, forms, or complex layout analysis.

If the user needs marker capabilities but the system lacks ~5GB free disk:
> "This document needs OCR/advanced extraction (marker-pdf), which requires ~5GB for PyTorch and models. Your system has [X]GB free. Options: free up space, provide a URL so I can use web_extract, or I can try pymupdf which works for text-based PDFs but not scanned documents or equations."

---

## pymupdf (lightweight)

```bash
pip install pymupdf pymupdf4llm
```

**Via helper script**:
```bash
python scripts/extract_pymupdf.py document.pdf              # Plain text
python scripts/extract_pymupdf.py document.pdf --markdown    # Markdown
python scripts/extract_pymupdf.py document.pdf --tables      # Tables
python scripts/extract_pymupdf.py document.pdf --images out/ # Extract images
python scripts/extract_pymupdf.py document.pdf --metadata    # Title, author, pages
python scripts/extract_pymupdf.py document.pdf --pages 0-4   # Specific pages
```

**Inline**:
```bash
python3 -c "
import pymupdf
doc = pymupdf.open('document.pdf')
for page in doc:
    print(page.get_text())
"
```

---

## marker-pdf (high-quality OCR)

```bash
# Check disk space first
python scripts/extract_marker.py --check

pip install marker-pdf
```

**Via helper script**:
```bash
python scripts/extract_marker.py document.pdf                # Markdown
python scripts/extract_marker.py document.pdf --json         # JSON with metadata
python scripts/extract_marker.py document.pdf --output_dir out/  # Save images
python scripts/extract_marker.py scanned.pdf                 # Scanned PDF (OCR)
python scripts/extract_marker.py document.pdf --use_llm      # LLM-boosted accuracy
```

**CLI** (installed with marker-pdf):
```bash
marker_single document.pdf --output_dir ./output
marker /path/to/folder --workers 4    # Batch
```

---

## Arxiv Papers

```
# Abstract only (fast)
web_extract(urls=["https://arxiv.org/abs/2402.03300"])

# Full paper
web_extract(urls=["https://arxiv.org/pdf/2402.03300"])

# Search
web_search(query="arxiv GRPO reinforcement learning 2026")
```

## Split, Merge & Search

pymupdf handles these natively — use `execute_code` or inline Python:

```python
# Split: extract pages 1-5 to a new PDF
import pymupdf
doc = pymupdf.open("report.pdf")
new = pymupdf.open()
for i in range(5):
    new.insert_pdf(doc, from_page=i, to_page=i)
new.save("pages_1-5.pdf")
```

```python
# Merge multiple PDFs
import pymupdf
result = pymupdf.open()
for path in ["a.pdf", "b.pdf", "c.pdf"]:
    result.insert_pdf(pymupdf.open(path))
result.save("merged.pdf")
```

```python
# Search for text across all pages
import pymupdf
doc = pymupdf.open("report.pdf")
for i, page in enumerate(doc):
    results = page.search_for("revenue")
    if results:
        print(f"Page {i+1}: {len(results)} match(es)")
        print(page.get_text("text"))
```

No extra dependencies needed — pymupdf covers split, merge, search, and text extraction in one package.

---

## Notes

- `web_extract` is always first choice for URLs
- pymupdf is the safe default — instant, no models, works everywhere
- marker-pdf is for OCR, scanned docs, equations, complex layouts — install only when needed
- Both helper scripts accept `--help` for full usage
- marker-pdf downloads ~2.5GB of models to `~/.cache/huggingface/` on first use
- For Word docs: `pip install python-docx` (better than OCR — parses actual structure)
- For PowerPoint: see the `powerpoint` skill (uses python-pptx)
- **Google Drive OCR fallback**: see `references/google-drive-ocr-workflow.md` for a reusable script. Use when local OCR fails (no tesseract, marker too slow). Requires `drive.file` scope.

## Pitfalls (learned the hard way)

### PDF is scanned/image-based? Check FIRST before any extraction attempt

**Always run this 30-second diagnostic before choosing an extractor:**

```python
import pymupdf
doc = pymupdf.open("document.pdf")
sample = sum(len(doc[i].get_text()) for i in range(min(5, doc.page_count)))
doc.close()
if sample < 200:
    print("SCANNED — needs OCR (marker-pdf)")
else:
    print("TEXT-BASED — pymupdf will work")
```

If scanned: expect OCR time of ~6s/page on CPU. A 300-page doc = ~30 minutes. For large scanned books, extract only the table of contents + key chapters, not the full document.

### marker-pdf timeout risk on large documents

marker-pdf running against 50 pages times out at 300s (~6s/page). For books >100 pages, either use `--pages` to limit scope, or accept that full-OCR will take many minutes. Consider targeted extraction of high-value pages instead.

### vision tool cannot read local files

The vision tool accepts only:
- Public HTTP/HTTPS URLs
- NOT `file://` paths, NOT `localhost`, NOT absolute paths on the machine

Workaround for local images: serve via Python HTTP server on a high port, or use `execute_code` + base64 data URI (not yet validated as working).

### No tesseract / apt-get denied / no root

If neither `tesseract` nor `apt-get` is available, and marker-pdf is impractical (too slow or too large), fall back to:
1. ✅ **Google Drive OCR** — see dedicated section below
2. Ask user to provide a text/Markdown version
3. Use web search for existing summaries/analysis of the work

### marker-pdf CPU-only: extremely slow (real-world data)

On CPU-only systems (no GPU/CUDA), marker-pdf processes at ~6s/page or slower. Measured: 3 pages exceeded 600-second timeout. For 300+ page scanned books, marker-pdf is effectively unusable without:
- A GPU (CUDA-enabled)
- `--pages` flag to restrict to TOC + key chapters only
- An alternative method (Google Drive OCR, web search)

---

## Google Drive OCR (ultimate fallback for scanned PDFs)

When the PDF is scanned/image-based AND local extraction fails (tesseract missing, marker too slow), use Google's Drive-side OCR. Google Drive automatically OCRs uploaded PDFs and can export the text.

### Prerequisites

- Google Workspace OAuth set up with `drive.file` scope (NOT `drive.readonly` — the default only allows search/read)
- To change scope: edit `setup.py` SCOPES list, replacing `drive.readonly` with `drive.file`, then re-run auth

### Workflow

**Step 1: Upload the PDF**

```python
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
import json

token = json.load(open('/home/user/.hermes/google_token.json'))
creds = ...  # build credentials from token
service = build('drive', 'v3', credentials=creds)

media = MediaFileUpload('/path/to/scanned.pdf',
                        mimetype='application/pdf',
                        resumable=True)
file = service.files().create(body={'name': 'scanned.pdf'},
                              media_body=media,
                              fields='id,webViewLink').execute()
print(f"Uploaded: id={file['id']}")
```

**Step 2: Export as Google Docs (triggers OCR)**

```python
doc_id = service.files().copy(
    fileId=file['id'],
    body={'name': 'scanned_ocr'},
    fields='id'
).execute()['id']

# Export doc content as plain text
content = service.files().export(
    fileId=doc_id,
    mimeType='text/plain'
).execute()
print(content.decode('utf-8'))
```

Or use the `google-api` CLI wrapper:

```bash
GAPI="python ~/.hermes/skills/productivity/google-workspace/scripts/google_api.py"
# Drive OCR method not yet implemented in google_api.py — use inline Python
```

**Step 3: Clean up**

```python
# Delete the uploaded files after extraction to avoid clutter
service.files().delete(fileId=file['id']).execute()
service.files().delete(fileId=doc_id).execute()
```

### Caveats
- Google Drive OCR is good but not perfect — complex layouts, equations, and heavily formatted text may lose structure
- Chinese / CJK OCR accuracy is generally high
- The exported text is raw plain text (no markdown structure), so expect plain paragraphs
- You need `drive.file` scope (or broader) — `drive.readonly` will fail with 403
- Processing time: usually 10-30 seconds for a 300-page book
- The OCR conversion consumes Drive storage quota for the Google Doc copy
