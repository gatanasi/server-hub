#!/usr/bin/env bash
#
# migrate-bind-to-volume.sh - Copy a bind-mounted directory into a Compose named volume
#
# Runs ON THE APP HOST (not on deployer.vm), before the PR that switches the
# app's compose.yaml from the bind mount to the named volume is merged.
# The backup playbook only archives named volumes (<project>_*), so state that
# lives in bind mounts is never backed up. This moves it.
#
# What it does:
#   1. Refuses to run while a running container still mounts the source directory.
#   2. Creates <project>_<volume> with the labels Docker Compose sets itself, so
#      Compose adopts the volume on the next deploy without a warning.
#   3. Copies the directory with `cp -a` (owners, modes, timestamps preserved),
#      optionally chowns the copy, and compares file lists and sizes.
# The source directory is left untouched: until it is deleted by hand, a deploy
# rollback (which restores the previous compose.yaml) still finds the old data.
#
# Usage (from deployer.vm, or anywhere that can ssh to the app host):
#   ssh <user>@<app>.vm 'bash -s' -- <project> <volume> <source-dir> [<uid:gid>] \
#       < deploy/migrate-bind-to-volume.sh
#
#   project     Compose project name: the app directory name, or `name:` in compose.yaml
#   volume      volume key as written under `volumes:` in compose.yaml
#   source-dir  absolute path of the bind-mounted directory
#   uid:gid     optional: chown the copy (for services moving to a non-root `user:`)
#
# Example:
#   ssh arr@arr.vm 'bash -s' -- arr radarr-config /opt/apps/arr/config/radarr \
#       < deploy/migrate-bind-to-volume.sh
#
# Environment:
#   HELPER_IMAGE  image used for the copy (default: alpine:3.23.2, as in the backup playbook)
#
# Standalone on purpose: it is piped to a host that has no copy of this repo,
# so it cannot source common.sh.

set -euo pipefail

HELPER_IMAGE="${HELPER_IMAGE:-alpine:3.23.2}"

log() {
    printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

die() {
    printf '[%s] ERROR: %s\n' "$(date '+%H:%M:%S')" "$*" >&2
    exit 1
}

usage() {
    sed -n '/^# Usage/,/^# Environment/p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//' >&2 \
        || echo "Usage: migrate-bind-to-volume.sh <project> <volume> <source-dir> [<uid:gid>]" >&2
    exit 2
}

[[ $# -ge 3 && $# -le 4 ]] || usage

project="$1"
volume_key="$2"
source_dir="${3%/}"
owner="${4:-}"
volume="${project}_${volume_key}"

[[ "${project}" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || die "invalid project name: ${project}"
[[ "${volume_key}" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]] || die "invalid volume name: ${volume_key}"
[[ "${source_dir}" == /* ]] || die "source-dir must be an absolute path: ${source_dir}"
[[ -d "${source_dir}" ]] || die "source-dir does not exist: ${source_dir}"
[[ -z "${owner}" || "${owner}" =~ ^[0-9]+:[0-9]+$ ]] || die "uid:gid must be numeric, got: ${owner}"
command -v docker >/dev/null || die "docker not found"

# 1. The app must be stopped, or the copy can catch a half-written database.
running_ids="$(docker ps -q)"
if [[ -n "${running_ids}" ]]; then
    # shellcheck disable=SC2086  # one argument per container ID
    users="$(docker inspect --format '{{.Name}}{{range .Mounts}} {{.Source}}{{end}}' ${running_ids} \
        | awk -v src="${source_dir}" '{ for (i = 2; i <= NF; i++) if ($i == src) print substr($1, 2) }')"
    [[ -z "${users}" ]] || die "still mounted by running container(s): ${users//$'\n'/, }. Stop the app first (docker compose stop)."
fi

# 2. Create the volume the way Compose would, or reuse an empty one from an earlier attempt.
if docker volume inspect "${volume}" >/dev/null 2>&1; then
    labels="$(docker volume inspect --format '{{index .Labels "com.docker.compose.project"}}/{{index .Labels "com.docker.compose.volume"}}' "${volume}")"
    [[ "${labels}" == "${project}/${volume_key}" ]] \
        || die "volume ${volume} exists with other Compose labels (${labels}); not touching it"
    if [[ -n "$(docker run --rm -v "${volume}:/to:ro" "${HELPER_IMAGE}" find /to -mindepth 1 -maxdepth 1)" ]]; then
        die "volume ${volume} exists and is not empty; already migrated? Remove it by hand to start over."
    fi
    log "Reusing empty volume ${volume}"
else
    docker volume create \
        --label "com.docker.compose.project=${project}" \
        --label "com.docker.compose.volume=${volume_key}" \
        "${volume}" >/dev/null
    log "Created volume ${volume}"
fi

# 3. Copy, optionally chown, then compare what arrived with what was there.
log "Copying ${source_dir} -> ${volume}"
docker run --rm \
    -v "${source_dir}:/from:ro" \
    -v "${volume}:/to" \
    -e OWNER="${owner}" \
    "${HELPER_IMAGE}" \
    sh -euc '
        cp -a /from/. /to/
        if [ -n "${OWNER}" ]; then chown -R "${OWNER}" /to; fi
        summary() {
            cd "$1"
            find . | sort | md5sum | cut -d" " -f1
            find . -type f -exec stat -c %s {} + | awk "{ s += \$1 } END { print NR \" files, \" s+0 \" bytes\" }"
        }
        from="$(summary /from)"; to="$(summary /to)"
        echo "source: $(echo "${from}" | tail -1)"
        echo "volume: $(echo "${to}" | tail -1)"
        if [ "${from}" != "${to}" ]; then echo "MISMATCH between source and volume" >&2; exit 1; fi
        if [ -n "${OWNER}" ]; then echo "owner:  ${OWNER} (recursive)"; fi
    '

log "Done. ${source_dir} is unchanged; delete it by hand once the app runs from ${volume}."
