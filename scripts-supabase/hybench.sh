#!/usr/bin/env bash

set -Eeuo pipefail

: "${WAREHOUSE_BENCH_REMOTE:=git@github.com:supabase/warehouse-bench.git}"
: "${WAREHOUSE_BENCH_DIR:=${HOME:?HOME must be set}/code/warehouse-bench}"
: "${HYBENCH_DGEN_SEED:=5193190799120537137}"
: "${HYBENCH_PGENV_FILE:=${HOME:?HOME must be set}/.postgres.env}"

hybench_is_installed() {
    command -v hybench-qgen >/dev/null 2>&1 &&
    command -v hybench-dgen >/dev/null 2>&1
}

hybench_pgenv_exists() {
    if [[ ! -f "$HYBENCH_PGENV_FILE" ]]; then
        printf 'hybench: Postgres environment file does not exist: %s\n' \
            "$HYBENCH_PGENV_FILE" >&2
        return 1
    fi

    if [[ ! -r "$HYBENCH_PGENV_FILE" ]]; then
        printf 'hybench: Postgres environment file is not readable: %s\n' \
            "$HYBENCH_PGENV_FILE" >&2
        return 1
    fi
}

hybench_require_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'install-hybench: required command not found: %s\n' "$command_name" >&2
        return 1
    fi
}

hybench_ensure_checkout() {
    if [[ -d "$WAREHOUSE_BENCH_DIR/.git" ]]; then
        printf 'Using existing warehouse-bench checkout at %s\n' "$WAREHOUSE_BENCH_DIR"
        return 0
    fi

    if [[ -e "$WAREHOUSE_BENCH_DIR" ]]; then
        printf 'install-hybench: %s exists but is not a Git checkout\n' \
            "$WAREHOUSE_BENCH_DIR" >&2
        return 1
    fi

    mkdir -p "$(dirname -- "$WAREHOUSE_BENCH_DIR")"
    git clone "$WAREHOUSE_BENCH_REMOTE" "$WAREHOUSE_BENCH_DIR"
}

hybench_install_from_source() {
    local source_dir="$WAREHOUSE_BENCH_DIR/rust/hybench"

    if [[ ! -d "$source_dir" ]]; then
        printf 'install-hybench: Hybench source directory not found: %s\n' "$source_dir" >&2
        return 1
    fi

    (
        cd "$source_dir"
        cargo install --path .
    )
}

hybench_install() {
    if hybench_is_installed; then
        printf 'Hybench is already installed.\n'
        return 0
    fi

    hybench_require_command git
    hybench_require_command cargo
    hybench_ensure_checkout
    hybench_install_from_source
}

hybench_generate() {
    local scaling_factor="${1:-1}"

    hybench_pgenv_exists || return

    if ! hybench_is_installed; then
        printf 'Hybench is not already installed.\n'
        printf 'Run the `install` command first.\n'
        return 1
    fi

    if (($# > 1)); then
        printf 'hybench generate: expected at most one scaling-factor argument\n' >&2
        return 2
    fi

    if [[ ! "$scaling_factor" =~ ^[0-9]+$ ]]; then
        printf 'hybench generate: scaling-factor must be an integer: %s\n' \
            "$scaling_factor" >&2
        return 2
    fi

    (
        . $HYBENCH_PGENV_FILE
        hybench-dgen \
            --seed "$HYBENCH_DGEN_SEED" \
            --scaling-factor "$scaling_factor" \
            --db-database hybench \
            --db-schema "$(printf 'sf%04d' "$((10#$scaling_factor))")"
    )
}

hybench_usage() {
    cat <<'EOF'
Usage: hybench.sh <command> [arguments]

Commands:
  install                    Install hybench when either binary is unavailable
  generate [scaling-factor]  Print the formatted scaling factor (default: 1)
EOF
}

main() {
    local command="${1:-}"

    if (($# > 0)); then
        shift
    fi

    case "$command" in
        install)
            if (($# != 0)); then
                hybench_usage >&2
                return 2
            fi
            hybench_install
            ;;
        generate)
            hybench_generate "$@"
            ;;
        -h | --help | help)
            hybench_usage
            ;;
        *)
            hybench_usage >&2
            return 2
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
