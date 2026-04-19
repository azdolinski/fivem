#!/usr/bin/env bash
# Entrypoint for FXServer container. Chooses FiveM or RedM defaults based on $GAME.
set -euo pipefail

# ---- Inputs ----
GAME="${GAME:-fivem}"                          # fivem | redm
LICENSE_KEY="${LICENSE_KEY:-}"                 # required unless NO_LICENSE_KEY set
NO_LICENSE_KEY="${NO_LICENSE_KEY:-}"           # skip license env injection (key can be in server.cfg)
NO_DEFAULT_CONFIG="${NO_DEFAULT_CONFIG:-}"     # set to 1 for txAdmin (no +exec server.cfg)
RCON_PASSWORD="${RCON_PASSWORD:-}"             # auto-generated on first run if empty
SV_HOSTNAME="${SV_HOSTNAME:-My FXServer}"
SV_MAXCLIENTS="${SV_MAXCLIENTS:-32}"
SV_ENDPOINT_PORT="${SV_ENDPOINT_PORT:-30120}"
TXADMIN_PORT="${TXADMIN_PORT:-40120}"          # used only if NO_DEFAULT_CONFIG=1
EXTRA_ARGS="${EXTRA_ARGS:-}"                   # anything appended to FXServer argv

CONFIG_DIR="/config"
SERVER_CFG="${CONFIG_DIR}/server.cfg"
RESOURCES_DIR="${CONFIG_DIR}/resources"
DEFAULT_RESOURCES_SRC="/opt/cfx-server-data/resources"

# ---- Normalize GAME ----
case "${GAME,,}" in
  fivem|gta5)  GAMENAME="gta5"; DEFAULT_BUILD="${SV_ENFORCE_GAME_BUILD:-3407}" ;;
  redm|rdr3)   GAMENAME="rdr3"; DEFAULT_BUILD="${SV_ENFORCE_GAME_BUILD:-1491}" ;;
  *) echo "[entrypoint] ERROR: unknown GAME='${GAME}' (use 'fivem' or 'redm')" >&2; exit 1 ;;
esac
echo "[entrypoint] GAME=${GAME} -> gamename=${GAMENAME}, sv_enforceGameBuild=${DEFAULT_BUILD}"

# ---- Bootstrap /config on first run ----
mkdir -p "${CONFIG_DIR}"
if [[ ! -d "${RESOURCES_DIR}" ]]; then
  echo "[entrypoint] Seeding default resources from ${DEFAULT_RESOURCES_SRC}"
  mkdir -p "${RESOURCES_DIR}"
  cp -a "${DEFAULT_RESOURCES_SRC}/." "${RESOURCES_DIR}/"
fi

# ---- Render default server.cfg if missing ----
if [[ ! -f "${SERVER_CFG}" && -z "${NO_DEFAULT_CONFIG}" ]]; then
  echo "[entrypoint] Generating default server.cfg for ${GAMENAME}"
  [[ -z "${RCON_PASSWORD}" ]] && RCON_PASSWORD="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)" || true

  # Base directives shared by FiveM and RedM
  cat >"${SERVER_CFG}" <<EOF
# Auto-generated on first run. Edit freely; this file will NOT be overwritten.
endpoint_add_tcp "0.0.0.0:${SV_ENDPOINT_PORT}"
endpoint_add_udp "0.0.0.0:${SV_ENDPOINT_PORT}"

sv_hostname "${SV_HOSTNAME}"
sv_maxclients ${SV_MAXCLIENTS}

set gamename ${GAMENAME}
sv_enforceGameBuild ${DEFAULT_BUILD}

rcon_password "${RCON_PASSWORD}"
set steam_webApiKey "none"
EOF

  # Default resources per game (per Cfx.re docs + tabarra/CFX-Default-recipe)
  if [[ "${GAMENAME}" == "gta5" ]]; then
    cat >>"${SERVER_CFG}" <<'EOF'

# FiveM default resources
ensure mapmanager
ensure chat
ensure spawnmanager
ensure sessionmanager
ensure basic-gamemode
ensure hardcap
ensure rconlog
ensure scoreboard
ensure playernames
EOF
  else
    cat >>"${SERVER_CFG}" <<'EOF'

# RedM default resources
ensure mapmanager
ensure chat
ensure spawnmanager
ensure sessionmanager-rdr3
ensure redm-map-one
ensure hardcap
EOF
  fi

  cat >>"${SERVER_CFG}" <<'EOF'

# ACL bootstrap
add_ace group.admin command allow
add_ace group.admin command.quit deny
# add_principal identifier.fivem:YOUR_ID group.admin
EOF
fi

# ---- Build argv for FXServer ----
# FXServer lives at /opt/cfx-server/FXServer after extracting fx.tar.xz (alpine/opt/cfx-server).
FXSERVER_BIN="/opt/cfx-server/FXServer"
ARGS=(+set gamename "${GAMENAME}")

# License key from env (unless disabled). Can also live in server.cfg.
if [[ -z "${NO_LICENSE_KEY}" && -n "${LICENSE_KEY}" ]]; then
  ARGS+=(+set sv_licenseKey "${LICENSE_KEY}")
fi

# When txAdmin is used the user sets NO_DEFAULT_CONFIG=1 and we skip +exec.
if [[ -z "${NO_DEFAULT_CONFIG}" ]]; then
  ARGS+=(+exec "${SERVER_CFG}")
fi

# Append user-supplied extras verbatim
if [[ -n "${EXTRA_ARGS}" ]]; then
  # shellcheck disable=SC2206
  EXTRA=( ${EXTRA_ARGS} )
  ARGS+=( "${EXTRA[@]}" )
fi

echo "[entrypoint] exec: ${FXSERVER_BIN} ${ARGS[*]}"
cd "${CONFIG_DIR}"
exec "${FXSERVER_BIN}" "${ARGS[@]}"
