{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);

      nixpkgsFor = forAllSystems (system: import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      });
    in
    {
      overlays.default = final: prev: {
        passky-desktop = final.stdenv.mkDerivation rec {
          pname = "passky-desktop";
          version = self.lastModifiedDate;

          src = self;

          nativeBuildInputs = [ final.makeWrapper ];

          installPhase = ''
            runHook preInstall

            mkdir -p $out/share/passky
            cp -r "." "$out/share/passky/electron"

            local resolution
            for icon in $out/share/passky/electron/images/icons/icon*.png; do
              resolution=''${icon%".png"}
              resolution=''${resolution##*/icon-}
              mkdir -p "$out/share/icons/hicolor/''${resolution}/apps"
              ln -s "$icon" "$out/share/icons/hicolor/''${resolution}/apps/passky.png"
            done

            mkdir "$out/share/applications"
            ln -s ${desktopItem}/share/applications/* "$out/share/applications"
            makeWrapper ${final.electron}/bin/electron "$out/bin/passky" \
              --add-flags "$out/share/passky/electron/" \
              --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"

            runHook postInstall
          '';

          desktopItem = final.pkgs.makeDesktopItem {
            name = "Passky";
            type = "Application";
            desktopName = "passky";
            comment = "Simple, modern, open source and secure password manager.";
            icon = "passky";
            exec = "passky %U";
            categories = [ "Utility" ];
            startupWMClass = "Passky";
          };
        };
      };

      packages = forAllSystems (system: rec {
        inherit (nixpkgsFor."${system}") passky-desktop;
        default = passky-desktop;
      });

      checks = forAllSystems (system: {
        build = self.packages."${system}".default;
      });

      devShells.default = forAllSystems (system: with nixpkgsFor."${system}"; mkShell {
        packages = [
          electron
          nodejs
          yarn
        ];
      });
    };
}
