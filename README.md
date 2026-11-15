# Heroku GSL Buildpack

A buildpack to install gsl on a heroku dyno.

## Installation

Use heroku multi buildpack:

https://github.com/nolman/heroku-buildpack-multi

Note: you need a variant of the buildpack multi that allows you to chain exported variables from one buildpack to the next. For now my fork will work fine (using ./export from the buildpack), in the longer term there should be a standard way to chain buildpacks together.

To set this buildpack on heroku run the following:

```
heroku config:set BUILDPACK_URL="https://github.com/nolman/heroku-buildpack-multi"
```

Then add a .buildpacks file to your app:

```
https://github.com/nolman/heroku-gsl-buildpack.git
https://github.com/heroku/heroku-buildpack-ruby.git#v119
```

You can replace the ruby buildpack with whatever you language of choice is.

## GSL version

The buildpack installs GSL 2.8, the default and the only supported version. The `GSL_VERSION` config var is optional; setting it to `2.8` is harmless, and any other value fails the build.

| Version | Release | Notes |
|---------|---------|-------|
| 2.8 (default) | [gsl-2.8](https://github.com/velopro/heroku-gsl-buildpack/releases/tag/gsl-2.8) | Built on `heroku/heroku:24-build` with `extra/build-gsl.sh`. |

`bin/compile` downloads `gsl-<version>.tar.gz` from the `gsl-<version>` release and checks it against a SHA-256 pinned in the script. An unsupported version, a missing asset or a checksum mismatch fails the build instead of deploying without GSL.

GSL 1.14 is no longer supported. The [gsl-1.14](https://github.com/velopro/heroku-gsl-buildpack/releases/tag/gsl-1.14) release is kept only as history: it was copied from the old `vp-public-dev` S3 bucket and built with prefix `/app/vendor/gsl-test`, so its `gsl-config` reports the wrong paths.

## Adding a GSL version

1. Build the tarball in the Heroku build image for your stack:

   ```
   docker run -i --user root --name gsl-build --platform linux/amd64 \
     heroku/heroku:24-build bash -c 'mkdir -p /out && bash -s 2.8 /out' < extra/build-gsl.sh
   docker cp gsl-build:/out/gsl-2.8.tar.gz .
   ```

   The script checks the GNU signature, builds with `--prefix=/app/vendor/gsl`, runs the test suites VeloPro relies on and prints the tarball's SHA-256.
2. Publish it as a release: `gh release create gsl-2.8 gsl-2.8.tar.gz --latest=false`.
3. Add the version and its SHA-256 to the `case` in `bin/compile`, and update the unsupported-version error to list it. To make it the default, also change the `GSL_VERSION` default in `bin/compile`.

Don't replace an existing release's asset. Builds pinned to the old checksum will fail; publish a new version instead.
