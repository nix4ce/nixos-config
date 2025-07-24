{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ nixpkgs, home-manager, ... }:
  let
    vars = {
      stateVersion = "25.11";
      hostname = "desktop";
      admin = {
        username = "nix4ce";
        description = "Alexander Zhuravlev";
        email = "nix4ce@gmail.com";
        password = "12";
      };
    };
  in
  {
    nixosConfigurations = {
      ${vars.hostname} = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          vars = vars;
        };
        modules = [
          # configuration.nix
          ({ config, lib, pkgs, modulesPath, vars, ... }: {
            imports =
              [ (modulesPath + "/installer/scan/not-detected.nix")
              ];

            boot = {
              initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "ums_realtek" "sd_mod" ];
              kernelModules = [ "kvm-intel" ];
              loader = {
                systemd-boot.enable = true;
                efi.canTouchEfiVariables = true;
              };
            };

            fileSystems = {
              "/" = {
                device = "/dev/disk/by-label/root";
                fsType = "ext4";
              };
              "/boot" = {
                device = "/dev/disk/by-label/boot";
                fsType = "vfat";
                options = [ "fmask=0022" "dmask=0022" ];
              };
            };

            swapDevices = [ { device = "/dev/disk/by-label/swap"; }];

            nixpkgs = {
              hostPlatform = lib.mkDefault "x86_64-linux";
              config.allowUnfreePredicate = _: true;
            };

            hardware = {
              cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
              graphics = {
                enable = true;
                extraPackages = with pkgs; [
                  vpl-gpu-rt
                ];
              };
            };

            networking = {
              hostName = vars.hostname;
              networkmanager.enable = true;
            };

            time.timeZone = "Europe/Moscow";

            i18n.defaultLocale = "en_US.UTF-8";
            console = {
              earlySetup = true;
              font = "ter-c28b";
              packages = with pkgs; [ terminus_font ];
              keyMap = "ruwin_alt_sh-UTF-8";
            };

            services = {
              displayManager.gdm.enable = true;
              desktopManager.gnome.enable = true;
              gnome.core-apps.enable = false;
              xserver.xkb.layout = "us,ru";
            };

            users = {
              mutableUsers = true;
              users.${vars.admin.username} = {
                password = vars.admin.password;
                description = vars.admin.description;
                isNormalUser = true;
                extraGroups = [
                  "wheel"
                  "networkmanager"
                ];
              };
              users.root.password = "root";
            };

            environment.gnome.excludePackages = (with pkgs; [
              gnome-tour
            ]);
            # environment.systemPackages = with pkgs; [
            # ];

            nix.settings.experimental-features = [ "nix-command" "flakes" ];

            security.sudo.extraRules= [{
              users = [ vars.admin.username ];
              commands = [{
                command = "ALL" ;
                options= [ "NOPASSWD" ];
              }];
            }];

            system.stateVersion = vars.stateVersion;
          })

          # Home manager
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.${vars.admin.username} = ({ pkgs, vars, ... }: {
                home = {
                  packages = [
                    pkgs.nautilus
                    pkgs.gnome-console
                  ];
                  stateVersion = vars.stateVersion;
                };

                programs = {
                  bash = {
                    enable = true;
                  };
                  chromium = {
                    enable = true;
                    package = pkgs.google-chrome;
                  };
                  vscode = {
                    enable = true;
                    package = pkgs.vscode.fhsWithPackages (ps: with ps; [
                      python3
                      python3Packages.pip
                    ]);
                    profiles.default = {
                      extensions = with pkgs.vscode-extensions; [
                        jnoortheen.nix-ide
                        myriad-dreamin.tinymist
                        ms-vscode.cpptools
                      ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
                        {
                          name = "wokwi-vscode";
                          publisher = "Wokwi";
                          version = "2.7.0";
                          sha256 = "G3atxCowrWzxxHBLC7RmxVtRnfYfMyKGvkkRZk9VCyQ=";
                        }
                        {
                          name = "platformio-ide";
                          publisher = "platformio";
                          version = "3.3.4";
                          sha256 = "qfNz4IYjCmCMFLtAkbGTW5xnsVT8iDnFWjrgkmr2Slk=";
                        }
                        {
                          name = "commit-message-editor";
                          publisher = "adam-bender";
                          version = "0.25.0";
                          sha256 = "Vw5RkY3W4FqKvCWlscxxpGQsfm3g2bZJ5suityQ3mG8=";
                        }
                      ];
                      userSettings = {
                        "editor.wordWrap" = "on";
                        "window.customMenuBarAltFocus" = false;
                        "window.enableMenuBarMnemonics" = false;
                        "extensions.autoCheckUpdates" = false;
                        "extensions.autoUpdate" = false;
                        "update.showReleaseNotes" = false;
                        "update.mode" = "none";
                        "chat.commandCenter.enabled" = false;
                        "chat.agent.enabled" = false;
                        "telemetry.feedback.enabled" = false;
                        "telemetry.editStats.enabled" = false;
                        "workbench.startupEditor" = "none";
                      };
                    };
                  };
                  git = {
                    enable = true;
                    userName = vars.admin.description;
                    userEmail = vars.admin.email;
                    extraConfig = {
                      commit.gpgsign = true;
                      tag.gpgSign = true;
                      gpg.format = "ssh";
                      user.signingkey = "/home/${vars.admin.username}/.ssh/id_ed25519.pub";
                      init.defaultBranch = "main";
                    };
                  };
                };

                dconf = {
                  enable = true;
                  settings = {
                    "org/gnome/desktop/input-sources" = {
                      xkb-options = [ "grp:alt_shift_toggle" ];
                    };
                    "org/gnome/desktop/interface".color-scheme = "prefer-dark";
                  };
                };

              });
              extraSpecialArgs = {
                vars = vars;
              };
            };
          }
        ];
      };
    };
  };
}
