# Readme In progress.

TODO Demo, TODO customization, TODO install, TODO build from source

# Overview

Basic window manager, primarily used to manage single window to be pinned to
some keyboard bindings and switch between them. Also some simple stuff for
resizing, and changing position of the window.

## Build for distribution

Shown for transparency of the build step, no need to run it

```sh
# Build the application striping symbols & remove unnecessary files that expose symbols
swift build --disable-prefetching -Xswiftc -gnone -c release --scratch-path ./winpin-build && \
rm -rf ./winpin-build/arm64-apple-macosx/release/swift-version*.txt && \
rm -rf ./winpin-build/arm64-apple-macosx/release/description.json && \
rm -rf ./winpin-build/arm64-apple-macosx/release/ModuleCache && \
rm -rf ./winpin-build/arm64-apple-macosx/release/Modules && \
rm -rf ./winpin-build/arm64-apple-macosx/release/VimiumNative.build && \
rm -rf ./winpin-build/arm64-apple-macosx/release/VimiumNative.build && \
rm -rf ./winpin-build/release.yaml && \
rm -rf ./winpin-build/build.db && \
rm -rf ./winpin-build/release/*.json && \
rm -rf ./winpin-build/release/*.product && \
sh -c 'cd ./winpin-build/release && tar -czvf ../../../winpin-build.tar.gz ./WinPin' && \
rm -rf ./winpin-build
```
