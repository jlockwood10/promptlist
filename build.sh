#!/usr/bin/env bash
# Build ffuf/gobuster-ready wordlists from the source files in ./sources/
set -euo pipefail
cd "$(dirname "$0")"

SRC=sources
OUT=.

# 1) ai-endpoints.txt — full wordlist, leading slashes stripped, deduped, sorted.
#    This is the primary list. Works with: ffuf -w ai-endpoints.txt -u https://TARGET/FUZZ
#                                          gobuster dir -w ai-endpoints.txt -u https://TARGET
cat "$SRC"/*.txt \
  | grep -v '^[[:space:]]*#' \
  | grep -v '^[[:space:]]*$' \
  | sed -E -e 's|^[[:space:]]*||' -e 's|[[:space:]]*$||' \
  | sed -E -e 's|^[-*][[:space:]]+||' \
  | sed -E -e 's|^/+||' \
  | grep -v '^$' \
  | grep -vE '^\{[^/]+\}$' \
  | grep -vE '^\*+$' \
  | grep -vE '^-+$' \
  | awk '!seen[$0]++' \
  | sort \
  > "$OUT/ai-endpoints.txt"

# 2) ai-endpoints-no-params.txt — drop everything from the first {param} onward.
#    Useful for blind path-discovery: hits the parent collection paths cleanly.
sed -E 's|/\{[^/]+\}.*$||' "$OUT/ai-endpoints.txt" \
  | sed -E 's|\{[^/]+\}.*$||' \
  | grep -v '^$' \
  | awk '!seen[$0]++' \
  | sort \
  > "$OUT/ai-endpoints-no-params.txt"

# 3) ai-segments.txt — every unique path segment (single words).
#    For fuzzing one level at a time: ffuf -w ai-segments.txt -u https://TARGET/api/FUZZ
tr '/' '\n' < "$OUT/ai-endpoints.txt" \
  | grep -v '^$' \
  | grep -v '^{' \
  | grep -v ':' \
  | awk '!seen[$0]++' \
  | sort \
  > "$OUT/ai-segments.txt"

# 4) ai-prefixes.txt — every cumulative path prefix of every endpoint.
#    `v1/chat/completions` emits `v1`, `v1/chat`, `v1/chat/completions`.
#    Catches API roots, version-only paths, and intermediate collection paths.
awk -F/ '{
  acc = ""
  for (i = 1; i <= NF; i++) {
    seg = $i
    if (seg == "") continue
    acc = (acc == "" ? seg : acc "/" seg)
    print acc
  }
}' "$OUT/ai-endpoints.txt" \
  | awk '!seen[$0]++' \
  | sort \
  > "$OUT/ai-prefixes.txt"

# 5) ai-endpoints-full.txt — main list + all prefixes, deduped. The "kitchen-sink" list.
cat "$OUT/ai-endpoints.txt" "$OUT/ai-prefixes.txt" \
  | awk '!seen[$0]++' \
  | sort \
  > "$OUT/ai-endpoints-full.txt"

# 6) ai-endpoints-with-slash.txt — main list with leading "/" preserved.
sed 's|^|/|' "$OUT/ai-endpoints.txt" > "$OUT/ai-endpoints-with-slash.txt"

# 7) ai-everything.txt — BOOM. Every full path, every prefix, every single segment.
#    The kitchen-sink-on-fire list. Maximum coverage, maximum noise.
cat "$OUT/ai-endpoints.txt" \
    "$OUT/ai-prefixes.txt" \
    "$OUT/ai-segments.txt" \
  | awk '!seen[$0]++' \
  | sort \
  > "$OUT/ai-everything.txt"

echo "Built:"
wc -l "$OUT/ai-endpoints.txt" \
      "$OUT/ai-endpoints-no-params.txt" \
      "$OUT/ai-prefixes.txt" \
      "$OUT/ai-endpoints-full.txt" \
      "$OUT/ai-segments.txt" \
      "$OUT/ai-endpoints-with-slash.txt" \
      "$OUT/ai-everything.txt"
