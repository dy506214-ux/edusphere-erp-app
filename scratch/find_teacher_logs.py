import re

log_path = r"C:\Users\Lenovo\.gemini\antigravity-ide\brain\1c289a7f-ca84-49ce-8b8d-6b56ea7bdbec\.system_generated\logs\transcript.jsonl"

try:
    with open(log_path, 'r', encoding='utf-8') as f:
        for idx, line in enumerate(f, 1):
            if "teacher1@edusphere" in line or "teacher51@edusphere" in line:
                # Print around 400 chars of matching lines
                print(f"Line {idx}: {line[:300]}")
except Exception as e:
    print("Error:", e)
