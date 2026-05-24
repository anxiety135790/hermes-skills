# Google Drive OCR Workflow (for scanned PDFs)

Use when: PDF is scanned/image-based, tesseract unavailable (no root), and marker-pdf too slow on CPU.

## Prerequisites

- Google Workspace OAuth with `drive.file` scope (not `drive.readonly`)
- Token at `~/.hermes/google_token.json`

## Step-by-step Python script

```python
#!/usr/bin/env python3
"""Upload scanned PDF to Drive, OCR via Google Docs export, print text."""
import json
import sys
from pathlib import Path
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

TOKEN_PATH = Path.home() / ".hermes" / "google_token.json"
SCOPES = ["https://www.googleapis.com/auth/drive.file"]

def ocr_pdf(pdf_path: str) -> str:
    """Upload PDF, convert to Google Doc (triggers OCR), export text."""
    creds = Credentials.from_authorized_user_file(str(TOKEN_PATH), SCOPES)
    drive = build("drive", "v3", credentials=creds)

    # 1. Upload the scanned PDF
    media = MediaFileUpload(pdf_path, mimetype="application/pdf", resumable=True)
    uploaded = (
        drive.files()
        .create(body={"name": Path(pdf_path).name}, media_body=media, fields="id")
        .execute()
    )
    print(f"Uploaded: {uploaded['id']}", file=sys.stderr)

    # 2. Copy as Google Doc (this triggers OCR on Drive side)
    doc = (
        drive.files()
        .copy(fileId=uploaded["id"], body={"name": "ocr_temp"}, fields="id")
        .execute()
    )
    print(f"Google Doc created: {doc['id']}", file=sys.stderr)

    # 3. Export as plain text (OCR output)
    content = (
        drive.files()
        .export(fileId=doc["id"], mimeType="text/plain")
        .execute()
    )
    text = content.decode("utf-8")

    # 4. Clean up temp files
    drive.files().delete(fileId=uploaded["id"]).execute()
    drive.files().delete(fileId=doc["id"]).execute()

    return text


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <scanned.pdf>", file=sys.stderr)
        sys.exit(1)
    text = ocr_pdf(sys.argv[1])
    print(text)
```

## Usage

```bash
python3 google-drive-ocr.py /path/to/scanned.pdf
```

## Notes

- Google Drive OCR: ~10-30s for a 300-page scanned book (vs marker-pdf: ~30min+ on CPU)
- CJK (Chinese/Japanese/Korean) OCR accuracy is generally high
- Output is raw plain text with minimal formatting — expect paragraphs, no table/equation structure
- Temp files are auto-deleted after extraction; if the script crashes, check Drive Trash
