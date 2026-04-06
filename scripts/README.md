# Scripts Directory

Build, test, and utility scripts for the Troop 500G website. For build/test/deploy commands, see the [project README](../README.md).

## Directory Structure

```
scripts/
├── build_and_test_pdf_first.ps1  # Main orchestrator script
├── build/                        # PDF generation (run inside Docker)
│   └── build-handbook-simple.sh  # Handbook + appendix PDF generation
├── test/                         # Validation scripts (PowerShell)
│   ├── test-appendix-pdfs.ps1    # Appendix PDF validation
│   ├── test-external-links.ps1   # External link checking
│   ├── test-linux-compatibility.ps1 # Cross-platform checks
│   ├── test-pdf-links.ps1        # PDF link validation
│   └── test-self-urls.ps1        # Internal endpoint testing
└── utils/                        # Helper utilities
    ├── convert_images_to_latex.py # HTML image → LaTeX conversion
    └── jekyll-service.ps1         # Jekyll container management
```

## Development Guidelines

### Adding Scripts

| Type | Directory | Environment |
|---|---|---|
| Build/generation | `build/` | Runs inside Docker (Pandoc/LaTeX) |
| Validation/testing | `test/` | PowerShell, imported by main script |
| Helpers | `utils/` | Mixed (Python, PowerShell) |

### Import Paths

```powershell
. "$PSScriptRoot\test\test-module.ps1"
. "$PSScriptRoot\utils\utility-module.ps1"
```

### Docker Context

Build scripts in `build/` are copied into Docker containers and should use relative paths from `/srv/jekyll`.

## Cross-Platform Notes

- **Docker containers and bash scripts** work on all platforms
- **PowerShell Core** (`pwsh`) is required on Linux/macOS
- **Known Linux issues:** backslash path separators in module imports, Windows-specific `Copy-FileWithRetry`
- Run `scripts/test/test-linux-compatibility.ps1` to check compatibility
