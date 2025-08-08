#!/bin/bash

# Troop 500G Handbook PDF Generator
# Processes the main handbook.md exactly like Jekyll to guarantee PDF matches web version

echo "🏕️ Building Troop 500G Handbook PDF..."
echo "======================================"

# Create temporary and output directories
mkdir -p /tmp/handbook-processed
mkdir -p assets/files/handbook
mkdir -p assets/files/handbook/archive

CURRENT_DATE=$(date +"%B %Y")
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

echo "📁 Archiving old PDF files..."
# Archive all timestamped PDFs (keep only the latest copies in main directory)
# Move handbook PDFs to archive (excluding *latest* files)
for file in assets/files/handbook/troop-handbook-[0-9]*.pdf; do
    if [ -f "$file" ] && [[ "$file" != *"latest"* ]]; then
        mv "$file" assets/files/handbook/archive/ 2>/dev/null || true
    fi
done

# Move contact info PDFs to archive (excluding *latest* files)  
for file in assets/files/handbook/contact-info-[0-9]*.pdf; do
    if [ -f "$file" ] && [[ "$file" != *"latest"* ]]; then
        mv "$file" assets/files/handbook/archive/ 2>/dev/null || true
    fi
done

echo "🧹 Cleaning archive (keeping last 5 versions of each type)..."
# Keep only the 5 most recent handbook PDFs in archive (sorted by filename which includes timestamp)
cd assets/files/handbook/archive/
if ls troop-handbook-*.pdf 1> /dev/null 2>&1; then
    ls -1 troop-handbook-*.pdf | sort -r | tail -n +6 | xargs rm -f 2>/dev/null || true
    echo "   📖 Handbook archive: kept $(ls troop-handbook-*.pdf 2>/dev/null | wc -l) versions"
fi

# Keep only the 5 most recent contact info PDFs in archive  
if ls contact-info-*.pdf 1> /dev/null 2>&1; then
    ls -1 contact-info-*.pdf | sort -r | tail -n +6 | xargs rm -f 2>/dev/null || true
    echo "   📞 Contact info archive: kept $(ls contact-info-*.pdf 2>/dev/null | wc -l) versions"
fi
cd - > /dev/null

# Define unique filenames
HANDBOOK_PDF="troop-handbook-${TIMESTAMP}.pdf"
CONTACT_PDF="contact-info-${TIMESTAMP}.pdf"

echo "🔄 Processing main handbook file (same as website)..."

# Function to recursively process Jekyll includes
process_handbook() {
    local input_file="$1"
    local output_file="$2"
    
    echo "   → Processing $(basename "$input_file")"
    
    # Strip Jekyll frontmatter and copy to temp file, converting Windows line endings
    # Skip the first 6 lines (frontmatter block) of the handbook
    # Convert line endings and ensure UTF-8 encoding
    tail -n +7 "$input_file" | iconv -f utf-8 -t utf-8 | tr -d '\r' > "$output_file"
    
    # Process Jekyll includes iteratively (exactly like Jekyll does)
    while grep -q "{% include" "$output_file"; do
        # Create temp file for this iteration
        temp_iter="/tmp/handbook-processed/temp_iter.md"
        cp "$output_file" "$temp_iter"
        
        # Find first include (either include or include_relative) and replace it
        local include_line=$(grep -m1 "{% include" "$temp_iter")
        # Extract the relative path from include_relative
        local include_file=""
        if echo "$include_line" | grep -q "include_relative"; then
            include_file=$(echo "$include_line" | sed 's/.*{% include_relative \([^%}]*\) %}.*/\1/' | xargs)
            # Convert relative path to absolute from pages/ directory
            if [[ "$include_file" == ../* ]]; then
                include_file=${include_file#../}  # Remove leading ../
            fi
        else
            include_file=$(echo "$include_line" | sed 's/.*{% include \([^%}]*\) %}.*/\1/' | xargs)
        fi
        
        # Check multiple possible locations for content files
        local source_file=""
        if [ -f "$include_file" ]; then
            source_file="$include_file"
            echo "     ↳ Including $include_file"
        elif [ -f "_includes/$include_file" ]; then
            source_file="_includes/$include_file"
            echo "     ↳ Including $include_file from _includes"
        elif [ -f "_content/handbook/$include_file" ]; then
            source_file="_content/handbook/$include_file"
            echo "     ↳ Including $include_file from _content/handbook"
        elif [ -f "_handbook/$include_file" ]; then
            source_file="_handbook/$include_file"
            echo "     ↳ Including $include_file from _handbook collection"
        fi
        
        if [ -n "$source_file" ]; then
            # Get include content and convert Windows line endings to Unix
            local include_content_file="/tmp/handbook-processed/include_temp.md"
            # Convert line endings and ensure UTF-8 encoding
            iconv -f utf-8 -t utf-8 "$source_file" | tr -d '\r' > "$include_content_file"
            
            # Use awk to replace the include line with file content (handle both include and include_relative)
            local pattern_to_replace=""
            if echo "$include_line" | grep -q "include_relative"; then
                pattern_to_replace=$(echo "$include_line" | sed 's/[[\.*^$()+?{|]/\\&/g')
            else
                pattern_to_replace="{% include $include_file %}"
            fi
            
            awk -v include_pattern="$pattern_to_replace" -v include_file="$include_content_file" '
            {
                if ($0 ~ include_pattern) {
                    while ((getline line < include_file) > 0)
                        print line
                    close(include_file)
                } else {
                    print $0
                }
            }' "$temp_iter" > "$output_file"
            rm -f "$include_content_file"
        else
            echo "     ⚠️  Warning: $include_file not found in any content directories"
            # Remove the include line entirely if file not found
            sed "/$include_line/d" "$temp_iter" > "$output_file"
        fi
        
        rm -f "$temp_iter"
    done
    
    echo "   ✅ Processed $(basename "$input_file")"
}

# Process the main handbook file (same source as website)
PROCESSED_HANDBOOK="/tmp/handbook-processed/handbook-processed.md"
process_handbook "pages/handbook.md" "$PROCESSED_HANDBOOK"

echo "🧹 Cleaning PDF-specific content..."

# Remove web-specific elements for PDF version
sed -i '/Download Complete Handbook PDF/d' "$PROCESSED_HANDBOOK"
sed -i '/Build Tools.*BUILD_TOOLS.md/d' "$PROCESSED_HANDBOOK"
sed -i '/{:target="_blank"}/d' "$PROCESSED_HANDBOOK"
sed -i '/<!-- PDF download links removed for PDF version -->/d' "$PROCESSED_HANDBOOK"

# Replace web-only content with PDF-friendly alternatives
echo "🗺️ Converting interactive content for PDF..."
# Replace iframe with address block for Charter Organization
sed -i '/<!-- PDF-REPLACE-START:/,/<!-- PDF-REPLACE-END -->/c\
**Location Map:** Visit [Google Maps: Advent Lutheran Church, 5525 Harper Road, Solon, OH](https://www.google.com/maps/place/Advent+Lutheran+Church+ELCA)' "$PROCESSED_HANDBOOK"

echo "🖼️ Converting HTML images to LaTeX format..."
# Convert HTML img tags to LaTeX \includegraphics with proper positioning
python3 /scripts/utils/convert_images_to_latex.py "$PROCESSED_HANDBOOK" --verbose || echo "⚠️ Python3 not found, trying alternative image conversion..."

# Fallback sed-based image conversion if Python isn't available
if [ $? -ne 0 ]; then
    echo "🔧 Using sed-based image conversion fallback..."
    # Convert HTML img tags to LaTeX includegraphics commands
    # Handle images with float: right styling
    sed -i 's|<img src="/assets/images/handbook/\([^"]*\)" alt="[^"]*" style="[^"]*float: right[^"]*width: *\([0-9]*\)px[^"]*">|\\begin{wrapfigure}{r}{0.15\\textwidth}\\centering\\includegraphics[width=0.15\\textwidth]{handbook/\1}\\end{wrapfigure}|g' "$PROCESSED_HANDBOOK"
    
    # Handle images with float: left styling
    sed -i 's|<img src="/assets/images/handbook/\([^"]*\)" alt="[^"]*" style="[^"]*float: left[^"]*width: *\([0-9]*\)px[^"]*">|\\begin{wrapfigure}{l}{0.15\\textwidth}\\centering\\includegraphics[width=0.15\\textwidth]{handbook/\1}\\end{wrapfigure}|g' "$PROCESSED_HANDBOOK"
    
    # Handle centered/block images (no float)
    sed -i 's|<img src="/assets/images/handbook/\([^"]*\)" alt="[^"]*" style="[^"]*width: *50%[^"]*">|\\begin{center}\\includegraphics[width=0.5\\textwidth]{handbook/\1}\\end{center}|g' "$PROCESSED_HANDBOOK"
    
    # Handle any remaining img tags with basic conversion
    sed -i 's|<img src="/assets/images/handbook/\([^"]*\)" alt="[^"]*"[^>]*>|\\includegraphics[width=0.15\\textwidth]{handbook/\1}|g' "$PROCESSED_HANDBOOK"
    
    echo "✅ Image conversion complete using sed fallback"
fi

# Combine into single markdown file with proper PDF metadata
COMBINED_MD="/tmp/handbook-processed/handbook-complete.md"

echo "📖 Creating final PDF version..."

# Create header with metadata
cat > "$COMBINED_MD" << EOF
---
title: "Troop 500G Handbook"
subtitle: "Scouting America Troop 500G, Solon, Ohio"
author: "Lake Erie Council"
date: "$CURRENT_DATE"
---
---

EOF

# Add the processed handbook content (matches website exactly)
cat "$PROCESSED_HANDBOOK" >> "$COMBINED_MD"

echo "🎯 Generating PDF with Pandoc..."

# Generate PDF using external template with fixed TOC depth
pandoc "$COMBINED_MD" \
    --from markdown \
    --to pdf \
    --pdf-engine=xelatex \
    --output="assets/files/handbook/$HANDBOOK_PDF" \
    --template="templates/handbook.latex" \
    --verbose || echo "⚠️ Warning: Main handbook PDF generation had LaTeX errors but file may still be created"

# Generate contact information PDF
echo "📞 Creating contact information PDF..."

# Process contact-info.md directly with includes resolved
process_handbook "_includes/content/contact-info.md" "/tmp/handbook-processed/contact-info-processed.md"

echo "🖼️ Converting contact info images to LaTeX format..."
# Convert HTML img tags to LaTeX \includegraphics for contact info
python3 /scripts/utils/convert_images_to_latex.py "/tmp/handbook-processed/contact-info-processed.md" --verbose || echo "⚠️ Python3 not found, trying alternative image conversion..."

# Fallback sed-based image conversion if Python isn't available
if [ $? -ne 0 ]; then
    echo "🔧 Using sed-based image conversion fallback for contact info..."
    # Simple sed replacement for common image patterns
    sed -i 's|<img src="/assets/images/handbook/\([^"]*\)" alt="[^"]*" style="[^"]*float: right[^"]*">|\\includegraphics[width=0.12\\textwidth]{handbook/\1}|g' "/tmp/handbook-processed/contact-info-processed.md"
    sed -i 's|<img src="/assets/images/handbook/\([^"]*\)" alt="[^"]*" style="[^"]*float: left[^"]*">|\\includegraphics[width=0.12\\textwidth]{handbook/\1}|g' "/tmp/handbook-processed/contact-info-processed.md"
    sed -i 's|<img src="/assets/images/handbook/\([^"]*\)" alt="[^"]*" style="[^"]*">|\\includegraphics[width=0.12\\textwidth]{handbook/\1}|g' "/tmp/handbook-processed/contact-info-processed.md"
fi

cat > "/tmp/handbook-processed/contact-info.md" << EOF
---
title: "Troop 500G Contact Directory"
subtitle: "Scouting America Troop 500G"
author: "Current Leadership Contacts"
date: "$CURRENT_DATE"
documentclass: article
geometry: "margin=0.75in"
fontsize: 11pt
---

$(cat "/tmp/handbook-processed/contact-info-processed.md")
EOF

pandoc "/tmp/handbook-processed/contact-info.md" \
    --from markdown \
    --to pdf \
    --pdf-engine=xelatex \
    --output="assets/files/handbook/$CONTACT_PDF" \
    --template="templates/contact-info.latex" \
    --verbose

# Create copies for latest versions (for consistent URLs)
# Using cp instead of ln to avoid Windows symlink issues
echo "🔗 Creating latest file copies..."
cd assets/files/handbook

# Wait a moment for files to be fully written
sleep 2

# Check and copy handbook PDF
if [ -f "$HANDBOOK_PDF" ] && [ -s "$HANDBOOK_PDF" ]; then
    cp "$HANDBOOK_PDF" "troop-handbook-latest.pdf"
    if [ -s "troop-handbook-latest.pdf" ]; then
        echo "🔗 Created: troop-handbook-latest.pdf ($(stat -c%s "$HANDBOOK_PDF") bytes)"
    else
        echo "⚠️  Failed to copy: troop-handbook-latest.pdf"
    fi
else
    echo "⚠️  Source not found or empty: $HANDBOOK_PDF"
    ls -la "$HANDBOOK_PDF" 2>/dev/null || echo "   File does not exist"
fi

# Check and copy contact info PDF
if [ -f "$CONTACT_PDF" ] && [ -s "$CONTACT_PDF" ]; then
    cp "$CONTACT_PDF" "contact-info-latest.pdf"
    if [ -s "contact-info-latest.pdf" ]; then
        echo "🔗 Created: contact-info-latest.pdf ($(stat -c%s "$CONTACT_PDF") bytes)"
    else
        echo "⚠️  Failed to copy: contact-info-latest.pdf"
    fi
else
    echo "⚠️  Source not found or empty: $CONTACT_PDF"
    ls -la "$CONTACT_PDF" 2>/dev/null || echo "   File does not exist"
fi

cd - > /dev/null

# Generate appendix PDFs
echo "📋 Generating appendix PDFs..."
APPENDIX_DIR="_includes/content/appendix"

# Create appendix output directory
mkdir -p assets/files/handbook/appendix

# Process each .md file in the appendix directory
for appendix_file in "$APPENDIX_DIR"/*.md; do
    if [ -f "$appendix_file" ]; then
        # Extract filename without path and extension
        filename=$(basename "$appendix_file" .md)
        echo "   → Processing $filename.md"
        
        # Copy the appendix file to temp processing directory
        cp "$appendix_file" "/tmp/handbook-processed/${filename}-processed.md"
        
        # Clean up any Jekyll includes or front matter for PDF processing
        echo "   🧹 Cleaning PDF-specific content for $filename..."
        sed -i 's/{% include [^%]*%}//g' "/tmp/handbook-processed/${filename}-processed.md"
        sed -i '/^---$/,/^---$/d' "/tmp/handbook-processed/${filename}-processed.md"
        
        # Remove numbering from subsection headers but keep main appendix header
        # Remove numbers from headers like "#### 1. Title" -> "#### Title"
        sed -i 's/^\(####* \)[0-9][0-9]*\. */\1/' "/tmp/handbook-processed/${filename}-processed.md"
        # Remove numbers from headers like "### 1. Title" -> "### Title"  
        sed -i 's/^\(### \)[0-9][0-9]*\. */\1/' "/tmp/handbook-processed/${filename}-processed.md"
        # Remove numbers from headers like "## 1. Title" -> "## Title" (but not "## Appendix A:")
        sed -i 's/^\(## \)\([0-9][0-9]*\. \)/\1/' "/tmp/handbook-processed/${filename}-processed.md"
        
        # Convert HTML images to LaTeX format
        echo "   🖼️ Converting images to LaTeX format for $filename..."
        if [ -f /scripts/utils/convert_images_to_latex.py ]; then
            python3 /scripts/utils/convert_images_to_latex.py "/tmp/handbook-processed/${filename}-processed.md"
        fi
        
        # Define output filenames
        APPENDIX_PDF_DATED="${filename}-${TIMESTAMP}.pdf"
        APPENDIX_PDF_LATEST="${filename}-latest.pdf"
        
        echo "   📖 Creating PDF for $filename..."
        
        # Generate PDF using Pandoc with appendix template
        pandoc "/tmp/handbook-processed/${filename}-processed.md" \
            --from markdown \
            --to pdf \
            --pdf-engine=xelatex \
            --template=templates/appendix.latex \
            --variable=date:"$CURRENT_DATE" \
            --variable=timestamp:"$TIMESTAMP" \
            --output="assets/files/handbook/appendix/$APPENDIX_PDF_DATED" \
            --verbose
        
        if [ $? -eq 0 ]; then
            echo "   ✅ Created: $APPENDIX_PDF_DATED"
            
            # Create latest version link
            echo "   🔗 Creating latest file copy for $filename..."
            cp "assets/files/handbook/appendix/$APPENDIX_PDF_DATED" "assets/files/handbook/appendix/$APPENDIX_PDF_LATEST"
            echo "   🔗 Created: $APPENDIX_PDF_LATEST"
        else
            echo "   ❌ Failed to create PDF for $filename"
        fi
    fi
done

echo "✅ PDF generation complete!"
echo ""
echo "📁 Files created in: assets/files/handbook/"
echo "📖 Main handbook: $HANDBOOK_PDF"
echo "📞 Contact info: $CONTACT_PDF"
echo "🔗 Latest links: troop-handbook-latest.pdf, contact-info-latest.pdf"

# List appendix files if any were created
if ls assets/files/handbook/appendix/*.pdf 1> /dev/null 2>&1; then
    echo ""
    echo "📋 Appendix PDFs created:"
    for pdf in assets/files/handbook/appendix/*.pdf; do
        if [ -f "$pdf" ]; then
            if [[ "$pdf" == *"latest"* ]]; then
                echo "🔗 Latest link: $(basename "$pdf")"
            else
                echo "📋 Appendix: $(basename "$pdf")"
            fi
        fi
    done
fi
echo ""
