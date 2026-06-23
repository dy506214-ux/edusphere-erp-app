import os
import re

def map_to_token(size, weight):
    # Mapping based on AppTypography
    if size >= 32: return "AppTypography.h1"
    if size >= 28: return "AppTypography.h2"
    if size >= 24: return "AppTypography.h3"
    if size >= 20: return "AppTypography.h4"
    if size >= 18: return "AppTypography.bodyLarge"
    if size >= 16:
        if weight and ("w600" in weight or "bold" in weight or "w700" in weight):
            return "AppTypography.tableHeader"
        if weight and ("w500" in weight or "medium" in weight):
            return "AppTypography.button"
        return "AppTypography.body"
    if size >= 14: return "AppTypography.small"
    return "AppTypography.caption"

def process_file(filepath):
    if "typography.dart" in filepath:
        return

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content
    
    # We will look for GoogleFonts.inter(...) and TextStyle(...)
    # Since they can span multiple lines, we use a regex that balances parentheses, 
    # but Python's re doesn't support recursive matching well.
    # Instead, we'll find "GoogleFonts.inter(" and "TextStyle(" and manually parse until the matching ")"
    
    def replace_styles(text):
        idx = 0
        while True:
            # Find the next TextStyle or GoogleFonts.inter
            gf_idx = text.find("GoogleFonts.inter(", idx)
            ts_idx = text.find("TextStyle(", idx)
            
            if gf_idx == -1 and ts_idx == -1:
                break
                
            if gf_idx != -1 and (ts_idx == -1 or gf_idx < ts_idx):
                start_idx = gf_idx
                prefix_len = len("GoogleFonts.inter(")
            else:
                start_idx = ts_idx
                prefix_len = len("TextStyle(")
                
            # Find the matching closing parenthesis
            paren_count = 1
            curr_idx = start_idx + prefix_len
            in_string = False
            string_char = None
            
            while curr_idx < len(text) and paren_count > 0:
                char = text[curr_idx]
                if not in_string:
                    if char in ("'", '"'):
                        in_string = True
                        string_char = char
                    elif char == '(':
                        paren_count += 1
                    elif char == ')':
                        paren_count -= 1
                else:
                    if char == string_char and text[curr_idx - 1] != '\\':
                        in_string = False
                curr_idx += 1
                
            if paren_count == 0:
                end_idx = curr_idx
                inner_text = text[start_idx + prefix_len:end_idx - 1]
                
                # Check if it has fontSize:
                font_size_match = re.search(r'fontSize:\s*(\d+(?:\.\d+)?)(?:\.sp)?', inner_text)
                if font_size_match:
                    size = float(font_size_match.group(1))
                    weight_match = re.search(r'fontWeight:\s*([^,]+)', inner_text)
                    weight = weight_match.group(1) if weight_match else None
                    
                    token = map_to_token(size, weight)
                    
                    # Remove fontSize and fontWeight from inner_text
                    inner_text = re.sub(r'fontSize:\s*[\d\.]+(?:\.sp)?\s*,?', '', inner_text)
                    inner_text = re.sub(r'fontWeight:\s*[^,]+\s*,?', '', inner_text)
                    inner_text = inner_text.strip()
                    if inner_text.endswith(','):
                        inner_text = inner_text[:-1].strip()
                        
                    # Reconstruct
                    if inner_text:
                        new_expr = f"{token}.copyWith({inner_text})"
                    else:
                        new_expr = token
                        
                    text = text[:start_idx] + new_expr + text[end_idx:]
                    idx = start_idx + len(new_expr)
                else:
                    idx = end_idx
            else:
                break
        return text

    new_content = replace_styles(content)
    
    if new_content != original_content:
        # Add import if needed
        if "AppTypography" in new_content and "import 'package:edusphere/theme/typography.dart';" not in new_content:
            # find last import
            imports = list(re.finditer(r'^import\s+.*?;$', new_content, re.MULTILINE))
            if imports:
                last_import = imports[-1]
                new_content = new_content[:last_import.end()] + "\nimport 'package:edusphere/theme/typography.dart';" + new_content[last_import.end():]
            else:
                new_content = "import 'package:edusphere/theme/typography.dart';\n" + new_content
                
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {filepath}")

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
