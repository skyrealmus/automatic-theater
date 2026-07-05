#!/usr/bin/env bash
set -euo pipefail

compose=docker-compose-default.yml

grep -q 'subnet: 172.30.12.0/24' "$compose"
! grep -R -I -q '172\.128\.2\.' . --exclude-dir=.git --exclude=.env
! grep -R -I -q '192\.168\.2\.' . --exclude-dir=.git --exclude=.env
! grep -R -I -q 'Asia/Shanghai' README.md docker-compose-default.env docker-compose-default.yml install.sh check.sh
! grep -q '^  portainer:' "$compose"
[ ! -e config/portainer ]
! grep -R -I -q 'Portainer' README.md config/heimdall/www/app.sqlite config/heimdall/www/SupportedApps config/heimdall/www/icons 2>/dev/null
! grep -R -I -q 'Jellyseerr\|jellyseerr\|fallenbagel/jellyseerr' README.md docker-compose-default.yml config/heimdall/www/app.sqlite 2>/dev/null

grep -q '^  seerr:' "$compose"
grep -q 'image: seerr/seerr:latest' "$compose"
grep -q '^  bazarr:' "$compose"
grep -q 'image: linuxserver/bazarr:latest' "$compose"
grep -q '^  recyclarr:' "$compose"
grep -q 'image: recyclarr/recyclarr:latest' "$compose"

bad_images=$(awk '/image:/{print $2}' "$compose" | grep -v ':latest$' || true)
[ -z "$bad_images" ] || { printf 'non-latest images:\n%s\n' "$bad_images"; exit 1; }

bash -n install.sh

echo OK
