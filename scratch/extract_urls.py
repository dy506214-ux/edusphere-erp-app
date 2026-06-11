import json
import re

log_path = r"C:\Users\Lenovo\.gemini\antigravity-ide\brain\ef8d28b4-902e-47df-964e-ab90ba325546\.system_generated\logs\transcript.jsonl"

found_urls = set()
with open(log_path, 'r', encoding='utf-8') as f:
    for line in f:
        matches = re.findall(r'https://[a-zA-Z0-9\-]+\.supabase\.co', line)
        for m in matches:
            found_urls.add(m)

print("Found URLs:")
for u in found_urls:
    print(u)
