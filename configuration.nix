# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:


let
  sensitive = import ./sensitive.nix;
in {
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable networking
  networking = {
    hostName = sensitive.host.internal;
    wireless = {
      enable = false;
    };
    firewall = {
      allowedTCPPorts = [ 80 443 1883 6052 8080 8096 8123 8443 9443 ]; # For home assistant, mosquitto, jellyfin, unifi, esphome
      allowedUDPPorts = [ 3478 5353 ]; # For unifi & home assistant discovery
    };
  };

  # Set your time zone.
  time.timeZone = "Europe/Brussels";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  users = {
    mutableUsers = false;
    users."${sensitive.user.name}" = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      hashedPassword = sensitive.user.hashedPassword;
      openssh.authorizedKeys.keys = sensitive.user.sshKeys;
    };

    # NEW: one dedicated system user per container, so each rootless
    # container only gets the host access it actually needs.
    #
    #  * static uid/gid  -> ids 980-984 already exist on this host;
    #    NixOS never renumbers existing entries (it only warns and
    #    keeps the old id), so the config must match /etc/passwd and
    #    /etc/group exactly. Declared ids are always skipped by the
    #    auto-allocator, which scans 999 downward. Verify 985-988 are
    #    free before the first deploy:
    #    getent passwd | awk -F: '$3 >= 985 && $3 <= 988'
    #    getent group | awk -F: '$3 >= 985 && $3 <= 988'
    #  * linger          -> the user manager starts at boot, so the
    #    rootless containers can start without a login session
    #  * autoSubUidGidRange -> allocates the /etc/subuid & /etc/subgid
    #    entries rootless podman requires
    groups = {
      homeassistant.gid = 980;
      unifi.gid = 981;
      jellyfin.gid = 982;
      pds.gid = 983;
      mosquitto.gid = 984;
      whisper.gid = 986;
      piper.gid = 987;
      esphome.gid = 988;
    };
    users = {
      homeassistant = {
        uid = 980;
        isSystemUser = true;
        group = "homeassistant";
        home = "/var/lib/homeassistant"; # rootless podman stores images & volumes here
        createHome = true;
        linger = true;
        autoSubUidGidRange = true;
        extraGroups = [ "dialout" ]; # /dev/ttyUSB0 & /dev/ttyACM0 are root:dialout 0660
      };
      unifi = {
        uid = 981;
        isSystemUser = true;
        group = "unifi";
        home = "/var/lib/unifi";
        createHome = true;
        linger = true;
        autoSubUidGidRange = true;
      };
      jellyfin = {
        uid = 982;
        isSystemUser = true;
        group = "jellyfin";
        home = "/var/lib/jellyfin";
        createHome = true;
        linger = true;
        autoSubUidGidRange = true;
        extraGroups = [ "render" ]; # /dev/dri/renderD128 (usually 0666, group as a safety net)
      };
      pds = {
        uid = 983;
        isSystemUser = true;
        group = "pds";
        home = "/var/lib/pds";
        createHome = true;
        linger = true;
        autoSubUidGidRange = true;
      };
      mosquitto = {
        uid = 984;
        isSystemUser = true;
        group = "mosquitto";
        home = "/var/lib/mosquitto";
        createHome = true;
        linger = true;
        autoSubUidGidRange = true;
      };
      whisper = {
        uid = 986;
        isSystemUser = true;
        group = "whisper";
        home = "/var/lib/whisper";
        createHome = true;
        linger = true;
        autoSubUidGidRange = true;
      };
      piper = {
        uid = 987;
        isSystemUser = true;
        group = "piper";
        home = "/var/lib/piper";
        createHome = true;
        linger = true;
        autoSubUidGidRange = true;
      };
      esphome = {
        uid = 988;
        isSystemUser = true;
        group = "esphome";
        home = "/var/lib/esphome";
        createHome = true;
        linger = true;
        autoSubUidGidRange = true;
      };
    };
  };

  fileSystems."/mnt/media" =
    { device = "/dev/disk/by-uuid/8d3c8372-19d4-4f65-8eb4-b9ff1c91e689";
      fsType = "ext4";
    };

  hardware.graphics.enable = true;
  hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
    git
  ];

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  services.dbus.implementation = "broker";

  services.nginx.enable = true;
  services.nginx.recommendedProxySettings = true;
  services.nginx.recommendedTlsSettings = true;
  services.nginx.virtualHosts."${sensitive.host.external.home}" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8123";
      proxyWebsockets = true;
    };
  };

  services.nginx.virtualHosts."${sensitive.host.external.media}" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8096";
      proxyWebsockets = true;
    };
  };

  services.nginx.virtualHosts."${sensitive.host.external.bluesky}" = {
    forceSSL = true;
    enableACME = true;
    serverAliases = [ "brecht.${sensitive.host.external.bluesky}" ];
    locations."/" = {
      proxyPass = "http://127.0.0.1:3000";
      proxyWebsockets = true;
    };
  };

  services.ddclient = {
    enable = true;
    protocol = "cloudflare";
    zone = "${sensitive.host.external.cloudflare.zone}";
    passwordFile = "/opt/cloudflare_token";
    domains = ["${sensitive.host.external.cloudflare.domain}"];
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = sensitive.user.acmeEmail;
  };

  virtualisation.oci-containers = {
    backend = "podman";
    containers.home-assistant = {
      # podman.user = "homeassistant"; # do LAST: volume migration + device tests
      # (note: NET_ADMIN/NET_RAW are namespaced/unavailable under rootless;
      # revisit whether the integrations that needed them still work)
      volumes = [ "home-assistant:/config" "/run/dbus:/run/dbus:ro" ];
      environment.TZ = "Europe/Brussels";
      image = "ghcr.io/home-assistant/home-assistant:stable"; 
      capabilities = {
        NET_ADMIN = true;
        NET_RAW = true;
      };
      extraOptions = [ 
        "--network=host" 
        "--device=/dev/ttyUSB0:/dev/ttyUSB0"
        "--device=/dev/ttyACM0:/dev/ttyACM0"
        "--stop-timeout=30"        
      ];
    };
    containers.unifi = {
      # podman.user = "unifi"; # enable after volume migration:
      # migrate "unifi" volume, then podman unshare chown -R 999:999
      volumes = [ "unifi:/unifi" ];
      environment.TZ = "Europe/Brussels";
      image = "jacobalberty/unifi";
      user = "unifi";
      extraOptions = [
        "--network=host"
        "--stop-timeout=30"
      ];
    };
    containers.jellyfin = {
      podman.user = "jellyfin"; # NEXT: enable after volume migration (see migration steps)
      volumes = [ "jellyfin-cache:/cache:Z" "jellyfin-config:/config:Z" ];
      environment.TZ = "Europe/Brussels";
      image = "docker.io/jellyfin/jellyfin:latest";
      extraOptions = [
        "--network=host"
        "--stop-timeout=30"
        # Render node access via the render group on the jellyfin user.
        "--device=/dev/dri/renderD128:/dev/dri/renderD128"
        # CHANGED: dropped relabel=private — under rootless it idmap-remaps
        # UIDs outside jellyfin's subuid range, making /mnt/media unreadable.
        # /mnt/media must be readable by the jellyfin user instead
        # (e.g. sudo chmod -R a+rX /mnt/media). Harmless while still rootful.
        "--mount=type=bind,source=/mnt/media,destination=/media,ro=true"
      ];
    };
    containers.pds = {
      podman.user = "pds"; # run rootless as the pds user
      image = "ghcr.io/bluesky-social/pds:0.4";
      volumes = [ "/opt/pds:/pds" ]; # needs: chown -R pds:pds /opt/pds
      environmentFiles = [ "/opt/pds/pds.env" ];
      # loopback only: nginx on the host is the only consumer
      ports = [ "127.0.0.1:3000:3000" ];
    };
    containers.mosquitto = {
      podman.user = "mosquitto"; # rootless — done
      image = "eclipse-mosquitto:latest";
      # The broker drops to the in-container "mosquitto" user (uid 1883),
      # so writable bind mounts need (run from /, with HOME set):
      #   sudo -u mosquitto env HOME=/var/lib/mosquitto XDG_RUNTIME_DIR=/run/user/984 \
      #     podman unshare chown -R 1883:1883 /opt/mosquitto/config /opt/mosquitto/log
      volumes = [ "/opt/mosquitto:/mosquitto" "/opt/mosquitto/data:/mosquitto/data" "/opt/mosquitto/log:/mosquitto/log" ];
      ports = [ "1883:1883" "9001:9001" ];
    };
    containers.whisper = {
      # podman.user = "whisper"; # easy: chown -R whisper:whisper /opt/whisper first
      image = "rhasspy/wyoming-whisper";
      ports = [ "10300:10300" ];
      volumes = [ "/opt/whisper:/data" ];
      cmd = [
        "--model" "tiny-int8"
        "--language" "en"
      ];
    };
    containers.piper = {
      # podman.user = "piper"; # easy: chown -R piper:piper /opt/piper first
      volumes = [ "/opt/piper:/data" ];
      ports = [ "5000:5000" "10200:10200" ];
      image = "rhasspy/wyoming-piper";
      cmd = [ 
        "--voice" "en_US-lessac-medium"
      ];
    };
    containers.esphome = {
      # podman.user = "esphome"; # chown -R esphome:esphome /opt/esphome first;
      # note: dashboard pings (ESPHOME_DASHBOARD_USE_PING) may not work
      # rootless — set it to "false" if device status shows offline
      volumes = [ "/opt/esphome:/config" ];
      ports = [ "6052:6052" ];
      image = "ghcr.io/esphome/esphome";
      environment.ESPHOME_DASHBOARD_USE_PING = "true";
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?

  system.autoUpgrade = {
    enable = true;
    allowReboot = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nix.settings.experimental-features = "nix-command";
}
