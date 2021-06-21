with import <nixpkgs> {} ;
pkgs.mkShell {
  buildInputs = with pkgs; [
    ponyc
    pony-corral
    stdenv
  ];
}
