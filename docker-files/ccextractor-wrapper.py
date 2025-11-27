#!/usr/bin/env python3
"""
CCExtractor wrapper using ffmpeg to extract CEA-608 closed captions.
Mimics CCExtractor CLI: ccextractor -trim -nobom -noru -ru1 -o <output> <input>
"""
import sys
import subprocess
from pathlib import Path

def parse_args(argv):
    """Parse CCExtractor command-line arguments."""
    output_file = None
    input_file = None
    
    # Parse flags
    i = 0
    while i < len(argv):
        if argv[i] in ('-o', '--output'):
            if i + 1 < len(argv):
                output_file = argv[i + 1]
                i += 2
            else:
                i += 1
        elif argv[i].startswith('-'):
            # Skip known flags: -trim, -nobom, -noru, -ru1
            i += 1
        else:
            # Assume it's the input file
            input_file = argv[i]
            i += 1
    
    return input_file, output_file

def extract_captions(input_file, output_file):
    """
    Extract CEA-608 closed captions using ffmpeg.
    Returns True if captions found, False otherwise.
    """
    input_path = Path(input_file)
    output_path = Path(output_file)
    
    if not input_path.exists():
        print(f"Error: Input file not found: {input_file}", file=sys.stderr)
        return False
    
    # First, check if the file has closed caption data
    probe_cmd = [
        'ffprobe',
        '-v', 'quiet',
        '-print_format', 'json',
        '-show_streams',
        '-select_streams', 's',
        str(input_path)
    ]
    
    try:
        result = subprocess.run(
            probe_cmd,
            capture_output=True,
            text=True,
            check=True
        )
        # If no subtitle streams, try to extract embedded captions
        if '"streams": []' in result.stdout or not result.stdout.strip():
            # Try extracting CEA-608 captions embedded in video stream
            extract_cmd = [
                'ffmpeg',
                '-f', 'lavfi',
                '-i', f'movie={input_path}[out+subcc]',
                '-map', '0:s',
                '-y',  # Overwrite output
                str(output_path)
            ]
        else:
            # Extract first subtitle stream
            extract_cmd = [
                'ffmpeg',
                '-i', str(input_path),
                '-map', '0:s:0',
                '-y',  # Overwrite output
                str(output_path)
            ]
        
        subprocess.run(
            extract_cmd,
            capture_output=True,
            check=True
        )
        
        # Verify output file was created and has content
        if output_path.exists() and output_path.stat().st_size > 0:
            return True
        else:
            return False
            
    except subprocess.CalledProcessError:
        # No captions found or extraction failed
        return False
    except Exception as e:
        print(f"Error extracting captions: {e}", file=sys.stderr)
        return False

def main():
    if len(sys.argv) < 2:
        print("Usage: ccextractor -trim -nobom -noru -ru1 -o <output> <input>", file=sys.stderr)
        sys.exit(1)
    
    input_file, output_file = parse_args(sys.argv[1:])
    
    if not input_file or not output_file:
        print("Error: Missing input or output file", file=sys.stderr)
        print("Usage: ccextractor -trim -nobom -noru -ru1 -o <output> <input>", file=sys.stderr)
        sys.exit(1)
    
    success = extract_captions(input_file, output_file)
    
    if success:
        sys.exit(0)
    else:
        # Exit code 10 matches CCExtractor's "no captions found" behavior
        sys.exit(10)

if __name__ == '__main__':
    main()
