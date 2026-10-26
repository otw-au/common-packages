# Mirrors the preStart of the NixOS cups service: /etc/cups is a symlink to
# the /var/lib/cups volume, and any static config file the user hasn't
# provided there is linked in from the image.

(umask 022 && mkdir -p /var/cache /var/lib/cups /var/spool /run/cups /tmp)
(umask 077 && mkdir -p /var/cache/cups /var/spool/cups /var/lib/cups/ssl)

shopt -s nullglob
for i in /var/lib/cups/*; do
  if [ -L "$i" ]; then rm "$i"; fi
done
for i in "$CUPS_STATIC_CONF"/*; do
  name=$(basename "$i")
  if [ ! -e "/var/lib/cups/$name" ]; then ln -s "$i" "/var/lib/cups/$name"; fi
done

if [ -n "${CUPS_ADMIN_USER:-}" ]; then
  if [ -z "${CUPS_ADMIN_PASSWORD:-}" ]; then
    echo "CUPS_ADMIN_USER is set but CUPS_ADMIN_PASSWORD is not" >&2
    exit 1
  fi
  if ! grep -q "^$CUPS_ADMIN_USER:" /etc/passwd; then
    echo "$CUPS_ADMIN_USER:x:1000:1000::/var/empty:/bin/false" >> /etc/passwd
    sed -i "s/^lpadmin:x:\([0-9]*\):.*/lpadmin:x:\1:$CUPS_ADMIN_USER/" /etc/group
  fi
  hash=$(openssl passwd -6 -stdin <<< "$CUPS_ADMIN_PASSWORD")
  sed -i "/^$CUPS_ADMIN_USER:/d" /etc/shadow
  echo "$CUPS_ADMIN_USER:$hash:::::::" >> /etc/shadow
fi

exec cupsd -f "$@"
