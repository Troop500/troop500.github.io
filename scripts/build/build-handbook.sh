#!/bin/bash

# Troop 500G Handbook & Contact Info PDF Generator
# Builds the main handbook and contact information PDFs
# This is Phase 1 of the PDF build process (Phase 2: build-appendices.sh)

echo "🏕️ Building Troop 500G Handbook & Contact PDFs..."
echo "================================================="

# Create temporary and output directories
mkdir -p /tmp/handbook-processed
mkdir -p assets/files/handbook
mkdir -p assets/files/handbook/archive

CURRENT_DATE=$(date +"%B %Y")
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Save timestamp so build-appendices.sh can reuse it
echo "$TIMESTAMP" > /tmp/handbook-processed/timestamp.txt

echo "📁 Archiving old handbook PDF files..."
for file in assets/files/handbook/troop-handbook-[0-9]*.pdf; do
    if [ -f "$file" ] && [[ "$file" != *"latest"* ]]; then
        mv "$file" assets/files/handbook/archive/ 2>/dev/null || true
    fi
done

echo "🧹 Cleaning archive (keeping last 5 versions)..."
cd assets/files/handbook/archive/
if ls troop-handbook-*.pdf 1> /dev/null 2>&1; then
    ls -1 troop-handbook-*.pdf | sort -r | tail -n +6 | xargs rm -f 2>/dev/null || true
    echo "   📖 Handbook archive: kept $(ls troop-handbook-*.pdf 2>/dev/null | wc -l) versions"
fi
cd - > /dev/null

# Define unique filenames
HANDBOOK_PDF="troop-handbook-${TIMESTAMP}.pdf"

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
        local include_file=""
        if echo "$include_line" | grep -q "include_relative"; then
            include_file=$(echo "$include_line" | sed 's/.*{% include_relative \([^%}]*\) %}.*/\1/' | xargs)
            if [[ "$include_file" == ../* ]]; then
                include_file=${include_file#../}
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
            local include_content_file="/tmp/handbook-processed/include_temp.md"
            iconv -f utf-8 -t utf-8 "$source_file" | tr -d '\r' > "$include_content_file"
            
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

# Convert web-safe page break markers to LaTeX \newpage
sed -i 's/<!-- pagebreak -->/\\newpage/g' "$PROCESSED_HANDBOOK"

# Remove web-specific elements for PDF version
sed -i '/Download Complete Handbook PDF/d' "$PROCESSED_HANDBOOK"
sed -i '/Build Tools.*BUILD_TOOLS.md/d' "$PROCESSED_HANDBOOK"
sed -i '/{:target="_blank"}/d' "$PROCESSED_HANDBOOK"
sed -i '/<!-- PDF download links removed for PDF version -->/d' "$PROCESSED_HANDBOOK"

# Replace web-only content with PDF-friendly alternatives
echo "🗺️ Converting interactive content for PDF..."
sed -i '/<!-- PDF-REPLACE-START:/,/<!-- PDF-REPLACE-END -->/c\
**Location Map:** Visit [Google Maps: Advent Lutheran Church, 5525 Harper Road, Solon, OH](https://www.google.com/maps/place/Advent+Lutheran+Church+ELCA)' "$PROCESSED_HANDBOOK"

echo "🖼️ Converting HTML images to LaTeX format..."
if python3 /scripts/utils/convert_images_to_latex.py "$PROCESSED_HANDBOOK" --verbose; then
    echo "✅ Image conversion complete using Python"
else
    echo "🔧 Using sed-based image conversion fallback..."
    # Normalize {{ site.baseurl }}/assets/ -> /assets/ so patterns below match consistently
    sed -i 's|{{ site\.baseurl }}/assets/|/assets/|g' "$PROCESSED_HANDBOOK"
    sed -i 's|<img src="/assets/images/handbook/\([^"]*\)" alt="[^"]*" style="[^"]*float: right[^"]*width: *\([0-9]*\)px[^"]*">|\\begin{wrapfigure}{r}{0.15\\textwidth}\\centering\\includegraphics[width=0.15\\textwidth]{handbook/\1}\\end{wrapfigure}|g' "$PROCESSED_HANDBOOK"
    sed -i 's|<img src="/assets/images/handbook/\([^"]*\)" alt="[^"]*" style="[^"]*float: left[^"]*width: *\([0-9]*\)px[^"]*">|\\begin{wrapfigure}{l}{0.15\\textwidth}\\centering\\includegraphics[width=0.15\\textwidth]{handbook/\1}\\end{wrapfigure}|g' "$PROCESSED_HANDBOOK"
    sed -i 's|<img src="/assets/images/handbook/\([^"]*\)" alt="[^"]*" style="[^"]*width: *50%[^"]*">|\\begin{center}\\includegraphics[width=0.5\\textwidth]{handbook/\1}\\end{center}|g' "$PROCESSED_HANDBOOK"
    sed -i 's|<img src="/assets/images/handbook/\([^"]*\)" alt="[^"]*"[^>]*>|\\includegraphics[width=0.15\\textwidth]{handbook/\1}|g' "$PROCESSED_HANDBOOK"
    echo "✅ Image conversion complete using sed fallback"
fi

# Combine into single markdown file with proper PDF metadata
COMBINED_MD="/tmp/handbook-processed/handbook-complete.md"

echo "📖 Creating final PDF version..."

cat > "$COMBINED_MD" << EOF
---
title: "Troop 500G Handbook"
subtitle: "Scouting America Troop 500G, Solon, Ohio"
author: "Lake Erie Council"
date: "$CURRENT_DATE"
---
---

EOF

cat "$PROCESSED_HANDBOOK" >> "$COMBINED_MD"

echo "🎯 Generating Handbook PDF with Pandoc..."

pandoc "$COMBINED_MD" \
    --from markdown \
    --to pdf \
    --pdf-engine=xelatex \
    --output="assets/files/handbook/$HANDBOOK_PDF" \
    --template="templates/handbook.latex" \
    --verbose || true

# Verify handbook PDF was created
if [ ! -s "assets/files/handbook/$HANDBOOK_PDF" ]; then
    echo "❌ ERROR: Handbook PDF was not generated: $HANDBOOK_PDF"
    HANDBOOK_FAILED=true
else
    echo "✅ Handbook PDF created: $HANDBOOK_PDF ($(stat -c%s "assets/files/handbook/$HANDBOOK_PDF") bytes)"
fi

# Create copies for latest versions (for consistent URLs)
echo ""
echo "🔗 Creating latest file copies..."
cd assets/files/handbook

sleep 2

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

cd - > /dev/null

# Summary
echo ""
echo "================================================="
echo "📖 Handbook PDF Build Summary"
echo "================================================="
echo "📁 Output directory: assets/files/handbook/"
echo "📖 Main handbook: $HANDBOOK_PDF"
echo "🔗 Latest: troop-handbook-latest.pdf"

# Exit with error if handbook PDF failed
if [ "${HANDBOOK_FAILED:-}" = "true" ]; then
    echo ""
    echo "❌ Handbook PDF failed to generate!"
    exit 1
fi

echo ""
echo "✅ Handbook PDF generation complete!"
