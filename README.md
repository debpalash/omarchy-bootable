# Bootable for Omarchy

A keyboard-friendly Omarchy bar client for [Bootable](https://github.com/debpalash/bootable). Search Bootable's distribution catalog and ISO releases or choose a local image, explicitly select an eligible removable drive, review the erase plan, and follow live download/write progress without leaving the bar. The full desktop GUI and terminal UI remain one click away.

## Install

```bash
omarchy plugin add https://github.com/debpalash/omarchy-bootable.git --enable --yes
```

The Bootable icon appears in the right side of the Omarchy bar. Click it to open the panel. Press `C` to choose a local image, `S` to search the ISO catalog, `R` to refresh removable drives, `G` for the GUI, `T` for the TUI, or `A` for AI troubleshooting.

The plugin delegates its media workflow to Bootable's CLI API: `catalog --json` → `releases --json` → `download --json-progress` → `inspect --json` → `devices --json` → `plan --json` → `write --json-progress`. Distribution results stay inside a bounded scrolling list. A verified download is automatically loaded as the source image, but target selection and erase acknowledgement remain explicit.

Downloads run as a detached per-user systemd service and keep their progress under the user's XDG state directory. Closing the panel, moving it out of view, or restarting Omarchy Shell does not interrupt the transfer; reopening the panel restores the latest phase, byte count, percentage, speed, and ETA reported by Bootable. Only one managed ISO download runs at a time.

The client never auto-selects a target. Internal, read-only, and system disks are visible only as blocked entries. Writing requires Bootable to return a safe plan for the exact selected device, followed by a separate erase acknowledgement. Bootable re-discovers and validates the target again before its root-owned helper writes anything. The panel streams preparation, writing, syncing, and verification progress; closing it does not interrupt an active write.

The compact panel checks removable media as soon as it opens and always shows whether no drive is connected, how many drives are ready, or whether discovery needs to be retried. This status does not select a target.

When Bootable, its streaming client mode, or its privileged helper is missing, the create-media area asks Omarchy's configured default coding agent to install the verified official release. The AI troubleshooting row is always available for diagnosis and repair. The generated prompt tells the agent to explain system changes, ask before privileged or destructive actions, and preserve Bootable's removable-media safety gates.

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
- Bootable 0.1.4 or newer with streaming download/write client modes, the root-owned `bootable-helper`, and its Polkit policy for the complete in-panel client
- Optional: `bootable-desktop` for the full GUI action
- Uses Omarchy's portal-backed `omarchy file select` command for local image selection
- Uses `omarchy-launch-terminal` and `omarchy-launch-browser` for user-requested launches
- Uses `omarchy agent prompt` for user-requested installation or troubleshooting sessions with the configured default coding agent; the prompt forbids downgrading a compatible published RC to a stable release that lacks client mode
- Runs a bundled read-only status helper that checks `PATH`, `bootable --version`, client-mode support, and fixed helper locations
- Uses a bundled download-session helper and a transient per-user systemd service so ISO downloads survive panel and shell lifecycles; no root service or elevated download is used
- Starts a write only after the user chooses an eligible device and acknowledges Bootable's exact reviewed erase plan
- Does not use `sudo`, access GitHub APIs, auto-select storage, accept arbitrary privileged commands, or weaken fixed-disk protections

## Development

```bash
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" Panel.qml Service.qml
```

Licensed under MIT.
