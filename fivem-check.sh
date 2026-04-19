#!/usr/bin/env bash
# FiveM/RedM — check online Cfx.re artifacts, output JSON.
set -euo pipefail

ARTIFACTS_URL="https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/"
BUILD_LIST_LIMIT="${BUILD_LIST_LIMIT:-50}"

# ── JSON helpers ───────────────────────────────────────────────────────────
json_str()  { local v="$1"; v="${v//\\/\\\\}"; v="${v//\"/\\\"}"; printf '"%s"' "$v"; }
json_num()  { printf '%s' "$1"; }
json_key()  { printf '"%s": ' "$1"; }

# ── Fetch artifacts page ───────────────────────────────────────────────────
ARTIFACTS_HTML=""
fetch_artifacts() {
    ARTIFACTS_HTML=$(curl -s --max-time 15 "$ARTIFACTS_URL" 2>/dev/null || echo "")
}

parse_recommended() {
    echo "$ARTIFACTS_HTML" | grep -oP 'LATEST RECOMMENDED.*?\K\d+' 2>/dev/null | head -1 || echo "0"
}

parse_all_builds() {
    echo "$ARTIFACTS_HTML" | perl -0777 -ne '
        while (m{<a[^>]*href="\./(\d+-[a-f0-9]+)/fx\.tar\.xz"[^>]*>(.*?)</a>}sg) {
            my $bh = $1;
            my $inner = $2;
            my $date = "";
            if ($inner =~ /(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})/) {
                $date = $1;
            }
            print "$bh $date\n" if $date;
        }
    ' | sort -t- -k1 -n -r -u || true
}

parse_latest() {
    parse_all_builds | head -1 || echo ""
}

parse_line_fields() {
    echo "$1" | awk '{print $1}' | cut -d- -f1    # build num
}
parse_line_hash() {
    echo "$1" | awk '{print $1}' | cut -d- -f2-   # hash
}
parse_line_date() {
    echo "$1" | awk '{print $2 " " $3}'            # date
}

# ── Build list ─────────────────────────────────────────────────────────────
get_builds() {
    local recommended total count line first=true
    recommended=$(parse_recommended)
    local builds
    builds=$(parse_all_builds)
    total=$(echo "$builds" | wc -l)

    printf '  %s [\n' "$(json_key "builds")"

    count=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        count=$((count + 1))
        [[ "$count" -gt "$BUILD_LIST_LIMIT" ]] && break

        local build_num build_hash build_date
        build_num=$(echo "$line" | awk '{print $1}' | cut -d- -f1)
        build_hash=$(echo "$line" | awk '{print $1}' | cut -d- -f2-)
        build_date=$(echo "$line" | awk '{print $2 " " $3}')

        local is_recommended="false"
        [[ "$build_num" == "$recommended" ]] && is_recommended="true"

        [[ "$first" == "true" ]] && first=false || printf ',\n'

        printf '    {"build": %s, "hash": %s, "name": %s, "date": %s, "recommended": %s}' \
            "$(json_num "$build_num")" "$(json_str "$build_hash")" "$(json_str "${build_num}-${build_hash}")" "$(json_str "$build_date")" "$is_recommended"
    done <<< "$builds"

    printf '\n  ],\n'
    printf '  %s %s\n' "$(json_key "total_builds")" "$(json_num "$total")"
}

# ── Single build entry as JSON object ───────────────────────────────────────
build_json() {
    local line="$1" is_rec="${2:-false}"
    local b h d
    b=$(parse_line_fields "$line")
    h=$(parse_line_hash "$line")
    d=$(parse_line_date "$line")
    printf '{"build": %s, "hash": %s, "name": %s, "date": %s, "recommended": %s}' \
        "$(json_num "$b")" "$(json_str "$h")" "$(json_str "${b}-${h}")" "$(json_str "$d")" "$is_rec"
}

parse_recommended_json() {
    local rec all line
    rec=$(parse_recommended)
    all=$(parse_all_builds)
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local b
        b=$(parse_line_fields "$line")
        if [[ "$b" == "$rec" ]]; then
            build_json "$line" "true"
            return
        fi
    done <<< "$all"
    echo "null"
}

parse_latest_json() {
    local line
    line=$(parse_latest)
    if [[ -n "$line" ]]; then
        build_json "$line" "false"
    else
        echo "null"
    fi
}

# ── Main ───────────────────────────────────────────────────────────────────
fetch_artifacts

cat <<JEOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "source": $(json_str "$ARTIFACTS_URL"),
  "recommended_build": $(parse_recommended_json),
  "latest_build": $(parse_latest_json),
  "available_builds": {
$(get_builds)
  }
}
JEOF
