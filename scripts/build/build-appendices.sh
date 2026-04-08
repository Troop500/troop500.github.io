#!/bin/bash

# Troop 500G Appendix PDF Generator
# Builds individual PDFs for each appendix document
# This is Phase 2 of the PDF build process (Phase 1: build-handbook.sh)

echo "📋 Building Troop 500G Appendix PDFs..."
echo "========================================"

# Create temporary and output directories
mkdir -p /tmp/handbook-processed
mkdir -p assets/files/handbook/appendix
mkdir -p assets/files/handbook/appendix/archive

CURRENT_DATE=$(date +"%B %Y")

# Reuse timestamp from build-handbook.sh if available, otherwise generate new
if [ -f /tmp/handbook-processed/timestamp.txt ]; then
    TIMESTAMP=$(cat /tmp/handbook-processed/timestamp.txt)
    echo "📅 Reusing timestamp from handbook build: $TIMESTAMP"
else
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    echo "📅 Generated new timestamp: $TIMESTAMP"
fi

APPENDIX_DIR="_includes/content/appendix"

echo "📁 Archiving old appendix PDF files..."
for file in assets/files/handbook/appendix/*-[0-9]*.pdf; do
    if [ -f "$file" ] && [[ "$file" != *"latest"* ]]; then
        mv "$file" assets/files/handbook/appendix/archive/ 2>/dev/null || true
    fi
done

echo "🧹 Cleaning appendix archive (keeping last 5 versions of each type)..."
cd assets/files/handbook/appendix/archive/
for prefix in $(ls *.pdf 2>/dev/null | sed 's/-[0-9][0-9]*_.*//' | sort -u); do
    if ls ${prefix}-*.pdf 1> /dev/null 2>&1; then
        ls -1 ${prefix}-*.pdf | sort -r | tail -n +6 | xargs rm -f 2>/dev/null || true
    fi
done
cd - > /dev/null

# Track results
TOTAL_APPENDIX=0
PASSED_APPENDIX=0
FAILED_APPENDIX=0

# Process each .md file in the appendix directory
if [ ! -d "$APPENDIX_DIR" ]; then
    echo "⚠️  Appendix directory not found: $APPENDIX_DIR"
    exit 1
fi

for appendix_file in "$APPENDIX_DIR"/*.md; do
    if [ -f "$appendix_file" ]; then
        TOTAL_APPENDIX=$((TOTAL_APPENDIX + 1))
        
        # Extract filename without path and extension
        filename=$(basename "$appendix_file" .md)
        echo ""
        echo "   → Processing $filename.md"
        
        # Copy the appendix file to temp processing directory
        cp "$appendix_file" "/tmp/handbook-processed/${filename}-processed.md"
        
        # Clean up any Jekyll includes or front matter for PDF processing
        echo "   🧹 Cleaning PDF-specific content for $filename..."
        sed -i 's/\r$//' "/tmp/handbook-processed/${filename}-processed.md"
        sed -i 's/{% include [^%]*%}//g' "/tmp/handbook-processed/${filename}-processed.md"
        sed -i '/^---$/,/^---$/d' "/tmp/handbook-processed/${filename}-processed.md"
        # Convert web-safe page break markers to LaTeX \newpage
        sed -i 's/<!-- pagebreak -->/\\newpage/g' "/tmp/handbook-processed/${filename}-processed.md"
        
        # Remove numbering from subsection headers but keep main appendix header
        sed -i 's/^\(####* \)[0-9][0-9]*\. */\1/' "/tmp/handbook-processed/${filename}-processed.md"
        sed -i 's/^\(### \)[0-9][0-9]*\. */\1/' "/tmp/handbook-processed/${filename}-processed.md"
        sed -i 's/^\(## \)\([0-9][0-9]*\. \)/\1/' "/tmp/handbook-processed/${filename}-processed.md"
        
        # Convert HTML images to LaTeX format
        echo "   🖼️ Converting images to LaTeX format for $filename..."
        if [ -f /scripts/utils/convert_images_to_latex.py ]; then
            python3 /scripts/utils/convert_images_to_latex.py "/tmp/handbook-processed/${filename}-processed.md" || true
        fi
        
        # Define output filenames
        APPENDIX_PDF_DATED="${filename}-${TIMESTAMP}.pdf"
        APPENDIX_PDF_LATEST="${filename}-latest.pdf"
        
        echo "   📖 Creating PDF for $filename..."
        
        # Generate PDF using Pandoc with appendix template
        # --shift-heading-level-by=-1 promotes ## to # for standalone PDFs
        pandoc "/tmp/handbook-processed/${filename}-processed.md" \
            --from markdown \
            --to pdf \
            --pdf-engine=xelatex \
            --template=templates/appendix.latex \
            --shift-heading-level-by=-1 \
            --variable=date:"$CURRENT_DATE" \
            --variable=timestamp:"$TIMESTAMP" \
            --output="assets/files/handbook/appendix/$APPENDIX_PDF_DATED" \
            --verbose || true
        
        # Verify PDF was created
        if [ -s "assets/files/handbook/appendix/$APPENDIX_PDF_DATED" ]; then
            PASSED_APPENDIX=$((PASSED_APPENDIX + 1))
            echo "   ✅ Created: $APPENDIX_PDF_DATED ($(stat -c%s "assets/files/handbook/appendix/$APPENDIX_PDF_DATED") bytes)"
            
            # Create latest version copy
            echo "   🔗 Creating latest file copy for $filename..."
            cp "assets/files/handbook/appendix/$APPENDIX_PDF_DATED" "assets/files/handbook/appendix/$APPENDIX_PDF_LATEST"
            echo "   🔗 Created: $APPENDIX_PDF_LATEST"
        else
            FAILED_APPENDIX=$((FAILED_APPENDIX + 1))
            echo "   ❌ Failed to create PDF for $filename"
        fi
    fi
done

# Summary
echo ""
echo "========================================"
echo "📋 Appendix PDF Build Summary"
echo "========================================"
echo "📁 Output directory: assets/files/handbook/appendix/"
echo "   Total appendices: $TOTAL_APPENDIX"
echo "   Succeeded: $PASSED_APPENDIX"
echo "   Failed: $FAILED_APPENDIX"

if ls assets/files/handbook/appendix/*.pdf 1> /dev/null 2>&1; then
    echo ""
    echo "📋 Appendix PDFs created:"
    for pdf in assets/files/handbook/appendix/*.pdf; do
        if [ -f "$pdf" ]; then
            size=$(stat -c%s "$pdf" 2>/dev/null || echo "?")
            if [[ "$pdf" == *"latest"* ]]; then
                echo "   🔗 $(basename "$pdf") ($size bytes)"
            else
                echo "   📋 $(basename "$pdf") ($size bytes)"
            fi
        fi
    done
fi

if [ "$FAILED_APPENDIX" -gt 0 ]; then
    echo ""
    echo "❌ $FAILED_APPENDIX appendix PDF(s) failed to generate!"
    exit 1
fi

echo ""
echo "✅ Appendix PDF generation complete!"
