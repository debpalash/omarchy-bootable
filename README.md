# Bootable for Omarchy

A small, keyboard-friendly Omarchy bar plugin for [Bootable](https://github.com/debpalash/bootable). It detects the locally installed version and launches either the desktop GUI or terminal UI without taking over any device-selection or write confirmation.

## Install

```bash
omarchy plugin add https://github.com/debpalash/omarchy-bootable.git --enable --yes
```

The USB icon appears in the right side of the Omarchy bar. Click it to open the panel. Press `G` for the GUI, `T` for the TUI, `D` for downloads, or `R` to refresh local status.

Bootable itself can be installed from the [latest stable release](https://github.com/debpalash/bootable/releases/latest).

## Update

```bash
omarchy plugin update io.github.debpalash.bootable
```

## Remove

```bash
omarchy plugin remove io.github.debpalash.bootable
```

Removal deletes only this plugin's Omarchy-managed checkout and settings. The plugin does not modify Bootable, disks, shell configuration, or system packages.

## Dependencies and permissions

- Omarchy 4 or newer with the Quickshell plugin API
- Optional: `bootable-desktop` for the GUI action and `bootable` for the TUI action
- Uses `omarchy-launch-terminal` and `omarchy-launch-browser` for user-requested launches
- Runs a bundled read-only status helper that only checks `PATH` and `bootable --version`
- Does not use `sudo`, access GitHub APIs, write removable media, or select a storage device

## Development

```bash
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" Panel.qml Service.qml
```

Licensed under MIT.
