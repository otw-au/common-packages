# common-packages

Shared nix packages and container images, pinned to `nixos-26.05`.

## Images

Each attribute in `images/default.nix` becomes `packages.<system>.<name>-image`
and is built and pushed by CI to `ghcr.io/<owner>/<name>`.

```sh
nix build .#cups-image
docker load < result
```

### cups

CUPS 2.4 with cups-filters and ghostscript, so driverless (IPP Everywhere /
AirPrint) printers work out of the box. Add drivers with
`cups-image.override { drivers = [ pkgs.gutenprint ]; }`.

```sh
docker run -d -p 631:631 \
  -v cups:/var/lib/cups \
  -e CUPS_ADMIN_USER=admin -e CUPS_ADMIN_PASSWORD=change-me \
  ghcr.io/<owner>/cups
```

- `/var/lib/cups` (also `/etc/cups`) holds printers and config. Any config file
  you place there (e.g. your own `cupsd.conf`) overrides the image default.
- The admin user is created on every start and is the one allowed into `/admin`.
- USB printers: add `--device /dev/bus/usb`.

## CI

`.github/workflows/images.yml` runs on GitHub and Forgejo. It builds each image
natively per architecture, pushes `:<sha>-<system>`, then publishes a
multi-arch `:<sha>`, plus `:latest` on the default branch and `:<tag>` for `v*` tags.
Pull requests only build. See the header of the workflow for the variables and
secrets that configure it on Forgejo.
