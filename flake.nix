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
              electron = final.electron_13;
              packageJSON = final.lib.importJSON ./package.json;
            in
            final.stdenv.mkDerivation rec {
              pname = packageJSON.name;
              version = packageJSON.version;

              src = builtins.fetchurl {
                url = "https://github.com/Rabbit-Company/Passky-Desktop/releases/download/v${version}/${pname}-${version}.AppImage";
                name = "${pname}-${version}.AppImage";
              };

              appimageContents = final.appimageTools.extractType2 {
                name = "${pname}-${version}";
                inherit src;
              };

              dontUnpack = true;
              dontConfigure = true;
              dontBuild = true;

              nativeBuildInputs = [ final.makeWrapper ];

              installPhase = ''
                runHook preInstall
                mkdir -p $out/bin $out/share/${pname} $out/share/applications
                cp -a ${appimageContents}/{locales,resources} $out/share/${pname}
                cp -a ${appimageContents}/${pname}.desktop $out/share/applications/${pname}.desktop
                cp -a ${appimageContents}/usr/share/icons $out/share
                substituteInPlace $out/share/applications/${pname}.desktop \
                  --replace 'Exec=AppRun' 'Exec=${pname}'
                runHook postInstall
              '';

              postFixup = ''
                makeWrapper ${electron}/bin/electron $out/bin/${pname} \
                  --add-flags $out/share/${pname}/resources/app.asar \
                  --prefix LD_LIBRARY_PATH : "${final.lib.makeLibraryPath [ final.stdenv.cc.cc ]}"
              '';

              meta = with final.lib; {
                description = "Simple and secure password manager.";
                homepage = "https://passky.org";
                platforms = supportedSystems;
                license = licenses.gpl3;
              };
            };
        };

      defaultPackage = forAllSystems (system: (import nixpkgs {
        inherit system;
        overlays = [ self.overlay ];
      }).passky);

      checks = forAllSystems (system: {
        build = self.defaultPackage.${system};
      });

      nixosModules.passky = { pkgs, ... }: {
        nixpkgs.overlays = [ self.overlay ];
        environment.systemPackages = [ pkgs.passky ];
      };
      nixosModule = self.nixosModulesModules.passky;

      homeManagerModules.passky = { pkgs, ... }: {
        nixpkgs.overlays = [ self.overlay ];
        home.packages = [ pkgs.passky ];
      };
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
>>>>>>> bf406f2 (add modules)
      homeManagerModule = self.homeManagerModules.passky;

      devShell = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in 
        pkgs.mkShell {
          buildInputs = with pkgs; [
            nodejs-14_x
            yarn
            yarn2nix
            electron
          ];
        }
      );
    };
}
