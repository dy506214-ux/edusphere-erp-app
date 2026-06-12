import json
import re

log_path = r"C:\Users\Lenovo\.gemini\antigravity-ide\brain\1c289a7f-ca84-49ce-8b8d-6b56ea7bdbec\.system_generated\logs\transcript.jsonl"

found_tokens = []
try:
    with open(log_path, 'r', encoding='utf-8') as f:
        for line in f:
            # Look for JWT tokens
            matches = re.findall(r'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9\.[a-zA-Z0-9\-_]+\.[a-zA-Z0-9\-_]+', line)
            for m in matches:
                if m not in found_tokens:
                    found_tokens.append(m)
except Exception as e:
    print("Error reading log:", e)

print(f"Found {len(found_tokens)} unique JWT tokens:")
for idx, token in enumerate(found_tokens, 1):
    # Decode the payload (second part of JWT)
    try:
        parts = token.split('.')
        payload_b64 = parts[1]
        # Pad payload_b64
        payload_b64 += '=' * (4 - len(payload_b64) % 4)
        payload = json.loads(base64.b64decode(payload_b64).decode('utf-8'))
        print(f"\n{idx}. Token: {token[:40]}...")
        print(f"   Payload: {payload}")
    except Exception as ex:
        # If base64 is not imported
        import base64
        try:
            parts = token.split('.')
            payload_b64 = parts[1]
            payload_b64 += '=' * (4 - len(payload_b64) % 4)
            payload = json.loads(base64.b64decode(payload_b64).decode('utf-8'))
            print(f"\n{idx}. Token: {token[:40]}...")
            print(f"   Payload: {payload}")
        except Exception as ex2:
            print(f"\n{idx}. Token: {token[:40]}... (failed to decode: {ex2})")
