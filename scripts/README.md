# Scripts Directory Organization

This directory contains all build, test, and utility scripts for the Troop 500G website and handbook generation.

## Directory Structure

```
scripts/
├── build_and_test_pdf_first.ps1  # Main orchestrator script (run this!)
├── README.md                     # This file
├── build/                        # PDF generation and build scripts
│   ├── build-appendix-pdfs.sh    # Generates individual appendix PDFs
│   ├── build-handbook-pandoc.sh  # Main handbook PDF generation
│   └── build-handbook-simple.sh  # Simple handbook PDF generation
├── test/                         # Testing and validation scripts
│   ├── test-appendix-pdfs.ps1    # Validates appendix PDF generation
│   ├── test-external-links.ps1   # Tests external links in webpages
│   ├── test-linux-compatibility.ps1 # Tests Linux/cross-platform readiness
│   ├── test-pdf-links.ps1        # Validates links within generated PDFs
│   └── test-self-urls.ps1        # Tests internal website URL endpoints
└── utils/                        # Helper utilities and tools
    ├── convert_images_to_latex.py # Converts HTML images to LaTeX
    └── jekyll-service.ps1         # Jekyll container management
```

## Usage

### Quick Start
```powershell
# Full build with testing (recommended)
.\build_and_test_pdf_first.ps1

# Fast web-only build (skip PDFs and tests)
.\build_and_test_pdf_first.ps1 -Quick

# Clean rebuild from scratch
.\build_and_test_pdf_first.ps1 -NoCache
```

### Individual Testing
```powershell
# Test internal website endpoints
.\test\test-self-urls.ps1

# Test external links in webpages
.\test\test-external-links.ps1 -Verbose

# Test links in generated PDFs (requires poppler-utils)
.\test\test-pdf-links.ps1 -IncludeLatest

# Check Linux compatibility
.\test\test-linux-compatibility.ps1
```

### Individual Components

#### Build Scripts (`build/`)
- **Purpose**: Generate PDFs and compile handbook content
- **Environment**: Run inside Docker containers (pandoc/latex)
- **Usage**: Called automatically by main script, can be run manually for debugging

#### Test Scripts (`test/`)
- **Purpose**: Validate build outputs and website functionality
- **Environment**: PowerShell modules, imported by main script
- **Usage**: Can be run standalone for targeted testing

**Available Test Scripts:**
- `test-self-urls.ps1`: Tests internal website endpoints (homepage, handbook, etc.)
- `test-external-links.ps1`: Scans webpages and validates external links (excludes local/internal hosts, reports failures with page context)
- `test-pdf-links.ps1`: Extracts and validates links from generated PDF files
- `test-appendix-pdfs.ps1`: Validates appendix PDF generation and content
- `test-linux-compatibility.ps1`: Checks cross-platform compatibility

#### Utilities (`utils/`)
- **Purpose**: Helper functions and conversion tools
- **Environment**: Mixed (Python, PowerShell)
- **Usage**: Called by build scripts or imported as modules

## Script Categories

### 🏗️ Build Scripts
Scripts that generate content, compile PDFs, or build the website.
- Handle PDF generation from Markdown
- Process images and LaTeX conversion
- Manage file organization and timestamps

### 🧪 Test Scripts  
Scripts that validate functionality, test endpoints, or verify outputs.
- Check PDF generation and content
- Validate website URL accessibility
- Ensure build artifacts are correct

### 🔧 Utility Scripts
Helper tools that provide common functionality or conversion services.
- Image format conversion
- Service management (Jekyll, Docker)
- File processing utilities

## Development Guidelines

### Adding New Scripts
1. **Build scripts**: Add to `build/` if they generate or compile content
2. **Test scripts**: Add to `test/` if they validate or verify functionality  
3. **Utilities**: Add to `utils/` if they provide helper functions or tools

### Import Paths
When the main script imports modules, use the new paths:
```powershell
. "$PSScriptRoot\test\test-module.ps1"
. "$PSScriptRoot\utils\utility-module.ps1"
```

### Docker Context
Build scripts in `build/` are copied to Docker containers and should:
- Use relative paths from `/srv/jekyll`
- Handle both local and container environments
- Include appropriate error handling

## Maintenance

The main orchestrator script (`build_and_test_pdf_first.ps1`) coordinates all operations:
1. **Imports** test and utility modules
2. **Calls** build scripts via Docker
3. **Runs** tests to validate outputs
4. **Reports** status and provides debugging info

This organization makes it intuitive to:
- Find the right script for a task
- Understand dependencies between components
- Add new functionality in the appropriate category
- Maintain and debug the build system

## Cross-Platform Compatibility

### Linux Support: ✅ Mostly Compatible

#### ✅ **What Works on Linux**
- **Docker containers**: Fully compatible (Linux-based images)
- **Build scripts**: All bash scripts (`.sh`) work natively on Linux
- **PowerShell Core**: Main script uses `#!/usr/bin/env pwsh` (cross-platform)
- **Test modules**: Use `Join-Path` for proper cross-platform path handling
- **Docker Compose**: Same `docker-compose.yml` works on both platforms

#### ⚠️ **Known Issues on Linux**
1. **Path separators in imports**: Main script uses backslashes in module imports:
   ```powershell
   . "$PSScriptRoot\test\test-urls.ps1"  # Should use Join-Path or forward slashes
   ```
2. **File locking behavior**: The `Copy-FileWithRetry` function is Windows-specific
3. **PowerShell availability**: Requires PowerShell Core (pwsh) to be installed

#### 🔧 **Linux Setup Requirements**
```bash
# Install PowerShell Core
sudo apt-get install -y powershell  # Ubuntu/Debian
# OR
sudo dnf install powershell         # Fedora/RHEL

# Install Docker and Docker Compose
sudo apt-get install docker.io docker-compose  # Ubuntu/Debian

# Make scripts executable
chmod +x scripts/build/*.sh

# Test Linux compatibility
./scripts/test-linux-compatibility.ps1
```

#### 🚀 **Running on Linux**
```bash
# Full build and test
./scripts/build_and_test_pdf_first.ps1

# Or with explicit PowerShell
pwsh ./scripts/build_and_test_pdf_first.ps1
```

### Recommended Linux Improvements
To make the system fully Linux-compatible, consider:
1. **Fix import paths**: Use `Join-Path` or forward slashes for module imports
2. **Conditional file handling**: Detect platform and adjust file locking behavior
3. **Add Linux CI/CD**: Include Linux testing in automation

### macOS Support
Should work similarly to Linux with PowerShell Core installed via Homebrew:
```bash
brew install powershell
```
