# Readme In progress.

TODO Demo

# Overview

Basic window manager, primarily used to manage single window to be pinned to
some keyboard bindings and switch between them. Also some simple stuff for
resizing, and changing position of the window.

# Getting started

## Install

```sh
# Tap formula that contains latest build
brew tap abilkhan024/tools

# Install latest build
brew install win-pin
```

## Run

```sh
# Run in the foreground
win-pin

# Run in the background, logs are written to /tmp/winpin-daemon-log
win-pin daemon

# Stop the background process
win-pin kill
```

The app needs Accessibility permission to read and move windows, grant it in
`System Settings -> Privacy & Security -> Accessibility`

## Upgrade via homebrew

```sh
brew upgrade win-pin
```

## Uninstall

If you didn't like the application you can easily uninstall it by following:

_P.S. constructive criticism is appreciated in the `Issues` section_

```sh
# Uninstall binary
brew uninstall win-pin
# Untap homebrew formula
brew untap abilkhan024/tools
```

# Options

Config file will be read from `$HOME/.config/winpin` or `$WINPIN_CONFIG_PATH`
if it's set. If the file can't be read the default config below is used.

Note that the config file replaces the default config, it's not merged with it,
so only the bindings defined in your file will be active (except
`save_windows`, which falls back to its default when not set)

Default config:

```sh
# Key bindings, format is <Mod>{key} mapping can be found in
# `Sources/WinPin/Core/Keyboard/KeyboardMapping.swift` -> `let mappingToValue`
# Modifiers: <D> - Cmd, <M> - Option, <C> - Control, <S> - Shift, <Fn> - Fn

# Workspaces, each workspace is defined by a pair of bindings with the same
# name suffix: `workspace_pin_{name}` pins the focused window to the workspace,
# `workspace_open_{name}` focuses the window pinned to it.
# Both bindings must be set for every workspace
workspace_open_j=<D><M>j
workspace_pin_j=<D><M><S>j
workspace_open_k=<D><M>k
workspace_pin_k=<D><M><S>k
workspace_open_l=<D><M>l
workspace_pin_l=<D><M><S>l
workspace_open_h=<D><M>h
workspace_pin_h=<D><M><S>h
workspace_open_u=<D><M>u
workspace_pin_u=<D><M><S>u
workspace_open_;=<D><M>;
workspace_pin_;=<D><M><S>;
workspace_open_o=<D><M>o
workspace_pin_o=<D><M><S>o
workspace_open_p=<D><M>p
workspace_pin_p=<D><M><S>p
workspace_open_y=<D><M>y
workspace_pin_y=<D><M><S>y
workspace_open_x=<D><M>x
workspace_pin_x=<D><M><S>x
workspace_open_z=<D><M>z
workspace_pin_z=<D><M><S>z

# Saves pinned windows to /tmp/winpin.json so they are restored on the next
# start of the app
save_windows=<D><M>e

# Positions, format is position_{name}=x,y,width,height
# Each value is either in pixels e.g. 200 or in percentage of the screen e.g. 50%
position_top=0,0,100%,100%
position_left_q=0,0,50%,50%
position_right_q=50%,0,50%,50%

# Transforms, format is transform_[{position},{position},...]={binding}
# Pressing the binding moves the focused window to the next position in the list,
# cycling back to the first one after the last
transform_[top,left_q,right_q]=<D><M>n
```

# Building from source

```sh
# Prerequisites:
# - Clone however you want and cd into the dir
# - Ensure that dev utils are installed so swift is available and matches
#   with Package.swift version (6.0 as of now)

# Build in release mode
swift build -c release

# Run
.build/release/WinPin
```

## Build for distribution

Shown for transparency of the build step, no need to run it

```sh
# Build the application striping symbols & remove unnecessary files that expose symbols
swift build --disable-prefetching -Xswiftc -gnone -c release --scratch-path ./winpin-build && \
rm -rf ./winpin-build/arm64-apple-macosx/release/swift-version*.txt && \
rm -rf ./winpin-build/arm64-apple-macosx/release/description.json && \
rm -rf ./winpin-build/arm64-apple-macosx/release/ModuleCache && \
rm -rf ./winpin-build/arm64-apple-macosx/release/Modules && \
rm -rf ./winpin-build/arm64-apple-macosx/release/WinPin.build && \
rm -rf ./winpin-build/release.yaml && \
rm -rf ./winpin-build/build.db && \
rm -rf ./winpin-build/release/*.json && \
rm -rf ./winpin-build/release/*.product && \
sh -c 'cd ./winpin-build/release && tar -czvf ../../../winpin-build.tar.gz ./WinPin' && \
rm -rf ./winpin-build
```
