{
  description = "webkit_web_process_extension — Ruby bindings";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    mine.url = "github:n-at-han-k/flake.nix";
    mine.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { self, mine, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = mine.lib.${system};

        gemspecFiles = pkgs.runCommand "webkit_web_process_extension-gemspec" { } ''
          mkdir -p $out/lib/webkit_web_process_extension
          cp ${./webkit-web-process-extension.gemspec}         $out/webkit-web-process-extension.gemspec
          cp ${./lib/webkit_web_process_extension/version.rb}  $out/lib/webkit_web_process_extension/version.rb
        '';

        gems = pkgs.bundlerEnv {
          name = "webkit_web_process_extension-gems";
          ruby = pkgs.ruby_3_4;
          gemfile = ./Gemfile;
          lockfile = ./Gemfile.lock;
          gemset = import ./gemset.nix;
          extraConfigPaths = [ "${gemspecFiles}/." ];
        };

        # WebKitWebProcessExtension-6.0 declares Soup-3.0 and the GTK widget chain beneath WebKit.
        #
        # The namespaces the loader needs at require time: WebKitWebProcessExtension itself, and
        # Gio/GLib/GObject which WebKitWebProcessExtension-6.0.typelib declares as dependencies and
        # the loader resolves transitively.
        #
        # `makeSearchPath` would take each package's *first* output, and glib's
        # first output is `bin`, which carries no typelibs -- hence the explicit
        # `.out`. This is the same trap the port scaffold documents.
        typelibPath = pkgs.lib.makeSearchPath "lib/girepository-1.0"
          (map (drv: drv.out or drv) [ pkgs.webkitgtk_6_0 pkgs.libsoup_3 pkgs.gtk4 pkgs.pango pkgs.cairo pkgs.gdk-pixbuf pkgs.graphene pkgs.harfbuzz pkgs.glib ]);
      in
      {
        devShells.default = lib.mkRubyShell {
          buildInputs = with pkgs; [
            gems
            libsoup_3
            gtk4
            pango
            cairo
            gdk-pixbuf
            graphene
            harfbuzz
            gems.wrappedRuby

            # webkitgtk_6_0 itself, for its typelib. Taking it from the same
            # nixpkgs as the gobject-introspection gem is not a tidiness
            # point: a typelib built against a different glib registers GIO a
            # second time in the process and dies with
            #   cannot register existing type 'GTlsCertificate'
            webkitgtk_6_0

            skywalking-eyes
          ];

          shellHook = /* bash */ ''
            # WebKitWebProcessExtension-6.0.typelib and the typelibs it declares, which the loader
            # resolves transitively at require time. A missing one surfaces as
            # "Typelib file for namespace 'X' not found", one at a time.
            export GI_TYPELIB_PATH="${typelibPath}''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"

            export BUNDLE_GEMFILE="$PWD/Gemfile"
            export BUNDLE_FROZEN=false

            export LANG="''${LANG:-C.UTF-8}"
            export LC_ALL="''${LC_ALL:-$LANG}"

            export RUBYLIB="$PWD/lib''${RUBYLIB:+:$RUBYLIB}"
          '';
        };
      }
    );
}
