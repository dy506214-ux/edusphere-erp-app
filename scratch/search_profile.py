with open("lib/screens/profile_screen.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if "_load" in line or "Emma" in line:
        print(f"{i+1}: {line.strip()}")
