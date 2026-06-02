{
  description = "ttmux - modular tmux configuration framework";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        pkgs = nixpkgs.legacyPackages.${system};
      });
    in
    {
      packages = forAllSystems ({ pkgs }: {
        default = pkgs.stdenvNoCC.mkDerivation {
          pname = "ttmux";
          version = "0.1.0";

          src = pkgs.lib.fileset.toSource {
            root = ./.;
            fileset = pkgs.lib.fileset.unions [
              ./tmux.conf
              ./init.tmux.conf
              ./options.tmux.conf
              ./bindings.tmux.conf
              ./programs
              ./scripts
            ];
          };

          nativeBuildInputs = [ pkgs.makeWrapper ];

          dontBuild = true;

          installPhase = let
            # common utilities needed across platforms (especially macOS)
            coreTools = pkgs.lib.makeBinPath [
              pkgs.coreutils
              pkgs.gnused
              pkgs.gnugrep
              pkgs.gawk
              pkgs.findutils
            ];
          in ''
            runHook preInstall

            mkdir -p $out/share/ttmux
            cp tmux.conf init.tmux.conf options.tmux.conf bindings.tmux.conf $out/share/ttmux/
            cp -r programs $out/share/ttmux/
            cp -r scripts $out/share/ttmux/

            # make all scripts executable
            chmod +x $out/share/ttmux/scripts/*

            # --- wrap scripts with their runtime dependencies ---

            wrapProgram $out/share/ttmux/scripts/clean-context \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.perl ]}

            wrapProgram $out/share/ttmux/scripts/colorscheme \
              --prefix PATH : ${coreTools}

            wrapProgram $out/share/ttmux/scripts/debug-run \
              --prefix PATH : ${coreTools}

            wrapProgram $out/share/ttmux/scripts/bind-programs \
              --prefix PATH : ${coreTools}

            wrapProgram $out/share/ttmux/scripts/popup-keys \
              --prefix PATH : ${coreTools}

            wrapProgram $out/share/ttmux/scripts/copy-keys \
              --prefix PATH : ${coreTools}

            wrapProgram $out/share/ttmux/scripts/session-launch \
              --prefix PATH : ${coreTools}

            wrapProgram $out/share/ttmux/scripts/agent-popup \
              --prefix PATH : ${coreTools}

            wrapProgram $out/share/ttmux/scripts/fzf-dispatch \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.coreutils pkgs.fzf ]}

            wrapProgram $out/share/ttmux/scripts/telescope \
              --prefix PATH : ${pkgs.lib.makeBinPath [
                pkgs.coreutils pkgs.gnused pkgs.gnugrep
                pkgs.curl pkgs.w3m pkgs.jq
                pkgs.xmlstarlet pkgs.surfraw pkgs.fzf
              ]} \
              --suffix XDG_CONFIG_DIRS : "${pkgs.surfraw}/etc/xdg"

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Modular tmux configuration framework";
            platforms = platforms.unix;
          };
        };
      });

      overlays.default = final: prev: {
        ttmux = self.packages.${prev.system}.default;
      };
    };
}
