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
          buildInputs = [ pkgs.perl ];

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            mkdir -p $out/share/ttmux
            cp tmux.conf init.tmux.conf options.tmux.conf bindings.tmux.conf $out/share/ttmux/
            cp -r programs $out/share/ttmux/
            cp -r scripts $out/share/ttmux/
            chmod +x $out/share/ttmux/scripts/clean-context
            chmod +x $out/share/ttmux/scripts/debug-run
            chmod +x $out/share/ttmux/scripts/colorscheme

            wrapProgram $out/share/ttmux/scripts/clean-context \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.perl ]}

            wrapProgram $out/share/ttmux/scripts/colorscheme \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.coreutils pkgs.gawk ]}

            wrapProgram $out/share/ttmux/scripts/debug-run \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.coreutils ]}

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Modular tmux configuration framework";
            platforms = platforms.all;
          };
        };
      });

      overlays.default = final: prev: {
        ttmux = self.packages.${prev.system}.default;
      };
    };
}
