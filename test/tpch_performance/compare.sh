#!/usr/bin/env bash
# Compare two engine run directories containing q<N>/timings.csv.
# Usage: test/tpch_performance/compare.sh <run1> <run2> [> comparison.txt]
# Cold = iteration 1; warm = fastest later iteration; speedup = Run A / Run B.
# Prints the summary to stdout without validation or combined CSV generation.

set -uo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <run1> <run2>" >&2
    exit 1
fi

for run in "$@"; do
    if [ ! -d "$run" ]; then
        echo "ERROR: run directory not found: $run" >&2
        exit 1
    fi
done

generate_report() {
    local run1="${1%/}"
    local run2="${2%/}"
    local QUERIES=()

    # Discover which queries are present by scanning both run directories.
    for d in "$run1"/q* "$run2"/q*; do
        [ -d "$d" ] || continue
        local qnum="${d##*/q}"
        [[ "$qnum" =~ ^[0-9]+$ ]] || continue
        QUERIES+=("$qnum")
    done

    if [ ${#QUERIES[@]} -eq 0 ]; then
        echo "ERROR: no query directories found in $run1 or $run2" >&2
        return 1
    fi

    # Deduplicate and sort numerically.
    readarray -t QUERIES < <(printf '%s\n' "${QUERIES[@]}" | sort -un)

    # Try to extract SF from the directory name (e.g. ..._sf10_2iter).
    local SF="?"
    local dir_base
    dir_base=$(basename "$(dirname "$run1")")
    if [[ "$dir_base" =~ _sf([^_]+)_ ]]; then
        SF="${BASH_REMATCH[1]}"
    fi

    # ---------- Comparison table ----------
    {
    echo ""
    echo "============================================================"
    printf "  Results Summary  (SF%s)\n" "$SF"
    echo "============================================================"
    echo ""

        declare -A AC AW BC BW

        for q in "${QUERIES[@]}"; do
            local RUN_A_TIMING="$run1/q${q}/timings.csv"
            local RUN_B_TIMING="$run2/q${q}/timings.csv"

            if [ -f "$RUN_A_TIMING" ]; then
                AC[$q]=$(awk -F',' '$1=="iter_1" && $2 != "N/A"{print $2; exit}' "$RUN_A_TIMING")
                AW[$q]=$(awk -F',' '$1~/^iter_/ && $1!="iter_1" && $2 != "N/A"{v=$2+0; if(min==""||v<min)min=v}END{if(min!="")print min}' "$RUN_A_TIMING")
            fi
            if [ -f "$RUN_B_TIMING" ]; then
                BC[$q]=$(awk -F',' '$1=="iter_1" && $2 != "N/A"{print $2; exit}' "$RUN_B_TIMING")
                BW[$q]=$(awk -F',' '$1~/^iter_/ && $1!="iter_1" && $2 != "N/A"{v=$2+0; if(min==""||v<min)min=v}END{if(min!="")print min}' "$RUN_B_TIMING")
            fi
        done

    printf "%-7s | %13s | %13s | %13s | %13s | %14s\n" \
        "Query" "Run A Cold" "Run A Warm" "Run B Cold" "Run B Warm" "Speedup (warm)"
    printf "%-7s-+-%13s-+-%13s-+-%13s-+-%13s-+-%14s\n" \
        "-------" "-------------" "-------------" "-------------" "-------------" "--------------"

        local TOTAL_AC=0 TOTAL_AW=0 TOTAL_BC=0 TOTAL_BW=0
        local HAVE_AC=0 HAVE_AW=0 HAVE_BC=0 HAVE_BW=0

    for q in "${QUERIES[@]}"; do
        local ac="${AC[$q]:-N/A}" aw="${AW[$q]:-N/A}"
        local bc="${BC[$q]:-N/A}" bw="${BW[$q]:-N/A}"

        local speedup="N/A"
        if [ "$aw" != "N/A" ] && [ "$bw" != "N/A" ]; then
            speedup=$(echo "scale=2; $aw / $bw" | bc 2>/dev/null || echo "N/A")
            [ "$speedup" != "N/A" ] && speedup="${speedup}x"
        fi

        local fmt_ac="N/A" fmt_aw="N/A" fmt_bc="N/A" fmt_bw="N/A"
        [ "$ac" != "N/A" ] && fmt_ac=$(printf "%.2fs" "$ac")
        [ "$aw" != "N/A" ] && fmt_aw=$(printf "%.2fs" "$aw")
        [ "$bc" != "N/A" ] && fmt_bc=$(printf "%.2fs" "$bc")
        [ "$bw" != "N/A" ] && fmt_bw=$(printf "%.2fs" "$bw")

        printf "%-7s | %13s | %13s | %13s | %13s | %14s\n" \
            "Q${q}" "$fmt_ac" "$fmt_aw" "$fmt_bc" "$fmt_bw" "$speedup"

            if [ "$ac" != "N/A" ]; then
                TOTAL_AC=$(echo "$TOTAL_AC + $ac" | bc)
                HAVE_AC=1
            fi
            if [ "$aw" != "N/A" ]; then
                TOTAL_AW=$(echo "$TOTAL_AW + $aw" | bc)
                HAVE_AW=1
            fi
            if [ "$bc" != "N/A" ]; then
                TOTAL_BC=$(echo "$TOTAL_BC + $bc" | bc)
                HAVE_BC=1
            fi
            if [ "$bw" != "N/A" ]; then
                TOTAL_BW=$(echo "$TOTAL_BW + $bw" | bc)
                HAVE_BW=1
            fi
        done

        local total_speedup="N/A"
        if [ "$HAVE_AW" -eq 1 ] && [ "$HAVE_BW" -eq 1 ] && [ "$(echo "$TOTAL_BW > 0" | bc)" -eq 1 ]; then
            total_speedup=$(echo "scale=2; $TOTAL_AW / $TOTAL_BW" | bc 2>/dev/null || echo "N/A")
            [ "$total_speedup" != "N/A" ] && total_speedup="${total_speedup}x"
        fi

        local fmt_total_ac="N/A" fmt_total_aw="N/A" fmt_total_bc="N/A" fmt_total_bw="N/A"
        [ "$HAVE_AC" -eq 1 ] && fmt_total_ac=$(printf '%.2fs' "$TOTAL_AC")
        [ "$HAVE_AW" -eq 1 ] && fmt_total_aw=$(printf '%.2fs' "$TOTAL_AW")
        [ "$HAVE_BC" -eq 1 ] && fmt_total_bc=$(printf '%.2fs' "$TOTAL_BC")
        [ "$HAVE_BW" -eq 1 ] && fmt_total_bw=$(printf '%.2fs' "$TOTAL_BW")

        printf "%-7s-+-%13s-+-%13s-+-%13s-+-%13s-+-%14s\n" \
            "-------" "-------------" "-------------" "-------------" "-------------" "--------------"
        printf "%-7s | %13s | %13s | %13s | %13s | %14s\n" \
            "TOTAL" "$fmt_total_ac" "$fmt_total_aw" "$fmt_total_bc" "$fmt_total_bw" "$total_speedup"
        echo ""
        echo "============================================================"
    }
}

generate_report "$1" "$2"
