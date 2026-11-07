"""Checks that an exported Airsoft.exe carries our icon (installer/icon.ico), not Godot's (BP7 row 102).

Run:  python3 tools/exe_icon.py build/windows/Airsoft.exe installer/icon.ico
The Windows export writes the icon into the exe's resources itself (export_presets.cfg: application/modify_resources
and application/icon; no rcedit), each of the .ico's images stored as it is. So every image of the .ico must be found,
byte for byte, in the exe. Exits 1 and says which sizes are missing otherwise. Standard library only.
"""
import struct
import sys


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
    """The sizes of the .ico's images not found in the exe."""
    return [name for name, image in ico_images(ico) if image not in exe]


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__.strip().splitlines()[2])
        return 2
    with open(argv[1], "rb") as f:
        exe = f.read()
    with open(argv[2], "rb") as f:
        ico = f.read()
    missing = missing_images(exe, ico)
    if missing:
        print("%s does not carry %s's icon: %s missing" % (argv[1], argv[2], ", ".join(missing)))
        return 1
    print("%s carries %s's icon (%d sizes)" % (argv[1], argv[2], len(ico_images(ico))))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
