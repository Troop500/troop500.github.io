#!/bin/bash

# Troop 500G Appendix PDF Generator
# Generates individual PDF files for each appendix markdown file

echo "📋 Building Troop 500G Appendix PDFs..."
echo "======================================="

# Create temporary and output directories
mkdir -p /tmp/appendix-processed
mkdir -p assets/files/handbook/appendix

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
APPENDIX_DIR="_includes/content/appendix"

echo "📁 Archiving old appendix PDF files..."
# Archive all timestamped appendix PDFs (keep only the latest copies in main directory)
for file in assets/files/handbook/appendix/*-[0-9]*.pdf; do
    if [ -f "$file" ] && [[ "$file" != *"latest"* ]]; then
        mv "$file" assets/files/handbook/appendix/archive/ 2>/dev/null || true
    fi
done

# Create archive directory if it doesn't exist
mkdir -p assets/files/handbook/appendix/archive

echo "🔍 Processing appendix files..."

# Check if appendix directory exists
if [ ! -d "$APPENDIX_DIR" ]; then
    echo "❌ Appendix directory not found: $APPENDIX_DIR"
    exit 1
fi

# Process each .md file in the appendix directory
for appendix_file in "$APPENDIX_DIR"/*.md; do
    if [ -f "$appendix_file" ]; then
        # Extract filename without path and extension
        filename=$(basename "$appendix_file" .md)
        echo "   → Processing $filename.md"
        
        # Copy the appendix file to temp processing directory
        cp "$appendix_file" "/tmp/appendix-processed/${filename}-processed.md"
        
        # Clean up any Jekyll includes or front matter for PDF processing
        echo "🧹 Cleaning PDF-specific content for $filename..."
        sed -i 's/{% include [^%]*%}//g' "/tmp/appendix-processed/${filename}-processed.md"
        sed -i '/^---$/,/^---$/d' "/tmp/appendix-processed/${filename}-processed.md"
        
        # Convert HTML images to LaTeX format
        echo "🖼️ Converting images to LaTeX format for $filename..."
        if [ -f /scripts/utils/convert_images_to_latex.py ]; then
            python3 /scripts/utils/convert_images_to_latex.py "/tmp/appendix-processed/${filename}-processed.md"
        fi
        
        # Define output filenames
        APPENDIX_PDF_DATED="${filename}-${TIMESTAMP}.pdf"
        APPENDIX_PDF_LATEST="${filename}-latest.pdf"
        
        echo "📖 Creating PDF for $filename..."
        echo "🎯 Generating PDF with Pandoc..."
        
        # Generate PDF using Pandoc with simplified template
        pandoc "/tmp/appendix-processed/${filename}-processed.md" \
            --from markdown \
            --to pdf \
            --pdf-engine=xelatex \
            --template=templates/appendix.latex \
            --variable=date:"$(date +'%B %Y')" \
            --variable=timestamp:"$TIMESTAMP" \
            --output="assets/files/handbook/appendix/$APPENDIX_PDF_DATED" \
            --verbose
        
        if [ $? -eq 0 ]; then
            echo "   ✅ Created: $APPENDIX_PDF_DATED"
            
            # Create latest version link
            echo "🔗 Creating latest file copy for $filename..."
            cp "assets/files/handbook/appendix/$APPENDIX_PDF_DATED" "assets/files/handbook/appendix/$APPENDIX_PDF_LATEST"
            echo "   🔗 Created: $APPENDIX_PDF_LATEST ($(stat -f%z "assets/files/handbook/appendix/$APPENDIX_PDF_LATEST" 2>/dev/null || stat -c%s "assets/files/handbook/appendix/$APPENDIX_PDF_LATEST" 2>/dev/null || echo "unknown") bytes)"
        else
            echo "   ❌ Failed to create PDF for $filename"
        fi
    fi
done

# Clean up temporary files
rm -rf /tmp/appendix-processed

echo ""
echo "✅ Appendix PDF generation complete!"
echo ""
echo "📁 Files created in: assets/files/handbook/appendix/"

# List all generated files
for pdf in assets/files/handbook/appendix/*.pdf; do
    if [ -f "$pdf" ]; then
        if [[ "$pdf" == *"latest"* ]]; then
            echo "🔗 Latest link: $(basename "$pdf")"
        else
            echo "📋 Appendix: $(basename "$pdf")"
        fi
    fi
done
