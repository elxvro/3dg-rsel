from pathlib import Path
import base64
import hashlib

ROOT = Path(__file__).resolve().parents[1]
PACKED = ROOT / "assets" / "packed"
OUT = ROOT / "assets" / "models"

EXPECTED = {
    "grim_reaper_boss.glb": "5e25b66bfe675fbdc771c3030f324c644fb0ce9706d3aec9fb1f39a49080b799",
    "robot_enemy.glb": "2b5789d67e2a03b01a1a67305fc715a097d9a0b042f36308ec2278f6863dee66",
    "robot_player.glb": "bce0834ead4fd07fec8c191cef50c25e498195b73d7c66f428d864450be4a8f0",
}

OUT.mkdir(parents=True, exist_ok=True)

for name, expected_sha in EXPECTED.items():
    parts = sorted(PACKED.glob(f"{name}.part*.b64"))
    if not parts:
        raise SystemExit(f"Missing packed model: {name}")

    encoded = "".join(part.read_text(encoding="utf-8").strip() for part in parts)
    data = base64.b64decode(encoded, validate=True)
    digest = hashlib.sha256(data).hexdigest()

    if digest != expected_sha:
        raise SystemExit(
            f"Checksum mismatch for {name}: expected {expected_sha}, got {digest}"
        )

    target = OUT / name
    target.write_bytes(data)
    print(f"Unpacked {name}: {len(data)} bytes")
