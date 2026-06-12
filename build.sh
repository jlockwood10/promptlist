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

# 7) ai-everything.txt — paths ∪ prefixes ∪ segments, deduped.
cat "$OUT/ai-endpoints.txt" \
    "$OUT/ai-prefixes.txt" \
    "$OUT/ai-segments.txt" \
  | awk '!seen[$0]++' \
  | sort \
  > "$OUT/ai-everything.txt"

# 8) ai-megafuzz.txt — BOOM. Cross-product of common AI prefixes × every documented tail.
#    Generates combos that don't appear in any specific doc but are plausible across vendors,
#    e.g. `api/v2/chat/completions`, `openai/v1/embeddings`, `inference/v1/responses`, etc.
TAILS=/tmp/.promptlist_tails.$$
PFX=/tmp/.promptlist_prefixes.$$
trap 'rm -f "$TAILS" "$PFX"' EXIT

# Derive tails: every documented path, plus the same path with a leading version-like
# segment stripped, so cross-product doesn't double-prefix.
{
  cat "$OUT/ai-endpoints.txt"
  awk '
    {
      orig = $0
      # Strip up to two leading version-like segments.
      for (i = 0; i < 2; i++) {
        if (match($0, /^(v[0-9]+[a-z0-9]*|api|openai|inference|admin|beta|alpha|deployments)\//)) {
          $0 = substr($0, RLENGTH + 1)
        } else {
          break
        }
      }
      if ($0 != orig && $0 != "") print
    }
  ' "$OUT/ai-endpoints.txt"
} | awk 'NF && !seen[$0]++' > "$TAILS"

# Common AI/API prefix patterns observed across vendors.
cat > "$PFX" <<'PREFIXES'

v1
v2
v3
v4
v1beta
v1beta1
v1beta2
v1beta3
v2beta
v2beta1
v3beta
v1alpha
v1alpha1
v2alpha
api
api/v1
api/v2
api/v3
api/v4
api/v1beta
api/v2beta
api/v1alpha
openai
openai/v1
openai/v2
openai/deployments
inference
inference/v1
inference/v2
admin
admin/v1
admin/v2
ai
ai/v1
ai/v2
ml
ml/v1
llm
llm/v1
rest
rest/v1
internal
internal/v1
public
public/v1
private
private/v1
beta
alpha
chat
completions
PREFIXES

# Cross-product: prefix × tail (empty prefix = bare tail).
while IFS= read -r prefix; do
  if [ -z "$prefix" ]; then
    cat "$TAILS"
  else
    sed "s|^|${prefix}/|" "$TAILS"
  fi
done < "$PFX" \
  | awk 'NF && !seen[$0]++' \
  | sort \
  > "$OUT/ai-megafuzz.txt"

echo "Built:"
wc -l "$OUT/ai-endpoints.txt" \
      "$OUT/ai-endpoints-no-params.txt" \
      "$OUT/ai-prefixes.txt" \
      "$OUT/ai-endpoints-full.txt" \
      "$OUT/ai-segments.txt" \
      "$OUT/ai-endpoints-with-slash.txt" \
      "$OUT/ai-everything.txt" \
      "$OUT/ai-megafuzz.txt"
