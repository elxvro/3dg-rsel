# Reaper Protocol

Android-first 3D arena / roguelite prototype built with Godot 4.

## Prototype v0.1.0

- Landscape mobile layout.
- Robot character supplied for this project is the player.
- Robot supplied for this project is the standard enemy.
- Grim Reaper supplied for this project is the first boss.
- Virtual joystick, **ATEŞ** and **KAÇIN** controls.
- Three enemy waves followed by the Grim Reaper encounter.
- Health, kill counter, wave HUD, projectile combat and restart flow.
- GitHub Actions Android debug APK build.

## Controls

### Android
- Left virtual stick: movement
- **ATEŞ**: fire at the nearest enemy
- **KAÇIN**: short dash with brief invulnerability

### Desktop test
- WASD: movement
- Space: fire
- Shift: dash

## 3D assets

The original uploaded GLB files are not committed to this public repository. For the first playable mobile build, lightweight proxy GLBs are generated from those exact source models, with their orientation corrected and source colors baked into vertex colors.

The proxy files are stored as Base64 build inputs under `assets/packed/`. `tools/unpack_models.py` verifies SHA-256 checksums and reconstructs the GLB files in `assets/models/` before Godot imports the project.

## Build

The `Android APK` workflow reconstructs the models, installs Godot 4.4.1 export templates, imports the project, exports `ReaperProtocol-v0.1.0.apk`, and uploads the APK as a GitHub Actions artifact.
