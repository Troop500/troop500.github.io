#!/usr/bin/env python3
"""
Convert HTML img tags to LaTeX includegraphics commands for PDF generation.

This script processes markdown files and converts HTML image tags with CSS styling
to appropriate LaTeX includegraphics commands with proper positioning and sizing.

Key Features:
- Converts HTML <img> tags to LaTeX \\includegraphics commands
- Handles CSS float positioning (left/right) 
- Special handling for Scout position patches (right-aligned using \hfill)
- Automatic width scaling based on pixel values
- Path normalization for LaTeX graphics path
- Uses wrapfigure for non-patch images with float positioning

Usage:
    python convert_images_to_latex.py input.md [-o output.md] [-v]
"""

import re
import sys
import argparse


def convert_img_to_latex(content):
    """
    Convert HTML img tags with CSS styling to LaTeX includegraphics commands.
    
    This function processes HTML <img> tags and converts them to appropriate LaTeX
    commands based on their attributes and CSS styling:
    
    - Position patches (containing 'patch_' or 'patrol_patch'): Use \\hfill for alignment
    - Other images: Use wrapfigure environment for text wrapping
    - Width conversion: Pixel values mapped to \textwidth fractions
    - Path normalization: Strip leading slash and 'assets/images/' prefix, preserving subdirectories (e.g. 'handbook/patch_scribe.jpg'). LaTeX template's \\graphicspath{{assets/images/}} resolves these paths correctly.
    
    Args:
        content (str): Markdown content containing HTML img tags
        
    Returns:
        str: Content with img tags converted to LaTeX includegraphics commands
    """
    
    # Pattern to match img tags with various attributes
    img_pattern = r'<img\s+([^>]+)>'
    
    def replace_img(match):
        """
        Replace a single img tag with appropriate LaTeX command.
        
        Extracts src, alt, and style attributes from the img tag and converts
        to LaTeX based on image type and positioning requirements.
        """
        attrs = match.group(1)
        
        # Extract key attributes from the img tag
        src_match = re.search(r'src="([^"]+)"', attrs)
        alt_match = re.search(r'alt="([^"]+)"', attrs)
        style_match = re.search(r'style="([^"]+)"', attrs)
        
        if not src_match:
            return match.group(0)  # Return original img tag if no src attribute found
            
        src = src_match.group(1)
        alt = alt_match.group(1) if alt_match else ""
        style = style_match.group(1) if style_match else ""
        
        # Convert web path to LaTeX graphics path
        # Strip Liquid baseurl tag, leading slash, and 'assets/images/' base, preserving any subdirectory.
        # e.g. '/assets/images/handbook/patch_scribe.jpg' -> 'handbook/patch_scribe.jpg'
        # e.g. '{{ site.baseurl }}/assets/images/handbook/patch_scribe.jpg' -> 'handbook/patch_scribe.jpg'
        # The LaTeX template's \graphicspath{{assets/images/}} resolves these paths correctly.
        latex_path = re.sub(r'\{\{[^}]+\}\}', '', src).lstrip('/').replace('assets/images/', '').replace('assets/', '')
        
        # Parse CSS styles to extract width and float positioning
        width = None
        float_pos = None
        
        if style:
            # Extract width from CSS (e.g., "width: 80px")
            width_match = re.search(r'width:\s*(\d+)px', style)
            if width_match:
                width_px = int(width_match.group(1))
                # Convert pixel values to LaTeX \textwidth fractions
                # Mapping based on common Scout handbook image sizes
                if width_px <= 60:
                    width = "0.08\\textwidth"  # Small patrol badges
                elif width_px <= 80:
                    width = "0.12\\textwidth"  # Standard position patches
                elif width_px <= 100:
                    width = "0.15\\textwidth"  # Medium images
                else:
                    width = "0.2\\textwidth"   # Large images
            
            # Extract float positioning from CSS
            if 'float: right' in style:
                float_pos = 'right'
            elif 'float: left' in style:
                float_pos = 'left'
        
        # Generate appropriate LaTeX commands based on image type and positioning
        
        # Special handling for Scout position patches and patrol badges
        # These need clean alignment to page edges, not text wrapping
        if 'patch_' in latex_path or 'patrol_patch' in latex_path:
            if float_pos == 'right':
                # Use \hfill to push image to right edge of page
                if width:
                    return f"\\hfill\\includegraphics[width={width}]{{{latex_path}}}\\\\\n"
                else:
                    return f"\\hfill\\includegraphics[width=0.12\\textwidth]{{{latex_path}}}\\\\\n"
            elif float_pos == 'left':
                # Place image at left, push following content right
                if width:
                    return f"\\includegraphics[width={width}]{{{latex_path}}}\\hfill\\\\\n"
                else:
                    return f"\\includegraphics[width=0.12\\textwidth]{{{latex_path}}}\\hfill\\\\\n"
            else:
                # No float specified, use simple inline placement
                if width:
                    return f"\\includegraphics[width={width}]{{{latex_path}}}"
                else:
                    return f"\\includegraphics[width=0.12\\textwidth]{{{latex_path}}}"
        
        # For other images (diagrams, photos, etc.), use wrapfigure for text wrapping
        if float_pos == 'right':
            if width:
                return f"\\begin{{wrapfigure}}{{r}}{{{width}}}\\centering\\includegraphics[width={width}]{{{latex_path}}}\\end{{wrapfigure}}\n\n"
            else:
                return f"\\begin{{wrapfigure}}{{r}}{{0.15\\textwidth}}\\centering\\includegraphics[width=0.15\\textwidth]{{{latex_path}}}\\end{{wrapfigure}}\n\n"
        elif float_pos == 'left':
            if width:
                return f"\\begin{{wrapfigure}}{{l}}{{{width}}}\\centering\\includegraphics[width={width}]{{{latex_path}}}\\end{{wrapfigure}}\n\n"
            else:
                return f"\\begin{{wrapfigure}}{{l}}{{0.15\\textwidth}}\\centering\\includegraphics[width=0.15\\textwidth]{{{latex_path}}}\\end{{wrapfigure}}\n\n"
        else:
            # No float positioning - inline or block image
            if width:
                return f"\\includegraphics[width={width}]{{{latex_path}}}"
            else:
                return f"\\includegraphics[width=0.15\\textwidth]{{{latex_path}}}"
    
    # Apply the conversion to all img tags in the content
    return re.sub(img_pattern, replace_img, content)


def main():
    """
    Main function to process command line arguments and convert images.
    
    Handles file I/O, error checking, and provides both verbose and quiet output modes.
    Supports in-place editing or writing to a separate output file.
    """
    parser = argparse.ArgumentParser(description='Convert HTML img tags to LaTeX includegraphics')
    parser.add_argument('input_file', help='Input markdown file to process')
    parser.add_argument('-o', '--output', help='Output file (default: overwrite input)')
    parser.add_argument('-v', '--verbose', action='store_true', help='Verbose output')
    
    args = parser.parse_args()
    
    try:
        # Read the input markdown file
        with open(args.input_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        if args.verbose:
            print(f"Processing {args.input_file}...")
            
        # Convert all HTML img tags to LaTeX includegraphics commands
        converted_content = convert_img_to_latex(content)
        
        # Determine output file (either specified output or overwrite input)
        output_file = args.output if args.output else args.input_file
        
        # Write the converted content
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(converted_content)
        
        if args.verbose:
            print(f"✅ Image conversion complete: {output_file}")
        else:
            print("✅ Image conversion complete")
            
    except FileNotFoundError:
        print(f"Error: File '{args.input_file}' not found", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
