#!/bin/bash
#
# Automatic Theater installer
# Original project: https://github.com/LuckyPuppy514/automatic-theater
#

set -euo pipefail

cd "$(dirname "$0")"
SUDO=sudo
if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
	SUDO=
fi

echo "|------------------------------------------------------|"
echo "|                                                      |"
echo "|                  Automatic Theater                   |"
echo "|  https://github.com/skyrealmus/automatic-theater     |"
echo "|                                                      |"
echo "|------------------------------------------------------|"
echo ""
echo "|------------------------------------------------------|"
echo "|                 Current configuration                |"
echo "|------------------------------------------------------|"
cat ./docker-compose-default.env
echo "|------------------------------------------------------|"
echo ""
read -r -p "Review the configuration and continue? (yes: y, no: n): " CONFIRM
if [[ "${CONFIRM}" != "y" ]]; then
	echo "Cancelled."
	exit 0
fi

set -a
. ./docker-compose-default.env
set +a

echo ""
echo "Creating media directories ..."
for dir in 	"${MEDIA_PATH}" 	"${MEDIA_PATH}/movie" 	"${MEDIA_PATH}/serial" 	"${MEDIA_PATH}/anime" 	"${MEDIA_PATH}/download"
do
	${SUDO} mkdir -p "${dir}"
	echo "Ready: ${dir}"
done

echo ""
echo "Updating media directory ownership and permissions ..."
${SUDO} chown -R "${USERNAME}:${GROUPNAME}" "${MEDIA_PATH}"
${SUDO} chmod -R 770 "${MEDIA_PATH}"
echo "Media permissions updated."

echo ""
echo "Generating deployment files ..."
cp ./docker-compose-default.env ./.env
cp ./docker-compose-default.yml ./docker-compose.yml

echo ""
echo "Adding hardware acceleration devices ..."
GPU_DEVICES=()
if [[ -d "/dev/dri" ]]; then
	GPU_DEVICES+=("/dev/dri:/dev/dri")
fi
if [[ -d "/dev/vchiq" ]]; then
	GPU_DEVICES+=("/dev/vchiq:/dev/vchiq")
fi
if (( ${#GPU_DEVICES[@]} )); then
	{
		echo "    devices:"
		for device in "${GPU_DEVICES[@]}"; do
			echo "      - ${device}"
		done
	} >> ./docker-compose.yml
	echo "Hardware acceleration devices added."
else
	echo "No /dev/dri or /dev/vchiq device found; hardware acceleration devices were skipped."
fi

${SUDO} chown "${USERNAME}:${GROUPNAME}" ./.env ./docker-compose.yml
chmod 660 ./.env ./docker-compose.yml

echo ""
echo "Automatic Theater setup completed."
if docker info >/dev/null 2>&1; then
	DOCKER_RUN="docker compose"
else
	DOCKER_RUN="sudo docker compose"
fi
echo "Next step: ${DOCKER_RUN} pull && ${DOCKER_RUN} up -d"
