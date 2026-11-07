extends GutTest
## BP7 (row 102): the Windows export writes our icon into Airsoft.exe itself (application/modify_resources, Godot's
## own resource writer, no rcedit), the same icon the installer and its shortcuts use; release.yml checks the exported
## exe carries it (tools/exe_icon.py). Signing stays the owner's (B10: not now).

const ICON := "res://installer/icon.ico"


func _windows_options() -> String:
	var presets := ConfigFile.new()
	assert_eq(presets.load("res://export_presets.cfg"), OK)
	for section: String in presets.get_sections():
		if str(presets.get_value(section, "platform", "")) == "Windows Desktop":
			return section + ".options"
	return ""


func test_the_windows_export_writes_our_icon_into_the_exe() -> void:
	var presets := ConfigFile.new()
	assert_eq(presets.load("res://export_presets.cfg"), OK)
	var options := _windows_options()
	assert_ne(options, "", "a Windows preset")
	assert_true(presets.get_value(options, "application/modify_resources", false), "resources written")
	assert_eq(presets.get_value(options, "application/icon", ""), ICON, "the installer's icon")
	assert_false(presets.get_value(options, "codesign/enable", true), "no signing: the owner's call (B10)")


func test_the_icon_is_a_real_ico_with_every_size_windows_draws() -> void:
	var bytes := FileAccess.get_file_as_bytes(ICON)
	assert_gt(bytes.size(), 6)
	assert_eq(bytes.decode_u16(0), 0, "reserved")
	assert_eq(bytes.decode_u16(2), 1, "an icon")
	var sizes := PackedInt32Array()
	for i in bytes.decode_u16(4):
		var w := bytes[6 + 16 * i]
		sizes.append(256 if w == 0 else w)
		var length := bytes.decode_u32(6 + 16 * i + 8)
		var offset := bytes.decode_u32(6 + 16 * i + 12)
		assert_lte(offset + length, bytes.size(), "image %d inside the file" % i)
	for want: int in [16, 32, 48, 256]:
		assert_true(sizes.has(want), "%d px" % want)
