{
  description = "Cordial — Roblox на Linux (Android x86-64 рантайм)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    cordial-src = {
      url = "git+https://github.com/luohoa97/cordial?ref=main&submodules=1";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, cordial-src }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = pkgs.lib;
      cargoToml = builtins.fromTOML (builtins.readFile "${cordial-src}/Cargo.toml");

      version = "${cargoToml.workspace.package.version}-${cordial-src.shortRev or "dirty"}";

      runtimeLibs = with pkgs; [
        vulkan-loader
        libGL
        libxkbcommon
        wayland
        alsa-lib
        libx11
        libxcursor
        libxi
        libxrandr
      ];

      cordial = (pkgs.rustPlatform.buildRustPackage.override { stdenv = pkgs.clangStdenv; }) {
        pname = "cordial";
        inherit version;
        src = cordial-src;

        cargoLock = {
          lockFile = "${cordial-src}/Cargo.lock";
          allowBuiltinFetchGit = true;
        };

        nativeBuildInputs = with pkgs; [
          pkg-config
          cmake
          makeWrapper
          rustPlatform.bindgenHook
        ];
        buildInputs = runtimeLibs ++ [ pkgs.zlib ];

        doCheck = false;

        postInstall = ''
          for f in $out/bin/*; do
            wrapProgram "$f" --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs}
          done
        '';

        meta = {
          description = "Roblox for Linux";
          homepage = "https://github.com/luohoa97/cordial";
          license = lib.licenses.gpl3Plus;
          platforms = [ system ];
          mainProgram = "cordial-load";
        };
      };
    in
    {
      packages.${system} = {
        default = cordial;
        inherit cordial;
      };

      apps.${system}.default = {
        type = "app";
        program = lib.getExe cordial;
      };

      devShells.${system}.default = (pkgs.mkShell.override { stdenv = pkgs.clangStdenv; }) {
        inputsFrom = [ cordial ];
        packages = with pkgs; [ cargo rustc clippy rustfmt rust-analyzer ];
        LD_LIBRARY_PATH = lib.makeLibraryPath runtimeLibs;
      };
    };
}
