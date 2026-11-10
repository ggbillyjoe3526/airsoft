"""The Variable Scope (SN2, 2026-11-02; modelled from the owner's photos in BL8, 2026-11-05).

SN2's placeholder (the 2x Scope run on 3.5 cm) is gone: the scope is now the compact prism scope of the owner's
variable_scope photos, built with the other attachments by tools/blender/parts/attachments.py (build_scope_var). This
script rebuilds only it, in assets/models/replicaParts/aeg.glb, leaving the file's other parts as they are; then run
tools/blender/replicas/sniper.py, which copies the AEG's optics into the Sniper Rifle's parts file.

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3):

    python -I tools/blender/parts/variable_scope.py <repo root>
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import attachments  # noqa: E402

PART = "optic_scopeVar"


if __name__ == "__main__":
    attachments.FILES = {"aeg": [PART]}
    attachments.write("aeg")
    print("wrote aeg (now run tools/blender/replicas/sniper.py and smg.py)")
