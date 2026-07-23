# MacqueenDE

MacqueenDE is an independent Wayland desktop environment built around
**Macqueen**, a compositor derived from KWin and designed for first-class
integration with Quickshell.

The project is in its initial architecture and bootstrap phase. It is not yet
safe to install as a desktop session.

## Project goals

- Keep the mature rendering, input, display, XWayland, and effects foundations
  inherited from KWin.
- Run independently from Plasma Shell.
- Provide a documented, versioned Macqueen IPC.
- Make Quickshell a first-class shell platform through a dedicated integration
  module.
- Ship MolniyaMacqueenShell as the reference desktop shell.
- Provide native screen sharing and remote desktop through
  `xdg-desktop-portal-macqueen`.
- Package and test the complete session reproducibly on Arch Linux.

## Repository layout

```text
compositor/                 Macqueen compositor sources
ipc/                        Public protocol and client libraries
quickshell/macqueen-module/ Quickshell integration module
shell/MolniyaMacqueenShell/ Reference shell
portal/                     xdg-desktop-portal-macqueen
session/                    Session startup and service definitions
packaging/arch/             Arch Linux packaging
installer/                  Release bootstrap installers
docs/                       Architecture and development documentation
```

## Development policy

The first milestone is a reproducible, nested development session. Macqueen
must not replace the system compositor during early development. Changes are
tested nested first, then in a separate TTY/session, and only later packaged as
a system session.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and
[docs/UPSTREAM.md](docs/UPSTREAM.md). Local configuration and build
instructions are in [docs/BUILDING.md](docs/BUILDING.md).

## Start a direct development session

After building the compositor, Quickshell module, and Molniya backend, log out
of the current graphical desktop, enter a TTY, and run:

```bash
./start-macqueende
```

To add a separate `MacqueenDE` entry to SDDM:

```bash
./session/install-dev-session.sh
```

## Licensing

MacqueenDE contains components derived from upstream projects with their own
license sets and copyright notices. The license files imported with each
component are authoritative for that component. New project-level work is
licensed under GPL-3.0 unless a component requires a compatible alternative.
