#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESULT_DIR="${ROOT_DIR}/benchmarking/results"
K6_SCRIPT="${ROOT_DIR}/benchmarking/k6-script.js"
mkdir -p "${RESULT_DIR}"

wait_for_http() {
    local url="$1"
    local retries=90
    until curl -sk --fail "$url" >/dev/null 2>&1; do
        sleep 2
        retries=$((retries-1))
        if [ $retries -le 0 ]; then
            echo "Timed out waiting for ${url}" >&2
            return 1
        fi
    done
}

collect_docker_stats() {
    local project="$1"
    local outfile="$2"
    local containers
    containers=$(docker compose -p "$project" ps -q)
    if [ -z "$containers" ]; then
        echo "No containers found for ${project}" >"$outfile"
        return 0
    fi
    docker stats --no-stream $containers >"$outfile"
}

run_suite() {
    local label="$1"
    local compose_file="$2"
    local project="$3"
    local host_url="$4"
    local internal_url="$5"

    COMPOSE_PROJECT_NAME="$project" docker compose -f "$compose_file" up -d --build
    wait_for_http "$host_url"

    docker run --rm \
        --network "${project}_default" \
        -e BASE_URL="$internal_url" \
        -v "${K6_SCRIPT}:/scripts/k6-script.js:ro" \
        grafana/k6 run /scripts/k6-script.js | tee "${RESULT_DIR}/${label}-k6.txt"

    collect_docker_stats "$project" "${RESULT_DIR}/${label}-docker-stats.txt"
    COMPOSE_PROJECT_NAME="$project" docker compose -f "$compose_file" down -v
}

run_suite "frankenphp" "${ROOT_DIR}/compose/docker-compose.yml" "frankenphp-exp" "http://localhost:8080" "http://openemr-frankenphp:8080"
run_suite "apache" "${ROOT_DIR}/benchmarking/docker-compose.baseline.yml" "openemr-baseline" "http://localhost:8081" "http://openemr-baseline:80"

echo "Benchmark artifacts written to ${RESULT_DIR}"
