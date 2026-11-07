"""Checks that an exported Airsoft.exe carries our icon (installer/icon.ico), not Godot's (BP7 row 102).

Run:  python3 tools/exe_icon.py build/windows/Airsoft.exe installer/icon.ico
The Windows export writes the icon into the exe's resources itself (export_presets.cfg: application/modify_resources
and application/icon; no rcedit), each of the .ico's images stored as it is, but only at the sizes Godot's own icon
has (EXPORT_SIZES: the release dry run of 2026-11-07 found every image but the 24x24 one). So every image of the .ico
at those sizes must be found, byte for byte, in the exe. Exits 1 and says which sizes are missing otherwise. Standard
library only.
"""
import struct
import sys

# The sizes the Windows export writes from application/icon; an .ico's other sizes (the installer's 24x24) stay out.
EXPORT_SIZES = ("16x16", "32x32", "48x48", "64x64", "128x128", "256x256")


def ico_images(data: bytes) -> list[tuple[str, bytes]]:
    """Each image of an .ico file as (its size, its bytes)."""
    reserved, kind, count = struct.unpack_from("<HHH", data, 0)
    if reserved != 0 or kind != 1 or count == 0:
        raise ValueError("not an .ico file")
    images = []
    for i in range(count):
        width, height, _colours, _zero, _planes, _bits, size, offset = struct.unpack_from("<BBBBHHII", data, 6 + 16 * i)
        if offset + size > len(data):
            raise ValueError("image %d runs past the end of the file" % i)
        images.append(("%dx%d" % (width or 256, height or 256), data[offset:offset + size]))
    return images


def missing_images(exe: bytes, ico: bytes) -> list[str]:
    """The sizes of the .ico's images that the export writes (EXPORT_SIZES) not found in the exe."""
    return [name for name, image in ico_images(ico) if name in EXPORT_SIZES and image not in exe]


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__.strip().splitlines()[2])
        return 2
    with open(argv[1], "rb") as f:
        exe = f.read()
    with open(argv[2], "rb") as f:
        ico = f.read()
    checked = [name for name, _image in ico_images(ico) if name in EXPORT_SIZES]
    if not checked:
        print("%s has none of the sizes the export writes (%s)" % (argv[2], ", ".join(EXPORT_SIZES)))
        return 1
    missing = missing_images(exe, ico)
    if missing:
        print("%s does not carry %s's icon: %s missing" % (argv[1], argv[2], ", ".join(missing)))
        return 1
    print("%s carries %s's icon (%d sizes)" % (argv[1], argv[2], len(checked)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
