{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # The pin is the point of this file. nixos-26.05 ships Flix 0.69.1, three minor
        # versions behind the compiler this package's manifest names and the one its
        # consumer is on. The jar is therefore pinned by URL and hash, copied from the
        # consumer's own flake, so both build the same Flix version from the same jar.
        # Not from the same store path: each flake wraps the jar in its own nixpkgs' JDK,
        # and the two lock different nixpkgs, so the paths differ while the compiler does
        # not.
        flix = pkgs.flix.overrideAttrs (old: rec {
          version = "0.79.0";
          src = pkgs.fetchurl {
            url = "https://github.com/flix/flix/releases/download/v${version}/flix.jar";
            hash = "sha256-j60qoJVnp+2rzEP0EB+mGZEx3ywikp4AHIdlnXZPbc8=";
          };
        });

        # The project is the repository root, so a command runs where it is typed and
        # there is no subdirectory to change into. No `lib/` is cached beside it either:
        # the package declares no dependency, and `packages.lock` is empty.
        mkFlixApp = name: cmd:
          pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [ flix ];
            text = cmd;
          };

        app = name: cmd: description: {
          type = "app";
          program = "${mkFlixApp name cmd}/bin/${name}";
          meta.description = description;
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [ flix ];
        };

        apps = {
          check = app "check" "flix check" "Type-check the modules and their tests";
          test = app "test" "flix test" "Run the tests";
          build = app "build" "flix build" "Compile";
          pkg = app "pkg" "flix build-pkg" "Write the .fpkg to artifact/package.fpkg, the release asset";
          doc = app "doc" "flix doc" "API documentation under build/doc";
          clean = app "clean" "flix clean" "Remove build/ and artifact/";
        };
      });
}
