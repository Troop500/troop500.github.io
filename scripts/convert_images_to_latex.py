#!/usr/bin/env python3
"""
Convert HTML img tags to LaTeX includegraphics commands for PDF generation.

This script processes markdown files and converts HTML image tags with CSS styling
to appropriate LaTeX includegraphics commands with proper positioning and sizing.
"""

import re
import sys
import argparse


def convert_img_to_latex(content):
    """Convert HTML img tags with CSS styling to LaTeX includegraphics"""
    
    # Pattern to match img tags with various attributes
    img_pattern = r'<img\s+([^>]+)>'
    
    def replace_img(match):
        attrs = match.group(1)
        
        # Extract attributes
        src_match = re.search(r'src="([^"]+)"', attrs)
        alt_match = re.search(r'alt="([^"]+)"', attrs)
        style_match = re.search(r'style="([^"]+)"', attrs)
        
        if not src_match:
            return match.group(0)  # Return original if no src
            
        src = src_match.group(1)
        alt = alt_match.group(1) if alt_match else ""
        style = style_match.group(1) if style_match else ""
        
        # Remove leading slash and /assets/ prefix for LaTeX path
        latex_path = src.lstrip('/').replace('assets/images/', '').replace('assets/', '')
        
        # Parse CSS styles
        width = None
        float_pos = None
        
        if style:
            # Extract width
            width_match = re.search(r'width:\s*(\d+)px', style)
            if width_match:
                width_px = int(width_match.group(1))
                # Convert to appropriate LaTeX width (relative to textwidth)
                if width_px <= 60:
                    width = "0.08\\textwidth"
                elif width_px <= 80:
                    width = "0.12\\textwidth"
                elif width_px <= 100:
                    width = "0.15\\textwidth"
                else:
                    width = "0.2\\textwidth"
            
            # Extract float positioning
            if 'float: right' in style:
                float_pos = 'right'
            elif 'float: left' in style:
                float_pos = 'left'
        
        # Generate LaTeX based on positioning
        if float_pos == 'right':
            if width:
                return f"\\begin{{wrapfigure}}{{r}}{{{width}}}\\centering\\includegraphics[width={width}]{{{latex_path}}}\\end{{wrapfigure}}"
            else:
                return f"\\begin{{wrapfigure}}{{r}}{{0.15\\textwidth}}\\centering\\includegraphics[width=0.15\\textwidth]{{{latex_path}}}\\end{{wrapfigure}}"
        elif float_pos == 'left':
            if width:
                return f"\\begin{{wrapfigure}}{{l}}{{{width}}}\\centering\\includegraphics[width={width}]{{{latex_path}}}\\end{{wrapfigure}}"
            else:
                return f"\\begin{{wrapfigure}}{{l}}{{0.15\\textwidth}}\\centering\\includegraphics[width=0.15\\textwidth]{{{latex_path}}}\\end{{wrapfigure}}"
        else:
            # Inline or block image
            if width:
                return f"\\includegraphics[width={width}]{{{latex_path}}}"
            else:
                return f"\\includegraphics[width=0.15\\textwidth]{{{latex_path}}}"
    
    # Replace all img tags
    return re.sub(img_pattern, replace_img, content)


def main():
    """Main function to process command line arguments and convert images"""
    parser = argparse.ArgumentParser(description='Convert HTML img tags to LaTeX includegraphics')
    parser.add_argument('input_file', help='Input markdown file to process')
    parser.add_argument('-o', '--output', help='Output file (default: overwrite input)')
    parser.add_argument('-v', '--verbose', action='store_true', help='Verbose output')
    
    args = parser.parse_args()
    
    try:
        # Read the input file
        with open(args.input_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        if args.verbose:
            print(f"Processing {args.input_file}...")
            
        # Convert images
        converted_content = convert_img_to_latex(content)
        
        # Determine output file
        output_file = args.output if args.output else args.input_file
        
        # Write the result
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
