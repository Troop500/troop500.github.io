# Troop 500G Website

The official website of Scouting America Troop 500G in Solon, Ohio.

This repository contains both the website source code and the automated PDF handbook generation system.

## 🚀 Quick Start

### Prerequisites

- **Docker Desktop** (Windows/Mac) or **Docker Engine** (Linux)
  - [Install Docker Desktop on Windows](https://docs.docker.com/desktop/install/windows-install/)
  - [Install Docker Desktop on Mac](https://docs.docker.com/desktop/install/mac-install/)
  - [Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)

### Local Development

1. **Clone the repository:**
   ```bash
   git clone https://github.com/troop500/troop500.github.io.git
   cd troop500.github.io
   ```

2. **Start development environment:**
   ```bash
   # Windows PowerShell (recommended)
   .\scripts\build_and_test_pdf_first.ps1
   
   # Or manual Docker commands
   docker-compose up jekyll
   ```

3. **View the site:**
   - Website: http://localhost:4000
   - Live reloading enabled for development

## 📋 Local Testing

### Full Build and Test (Recommended)

**Windows (PowerShell):**
```powershell
# Full build with PDFs and testing
.\scripts\build_and_test_pdf_first.ps1

# Quick web-only build (faster)
.\scripts\build_and_test_pdf_first.ps1 -Quick

# Clean rebuild without cache
.\scripts\build_and_test_pdf_first.ps1 -NoCache

# Skip PDF generation
.\scripts\build_and_test_pdf_first.ps1 -SkipPDFs
```

**Manual Docker Commands:**
```bash
# Generate PDFs first
docker-compose run --rm pdf-generator

# Start Jekyll
docker-compose up jekyll

# Full rebuild
docker-compose up --build
```

### Testing Checklist

The build script automatically tests:
- ✅ Homepage loads correctly
- ✅ Handbook page renders
- ✅ PDF files are generated and accessible
- ✅ Navigation links work
- ✅ Contact information is up to date

### PDF Generation

```bash
# Generate handbook PDFs
docker-compose run --rm pdf-generator

# PDFs created:
# - assets/files/handbook/troop-handbook-YYYYMMDD_HHMMSS.pdf
# - assets/files/handbook/contact-info-YYYYMMDD_HHMMSS.pdf
# - assets/files/handbook/troop-handbook-latest.pdf (auto-updated)
# - assets/files/handbook/contact-info-latest.pdf (auto-updated)
```

## 🌐 Official Deployment

### Live Website
- **Production URL:** https://troop500.org
- **GitHub Pages:** https://troop500.github.io

### Automated Deployment

**GitHub Actions automatically:**
1. ✅ Builds the Jekyll site
2. ✅ Generates updated PDFs
3. ✅ Deploys to GitHub Pages
4. ✅ Updates the live website

**Deployment triggers:**
- Push to `main` branch
- Manual workflow dispatch
- Scheduled updates (if configured)

### Deployment Status

Check deployment status:
- [GitHub Actions](https://github.com/troop500/troop500.github.io/actions)
- [GitHub Pages Settings](https://github.com/troop500/troop500.github.io/settings/pages)

## 📚 Content Management

### Blog Posts

#### Adding a Post
1. Create a new file in `_posts/` with format: `YYYY-MM-DD-title.md`
2. Add front matter:
   ```yaml
   ---
   layout: post
   title: "Your Post Title"
   author: "Your Name"
   date: YYYY-MM-DD HH:MM:SS -0500
   categories: category1 category2
   ---
   ```
3. Write your content below the front matter

#### Removing a Post
Delete the file from `_posts/` directory.

### Website Pages

#### Adding a New Page
1. Create a file in `pages/` directory (e.g., `new-page.md`)
2. Add front matter:
   ```yaml
   ---
   layout: page
   title: "Page Title"
   permalink: /page-url
   ---
   ```
3. Add the page to navigation in `_data/settings.yml`:
   ```yaml
   - {name: 'Page Title', url: 'page-url'}
   ```

### File Management

#### Adding Files
1. Place files in `assets/files/` directory
2. Use descriptive, lowercase names with hyphens: `inventory-patrol-box.pdf`
3. Link to files from pages:
   ```markdown
   - [File Description](assets/files/filename.pdf){:target="_blank"}
   ```

## 📖 Troop Handbook System

The Troop Handbook is a **modular system** that generates both web pages and downloadable PDFs from shared content sources.

### Content Structure

The handbook uses a modular approach with reusable content blocks:

- **`_includes/content/introduction-welcome.md`** - Welcome message and troop information
- **`_includes/content/getting-started.md`** - New scout orientation and requirements  
- **`_includes/content/leadership-organization.md`** - Leadership positions and patrol system
- **`_includes/content/troop-structure.md`** - Troop meetings and activities
- **`_includes/content/contact-info.md`** - Contact information and resources
- **`pages/handbook.md`** - Main handbook page that includes all sections

### Updating Handbook Content

#### Editing Existing Sections

1. **Edit the content files directly in `_includes/content/`:**
   ```bash
   _includes/content/introduction-welcome.md     # Welcome and troop info
   _includes/content/getting-started.md          # New scout information
   _includes/content/leadership-organization.md  # Leadership and patrol system
   _includes/content/troop-structure.md          # Meetings and activities
   _includes/content/contact-info.md             # Contact details
   ```

2. **Test your changes locally:**
   ```bash
   # Start Jekyll to see web version
   .\scripts\build_and_test_pdf_first.ps1
   # View at http://localhost:4000/handbook.html
   ```

3. **Generate updated PDFs:**
   ```bash
   # Generate new PDFs with your changes
   docker-compose run --rm pdf-generator
   ```

#### Adding New Sections

1. **Create a new include file:**
   ```bash
   # Create new content file
   _includes/content/new-section.md
   ```

2. **Add it to the main handbook page:**
   ```markdown
   # In pages/handbook.md, add:
   {% include content/new-section.md %}
   ```

3. **Update the PDF build script:**
   ```bash
   # Edit scripts/build-handbook-simple.sh
   # Add your new file to the process_file calls
   ```

### PDF Generation Details

The system creates **two PDF files**:

- **`troop-handbook-YYYYMMDD_HHMMSS.pdf`** - Complete handbook with all sections
- **`contact-info-YYYYMMDD_HHMMSS.pdf`** - Leadership and contact directory
- **`*-latest.pdf`** - Always-current versions (auto-updated)

**How it works:**
1. Jekyll processes the web version with `{% include %}` statements
2. The PDF generator creates clean intermediate files (without Jekyll syntax)
3. Python script converts HTML image tags to LaTeX format
4. Pandoc converts the processed markdown to professional PDFs

### Troubleshooting

#### PDFs Not Updating
```bash
# Rebuild containers if PDFs seem stale
docker-compose build pdf-generator --no-cache
docker-compose run --rm pdf-generator
```

#### Content Not Appearing  
- Check that include files are in `_includes/content/` directory
- Verify Jekyll syntax: `{% include content/filename.md %}`
- Test web version first at `http://localhost:4000/handbook.html`

#### PDF Formatting Issues
- Edit `scripts/build-handbook-simple.sh` for PDF-specific formatting
- LaTeX/Pandoc configuration is in the script's YAML frontmatter
- Image conversion handled by `scripts/convert_images_to_latex.py`

### Content Guidelines

- **File naming**: Use lowercase with hyphens (e.g., `new-section.md`)
- **Headers**: Use `##` and `###` for subsections (avoid single `#`)
- **Links**: Use relative paths for internal links: `[Page](/page-url)`
- **Images**: Place in `assets/img/` and reference relatively
- **Patch Images**: Leadership patch images in `/assets/images/handbook/`

### Publishing Changes

1. **Commit your changes:**
   ```bash
   git add _includes/ pages/ assets/
   git commit -m "Update handbook: describe changes"
   git push
   ```

2. **Automatic deployment:**
   - GitHub Actions automatically rebuilds the site
   - PDFs are regenerated and published
   - Changes appear at https://troop500.org

### Quick Workflow

```bash
# 1. Edit content
code _includes/content/getting-started.md

# 2. Test locally
.\scripts\build_and_test_pdf_first.ps1

# 3. View results
# Website: http://localhost:4000/handbook.html
# PDFs: assets/files/handbook/*.pdf

# 4. Commit and push
git add . && git commit -m "Update handbook content" && git push
```

## 🔧 Technical Details

### Architecture
- **Jekyll**: Static site generator with Liquid templating
- **Docker**: Containerized development and build environment
- **Pandoc**: Markdown to PDF conversion with LaTeX
- **GitHub Actions**: Automated deployment pipeline
- **Python**: Image processing for PDF generation

### Container Structure
- **`Dockerfile.jekyll`**: Jekyll development environment
- **`Dockerfile.pandoc`**: PDF generation container with Pandoc, LaTeX, and Python3
- **`docker-compose.yml`**: Multi-container orchestration

### Key Files
- **Build Scripts:**
  - `scripts/build_and_test_pdf_first.ps1` - Main build/test script (Windows)
  - `scripts/build-handbook-simple.sh` - PDF generation script (container)
  - `scripts/convert_images_to_latex.py` - Image conversion for PDFs
  
- **Configuration:**
  - `docker-compose.yml` - Development environment setup
  - `_config.yml` - Jekyll configuration
  - `_data/settings.yml` - Site navigation and settings
  
- **GitHub Actions:**
  - `.github/workflows/` - Automated deployment workflows

### Development Workflow
1. **Local Development**: Docker containers provide consistent environment
2. **Content Management**: Modular includes for reusable content
3. **PDF Generation**: Automated conversion from web content
4. **Deployment**: GitHub Actions handles build and publish

### Performance Optimizations
- **Caching**: Docker layer caching for faster builds
- **Incremental Builds**: Jekyll's incremental regeneration
- **Background Tasks**: Non-blocking PDF generation
- **Latest Files**: Auto-updated latest PDF versions

## 🤝 Contributing

### Development Process
1. **Create a feature branch** from `main`
2. **Make your changes** using the local development setup
3. **Test thoroughly** using the build scripts
4. **Submit a pull request** with a clear description

### Code Standards
- **Markdown**: Follow Jekyll conventions and content guidelines
- **Scripts**: Use clear variable names and comments
- **Docker**: Multi-stage builds and layer optimization
- **Documentation**: Update README for any workflow changes

### Testing Requirements
- ✅ Local build script passes all tests
- ✅ PDFs generate without errors
- ✅ Website renders correctly
- ✅ All navigation links work
- ✅ Content displays properly on mobile

## 📞 Support

For questions, issues, or contributions:

- **Troop Webmaster**: Contact through troop leadership
- **Issues**: [GitHub Issues](https://github.com/troop500/troop500.github.io/issues)
- **Documentation**: This README and inline comments

---

**Troop 500G** | Solon, Ohio | Scouting America