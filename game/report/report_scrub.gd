class_name ReportScrub
extends RefCounted
## Takes what names the player or their machine out of a report's lines (SV4), since a report may go into a public
## issue: the save folder's path becomes "<save folder>", the home folder "~", the account name "<you>" (as a whole
## word, min_name_chars or more and not one of its common_names; in any user folder too, whoever's), the machine's name
## "<machine>" (a full name and its first part), a OneDrive for Business folder's organisation "<organisation>", and
## network and e-mail addresses "<address>" (IPv4, IPv6 in any of its forms, MAC, e-mail), and a web address's user and
## password "<credentials>" ("https://<credentials>@host/"). Paths match with either slash and in any case (Windows' and
## Linux' alike, and log lines name them both ways). Built once with its names (`for_this_machine`, or injected by
## tests); `line` per line. Over-scrubs rather than leaks.

const SAVE_FOLDER := "<save folder>"
const HOME := "~"
const YOU := "<you>"
const MACHINE := "<machine>"
const ORGANISATION := "<organisation>"
const ADDRESS := "<address>"
const CREDENTIALS := "<credentials>"
## Unicode letters for \w and case-insensitive, so "Jöe" and "JÖE" are one name.
const UNICODE := "(*UCP)(?i)"
## A path starts where no word, dot or dash runs into it ("/var/home/bob" is not "/home/bob").
const PATH_START := r"(?<![\w.\-])"
## A path ends at a separator, a space, a quote or bracket, a comma or colon, or a full stop that ends a sentence.
const PATH_END := r"(?![^\\/\s\"'()\[\],:;.]|\.\w)"
## A user folder on Windows (C:\Users\name, or /mnt/c/Users/name as WSL sees it) or Linux and macOS (/home/name,
## /Users/name): its name is someone's account.
## The name may hold spaces ("Jo Bloggs") when a separator follows it within USER_FOLDER_CHARS and it holds none of
## the characters Windows bars from account names (so a sentence after the folder isn't taken up to the next slash);
## else it ends at a space, a bracket or a comma, and never on a full stop.
const USER_FOLDER := r"(*UCP)(?i)(?<![\w.\-\\/])((?:\b[a-z]:|/mnt/[a-z])?[\\/]++" \
		+ r"(?:users|home|documents and settings)[\\/]++)" \
		+ r"(?:[^\\/:*?\"<>|\[\]()\r\n,;=+]{1,48}+(?=[\\/])|[^\\/\s:*?\"<>|\[\](),;]*[^\\/\s:*?\"<>|\[\](),;.])"
## A OneDrive for Business folder is named after the employer: "OneDrive - Contoso Ltd".
const ONEDRIVE := r"(?i)(OneDrive - )[^\\/:*?\"<>|\r\n]+"
## An IPv4 part, zero-padded too ("010.001.002.003").
const OCTET := r"0{0,2}(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)"
const HEX := r"[0-9a-f]{1,4}"
## A full stop may follow an address (the end of a sentence), never another number. A version ("v1.2.3.4") and the
## graphics card's driver as the report writes it ("(driver 10.0.0.1)") aren't addresses.
const IPV4 := r"(?<![\d.])(?<!\b[vV])(?<!\(driver )(?:" + OCTET + r"\.){3}" + OCTET + r"(?!\d|\.\d)"
## Every IPv6 form: full, compressed ("2001:db8::1", "fe80::1ff:fe23:4567:890a", "::ffff:c0a8:105") and with an IPv4
## tail ("::ffff:1.2.3.4"), with its zone ("%eth0", "%Ethernet 2", "%12"); hex letters alone too ("dead::beef"). One
## whose first group is a capital and then small letters only is a C++ name ("Face::bad", "Fade::1"), as no tool writes
## an address so; with a digit in it ("Fe80::1") it is an address. Clocks have no "::" and too few groups. A label may
## run into it ("ip:fe80::1", "host:::1": one colon before it, never two) and a colon may follow it ("2001:db8::1:
## refused"), not a word or another colon. Linear on any line: a start is tried only with a "::" or an IPv4 tail's "."
## within its first eight groups, or as exactly eight groups, each look-ahead never giving back; so a long run of
## numbers and colons ("1:1:1:…") fails at each start in a few steps rather than through every form.
const IPV6 := r"(?i)(?<![\w.])(?<!::)(?!(?-i)[A-F][a-f]++(?![0-9A-Fa-f]))" \
		+ r"(?=(?:[0-9a-f]{1,4}+:){0,7}+(?::|\d{1,3}\.)|(?:" + HEX + r":){7}" + HEX + r"(?!\w|:[\w:]))(?:" \
		+ r"(?:[0-9a-f]{0,4}:){2,6}" + OCTET + r"(?:\." + OCTET + r"){3}(?!\d|\.\d)" \
		+ r"|(?:" + HEX + r":){7}" + HEX \
		+ r"|(?:" + HEX + r":){1,6}:" + HEX \
		+ r"|(?:" + HEX + r":){1,5}(?::" + HEX + r"){1,2}" \
		+ r"|(?:" + HEX + r":){1,4}(?::" + HEX + r"){1,3}" \
		+ r"|(?:" + HEX + r":){1,3}(?::" + HEX + r"){1,4}" \
		+ r"|(?:" + HEX + r":){1,2}(?::" + HEX + r"){1,5}" \
		+ r"|" + HEX + r":(?::" + HEX + r"){1,6}" \
		+ r"|:(?::" + HEX + r"){1,7}" \
		+ r"|(?:" + HEX + r":){1,7}:" \
		+ r")(?:%[\w.\-]+(?: \d+\b)?)?(?!\w|:[\w:])"
## A label may run into it as into IPv6 ("mac:aa:bb:cc:dd:ee:ff", "hw:aa-bb-cc-dd-ee-ff": one colon before it, never
## two separators); a colon may follow it, not a word or another group.
const MAC := r"(?i)(?<![\w.\-])(?<![:\-][:\-])(?:[0-9a-f]{2}[:-]){5}[0-9a-f]{2}(?!\w|[:\-]\w)"
## Starts only where a run of its characters starts, and never gives back, so a long run with no "@" costs one pass,
## not one a character (a pasted note of 60,000 took 4.7 s).
const EMAIL := r"(*UCP)(?<![\w.+-])[\w.+-]++@[\w-]+(?:\.[\w-]+)+"
## A web address's user information ("user:secret" in "https://user:secret@host/"), up to its "@", before the e-mail
## pattern sees "secret@host". Tried only after a "://", and never gives back, so it is linear on any line.
const CREDENTIALS_IN_URL := r"(?<=://)[^\s/?#@]++@"
## Where a cut may end a line: the characters between words and fields. Never "/", ".", ":", "@", "-" or "\", which sit
## inside paths, addresses and e-mail addresses.
const CUT_AT := " \t\r\n\"'`()[]{}<>,;="
const CUT_MARK := "…"
## The characters a regular expression gives a meaning to, escaped in a name or path.
const SPECIAL := "\\^$.|?*+()[]{}"

var _paths: Array[RegEx] = []
var _path_words: PackedStringArray = []
var _names: Array[RegEx] = []
var _max_chars: int = 0
var _common: PackedStringArray = []
var _name_words: PackedStringArray = []
## Per name of more than one word, its first words at a text's end ("Jo" of "Jo Bloggs"), for `cut`.
var _name_starts: Array[RegEx] = []
var _user_folder := RegEx.create_from_string(USER_FOLDER)
var _onedrive := RegEx.create_from_string(ONEDRIVE)
var _email := RegEx.create_from_string(EMAIL)
var _credentials := RegEx.create_from_string(CREDENTIALS_IN_URL)
## IPv6 before IPv4, so an IPv4 tail goes with its address.
var _addresses: Array[RegEx] = [RegEx.create_from_string(IPV6), RegEx.create_from_string(IPV4),
		RegEx.create_from_string(MAC)]


## `save_folder` (OS.get_user_data_dir), `home`, `account` and `machine` as this machine gives them ("" for one not
## known); names shorter than `config`'s min_name_chars are taken out of paths only, and a line is cut to its
## max_line_chars. A machine's full name ("box.corp.example") goes
## and so does its first part ("box").
func _init(save_folder: String = "", home: String = "", account: String = "", machine: String = "",
		config: ReportConfig = null) -> void:
	var c := config if config != null else ReportConfig.new()
	var min_chars := c.min_name_chars
	_common = c.common_names
	_max_chars = c.max_line_chars
	_add_path(save_folder, SAVE_FOLDER)
	_add_path(home, HOME)
	var names: Array[PackedStringArray] = [PackedStringArray([account, YOU]), PackedStringArray([machine, MACHINE])]
	var short := machine.get_slice(".", 0)
	if short != machine:
		names.append(PackedStringArray([short, MACHINE]))
	# The longer name first, so a machine named after its owner ("zandra-laptop") goes whole.
	names.sort_custom(func(a: PackedStringArray, b: PackedStringArray) -> bool: return a[0].length() > b[0].length())
	for n in names:
		_add_name(n[0], n[1], min_chars)


## This machine's: the save folder, the home folder (USERPROFILE or HOME), the account (USERNAME or USER, else the home
## folder's name) and the machine's name (COMPUTERNAME, HOSTNAME or /etc/hostname).
static func for_this_machine(config: ReportConfig = null) -> ReportScrub:
	var home := _env(["USERPROFILE", "HOME"])
	var account := _env(["USERNAME", "USER", "LOGNAME"])
	if account == "" and home != "":
		account = home.replace("\\", "/").trim_suffix("/").get_file()
	var machine := _env(["COMPUTERNAME", "HOSTNAME"])
	if machine == "" and FileAccess.file_exists("/etc/hostname"):
		machine = FileAccess.get_file_as_string("/etc/hostname").strip_edges()
	return ReportScrub.new(OS.get_user_data_dir(), home, account, machine, config)


## `text` with the folders, names and addresses taken out, cut to max_line_chars. E-mail addresses go before the names,
## so "<you>@domain" never stays behind. A huge line is cut to twice that before it is scrubbed (a pasted note can't
## stall the game) at a word's end (`cut_whole`), so no part of a name or address is left to slip past the patterns;
## and to max_line_chars after, which cuts only scrubbed text.
func line(text: String) -> String:
	var out := cut(text, _max_chars * 2) if _max_chars > 0 else text
	for i in _paths.size():
		out = _paths[i].sub(out, _path_words[i], true)
	out = _user_folder.sub(out, "$1" + YOU, true)
	out = _onedrive.sub(out, "$1" + ORGANISATION, true)
	out = _credentials.sub(out, CREDENTIALS + "@", true)
	out = _email.sub(out, ADDRESS, true)
	for i in _names.size():
		out = _names[i].sub(out, _name_words[i], true)
	for r in _addresses:
		out = r.sub(out, ADDRESS, true)
	return out.left(_max_chars) if _max_chars > 0 else out


## `text` cut to at most `chars` characters without splitting a word: back to the last of CUT_AT before the cut, the
## unfinished word dropped and "…" put in its place; all of it one word, just "…". Uncut when it fits.
static func cut_whole(text: String, chars: int) -> String:
	if text.length() <= chars:
		return text
	var at := chars - CUT_MARK.length()
	while at > 0 and not CUT_AT.contains(text[at]):
		at -= 1
	return text.left(maxi(at, 0)) + CUT_MARK


## `text` cut as `cut_whole` cuts it, then the first words of a name of more than one word dropped from its end: a cut
## at the space inside "Jo Bloggs" would leave "Jo", which the whole name's pattern no longer matches.
func cut(text: String, chars: int) -> String:
	if text.length() <= chars:
		return text
	var out := cut_whole(text, chars).trim_suffix(CUT_MARK)
	for r in _name_starts:
		out = r.sub(out, "")
	return out + CUT_MARK


## Every line of `texts`, scrubbed.
func lines(texts: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	out.resize(texts.size())
	for i in texts.size():
		out[i] = line(texts[i])
	return out


## A folder: matched with either slash between its parts and in any case, with or without a slash after it, never as
## the tail of a longer path.
func _add_path(path: String, word: String) -> void:
	var parts := PackedStringArray()
	for part in path.replace("\\", "/").split("/", false):
		parts.append(_escaped(part))
	if parts.is_empty():
		return
	var lead := r"(?<![\\/])[\\/]++" if path.begins_with("/") or path.begins_with("\\") else ""
	_paths.append(RegEx.create_from_string(UNICODE + PATH_START + lead + r"[\\/]+".join(parts) + PATH_END))
	_path_words.append(word)


## A name, as a whole word in any case; none shorter than `min_chars` nor one of the common names.
func _add_name(name: String, word: String, min_chars: int) -> void:
	if name.length() < min_chars or _common.has(name.to_lower()):
		return
	# its words split at any run of spaces or tabs, so "Jo\tBloggs" and "Jo  Bloggs" get the cut's guard too
	var words := name.replace("\t", " ").split(" ", false)
	if words.size() > 1:
		var starts := PackedStringArray()
		for k in range(words.size() - 1, 0, -1):
			var first := PackedStringArray()
			for w in words.slice(0, k):
				first.append(_escaped(w))
			starts.append(r"\s+".join(first))
		_name_starts.append(RegEx.create_from_string(UNICODE + r"(?<!\w)(?:" + "|".join(starts) + r")\s*$"))
	_names.append(RegEx.create_from_string(UNICODE + r"(?<!\w)" + _escaped(name) + r"(?!\w)"))
	_name_words.append(word)


static func _escaped(text: String) -> String:
	var out := ""
	for c in text:
		out += "\\" + c if SPECIAL.contains(c) else c
	return out


static func _env(names: PackedStringArray) -> String:
	for n in names:
		var v := OS.get_environment(n).strip_edges()
		if v != "":
			return v
	return ""
