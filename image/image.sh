#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-.}"           # default: current folder
MAX_W="${MAX_W:-1920}"       # change if you want (e.g., 1280)
MAX_H="${MAX_H:-1080}"
JPG_Q="${JPG_Q:-3}"          # 2=very high quality, 4-5=smaller files
PNG_CL="${PNG_CL:-9}"        # png compression level (0-9)

# Find jpg/jpeg/png recursively (case-insensitive), handle spaces safely
find "$ROOT_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print0 |
while IFS= read -r -d '' f; do
  dir="$(dirname "$f")"
  base="$(basename "$f")"
  name="${base%.*}"
  ext="${base##*.}"
  lower_ext="$(echo "$ext" | tr '[:upper:]' '[:lower:]')"
  tmp="${dir}/.${name}.tmp.${lower_ext}"

  echo "Processing: $f"

  case "$lower_ext" in
    jpg|jpeg)
      # Re-encode JPEG: downscale if bigger, strip metadata, keep orientation applied
      ffmpeg -hide_banner -loglevel error -nostdin -y \
        -i "$f" \
        -vf "scale='min(${MAX_W},iw)':'min(${MAX_H},ih)':force_original_aspect_ratio=decrease" \
        -map_metadata -1 -an \
        -q:v "${JPG_Q}" \
        "$tmp"
      ;;
    png)
      # Re-encode PNG: downscale if bigger, strip metadata, high compression
      ffmpeg -hide_banner -loglevel error -nostdin -y \
        -i "$f" \
        -vf "scale='min(${MAX_W},iw)':'min(${MAX_H},ih)':force_original_aspect_ratio=decrease" \
        -map_metadata -1 -an \
        -compression_level "${PNG_CL}" -pred mixed \
        "$tmp"
      ;;
    *)
      echo "Skipped (unknown ext): $f"
      continue
      ;;
  esac

  # Only replace if we succeeded
  if [ -s "$tmp" ]; then
    mv -f "$tmp" "$f"
  else
    echo "❗ Failed on $f (no output)."
    rm -f "$tmp" 2>/dev/null || true
  fi
done

echo "✅ Done."

