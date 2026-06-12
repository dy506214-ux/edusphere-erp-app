import re

log_path = r"C:\Users\Lenovo\.gemini\antigravity-ide\brain\1c289a7f-ca84-49ce-8b8d-6b56ea7bdbec\.system_generated\logs\transcript.jsonl"

try:
    with open(log_path, 'r', encoding='utf-8') as f:
        for line in f:
            if "login" in line.lower() or "auth" in line.lower():
                # Print lines containing passwords or request parameters
                if any(x in line for x in ["email", "password", "pass"]):
                    print(line[:400])
except Exception as e:
    print("Error:", e)
