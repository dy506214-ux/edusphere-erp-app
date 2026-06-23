import os
import re

def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find `.copyWith(...)`
    # Python doesn't support nested parentheses matching natively with re, but we know copyWith doesn't usually contain nested parentheses except maybe color: Color(...)
    # We can just iterate and clean up positional arguments inside copyWith.
    
    def remove_positional(match):
        inner = match.group(1)
        # Split by comma, but be careful with nested parentheses (e.g., Color(0xFF...))
        parts = []
        current = []
        paren_count = 0
        for char in inner:
            if char == '(':
                paren_count += 1
            elif char == ')':
                paren_count -= 1
            
            if char == ',' and paren_count == 0:
                parts.append("".join(current))
                current = []
            else:
                current.append(char)
        if current:
            parts.append("".join(current))
            
        new_parts = []
        for part in parts:
            if part.strip() == '':
                continue
            # A valid named argument must have a colon (e.g., `color: Colors.red`)
            # Wait, `Color(0xFF0000)` doesn't have a colon, but it would be an invalid positional arg for copyWith.
            if ':' in part:
                # Make sure the colon is not inside a string or something...
                # Usually it's `identifier : expression`
                if re.search(r'^\s*[a-zA-Z0-9_]+\s*:', part):
                    new_parts.append(part.strip())
        
        if new_parts:
            return ".copyWith(" + ", ".join(new_parts) + ")"
        else:
            return ""

    # Since regex can't easily match nested copyWith(...) perfectly, let's just do a manual pass similar to previous script
    idx = 0
    new_text = ""
    while True:
        pos = content.find('.copyWith(', idx)
        if pos == -1:
            new_text += content[idx:]
            break
            
        new_text += content[idx:pos]
        start_idx = pos
        idx = pos + len('.copyWith(')
        
        paren_count = 1
        inner_start = idx
        while idx < len(content) and paren_count > 0:
            if content[idx] == '(':
                paren_count += 1
            elif content[idx] == ')':
                paren_count -= 1
            idx += 1
            
        if paren_count == 0:
            inner = content[inner_start:idx-1]
            parts = []
            current = []
            p_count = 0
            for char in inner:
                if char == '(': p_count += 1
                elif char == ')': p_count -= 1
                
                if char == ',' and p_count == 0:
                    parts.append("".join(current))
                    current = []
                else:
                    current.append(char)
            if current:
                parts.append("".join(current))
                
            new_parts = []
            for part in parts:
                if re.search(r'^\s*[a-zA-Z0-9_]+\s*:', part):
                    new_parts.append(part.strip())
            
            if new_parts:
                new_text += ".copyWith(" + ", ".join(new_parts) + ")"
            else:
                new_text += ""
        else:
            # Reached EOF without closing paren
            new_text += content[start_idx:]
            break

    if new_text != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_text)
        print(f"Fixed {filepath}")

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            fix_file(os.path.join(root, file))
