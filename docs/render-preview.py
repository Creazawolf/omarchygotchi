#!/usr/bin/env python3
"""Render the marketing preview with the actual creature components, offline."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="tamagotchi-preview-") as directory:
    temporary = Path(directory)
    (temporary / "plugin").symlink_to(root)
    for name in ["Commons", "Ui", "services"]:
        (temporary / name).symlink_to(Path("/usr/share/omarchy/shell") / name)
    shutil.copy(root / "docs/preview.qml", temporary / "shell.qml")
    result = subprocess.run(
        ["quickshell", "--path", str(temporary / "shell.qml"), "--no-color"],
        env=dict(os.environ,
                 QT_SCALE_FACTOR="1", TAMA_PREVIEW=str(root / "preview.png")),
        text=True, capture_output=True, timeout=15,
    )
    print(result.stdout + result.stderr)
    if result.returncode or "PREVIEW_SAVED" not in result.stdout + result.stderr:
        raise SystemExit("Preview rendering failed")
