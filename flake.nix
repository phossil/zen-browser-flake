{
  description = "Zen Browser";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      version = "1.0.0-a.31";
      downloadUrl = {
        "specific" = {
	  url = "https://github.com/zen-browser/desktop/releases/download/${version}/zen.linux-specific.tar.bz2";
	  sha256 = "sha256:114188nfijhwynrxh0mkzzy13b1w05ar82vsjzcms6iiqwp4hnjm";
	};
	"generic" = {
	  url = "https://github.com/zen-browser/desktop/releases/download/${version}/zen.linux-generic.tar.bz2";
	  sha256 = "sha256:1k548dsslm31q7rgc2nff2ly3r3ac688qxyaz5n6i1f5mf8y08y6";
	};
      };

      pkgs = import nixpkgs {
        inherit system;
      };

      runtimeLibs = with pkgs; [
        libGL libGLU libevent libffi libjpeg libpng libstartup_notification libvpx libwebp
        stdenv.cc.cc fontconfig libxkbcommon zlib freetype
        gtk3 libxml2 dbus xcb-util-cursor alsa-lib libpulseaudio pango atk cairo gdk-pixbuf glib
	udev libva mesa libnotify cups pciutils
	ffmpeg libglvnd pipewire
      ] ++ (with pkgs.xorg; [
        libxcb libX11 libXcursor libXrandr libXi libXext libXcomposite libXdamage
	libXfixes libXScrnSaver
      ]);

      mkZen = { variant }: 
        let
	  downloadData = downloadUrl."${variant}";
	in
             pkgs.stdenv.mkDerivation {
    inherit version;
		pname = "zen-browser";

		src = builtins.fetchTarball {
		  url = downloadData.url;
		  sha256 = downloadData.sha256;
		};
		
		desktopSrc = ./.;

		phases = [ "installPhase" "fixupPhase" ];

		nativeBuildInputs = [ pkgs.makeWrapper pkgs.copyDesktopItems pkgs.wrapGAppsHook ] ;

		installPhase = ''
		  mkdir -p $out/bin && mkdir -p $out/opt/zen && cp -r $src/* $out/opt/zen
		  ln -s $out/opt/zen/zen $out/bin/zen
		  install -D $desktopSrc/zen.desktop $out/share/applications/zen.desktop
		  install -D $src/browser/chrome/icons/default/default128.png $out/share/icons/hicolor/128x128/apps/zen.png
		'';

		fixupPhase = ''
		  chmod 755 $out/opt/zen/* $out/bin/zen
		  patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/opt/zen/zen
		  wrapProgram $out/opt/zen/zen --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath runtimeLibs}" \
                    --set MOZ_LEGACY_PROFILES 1 --set MOZ_ALLOW_DOWNGRADE 1 --prefix XDG_DATA_DIRS : "$GSETTINGS_SCHEMAS_PATH"
		  patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/opt/zen/zen-bin
		  wrapProgram $out/opt/zen/zen-bin --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath runtimeLibs}" \
                    --set MOZ_LEGACY_PROFILES 1 --set MOZ_ALLOW_DOWNGRADE 1 --prefix XDG_DATA_DIRS : "$GSETTINGS_SCHEMAS_PATH"
		  patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/opt/zen/glxtest
		  wrapProgram $out/opt/zen/glxtest --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath runtimeLibs}"
		  patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/opt/zen/updater
		  wrapProgram $out/opt/zen/updater --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath runtimeLibs}"
		  patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/opt/zen/vaapitest
		  wrapProgram $out/opt/zen/vaapitest --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath runtimeLibs}"
		'';

    meta.mainProgram = "zen";
	      };
    in
    {
      packages."${system}" = {
        generic = mkZen { variant = "generic"; };
        specific = mkZen { variant = "specific"; };
	default = self.packages."${system}".specific;
      };
    };
}
