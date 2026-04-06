# Troop 500G Website

The official website of **Scouting America Troop 500G** in Solon, Ohio — built with Jekyll, containerized with Docker, and deployed via GitHub Pages.

- **Production:** https://troop500.org
- **GitHub Pages:** https://troop500.github.io

This repository contains the website source code, a modular Troop Handbook (web + PDF), and an automated build/test/deploy pipeline.

---

## Prerequisites

- **Docker Desktop** (Windows/Mac) or **Docker Engine** (Linux)
  - [Install on Windows](https://docs.docker.com/desktop/install/windows-install/) | [Mac](https://docs.docker.com/desktop/install/mac-install/) | [Linux](https://docs.docker.com/engine/install/ubuntu/)
- **PowerShell 5.1+** (Windows) or **PowerShell Core** (cross-platform) — for build/test scripts
- **Git**

---

## Quick Start

```bash
git clone https://github.com/troop500/troop500.github.io.git
cd troop500.github.io
```

```powershell
# Full build: PDFs + Jekyll + tests
.\scripts\build_and_test_pdf_first.ps1

# View the site at http://localhost:4000
```

---

## Building

All builds are orchestrated through a single PowerShell script that manages Docker containers.

### Build Commands

| Command | What it does |
|---|---|
| `.\scripts\build_and_test_pdf_first.ps1` | Full build — PDFs, Jekyll, and tests |
| `.\scripts\build_and_test_pdf_first.ps1 -Quick` | Web-only — skip PDFs and tests (fastest) |
| `.\scripts\build_and_test_pdf_first.ps1 -SkipPDFs` | Jekyll + tests, no PDF generation |
| `.\scripts\build_and_test_pdf_first.ps1 -SkipTests` | PDFs + Jekyll, no test suite |
| `.\scripts\build_and_test_pdf_first.ps1 -NoCache` | Clean rebuild — no Docker layer cache |

### Build Order

1. Build the PDF container (Pandoc + LaTeX + Python)
2. Generate handbook and contact-info PDFs (unless `-SkipPDFs`)
3. Build the Jekyll container
4. Start Jekyll with all generated assets in place
5. Run test suite and write results to `test-issues-summary.md` (unless `-SkipTests`)

### Manual Docker Commands

```bash
# Generate PDFs only
docker-compose run --rm pdf-generator

# Start Jekyll only
docker-compose up jekyll

# Full rebuild of containers
docker-compose up --build
```

---

## Testing

### Automated Tests

The build script runs these tests automatically (see `scripts/test/`):

| Script | Purpose |
|---|---|
| `test-self-urls.ps1` | Internal page endpoints return HTTP 200 |
| `test-external-links.ps1` | External links on pages are reachable |
| `test-pdf-links.ps1` | Links inside generated PDFs are valid |
| `test-appendix-pdfs.ps1` | Appendix PDFs exist and are well-formed |
| `test-linux-compatibility.ps1` | Cross-platform compatibility checks |

### Running Tests Individually

```powershell
# Test internal endpoints
.\scripts\test\test-self-urls.ps1

# Test external links (with verbose output)
.\scripts\test\test-external-links.ps1 -Verbose

# Validate PDF link integrity
.\scripts\test\test-pdf-links.ps1 -IncludeLatest
```

### Test Reports

The build generates `test-issues-summary.md` with categorized issues (build, internal links, external links, PDF links, content, cross-platform) and severity levels (critical/high/medium/low).

---

## Deployment

### Automated (GitHub Actions)

Pushing to `main` triggers the CI/CD pipeline (`.github/workflows/build-and-deploy.yml`):

1. Builds the Jekyll site
2. Generates updated PDFs
3. Deploys to GitHub Pages

**Other triggers:** manual workflow dispatch, pull requests to `main`/`master`.

**Monitor:** [GitHub Actions](https://github.com/troop500/troop500.github.io/actions) | [Pages Settings](https://github.com/troop500/troop500.github.io/settings/pages)

### Typical Workflow

```powershell
# 1. Edit content
code _includes/content/getting-started.md

# 2. Build and test locally
.\scripts\build_and_test_pdf_first.ps1

# 3. Verify at http://localhost:4000

# 4. Push to deploy
git add .
git commit -m "Update handbook content"
git push
```

---

## Project Structure

```
troop500.github.io/
├── _config.yml                 # Jekyll configuration
├── _data/settings.yml          # Site navigation and settings
├── _includes/content/          # Shared content blocks (handbook sections)
├── _layouts/                   # Page templates (default, handbook, post, etc.)
├── _posts/                     # Blog posts (YYYY-MM-DD-title.md)
├── _sass/                      # SCSS stylesheets
├── assets/
│   ├── css/                    # Compiled CSS
│   ├── files/handbook/         # Generated PDFs (gitignored)
│   ├── files/inventory/        # Inventory documents
│   ├── images/handbook/        # Handbook images (leadership patches, etc.)
│   └── img/                    # General site images
├── pages/                      # Top-level website pages
│   └── handbook/               # Individual handbook topic pages
├── scripts/
│   ├── build_and_test_pdf_first.ps1  # Main build/test orchestrator
│   ├── build/                  # PDF generation scripts (run inside Docker)
│   ├── test/                   # Test scripts (PowerShell)
│   └── utils/                  # Helpers (image conversion, Jekyll service mgmt)
├── templates/                  # LaTeX templates for PDF generation
├── docker-compose.yml          # Container orchestration
├── Dockerfile.jekyll           # Jekyll dev container
└── Dockerfile.pandoc           # PDF generation container (Pandoc + LaTeX + Python)
```

### Key Directories

| Directory | Purpose |
|---|---|
| `_includes/content/` | Handbook content fragments — shared between web pages and PDF generation |
| `pages/` | Top-level site pages (events, resources, handbook, etc.) |
| `pages/handbook/` | Individual handbook topic pages that `{% include %}` content fragments |
| `scripts/build/` | Shell scripts that run inside the Pandoc Docker container |
| `scripts/test/` | PowerShell test scripts for validation |
| `templates/` | LaTeX templates used by Pandoc for PDF styling |

---

## Content Management

### Blog Posts

Create a file in `_posts/` named `YYYY-MM-DD-title.md`:

```yaml
---
layout: post
title: "Your Post Title"
author: "Your Name"
date: YYYY-MM-DD HH:MM:SS -0500
categories: category1 category2
---

Post content here.
```

### Website Pages

Create a file in `pages/` with front matter:

```yaml
---
layout: page
title: "Page Title"
permalink: /page-url
---
```

Add it to navigation in `_data/settings.yml`:

```yaml
- {name: 'Page Title', url: 'page-url'}
```

### Handbook Content

The handbook uses a **write-once, render-everywhere** architecture:

1. **Content lives in** `_includes/content/*.md` — each file is one handbook section
2. **Web rendering:** `pages/handbook.md` pulls sections together with `{% include content/section.md %}`
3. **PDF rendering:** `scripts/build/build-handbook-simple.sh` concatenates and converts the same content via Pandoc + LaTeX

#### Editing a Section

Edit the file directly in `_includes/content/` — changes appear in both web and PDF outputs.

#### Adding a New Section

1. Create `_includes/content/new-section.md`
2. Add `{% include content/new-section.md %}` to `pages/handbook.md`
3. Add the file to the `process_file` calls in `scripts/build/build-handbook-simple.sh`

#### Content Guidelines

- **File naming:** lowercase with hyphens (`new-section.md`)
- **Headers:** use `##` and `###` (avoid `#` — reserved for document title)
- **Links:** relative paths for internal links (`[Page](/page-url)`)
- **Images:** place in `assets/img/` or `assets/images/handbook/`

### PDF Generation

The system produces two PDF documents:

| File | Contents |
|---|---|
| `troop-handbook-*.pdf` | Complete handbook with all sections |
| `contact-info-*.pdf` | Leadership and contact directory |

Each PDF gets a timestamped version (`*-YYYYMMDD_HHMMSS.pdf`) and an auto-updated `*-latest.pdf`.

**Pipeline:** Markdown → strip Jekyll syntax → convert HTML images to LaTeX → Pandoc → PDF

```bash
# Generate PDFs manually
docker-compose run --rm pdf-generator
```

---

## Troubleshooting

| Problem | Solution |
|---|---|
| PDFs not updating | `docker-compose build pdf-generator --no-cache` then `docker-compose run --rm pdf-generator` |
| Content not appearing on web | Verify file is in `_includes/content/` and included with `{% include content/filename.md %}` |
| Jekyll won't start | Check Docker is running, try `docker-compose down` then `docker-compose up jekyll` |
| PDF formatting issues | Edit `scripts/build/build-handbook-simple.sh` or LaTeX templates in `templates/` |
| Test failures | Review `test-issues-summary.md` for categorized issues and suggested resolutions |

---

## Contributing

1. Create a feature branch from `main`
2. Build and test locally: `.\scripts\build_and_test_pdf_first.ps1`
3. Verify all tests pass and PDFs generate correctly
4. Submit a pull request

---

## Support

- **Issues:** [GitHub Issues](https://github.com/troop500/troop500.github.io/issues)
- **Troop Webmaster:** Contact through troop leadership

---

**Troop 500G** | Solon, Ohio | Scouting America