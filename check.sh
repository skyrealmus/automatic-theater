#!/usr/bin/env bash
set -euo pipefail

compose=docker-compose-default.yml

reject() {
  local pattern=$1
  shift
  if grep -R -I -q "$pattern" "$@"; then
    printf 'rejected pattern: %s\n' "$pattern"
    exit 1
  fi
}

reject '^version:' "$compose"
grep -q 'subnet: 172.30.12.0/24' "$compose"
reject '172\.128\.2\.' . --exclude-dir=.git --exclude=.env
reject '192\.168\.2\.' . --exclude-dir=.git --exclude=.env
reject 'Asia/Shanghai' README.md docker-compose-default.env docker-compose-default.yml install.sh
reject 'docker compose pull && docker compose up -d' install.sh
reject 'sudo docker-compose pull\|sudo docker-compose up\|sudo docker-compose down' README.md
reject '^  portainer:' "$compose"
[ ! -e config/portainer ]
reject 'Portainer' README.md config/heimdall/www/app.sqlite config/heimdall/www/SupportedApps config/heimdall/www/icons 2>/dev/null
reject 'Jellyseerr\|jellyseerr\|fallenbagel/jellyseerr' README.md docker-compose-default.yml config/heimdall/www/app.sqlite 2>/dev/null

grep -q '^  seerr:' "$compose"
grep -q 'image: seerr/seerr:latest' "$compose"
grep -q '^  bazarr:' "$compose"
grep -q 'image: linuxserver/bazarr:latest' "$compose"
grep -q '^  recyclarr:' "$compose"
grep -q 'image: recyclarr/recyclarr:latest' "$compose"

bad_images=$(awk '/image:/{print $2}' "$compose" | grep -v ':latest$' || true)
[ -z "$bad_images" ] || { printf 'non-latest images:\n%s\n' "$bad_images"; exit 1; }

bash -n install.sh

if awk '/^```mermaid$/{inside=1; next} /^```$/{inside=0} inside && /== .* ==>/ {found=1} END{exit found ? 0 : 1}' README.md; then
  echo 'invalid Mermaid edge label syntax in README.md'
  exit 1
fi

python3 - <<'PY'
import re
import sqlite3
import subprocess
import sys
from pathlib import Path

pattern = re.compile(r'[\u3400-\u9fff\uf900-\ufaff]')
z = 'z' + 'h'
locale_pattern = re.compile(z + r'-(?:CN|HK|TW|SG|Hans|Hant)|' + z + r'_(?:CN|HK|TW|SG|Hans|Hant)|' + z + r'Hans|' + z + r'Hant|Locale=' + z + r'|UICulture>' + z + r'|MetadataCountryCode>' + 'CN', re.I)

def blob_as_text(value):
    try:
        text = value.decode('utf-8')
    except UnicodeDecodeError:
        return ''
    if not text:
        return ''
    printable = sum(ch.isprintable() or ch in '\r\n\t' for ch in text)
    if printable / len(text) < 0.95:
        return ''
    stripped = text.strip()
    if len(stripped) < 8:
        return ''
    return text

text_exts = {
    '.css', '.conf', '.config', '.env', '.html', '.ini', '.js', '.json',
    '.md', '.php', '.sh', '.txt', '.xml', '.yaml', '.yml'
}
violations = []
paths = [p for p in subprocess.check_output(['git', 'ls-files', '-z']).decode().split('\0') if p]
for path in paths:
    p = Path(path)
    if pattern.search(path) or locale_pattern.search(path):
        violations.append(f'{path}:PATH')
        continue
    if p.name.endswith(('-shm', '-wal')):
        violations.append(f'{path}:sqlite sidecar')
        continue
    suffix = p.suffix.lower()
    if suffix in {'.db', '.sqlite', '.sqlite3'}:
        try:
            con = sqlite3.connect(f'file:{path}?mode=ro', uri=True, timeout=2)
            for (table,) in con.execute("select name from sqlite_master where type='table'"):
                try:
                    cols = [r[1] for r in con.execute(f'pragma table_info("{table}")')]
                    if not cols:
                        continue
                    col_sql = ','.join('"' + c.replace('"', '""') + '"' for c in cols)
                    for row in con.execute(f'select {col_sql} from "{table}"'):
                        parts = []
                        for value in row:
                            if value is None:
                                parts.append('')
                            elif isinstance(value, bytes):
                                parts.append(blob_as_text(value))
                            else:
                                parts.append(str(value))
                        text = '\t'.join(parts)
                        if pattern.search(text) or locale_pattern.search(text):
                            violations.append(f'{path}:{table}')
                            raise StopIteration
                except StopIteration:
                    pass
                except Exception:
                    pass
            con.close()
        except Exception as exc:
            violations.append(f'{path}:sqlite open failed: {exc}')
        continue
    if suffix not in text_exts and not p.name.endswith('.blade.php'):
        continue
    data = p.read_bytes()
    try:
        text = data.decode('utf-8')
    except UnicodeDecodeError:
        continue
    if pattern.search(text) or locale_pattern.search(text):
        violations.append(path)

if violations:
    print('CJK text/path remains:')
    for item in violations[:200]:
        print(item)
    sys.exit(1)
PY

echo OK
