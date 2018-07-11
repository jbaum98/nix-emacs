{ lib, stdenv, emacs, emacsPackagesNg, emacsPackagesNgGen,
  runCommand, makeWrapper,
}:
let
  emacsWithPackages = (emacsPackagesNgGen emacs).emacsWithPackages;
  emacsUsePackage = emacsWithPackages (epkg: [ epkg.melpaPackages.use-package ]);

  packageNames = runCommand "package-names"
  {}
  ''
    mkdir -p $out
    cd $out
    ${emacsUsePackage}/bin/emacs --batch --load ${./extract-packages.el} --load ${~/.emacs.d/packages.el} -f output-packages
  '';

  packagesFromFile = t: file: 
    let lines = lib.filter (x: x != "") (lib.splitString "\n" (lib.readFile file));
    in map (x: t.${x}) lines;

  packages = with emacsPackagesNg; lib.flatten [
    melpaPackages.use-package
    (packagesFromFile melpaPackages       "${packageNames}/melpa")
    (packagesFromFile melpaStablePackages "${packageNames}/melpa-stable")
  ];

  isPackage = pkg: lib.isAttrs pkg && lib.any (x: x == "recipeFile") (lib.attrNames pkg);
  allDeps = pkg: lib.filter isPackage pkg.propagatedBuildInputs;
  recDeps = pkgs: pkgs ++ lib.concatMap (x: recDeps (allDeps x)) pkgs;
  deps = recDeps packages;
  depPaths = map (x: "${x}/share/emacs/site-lisp/elpa/${x.pname}-${x.version}") deps;

in stdenv.mkDerivation {
  name = (lib.appendToName "with-packages" emacs).name;

  nativeBuildInputs = [ makeWrapper ];
  inherit emacs;

  phases = [ "installPhase" ];

  siteStart = runCommand "emacs-packages-deps"
  { inherit depPaths emacs; }
  ''
    mkdir -p $out/share/emacs/site-lisp

    siteStart="$out/share/emacs/site-lisp/site-start.el"
    siteStartByteCompiled="$siteStart"c

    rm -f $siteStart $siteStartByteCompiled

    echo "(load-file \"$emacs/share/emacs/site-lisp/site-start.el\")" >> $siteStart
    for p in $depPaths; do
      echo "(add-to-list 'load-path \"$p\")" >> $siteStart
    done

    # Disable :ensure and :pin in use-package
    cat ${./disable-use-pin.el} >> $siteStart

    # Byte-compiling improves start-up time only slightly, but costs nothing.
    $emacs/bin/emacs --batch -f batch-byte-compile "$siteStart"
  '';

  installPhase = ''
    mkdir -p "$out/bin"
    # Wrap emacs and friends so they find our site-start.el before the original.
    for prog in $emacs/bin/*; do # */
      local progname=$(basename "$prog")
      rm -f "$out/bin/$progname"
      makeWrapper "$prog" "$out/bin/$progname" \
        --suffix EMACSLOADPATH ":" "$siteStart/share/emacs/site-lisp:"
    done
    # Wrap MacOS app
    # this has to pick up resources and metadata
    # to recognize it as an "app"
    if [ -d "$emacs/Applications/Emacs.app" ]; then
      mkdir -p $out/Applications/Emacs.app/Contents/MacOS
      cp -r $emacs/Applications/Emacs.app/Contents/Info.plist \
            $emacs/Applications/Emacs.app/Contents/PkgInfo \
            $emacs/Applications/Emacs.app/Contents/Resources \
            $out/Applications/Emacs.app/Contents
      makeWrapper $emacs/Applications/Emacs.app/Contents/MacOS/Emacs $out/Applications/Emacs.app/Contents/MacOS/Emacs \
        --suffix EMACSLOADPATH ":" "$siteStart/share/emacs/site-lisp:"
    fi
    mkdir -p $out/share
    # Link icons and desktop files into place
    for dir in applications icons info man; do
      ln -s $emacs/share/$dir $out/share/$dir
    done
  '';
  inherit (emacs) meta;
}
#  stdenv.mkDerivation {
#  name = "emacs-nix";
#
#  buildDeps = packages;
#
#  phases = [ "installPhase" ];
#
#  installPhase = ''
#
#  '';
#}


