extends GutTest
## ReportScrub (SV4): no folder path, account name, machine name or address reaches a report; with injected names,
## Windows and Linux paths, either slash and any case, and inside log lines.

const WIN_SAVE := "C:/Users/Jo Bloggs/AppData/Roaming/Airsoft"
const WIN_HOME := "C:\\Users\\Jo Bloggs"
const LINUX_SAVE := "/home/zandra/.local/share/Airsoft"
const LINUX_HOME := "/home/zandra"


func _windows() -> ReportScrub:
	return ReportScrub.new(WIN_SAVE, WIN_HOME, "Jo Bloggs", "DESKTOP-7QK2ZX")


func _linux() -> ReportScrub:
	return ReportScrub.new(LINUX_SAVE, LINUX_HOME, "zandra", "zandra-laptop")


func test_windows_save_folder_either_slash_and_case() -> void:
	var s := _windows()
	assert_eq(s.line("Saved to C:/Users/Jo Bloggs/AppData/Roaming/Airsoft/settings.save"),
			"Saved to <save folder>/settings.save")
	assert_eq(s.line("c:\\users\\JO BLOGGS\\appdata\\roaming\\airsoft\\logs\\godot.log"),
			"<save folder>\\logs\\godot.log")
	assert_eq(s.line("at C:\\Users\\Jo Bloggs\\AppData/Roaming\\Airsoft"), "at <save folder>")


func test_windows_home_and_the_account_name() -> void:
	var s := _windows()
	assert_eq(s.line("Loaded C:\\Users\\Jo Bloggs\\Documents\\x.txt"), "Loaded ~\\Documents\\x.txt")
	assert_eq(s.line("Hi, I'm jo bloggs from the club"), "Hi, I'm <you> from the club")


func test_linux_paths_and_the_account_name() -> void:
	var s := _linux()
	assert_eq(s.line("ERROR: Cannot open /home/zandra/.local/share/Airsoft/run.save."),
			"ERROR: Cannot open <save folder>/run.save.")
	assert_eq(s.line("   at: _load (/home/zandra/airsoft/game/x.gd:12)"), "   at: _load (~/airsoft/game/x.gd:12)")
	assert_eq(s.line("user Zandra played"), "user <you> played")


func test_the_account_name_is_a_whole_word() -> void:
	var s := _linux()
	assert_eq(s.line("zandras and alexzandra stay"), "zandras and alexzandra stay")


func test_a_home_that_only_starts_like_another_stays() -> void:
	var s := ReportScrub.new("", "/home/jo", "jo", "")
	assert_eq(s.line("/home/joanna/x"), "/home/<you>/x", "another account's folder still goes")
	assert_eq(s.line("/home/jo/x"), "~/x")


func test_a_short_account_name_goes_only_in_paths() -> void:
	var s := ReportScrub.new("", "/home/al", "al", "")
	assert_eq(s.line("Al shot al at /home/al/x"), "Al shot al at ~/x")


func test_another_users_folder_loses_its_name() -> void:
	var s := _windows()
	assert_eq(s.line("D:\\Users\\Someone Else\\Games\\Airsoft.exe"), "D:\\Users\\<you>\\Games\\Airsoft.exe")
	assert_eq(s.line("/Users/mac.person/Library/Application Support/Airsoft"),
			"/Users/<you>/Library/Application Support/Airsoft")


func test_the_machine_name() -> void:
	assert_eq(_windows().line("Connected from desktop-7qk2zx today"), "Connected from <machine> today")
	assert_eq(_linux().line("zandra-laptop kernel: oops"), "<machine> kernel: oops")


func test_addresses() -> void:
	var s := _linux()
	assert_eq(s.line("peer 192.168.1.20:7000 and 10.0.0.1"), "peer <address>:7000 and <address>")
	assert_eq(s.line("mail me@example.co.uk now"), "mail <address> now")
	assert_eq(s.line("nic 3c:22:fb:01:aa:9e"), "nic <address>")
	assert_eq(s.line("v6 2001:0db8:85a3:0000:0000:8a2e:0370:7334 end"), "v6 <address> end")


func test_credentials_in_a_web_address_go_whole() -> void:
	var s := _linux()
	assert_eq(s.line("fetch https://user:secret@example.com/x failed"), "fetch https://<credentials>@example.com/x failed")
	assert_eq(s.line("git remote ftp://anon@files.example.org"), "git remote ftp://<credentials>@files.example.org")
	assert_eq(s.line("see https://example.com/a@b and me@example.com"), "see https://example.com/a@b and <address>")
	var whole := ReportConfig.new()
	whole.max_line_chars = 0
	var unbounded := ReportScrub.new("", "", "", "", whole)
	var t := Time.get_ticks_msec()
	var out := unbounded.line("x://" + "a".repeat(60000) + " y://u:p@h")
	assert_lt(Time.get_ticks_msec() - t, 500, "linear with no @")
	assert_true(out.ends_with(" y://<credentials>@h"))


func test_versions_ticks_and_clocks_stay() -> void:
	var s := _windows()
	for kept: String in ["Godot: 4.7.2.stable.official.ed1daf0bf", "System: Windows 11 (10.0.22631), 16 threads",
			"Graphics card: NVIDIA GeForce RTX 3070 (driver 32.0.15.6636)", "Round: 4 (live), tick 11523, 3:12 in",
			"Time: Fri 23 Oct 2026 14:32 UTC, 12:40 after start", "  [1] RendererSceneRenderRD::_render_scene",
			"SCRIPT ERROR res://game/ui/hud_feed.gd:88 (_add_row): Invalid access to key \"name\""]:
		assert_eq(s.line(kept), kept)


func test_names_with_pattern_characters_and_accents() -> void:
	var s := ReportScrub.new("", "/home/j.o+", "Jöe (x)", "")
	assert_eq(s.line("/home/j.o+/a and /home/jxo+/b"), "~/a and /home/<you>/b")
	assert_eq(s.line("JÖE (X) said"), "<you> said")


func test_inside_a_whole_report() -> void:
	var info := BugReport.ReportInfo.new()
	info.crash = true
	info.note = "my name is zandra, the save is in /home/zandra/.local/share/Airsoft"
	info.errors = PackedStringArray(["ERROR /home/zandra/airsoft/game/a.gd:3 (f): zandra-laptop said no"])
	info.log_lines = PackedStringArray(["Loading /home/zandra/.local/share/Airsoft/settings.save",
			"OpenGL from 192.168.0.4 for Zandra"])
	info.log_count = 2
	info.scrub = _linux()
	var text := BugReport.write(info)
	for gone: String in ["zandra", "Zandra", "/home", "192.168"]:
		assert_false(text.contains(gone), "%s in:\n%s" % [gone, text])
	assert_true(text.contains("Note: my name is <you>, the save is in <save folder>"), text)
	assert_true(text.contains("  Loading <save folder>/settings.save"))
	assert_true(text.contains("  ERROR ~/airsoft/game/a.gd:3 (f): <machine> said no"))


func test_this_machine_takes_out_its_own() -> void:
	var s := ReportScrub.for_this_machine()
	assert_eq(s.line(OS.get_user_data_dir() + "/logs"), "<save folder>/logs")
	var home := OS.get_environment("HOME")
	if home != "":
		assert_eq(s.line(home + "/elsewhere"), "~/elsewhere")


## QA attempt 1: an IPv4 address ending a sentence came through.
func test_an_ipv4_address_ending_a_sentence() -> void:
	var s := ReportScrub.new()
	assert_eq(s.line("My IP is 192.168.1.5."), "My IP is <address>.")
	assert_eq(s.line("server 10.0.0.1. then"), "server <address>. then")
	assert_eq(s.line("ip:8.8.8.8."), "ip:<address>.")
	assert_eq(s.line("version 1.2.3.4.5 stays"), "version 1.2.3.4.5 stays", "five numbers are no address")


## QA attempt 1: compressed IPv6 came through; every form goes whole.
func test_every_ipv6_form_goes_whole() -> void:
	var s := ReportScrub.new()
	assert_eq(s.line("my ip is 2001:db8::8a2e:370:7334"), "my ip is <address>")
	assert_eq(s.line("fe80::1ff:fe23:4567:890a"), "<address>")
	assert_eq(s.line("[2001:db8::1]:443"), "[<address>]:443")
	assert_eq(s.line("peer ::ffff:c0a8:105"), "peer <address>")
	assert_eq(s.line("peer ::ffff:1.2.3.4."), "peer <address>.")
	assert_eq(s.line("loopback ::1 and fe80::"), "loopback <address> and <address>")


func test_clocks_and_cpp_names_stay() -> void:
	var s := ReportScrub.new()
	for kept: String in ["at 12:40:05 then", "00:01:02.5", "Round: 4, 3:12 in", "Face::bad and Node3D::_ready",
			"[1] RendererSceneRenderRD::_render_scene", "t11402 Beta 2 SHOT ×4"]:
		assert_eq(s.line(kept), kept)


func test_a_onedrive_for_business_folder_hides_the_employer() -> void:
	var s := _windows()
	assert_eq(s.line("C:\\Users\\Jo Bloggs\\OneDrive - Contoso Ltd\\Documents\\a.txt"),
			"~\\OneDrive - <organisation>\\Documents\\a.txt")
	assert_eq(s.line("D:/OneDrive - Fabrikam, Inc/x"), "D:/OneDrive - <organisation>/x")


func test_a_full_machine_name_and_its_short_form() -> void:
	var s := ReportScrub.new("", "", "", "box42.corp.example.com")
	assert_eq(s.line("box42.corp.example.com said hello to box42"), "<machine> said hello to <machine>")


func test_an_email_with_the_account_name_goes_whole() -> void:
	var s := ReportScrub.new("", "", "zandra", "")
	assert_eq(s.line("write to zandra@mail.example.org"), "write to <address>")


func test_paths_keep_what_follows_them() -> void:
	var s := ReportScrub.new("", "C:\\Users\\Bob", "bob", "")
	assert_eq(s.line("[C:\\Users\\Bob]"), "[~]")
	var t := ReportScrub.new("", "/home/bob", "bob", "")
	assert_eq(t.line("at /home/bob."), "at ~.")
	assert_eq(t.line("/var/home/bob/x"), "/var/home/<you>/x", "not the tail of a longer path")
	var u := ReportScrub.new()
	assert_eq(u.line("[C:\\Users\\Bob]"), "[C:\\Users\\<you>]")
	assert_eq(u.line("in /home/ann. Then"), "in /home/<you>. Then")


## QA attempt 2: an IPv6 address after "label:" or before a colon came through.
func test_an_ipv6_address_after_a_label_or_before_a_colon() -> void:
	var s := ReportScrub.new()
	assert_eq(s.line("addr:2001:db8::1"), "addr:<address>")
	assert_eq(s.line("ip:fe80::1"), "ip:<address>")
	assert_eq(s.line("from:2001:db8::1"), "from:<address>")
	assert_eq(s.line("IPv6:2001:db8::1"), "IPv6:<address>")
	assert_eq(s.line("host:::1"), "host:<address>")
	assert_eq(s.line("connect to 2001:db8::1: refused"), "connect to <address>: refused")
	for kept: String in ["12:40:05", "res://a.gd:12:5", "Face::bad", "std::vector<int>::iterator", "Vector2::ZERO",
			"x:y", "at: _load (res://game/x.gd:12)"]:
		assert_eq(s.line(kept), kept)


func test_an_ipv6_zone_goes_with_it() -> void:
	var s := ReportScrub.new()
	assert_eq(s.line("fe80::1%eth0 up"), "<address> up")
	assert_eq(s.line("fe80::1%Ethernet 2 up"), "<address> up")
	assert_eq(s.line("[fe80::1ff:fe23:4567:890a%12]:80"), "[<address>]:80")


## QA attempt 2: a long run with no "@" was quadratic for the e-mail pattern (60,000 characters, 4.7 s).
func test_a_huge_line_is_quick_and_cut() -> void:
	var config := ReportConfig.new()
	var s := ReportScrub.new("", "/home/william", "William", "", config)
	var huge := "a".repeat(60000)
	var t := Time.get_ticks_msec()
	var out := s.line(huge)
	var whole := ReportConfig.new()
	whole.max_line_chars = 0
	var unbounded := ReportScrub.new("", "", "", "", whole)
	var all := unbounded.line(huge + " me@example.com")
	var took := Time.get_ticks_msec() - t
	gut.p("a 60,000-character line, cut and whole: %d ms" % took)
	assert_lt(took, 500)
	assert_eq(out, ReportScrub.CUT_MARK, "one word with no place to cut: only the mark")
	assert_true(all.ends_with(" <address>"), "linear even uncut")
	var name_at_cut := "x".repeat(config.max_line_chars - 4) + " William"
	assert_false(s.line(name_at_cut).contains("Will"), "scrubbed before it is cut")


const ZED_SAVE := "/home/zed/.local/share/godot/app_userdata/Airsoft"


func _zed() -> ReportScrub:
	return ReportScrub.new(ZED_SAVE, "/home/zed", "zedbo", "zedbox.corp.example")


## `token` placed so the cut at `at` falls `inside` characters into it, after filler that shrinks as it is scrubbed (the
## save folder becomes "<save folder>"), so a fragment would otherwise land well inside the kept text.
static func _straddling(token: String, inside: int, at: int) -> String:
	var filler := (ZED_SAVE + "/x ").repeat(at / ZED_SAVE.length() + 2).left(at - inside - 1) + " "
	return filler + token + " and more after it"


## QA attempt 3: a cut before the scrub left part of a name or address that no pattern matched any more.
func test_no_part_of_a_name_or_address_survives_the_cut() -> void:
	var config := ReportConfig.new()
	var at := config.max_line_chars * 2
	var cases: Array[PackedStringArray] = [
		PackedStringArray(["bob.smith@example.com", "bob.smith@"]),
		PackedStringArray(["192.168.1.55", "192.168.1."]),
		PackedStringArray(["2001:db8:85a3::8a2e:370:7334", "2001:db8:85a3:"]),
		PackedStringArray(["zedbo", "zedb"]),
		PackedStringArray(["zedbox.corp.example", "zedbox.corp.ex"]),
		PackedStringArray(["aa:bb:cc:dd:ee:ff", "aa:bb:cc:dd:ee"]),
	]
	for c in cases:
		var text := _straddling(c[0], c[1].length(), at)
		assert_eq(text.substr(at - c[1].length(), c[1].length()), c[1], "the cut falls inside %s" % c[0])
		var out := _zed().line(text)
		assert_false(out.contains(c[1]), "%s left: …%s" % [c[1], out.right(30)])
		assert_false(out.contains(c[1].left(c[1].length() - 1)), "nor less of it")
		assert_lte(out.length(), config.max_line_chars)


func test_the_note_cut_leaves_no_part_either() -> void:
	var info := BugReport.ReportInfo.new()
	info.note_chars = 500
	info.scrub = _zed()
	for token: String in ["bob.smith@example.com", "192.168.1.55", "zedbo"]:
		info.note = "y ".repeat(600).left(info.note_chars * BugReport.SCRUB_MARGIN - 4) + " " + token
		var text := BugReport.write(info)
		assert_false(text.contains(token.left(4)), "report: " + token)
		var link := IssueLink.make(info, ReportConfig.new())
		assert_false(link.url.uri_decode().contains(token.left(4)), "issue: " + token)


func test_cut_whole() -> void:
	assert_eq(ReportScrub.cut_whole("short", 10), "short")
	assert_eq(ReportScrub.cut_whole("one two three", 10), "one two…")
	assert_eq(ReportScrub.cut_whole("see (a.b@c.d) x", 10), "see …")
	assert_eq(ReportScrub.cut_whole("k=v;path=/home/zed/x", 15), "k=v;path…", "never back to a slash")
	assert_eq(ReportScrub.cut_whole("10.0.0.1:80/x/y", 8), "…", "one word: just the mark")
	assert_lte(ReportScrub.cut_whole("a b c d e f g", 6).length(), 6)


## QA attempt 3: a MAC address after a label came through.
func test_a_mac_address_after_a_label() -> void:
	var s := _zed()
	assert_eq(s.line("mac:aa:bb:cc:dd:ee:ff"), "mac:<address>")
	assert_eq(s.line("hw:aa-bb-cc-dd-ee-ff"), "hw:<address>")
	assert_eq(s.line("ab:aa:bb:cc:dd:ee:ff"), "ab:<address>", "a hex label")
	assert_eq(s.line("fade:aa:bb:cc:dd:ee:ff"), "fade:<address>")
	assert_eq(s.line("aa:bb:cc:dd:ee:ff: link up"), "<address>: link up")
	assert_eq(s.line("12:40:05"), "12:40:05")


## QA attempt 3: the IPv6 pattern was quadratic on a long run of hex and colons. Every pattern runs in one pass: 60,000
## characters of each run, capped and uncapped, well under the bound (generous for CI).
func test_every_pattern_is_linear() -> void:
	var whole := ReportConfig.new()
	whole.max_line_chars = 0
	var scrubs: Array[ReportScrub] = [_zed(), ReportScrub.new(ZED_SAVE, "/home/zed", "zedbo", "zedbox.corp.example", whole)]
	var runs := PackedStringArray(["a:", "ff:", "aa:bb:", "1:", "1::", "12:34:", "\\", "/", "a.", "1.", "a-", "/home/"])
	var worst := 0.0
	var worst_run := ""
	for run in runs:
		var text := run.repeat(60000 / run.length())
		for i in scrubs.size():
			var t := Time.get_ticks_usec()
			scrubs[i].line(text)
			var ms := (Time.get_ticks_usec() - t) / 1000.0
			assert_lt(ms, 100.0, "%s × %d, %s: %.1f ms" % [run, text.length() / run.length(), ["capped", "whole"][i], ms])
			if ms > worst:
				worst = ms
				worst_run = "%s (%s)" % [run, ["capped", "whole"][i]]
	gut.p("60,000 characters, the slowest run: %s %.1f ms" % [worst_run, worst])


## BP6: an IPv6 address of hex letters only goes; a C++ name (a capital, then a small letter) stays.
func test_a_hex_letter_ipv6_address_goes_and_cpp_names_stay() -> void:
	var s := ReportScrub.new()
	assert_eq(s.line("peer dead::beef up"), "peer <address> up")
	assert_eq(s.line("DEAD::BEEF"), "<address>")
	assert_eq(s.line("fdab:cdef::face"), "<address>")
	assert_eq(s.line("ip:cafe::"), "ip:<address>")
	assert_eq(s.line("fade::1"), "<address>", "written small, an address")
	for kept: String in ["Face::bad", "Fade::1", "Vec3::ab", "Bad::add_child", "Node3D::_ready"]:
		assert_eq(s.line(kept), kept)


## BP6: a version and the card's driver as the report writes them aren't addresses; an address still is.
func test_a_version_and_the_driver_stay() -> void:
	var s := ReportScrub.new()
	for kept: String in ["v1.2.3.4", "build V10.0.0.1 ok", "Graphics card: Some GPU (driver 10.0.0.1)"]:
		assert_eq(s.line(kept), kept)
	assert_eq(s.line("driver at 10.0.0.1"), "driver at <address>")
	assert_eq(s.line("dev1.2.3.4"), "dev<address>", "a v inside a word is no version mark")


## BP6: an account named with an ordinary word leaves that word in the report; its folders still go.
func test_a_common_word_account_goes_from_paths_only() -> void:
	var s := ReportScrub.new("/home/player/.local/share/Airsoft", "/home/player", "Player", "desktop")
	assert_eq(s.line("the player shot the desktop test"), "the player shot the desktop test")
	assert_eq(s.line("/home/player/x and C:\\Users\\Player\\y"), "~/x and C:\\Users\\<you>\\y")
	assert_eq(s.line("/home/player/.local/share/Airsoft/a.save"), "<save folder>/a.save")
	assert_eq(ReportScrub.new("", "", "zandra", "").line("zandra"), "<you>", "a name still goes")


## BP6: a user folder's spaced name stops where an account name can't go on, so the sentence after it stays.
func test_a_sentence_after_a_user_folder_stays() -> void:
	var s := ReportScrub.new()
	assert_eq(s.line("in C:\\Users\\Bob, see a/b"), "in C:\\Users\\<you>, see a/b")
	assert_eq(s.line("C:\\Users\\Bob and then a sentence well over forty-eight characters long / x"),
			"C:\\Users\\<you> and then a sentence well over forty-eight characters long / x")
	assert_eq(s.line("C:\\Users\\Jo Bloggs\\x"), "C:\\Users\\<you>\\x")
	assert_eq(s.line("C:\\Users\\Jo Bloggs.CONTOSO.000\\x"), "C:\\Users\\<you>\\x")


## BP6: a cut at the space inside "Jo Bloggs" leaves no "Jo", in a line and in the note.
func test_a_cut_inside_a_spaced_name_leaves_no_first_word() -> void:
	var config := ReportConfig.new()
	var s := ReportScrub.new(ZED_SAVE, "/home/zed", "Jo Bloggs", "")
	var text := _straddling("Jo Bloggs", 3, config.max_line_chars * 2)
	assert_eq(text.substr(config.max_line_chars * 2 - 3, 3), "Jo ", "the cut falls at the name's space")
	var out := s.line(text)
	assert_false(out.contains("Jo"), "…" + out.right(30))
	assert_eq(s.cut("a b Jo Bloggs", 7), "a b …")
	assert_eq(s.cut("a b JO", 7), "a b JO", "uncut: kept, the whole-word scrub's to judge")
	assert_eq(s.cut("a bJo Bloggs x", 6), "a bJo…", "only a whole word")
	var info := BugReport.ReportInfo.new()
	info.note_chars = 500
	info.scrub = s
	var at := info.note_chars * BugReport.SCRUB_MARGIN
	var filler := (ZED_SAVE + " ").repeat(at / ZED_SAVE.length() + 2).left(at - 4) + " "
	info.note = filler + "Jo Bloggs said hi"
	assert_eq(info.note.substr(at - 3, 3), "Jo ")
	assert_false(BugReport.write(info).contains("Jo"), "report")
	assert_false(IssueLink.make(info, ReportConfig.new()).url.uri_decode().contains("Jo"), "issue")


## BP6 critic: the cheap edges QA found. A mixed-case address with a digit goes ("Fe80::1"), as do zero-padded IPv4
## and WSL's path to another account; a name split by a tab or two spaces gets the cut's guard.
func test_mixed_case_padded_and_wsl_addresses_go_and_odd_spaced_names_are_cut_clean() -> void:
	var s := ReportScrub.new()
	assert_eq(s.line("route Fe80::1 up"), "route <address> up")
	assert_eq(s.line("Fade::1 and Bad::add_child"), "Fade::1 and Bad::add_child", "C++ names stay")
	assert_eq(s.line("at 010.001.002.003 now"), "at <address> now")
	assert_eq(s.line("open /mnt/c/Users/Other/x"), "open /mnt/c/Users/<you>/x")
	for spaced: String in ["Jo\tBloggs", "Jo  Bloggs"]:
		var t := ReportScrub.new("", "", spaced, "")
		assert_eq(t.cut("a b " + spaced, 7), "a b …", "no first word left of %s" % spaced.c_escape())
