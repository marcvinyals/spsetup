{ flake, ... }:

{
  pkgs,
  modulesPath,
  lib,
  ...
}:

{
  system.stateVersion = "26.05";

  nixpkgs.config = {
    allowUnfreePredicate =
      pkg:
      builtins.elem (lib.getName pkg) [
        "sublimetext4"
        "vscode"
      ];
    permittedInsecurePackages = [ "openssl-1.1.1w" ];
  };

  # basic hardware support
  imports = [ "${modulesPath}/profiles/all-hardware.nix" ];
  hardware.cpu.amd.updateMicrocode = true;
  hardware.cpu.intel.updateMicrocode = true;
  # services.xserver.videoDrivers = [
  #   "intel"
  #   "amdgpu"
  #   "nvidia"
  #   "modesetting"
  #   "fbdev"
  # ];

  # Opt out of `useradd`.
  users.mutableUsers = false;

  security.sudo = {
    wheelNeedsPassword = false;
    extraConfig = "Defaults lecture = never";
  };

  users.users = {
    root = {
      hashedPassword = "$y$j9T$0Jov5InmqMQo5doHTgyyz/$hLAqsSNrI904auuedUB58KxHEFKoK67W2F11pmoRvJ2";
    };

    team = {
      password = "team";
      isNormalUser = true;
      uid = 1000; # provide uid for determinism
    };

    admin = {
      hashedPassword = "$y$j9T$0Jov5InmqMQo5doHTgyyz/$hLAqsSNrI904auuedUB58KxHEFKoK67W2F11pmoRvJ2";
      extraGroups = [
        "wheel"
        "networkmanager"
      ];
      isNormalUser = true;
      uid = 1001;
    };
  };

  time.timeZone = "Pacific/Auckland"; # TODO: is this correct?
  # services.automatic-timezoned.enable = true;

  # Some basic good defaults:
  boot.initrd.systemd.enable = true;
  boot.tmp.useTmpfs = true;
  boot.kernelPackages = pkgs.linuxKernel.packages.linux_6_18; # latest lts
  zramSwap.enable = true;
  boot.kernelParams = [ "console=tty0" ];
  hardware.graphics.enable = true;
  services.dbus.enable = true;

  nix.enable = false;
  # nix.settings = {
  #   trusted-users = [ "@wheel" ];
  #   experimental-features = [
  #     "nix-command"
  #     "flakes"
  #   ];

  #   # auto gc when there's less than 100MiB available
  #   # freeing up to 1GiB of space.
  #   min-free = 100 * 1024 * 1024;
  #   max-free = 1024 * 1024 * 1024;
  # };

  # Networking things:
  networking.hostName = "spcp";
  networking.networkmanager.enable = true;
  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
  ];

  networking.hosts = {
    "170.64.253.143" = [ "contest.sppcontests.org" ];
    "170.64.242.1" = [ "icpc.sppcontests.org" ];
  };

  # common pain point: https://github.com/NixOS/nixpkgs/issues/180175
  systemd.services.NetworkManager-wait-online.serviceConfig.ExecStart = [
    ""
    "${pkgs.networkmanager}/bin/nm-online -q"
  ];
  systemd.network.wait-online.enable = false;

  # disable the standard nixos incoming firewall
  networking.firewall.enable = false;

  # use our own rules
  networking.nftables = {
    enable = true;
    rulesetFile = ./firewall.nft;
  };

  # desktop environment
  services.xserver.enable = true;
  services.xserver.desktopManager.xfce.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.displayManager.autoLogin = {
    enable = true;
    user = "team";
  };
  services.printing.enable = true;

  hardware.printers = {
    ensurePrinters = [
      {
        name = "FollowMe";
        location = "";
        deviceUri = "lpd://mvin559@print.auckland.ac.nz/FollowMe-BW";
        model = "drv:///sample.drv/generic.ppd";
        ppdOptions = {
          PageSize = "A4";
        };
      }
    ];
    ensureDefaultPrinter = "FollowMe";
  };

  hardware.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    audio.enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;

  # tools
  programs.firefox = {
    enable = true;
    policies = {
      # https://mozilla.github.io/policy-templates
      Homepage = {
        URL = "http://icpc.sppcontests.org";
        Locked = true;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    (writeShellApplication {
      name = "spsetup";
      runtimeInputs = [ fzy ];
      text = builtins.readFile ../../spsetup.sh;
    })

    hyperfine
    man-pages
    p7zip
    sysstat
    zip
    htop
    btop
    wget
    xarchiver

    flake.packages.${pkgs.system}.ubuntu

    neovim
    vim
    emacs
    sublime4
    vscode
    gedit
    geany
    # includes idle, lower priority so ubuntu python takes precedence
    (lib.lowPrio (pkgs.python314.withPackages (ps: [ ps.tkinter ])))
  ];

  environment.ldso = flake.packages.${pkgs.system}.ubuntu.ldso;

  services.nixseparatedebuginfod2.enable = true;

  programs.git.enable = true;
}
