{
  lib,
  dockerTools,
  buildEnv,
  writeTextFile,
  writeShellApplication,
  runCommand,
  cups,
  cups-filters,
  libcupsfilters,
  ghostscript_headless,
  linux-pam,
  bashInteractive,
  coreutils,
  gnugrep,
  gnused,
  openssl,
  # Extra driver packages, e.g. [ gutenprint hplip ]. Driverless
  # (IPP Everywhere / AirPrint) printers work without any.
  drivers ? [ ],
}:

let
  # Same trick as the NixOS module: cups' ServerBin is read-only in the store,
  # so assemble one tree with cups' own programs plus filters and drivers.
  bindir = buildEnv {
    name = "cups-progs";
    paths = [
      cups.out
      libcupsfilters
      cups-filters
      ghostscript_headless
      (runCommand "cups-https-backend" { } ''
        mkdir -p $out/lib/cups/backend
        ln -s ${cups.out}/lib/cups/backend/ipp $out/lib/cups/backend/https
      '')
    ]
    ++ drivers;
    pathsToLink = [
      "/lib"
      "/share/cups"
      "/bin"
    ];
    ignoreCollisions = true;
  };

  writeConf =
    name: text:
    writeTextFile {
      inherit name text;
      destination = "/etc/cups/${name}";
    };

  staticConf = buildEnv {
    name = "cups-static-conf";
    paths = [
      (writeConf "cupsd.conf" (builtins.readFile ./cupsd.conf))
      (writeConf "cups-files.conf" ''
        SystemGroup root lpadmin

        ServerBin ${bindir}/lib/cups
        DataDir ${bindir}/share/cups
        DocumentRoot ${cups.out}/share/doc/cups

        AccessLog stderr
        ErrorLog stderr
        PageLog stderr

        SetEnv PATH ${bindir}/lib/cups/filter:${bindir}/bin

        User cups
        Group lp
      '')
      (writeConf "client.conf" "ServerName /run/cups/cups.sock\n")
      (writeConf "snmp.conf" ''
        Address @LOCAL
      '')
    ]
    ++ drivers;
    pathsToLink = [ "/etc/cups" ];
    ignoreCollisions = true;
  };

  entrypoint = writeShellApplication {
    name = "cups-entrypoint";
    runtimeInputs = [
      bindir
      coreutils
      gnugrep
      gnused
      openssl
    ];
    text = builtins.readFile ./entrypoint.sh;
  };
in
dockerTools.buildLayeredImage {
  name = "cups";
  tag = "latest";

  contents = [
    bindir
    bashInteractive
    coreutils
    dockerTools.caCertificates
  ];

  # /etc/passwd etc. are real files (not store symlinks) so the entrypoint
  # can add the admin user at runtime.
  extraCommands = ''
    mkdir -p etc/pam.d var/lib/cups run tmp root
    chmod 1777 tmp
    ln -s /var/lib/cups etc/cups

    cat > etc/passwd <<PASSWD
    root:x:0:0:root:/root:/bin/sh
    cups:x:36:7:CUPS:/var/empty:/bin/false
    nobody:x:65534:65534:nobody:/var/empty:/bin/false
    PASSWD
    cat > etc/group <<GROUP
    root:x:0:
    lp:x:7:cups
    lpadmin:x:999:
    nogroup:x:65534:
    GROUP
    cat > etc/shadow <<SHADOW
    root:!:::::::
    cups:!:::::::
    nobody:!:::::::
    SHADOW
    chmod 600 etc/shadow

    cat > etc/pam.d/cups <<PAM
    auth    required ${linux-pam}/lib/security/pam_unix.so
    account required ${linux-pam}/lib/security/pam_unix.so
    PAM

    echo 'hosts: files dns' > etc/nsswitch.conf
  '';

  config = {
    Entrypoint = [ (lib.getExe entrypoint) ];
    Env = [
      "PATH=${bindir}/bin:${coreutils}/bin:${bashInteractive}/bin"
      "CUPS_DATADIR=${bindir}/share/cups"
      "CUPS_STATIC_CONF=${staticConf}/etc/cups"
    ];
    ExposedPorts."631/tcp" = { };
    Volumes."/var/lib/cups" = { };
  };
}
