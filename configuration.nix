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
      allowedTCPPorts = [ 80 443 8080 8123 8443 ]; # For home assistant & unifi
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
      openssh.authorizedKeys.keys = [ sensitive.user.sshKey ];
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
  ];

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

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

  services.nginx.virtualHosts."${sensitive.host.external.personal}" = {
    forceSSL = true;
    enableACME = true;
    globalRedirect = "www.yperman.eu";
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = sensitive.user.acmeEmail;
  };

  virtualisation.oci-containers = {
    backend = "podman";
    containers.home-assistant = {
      volumes = [ "home-assistant:/config" ];
      environment.TZ = "Europe/Berlin";
      image = "ghcr.io/home-assistant/home-assistant:stable"; 
      extraOptions = [ 
        "--network=host" 
        "--device=/dev/ttyUSB0:/dev/ttyUSB0"
        "--stop-timeout=30"        
      ];
    };
    containers.unifi = {
      volumes = [ "unifi:/unifi" ];
      environment.TZ = "Europe/Berlin";
      image = "jacobalberty/unifi";
      user = "unifi";
      extraOptions = [
        "--network=host"
        "--stop-timeout=30"
      ];
    };
  };

  systemd = {
    timers.duckdns = {
      wantedBy = [ "timers.target" ];
      partOf = [ "duckdns.service" ];
      timerConfig.OnCalendar = "hourly";
    };
    services.duckdns = {
      serviceConfig.Type = "oneshot";
      path = [
        pkgs.curl
      ];
      script = ''
        echo url="https://www.duckdns.org/update?domains=${sensitive.duckdns.domain}&token=${sensitive.duckdns.token}&ip=" | curl -k -o /tmp/duckdns.log -K -
      '';
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
}
