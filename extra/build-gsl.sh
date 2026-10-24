#!/usr/bin/env bash
# Builds a GSL tarball for bin/compile. Run it inside the Heroku build image
# for the stack you deploy to, piping the script in on stdin:
#
#   docker run -i --user root --name gsl-build --platform linux/amd64 \
#     heroku/heroku:24-build bash -c 'mkdir -p /out && bash -s 2.8 /out' < extra/build-gsl.sh
#   docker cp gsl-build:/out/gsl-2.8.tar.gz .
#
# Usage: build-gsl.sh <version> <out-dir>
set -euo pipefail

VERSION=$1
OUT=$2
PREFIX=/app/vendor/gsl

mkdir -p /tmp/src && cd /tmp/src
curl -fsSLO "https://ftp.gnu.org/gnu/gsl/gsl-${VERSION}.tar.gz"
curl -fsSLO "https://ftp.gnu.org/gnu/gsl/gsl-${VERSION}.tar.gz.sig"
curl -fsSLO "https://ftp.gnu.org/gnu/gnu-keyring.gpg"

echo "== Verifying GNU signature"
gpgv --keyring ./gnu-keyring.gpg "gsl-${VERSION}.tar.gz.sig" "gsl-${VERSION}.tar.gz"
sha256sum "gsl-${VERSION}.tar.gz"

tar xzf "gsl-${VERSION}.tar.gz"
cd "gsl-${VERSION}"

echo "== Configure"
./configure --prefix="$PREFIX" > /tmp/configure.log

echo "== Build"
make -j"$(nproc)" > /tmp/make.log 2>&1

echo "== Test the parts VeloPro uses (multifit, linalg, blas, cblas, vector, matrix)"
for dir in multifit linalg blas cblas vector matrix; do
  if make -C "$dir" check > "/tmp/check-$dir.log" 2>&1; then
    echo "   $dir: $(grep -E '^# (PASS|FAIL)' "/tmp/check-$dir.log" | tr '\n' ' ')"
  else
    echo "   $dir: FAILED"; tail -30 "/tmp/check-$dir.log"; exit 1
  fi
done

echo "== Install to $PREFIX"
make install > /tmp/install.log 2>&1
"$PREFIX/bin/gsl-config" --version
"$PREFIX/bin/gsl-config" --cflags --libs

echo "== Package"
tar czf "$OUT/gsl-${VERSION}.tar.gz" -C "$PREFIX" .
cd "$OUT" && sha256sum "gsl-${VERSION}.tar.gz" | tee "gsl-${VERSION}.tar.gz.sha256"
ls -la "$OUT"
