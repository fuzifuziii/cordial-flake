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
          copyDesktopItems
        ];

        buildInputs = runtimeLibs ++ [ pkgs.zlib pkgs.glib pkgs.cairo pkgs.pango pkgs.gdk-pixbuf pkgs.gtk4 pkgs.libadwaita ]; 

        doCheck = false;

        desktopItems = [
          (pkgs.makeDesktopItem {
            name = "cordial";
            exec = "cordial-load";
            icon = "cordial";
            comment = "Roblox Client (Android x86-64 runtime)";
            desktopName = "Cordial";
            genericName = "Roblox for Linux";
            categories = [ "Game" ];
          })
        ];

        postInstall = ''
          for f in $out/bin/*; do
            wrapProgram "$f" --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs}
          done

          mkdir -p $out/share/icons/hicolor/scalable/apps
          
          if [ -f $src/assets/cordial.svg ]; then
            cp $src/assets/cordial.svg $out/share/icons/hicolor/scalable/apps/cordial.svg
          elif [ -f $src/resources/cordial.svg ]; then
            cp $src/resources/cordial.svg $out/share/icons/hicolor/scalable/apps/cordial.svg
          else
            find $src -name "*cordial*.svg" -exec cp {} $out/share/icons/hicolor/scalable/apps/cordial.svg \; -quit
          fi
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
