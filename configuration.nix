{ config, pkgs, lib, ... }:

let
  sensitive = import ./sensitive.nix;
in {
  boot = {
    kernelPackages = pkgs.linuxKernel.packages.linux_rpi4;
    initrd.availableKernelModules = [ "xhci_pci" "usbhid" "usb_storage" ];
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };
  };
  networking = {
    hostName = sensitive.host.internal;
    wireless = {
      enable = false;
    };
    firewall = {
      allowedTCPPorts = [ 80 443 8080 8443 ]; # For home assistant & unifi
      allowedUDPPorts = [ 3478 5353 ]; # For unifi & home assistant discovery
    };
  };
  
  environment.systemPackages = with pkgs; [ vim ];
  services.openssh.enable = true;

  services.nginx.enable = true;
  services.nginx.recommendedProxySettings = true;
  services.nginx.recommendedTlsSettings = true;
  services.nginx.virtualHosts."${sensitive.host.external}" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8123";
      proxyWebsockets = true;
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = sensitive.user.acmeEmail;
  };

  users = {
    mutableUsers = false;
    users."${sensitive.user.name}" = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      hashedPassword = sensitive.user.hashedPassword;
      openssh.authorizedKeys.keys = [ sensitive.user.sshKey ];
    };
  };

  virtualisation.oci-containers = {
    backend = "podman";
    containers.homeassistant = {
      volumes = [ "home-assistant:/config" ];
      environment.TZ = "Europe/Berlin";
      image = "ghcr.io/home-assistant/home-assistant:2023.11"; 
      extraOptions = [ 
        "--network=host" 
        "--device=/dev/ttyUSB0:/dev/ttyUSB0"        
      ];
    };
    containers.unifi = {
      volumes = [ "unifi:/unifi" ];
      environment.TZ = "Europe/Berlin";
      image = "jacobalberty/unifi";
      user = "unifi";
      extraOptions = [
        "--network=host"
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

  hardware.enableRedistributableFirmware = true;
  system.stateVersion = "23.11";
}
