#!/bin/bash

# Troop 500G Handbook PDF Generator using Pandoc
# This script works in both Docker and GitHub Actions environments

echo "🏕️ Building Troop 500G Handbook PDF with Pandoc..."
echo "=================================================="

# Determine working directory based on environment
if [ -n "$GITHUB_WORKSPACE" ]; then
    # GitHub Actions environment
    WORK_DIR="$GITHUB_WORKSPACE"
elif [ -d "/srv/jekyll" ]; then
    # Docker environment
    WORK_DIR="/srv/jekyll"
elif [ -f "pages/handbook.md" ]; then
    # Local environment
    WORK_DIR="$(pwd)"
else
    echo "❌ Error: Cannot determine working directory. Make sure you're in the project root."
    exit 1
fi

echo "📂 Working directory: $WORK_DIR"
cd "$WORK_DIR"

# Check if we're in the right directory
if [ ! -f "pages/handbook.md" ]; then
    echo "❌ Error: handbook.md not found. Make sure you're in the project root."
    exit 1
fi

# Configuration
HANDBOOK_DIR="$WORK_DIR/pages/handbook"
OUTPUT_DIR="$WORK_DIR/assets/files/handbook"
TEMP_DIR="/tmp/handbook_build"

echo "📁 Creating directories..."
mkdir -p "$OUTPUT_DIR"
mkdir -p "$TEMP_DIR"

# Handbook sections in order (only existing files)
HANDBOOK_SECTIONS=(
    "_includes/content/handbook-introduction.md"
    "_includes/content/introduction-welcome.md"
    "_includes/content/getting-started.md"
    "_includes/content/leadership-organization.md"
    "_includes/content/outdoor-program.md"
    "_includes/content/advancement-to-scout.md"
    "_includes/content/advancement-first-class.md"
    "_includes/content/advancement-eagle.md"
    "_includes/content/policies-safety.md"
    "_includes/content/accessibility-inclusion.md"
    "_includes/content/resources-equipment.md"
    "_includes/content/contact-info.md"
)

echo "📝 Combining handbook sections..."

# Create combined markdown file
COMBINED_MD="$TEMP_DIR/handbook-combined.md"

# Add YAML frontmatter for pandoc
CURRENT_DATE=$(date +"%B %d, %Y")
cat > "$COMBINED_MD" << 'EOF'
---
title: "Troop Handbook"
subtitle: "Scouting America Troop 500G, Solon, Ohio"
author: "Lake Erie Council"
date: \today
documentclass: article
geometry: "margin=1in"
fontsize: 11pt
linestretch: 1.2
toc: true
toc-depth: 3
numbersections: true
titlepage: true
header-includes:
  - \usepackage{fancyhdr}
  - \pagestyle{fancy}
  - \fancyhead[L]{Troop 500G Handbook}
  - \fancyhead[R]{$CURRENT_DATE}
  - \fancyfoot[C]{\thepage}
  - \renewcommand{\headrulewidth}{0.4pt}
  - \renewcommand{\footrulewidth}{0.4pt}
---

# Welcome to Troop 500G

This handbook serves as your comprehensive guide to troop operations, policies, procedures, and resources.

EOF

# Add the generated date
echo "" >> "$COMBINED_MD"
echo "**Generated on:** $CURRENT_DATE" >> "$COMBINED_MD"
echo "" >> "$COMBINED_MD"
echo "---" >> "$COMBINED_MD"
echo "" >> "$COMBINED_MD"

# Process each section
for section_file in "${HANDBOOK_SECTIONS[@]}"; do
    if [ -f "$section_file" ]; then
        echo "Processing: $section_file"
        
        # Extract content without YAML frontmatter
        if grep -q "^---$" "$section_file"; then
            # Skip YAML frontmatter (everything between first two --- lines)
            awk '/^---$/{if(++n==2) start=1; next} start' "$section_file" > "$TEMP_DIR/$(basename "$section_file")"
        else
            # No frontmatter, just copy the file
            cp "$section_file" "$TEMP_DIR/$(basename "$section_file")"
        fi
        
        # Replace Jekyll liquid templates with actual values for PDF
        CURRENT_DATE=$(date +'%B %Y')
        sed -i "s/.*PDF_BUILD: REPLACE_DATE.*/*Last Updated: ${CURRENT_DATE}*/g" "$TEMP_DIR/$(basename "$section_file")"
        
        # Append processed content to combined markdown
        cat "$TEMP_DIR/$(basename "$section_file")" >> "$COMBINED_MD"
        
        # Add page break between sections
        echo -e "\n\\newpage\n" >> "$COMBINED_MD"
    else
        echo "Warning: $section_file not found, skipping..."
    fi
done

echo "🚀 Generating PDF with pandoc..."

# Generate main handbook PDF
pandoc "$COMBINED_MD" \
    --from markdown \
    --to pdf \
    --pdf-engine=xelatex \
    --output "$OUTPUT_DIR/troop-handbook-2025.pdf" \
    --variable colorlinks=true \
    --variable linkcolor=blue \
    --variable urlcolor=blue \
    --variable titlepage=true \
    --shift-heading-level-by=-1 \
    --variable toccolor=gray \
    --table-of-contents \
    --number-sections

if [ $? -eq 0 ]; then
    echo "✅ Main handbook PDF generated: assets/files/handbook/troop-handbook-2025.pdf"
else
    echo "❌ Error generating main handbook PDF"
    exit 1
fi

# Clean up
rm -rf "$TEMP_DIR"

echo ""
echo "🎉 Handbook PDF generation complete!"
echo "📁 Files created in: assets/files/handbook/"
echo "📖 Main handbook: troop-handbook-2025.pdf"
echo ""
