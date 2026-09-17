#!/bin/bash

# Captures the current clipboard as a JSON entry on stdout. In watch mode,
# wl-paste invokes this with the payload on stdin and the mime as $1. Without
# arguments, it snapshots the current selection itself.

set -o pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy"
IMAGE_DIR="$STATE_DIR/clipboard-images"
mkdir -p "$IMAGE_DIR"

types=$(wl-paste --list-types 2>/dev/null || true)

if [[ ${CLIPBOARD_STATE:-} == "sensitive" ]] || grep -qx 'x-kde-passwordManagerHint' <<<"$types"; then
  exit 0
fi

MAX_IMAGE_BYTES="${CLIPBOARD_MAX_IMAGE_BYTES:-10485760}" # 10 MiB hard cap
MAX_TEXT_BYTES="${CLIPBOARD_MAX_TEXT_BYTES:-1048576}"    # 1 MiB hard ceiling

read_bounded_stream() {
  local target="$1"
  local max_bytes="$2"

  perl -e '
    my ($file, $max) = @ARGV;
    open my $fh, ">", $file or exit 1;
    binmode $fh;
    my ($total, $buf) = (0, "");
    while (my $bytes = sysread(STDIN, $buf, 65536)) {
      $total += $bytes;
      if ($total > $max) {
        close $fh;
        unlink $file;
        exit 2;
      }
      my $written = 0;
      while ($written < $bytes) {
        my $n = syswrite($fh, $buf, $bytes - $written, $written);
        if (!defined($n) || $n <= 0) {
          close $fh;
          unlink $file;
          exit 1;
        }
        $written += $n;
      }
    }
    close $fh;
    if ($total == 0) {
      unlink $file;
      exit 1;
    }
    exit 0;
  ' "$target" "$max_bytes"
}

emit_image() {
  local mime="$1"
  local ext tmp hash file bytes

  ext=${mime#image/}
  [[ $ext == jpeg ]] && ext=jpg

  tmp=$(mktemp --tmpdir="$IMAGE_DIR" clipboard.XXXXXX) || return 0
  trap 'rm -f "$tmp"' EXIT INT TERM

  if ! read_bounded_stream "$tmp" "$MAX_IMAGE_BYTES" || [[ ! -s $tmp ]]; then
    rm -f "$tmp"
    trap - EXIT INT TERM
    return 0
  fi

  bytes=$(wc -c <"$tmp" | tr -d ' ')
  hash=$(sha256sum "$tmp" | awk '{print $1}')
  file="$IMAGE_DIR/$hash.$ext"
  if [[ -e $file ]]; then
    rm -f "$tmp"
  else
    mv "$tmp" "$file"
  fi
  trap - EXIT INT TERM

  jq -cn --arg mime "$mime" --arg path "$file" --arg captured_at "$(date +'%A %H:%M')" --argjson bytes "$bytes" \
    '{type:"image", mime:$mime, path:$path, capturedAt:$captured_at, bytes:$bytes}'
}

emit_text() {
  perl -MEncode=decode,FB_CROAK,LEAVE_SRC -MJSON::PP=encode_json -e '
    my $max = $ARGV[0] || 1048576;
    my ($total, $buf, $raw) = (0, "", "");
    while (my $bytes = sysread(STDIN, $buf, 65536)) {
      $total += $bytes;
      if ($total > $max) {
        exit 0;
      }
      $raw .= $buf;
    }
    exit 0 unless length $raw;

    my $encoding;
    my $heuristic_encoding = 0;
    if ($raw =~ /^(?:\xFF\xFE|\xFE\xFF)/) {
      $encoding = "UTF-16";
    } elsif (length($raw) % 2 == 0 && index($raw, "\0") >= 0) {
      my $units = length($raw) / 2;
      my $nuls = $raw =~ tr/\0/\0/;

      # Neither byte lane can reach the padding threshold when the entire
      # payload contains fewer NULs than that, so avoid two full string passes.
      if ($nuls * 4 >= $units * 3) {
        my $even_bytes = $raw;
        $even_bytes =~ s/(.)./$1/sg;
        my $even_nuls = $even_bytes =~ tr/\0/\0/;
        undef $even_bytes;

        my $odd_bytes = $raw;
        $odd_bytes =~ s/.(.)/$1/sg;
        my $odd_nuls = $odd_bytes =~ tr/\0/\0/;

        # BOM-less UTF-16 is indistinguishable from NUL-separated bytes. Decode
        # only when at least three quarters of the code units have consistent
        # padding and fewer than one quarter have NULs in the opposite byte.
        if ($odd_nuls * 4 >= $units * 3 && $even_nuls * 4 < $units) {
          $encoding = "UTF-16LE";
          $heuristic_encoding = 1;
        } elsif ($even_nuls * 4 >= $units * 3 && $odd_nuls * 4 < $units) {
          $encoding = "UTF-16BE";
          $heuristic_encoding = 1;
        }
      }
    }

    my $text = $encoding ? eval { decode($encoding, $raw, FB_CROAK | LEAVE_SRC) } : undef;
    if ($heuristic_encoding && defined($text) && $text =~ /[\x00-\x08\x0E-\x1A\x1C-\x1F]/) {
      $text = undef;
    }
    $text = decode("UTF-8", $raw) unless defined $text;
    print "{\"type\":\"text\",\"text\":", encode_json($text), "}\n";
  ' "$MAX_TEXT_BYTES"
}

parse_bounded_uri_list() {
  perl -MJSON::PP=encode_json -e '
    my $max = $ARGV[0] || 1048576;
    my ($total, $buf, $raw) = (0, "", "");
    while (my $bytes = sysread(STDIN, $buf, 65536)) {
      $total += $bytes;
      if ($total > $max) {
        exit 2;
      }
      $raw .= $buf;
    }
    exit 1 unless length $raw;
    print "{\"type\":\"text\",\"mime\":\"text/uri-list\",\"text\":", encode_json($raw), "}\n";
    exit 0;
  ' "$MAX_TEXT_BYTES"
}

emit_uri_list() {
  local uri_json
  uri_json=$(timeout 2s wl-paste --type text/uri-list 2>/dev/null | parse_bounded_uri_list) || return 0
  if [[ -n $uri_json ]]; then
    printf '%s\n' "$uri_json"
    exit 0
  fi
}

case "${1:-}" in
text)
  if grep -qx 'text/uri-list' <<<"$types"; then
    emit_uri_list
  fi
  emit_text
  exit 0
  ;;
text/uri-list)
  parse_bounded_uri_list || exit 0
  exit 0
  ;;
image/*) emit_image "$1"; exit 0 ;;
esac

if grep -qx 'text/uri-list' <<<"$types"; then
  emit_uri_list
fi

for mime in image/png image/jpeg image/webp image/gif image/bmp image/tiff; do
  if grep -qx "$mime" <<<"$types"; then
    timeout 2s wl-paste --type "$mime" 2>/dev/null | emit_image "$mime"
    exit 0
  fi
done

if grep -q '^text/' <<<"$types" || grep -qx 'UTF8_STRING' <<<"$types" || grep -qx 'STRING' <<<"$types"; then
  timeout 2s wl-paste --type text --no-newline 2>/dev/null | emit_text
fi
