{
  description = "Desktop application for Passky";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      supportedSystems = [ "x86_64-linux" "i686-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems ( system: f system );
    in

    {
      overlay = final: prev: 
        {
          passky =
            let
              electron = final.electron_14;
            in
            final.pkgs.mkYarnPackage rec {
              src = self;

              packageJSON = "${src}/package.json";
              yarnLock = "${src}/yarn.lock";

              nativeBuildInputs = [ final.makeWrapper ];

              buildInputs = with final; [
                alsa-lib
                cups
                libdrm
                mesa
                nspr
                nss
                xorg.libXdamage
                xorg.libxshmfence
              ];

              yarnFlags = [
                "--offline"
                "--frozen-lockfile"
                "--ignore-scripts"
                "--production"
              ];

              installPhase = ''
                runHook preInstall

                mkdir -p $out/share/passky
                cp -r ./deps/passky $out/share/passky/deps
                cp -r ./node_modules $out/share/passky

                for icon in $out/share/passky/deps/images/logo*.png; do
                  mkdir -p "$out/share/icons/hicolor/$(basename $icon .png)/apps"
                  ln -s "$icon" "$out/share/icons/hicolor/$(basename $icon .png)/apps/passky.png"
                done

                mkdir $out/share/applications
                ls -s ${desktopItem}/share/applications $out/share/applications

                makeWrapper ${electron}/bin/electron $out/bin/passky \
                  --add-flags $out/share/passky/deps/main.js

                  runHook postInstall
              '';

              distPhase = ":";

              desktopItem = final.pkgs.makeDesktopItem {
                name = "Passky";
                comment = "Simple and secure password manager";
                genericName = "Password Manager";
                exec = "passky %U";
                icon = "passky";
                type = "Application";
                desktopName = "Passky";
                categories = "GNOME;GTK;Utility;";
              };
          };
        };

      packages = forAllSystems (system: {
        inherit (import nixpkgs {
          inherit system;
          overlays = [ self.overlay ];
        }) passky;
      });
      defaultPackage = forAllSystems (system: self.packages.${system}.passky);

      checks = forAllSystems (system: {
        build = self.defaultPackage.${system};
      });

      nixosModules.passky = { pkgs, lib, config, ... }:
        with lib;

        let
          cfg = config.programs.passky;
          browsers = [ "chrome" "brave" "vivaldi" "chromium" ];
          installChromium = pkgs.writeText "ngncpgfjhnkgfcjamgljadegplonbihi.json" ''
            {
              "external_update_url": "https://clients2.google.com/service/update2/crx"
            }
          '';
          chromiumPolicy = ''
            {
              "ExtensionInstallForcelist": [
               "ngncpgfjhnkgfcjamgljadegplonbihi;https://clients2.google.com/service/update2/crx"
              ]
            }
          '';
          firefoxPolicy = ''
            {
              "passky@passky.org": {
                "installation_mode": "force_installed",
                "install_url": "https://addons.mozilla.org/firefox/downloads/latest/passky/latest.xpi"
              }
            }
          '';
        in
        {
          options.programs.passky = {
            enable = mkEnableOption "Passky, a simple and secure password manager";

            package = mkOption {
              type = types.package;
              default = pkgs.passky;
              defaultText = "pkgs.passky";
              description = "Passky package to use.";
            };

            extension = {
              enable = mkEnableOption "the Passky browser extension";

              browsers = mkOption {
                type = types.listOf (types.enum browsers);
                default = browsers;
                example = [ "firefox" ];
              };
            };

            config = mkMerge [
                (mkIf cfg.enable {
                  nixpkgs.overlays = [ self.overlay ];
                  home.packages = [ cfg.package ];
                })

                (mkIf cfg.extension.enable {
                  environment.etc = foldl' (a: b: a // b) { } (concatMap (x:
                    with pkgs.stdenv;
                    if x == "chrome" then
                      let
                        dir = "opt/chrome";
                      in {
                        "${dir}/policies/managed/org.passky.json".text = chromiumPolicy;
                      }
                    else if x == "chromium" then
                      let
                        dir = "chromium";
                      in {
                        "${dir}/policies/managed/org.passky.json".text = chromiumPolicy;
                      }
                    else if x == "firefox" then
                      let
                        dir = "firefox";
                      in {
                        "${dir}/distribution/policies.json".text = firefoxPolicy;
                      }
                    else if x == "vivaldi" then
                      let
                        dir = "opt/vivaldi"; #TODO
                      in {
                        "${dir}/policies/managed/org.passky.json".text = chromiumPolicy;
                      }
                    else
                      throw "unknown browser ${x}") config.programs.browserpass.browsers);
                })
              ];
          };
        };
      nixosModule = self.nixosModulesModules.passky;

      homeManagerModules.passky = { pkgs, lib, config, ... }:
        with lib;

        let
          cfg = config.programs.passky;
        in
        {
          options.programs.passky = {
            enable = mkEnableOption "Passky, a simple and secure password manager";

            package = mkOption {
              type = types.package;
              default = pkgs.passky;
              defaultText = "pkgs.passky";
              description = "Passky package to use.";
            };

            extension = {
              enable = mkEnableOption "the Passky browser extension";
            };
          };

          config = mkIf cfg.enable {
            nixpkgs.overlays = [ self.overlay ];
            home.packages = [ cfg.package ];
          };
        };
      homeManagerModule = self.homeManagerModules.passky;

      devShell = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in 
        pkgs.mkShell {
          buildInputs = with pkgs; [
            nodejs
            yarn
            yarn2nix
            electron
          ];
        }
      );
    };
}
