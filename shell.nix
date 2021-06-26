with import <nixpkgs> {} ;
pkgs.mkShell {
  buildInputs = with pkgs; [
    jq
    stdenv
#    pkg-config
#    libzip
  ];
}
