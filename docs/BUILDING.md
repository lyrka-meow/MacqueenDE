# Building MacqueenDE

MacqueenDE currently targets Arch Linux for its first reproducible development
environment.

## Safety

Development builds install to `/opt/macqueen-dev` only when explicitly
requested. Configuring or compiling the project does not replace the active
KWin process. Do not run `ninja install` against `/usr`.

## Current baseline dependency

The Plasma 6.7.3 source baseline requires Plasma Wayland protocol definitions:

```bash
sudo pacman -S --needed plasma-wayland-protocols
```

This dependency is intentionally retained during the reproducibility milestone.
The protocols are inventoried in `PLASMA_INTEGRATION.md` and will later be
replaced, retained for compatibility, or moved into the versioned Macqueen
protocol set.

## Configure

```bash
cmake -S compositor -B build/compositor -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_INSTALL_PREFIX=/opt/macqueen-dev \
  -DBUILD_TESTING=OFF

cmake -S portal -B build/portal -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_INSTALL_PREFIX=/opt/macqueen-dev \
  -DBUILD_TESTING=OFF
```

The build directories are ignored by Git.

## Development sequence

1. Configure and compile the unmodified source baselines.
2. Create a nested compositor smoke-test command.
3. Add Macqueen identity without installing a system session.
4. Only after nested tests pass, add a separate display-manager session.

