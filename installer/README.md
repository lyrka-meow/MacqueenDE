# Installer

The public installer will download signed or checksummed release artifacts. It
will not build the compositor from the default branch or overwrite the active
desktop during early development.

MacqueenDE uses one permanent GitHub release tagged `rolling`. After committing
and building the current sources, maintainers replace its assets with:

```bash
./packaging/github/publish-rolling-release.sh VERSION
```

The publisher refuses to create a missing release, uploads the new archive
before deleting old assets, and moves the rolling tag to the published commit.
