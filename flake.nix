{
  description = "Parakeet Dictation packaged for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        python = pkgs.python312;
        py = python.pkgs;

        ten-vad = py.buildPythonPackage rec {
          pname = "ten-vad";
          version = "1.0.6.8";
          format = "wheel";

          src = py.fetchPypi {
            pname = "ten_vad";
            inherit version format;
            dist = "py3";
            python = "py3";
            abi = "none";
            platform = "any";
            hash = "sha256-yIGuzXdO4p9P1HNchyZbiI5a7Tf1m9P4fqH+JqtDbu4=";
          };

          propagatedBuildInputs = [ py.numpy ];
          doCheck = false;
        };

        pythonEnv = python.withPackages (
          ps: with ps; [
            numpy
            pygobject3
            pynput
            requests
            sherpa-onnx
            sounddevice
            tqdm
            ten-vad
          ]
        );
      in
      {
        packages.default = pkgs.stdenvNoCC.mkDerivation {
          pname = "parakeet-dictation";
          version = "0.1.0";

          src = self;

          nativeBuildInputs = [
            pkgs.makeWrapper
            pkgs.wrapGAppsHook3
          ];

          buildInputs = [
            pkgs.gtk3
            pkgs.libayatana-appindicator
          ];

          dontBuild = true;
          dontWrapGApps = true;

          installPhase = ''
            runHook preInstall

            install -Dm755 dictation_app.py $out/share/parakeet-dictation/dictation_app.py
            install -Dm755 download_models.py $out/share/parakeet-dictation/download_models.py
            install -Dm644 models.json $out/share/parakeet-dictation/models.json
            install -Dm644 debian/parakeet-dictation.desktop \
              $out/share/applications/parakeet-dictation.desktop

            runHook postInstall
          '';

          preFixup = ''
            makeWrapper ${pythonEnv}/bin/python $out/bin/parakeet-dictation \
              "''${gappsWrapperArgs[@]}" \
              --add-flags "$out/share/parakeet-dictation/dictation_app.py" \
              --prefix PATH : ${
                pkgs.lib.makeBinPath [
                  pkgs.wl-clipboard
                  pkgs.wtype
                  pkgs.xdotool
                  pkgs.ydotool
                ]
              }

            makeWrapper ${pythonEnv}/bin/python $out/bin/parakeet-download-models \
              --add-flags "$out/share/parakeet-dictation/download_models.py"
          '';

          meta = {
            description = "On-device voice typing for Linux using Parakeet and NeMo ASR models";
            homepage = "https://github.com/fbettag/Parakeet-Type-Ubuntu";
            mainProgram = "parakeet-dictation";
            platforms = [ "x86_64-linux" ];
          };
        };

        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/parakeet-dictation";
        };

        devShells.default = pkgs.mkShell {
          packages = [
            pythonEnv
            pkgs.nixfmt-rfc-style
            pkgs.wl-clipboard
            pkgs.wtype
          ];
        };
      }
    );
}
