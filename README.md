# Reaper Protocol

Android-first 3D arena / roguelite prototype built with Godot 4.

## Prototype v0.1.0

- Landscape mobile layout.
- User-provided robot character as the player.
- User-provided robot model as standard enemies.
- User-provided Grim Reaper model as the first boss.
- Virtual joystick, fire button and dash button.
- Three enemy waves followed by a boss encounter.
- Health, kill counter, wave HUD, projectile combat and restart flow.
- Android APK build through GitHub Actions.

## Controls

### Android
- Left virtual stick: movement
- **ATEŞ**: fire an energy projectile at the nearest enemy
- **KAÇIN**: short invulnerable dash

### Desktop test
- WASD / arrow keys: movement
- Space: fire
- Q / Shift: dash

## Build

The `Android APK` GitHub Actions workflow exports a debug APK and uploads it as a workflow artifact.

The source 3D assets are optimized copies of the models supplied for this project (textures reduced to 1024px for the first mobile prototype).
