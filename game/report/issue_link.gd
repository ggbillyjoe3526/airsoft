class_name IssueLink
extends RefCounted
## Report a Bug's address (SV4): a new issue on the game's GitHub repository with its title and body filled in (no
## token, no server; nothing is sent until the player presses Submit there). Titled from the note's first line, or the
## version; the body is the note and the report in a code fence longer than any backtick run in it, so nothing in it
## reads as Markdown (a "#3" as an issue link). Over max_url_chars the report is cut to fit, in order: each list's
## newest entries only (keep_steps), then drop_fields left out, then as many of its first lines as fit; the body then
## says to paste the whole report, which the caller has copied. Pure. The browser game's core/bugIssue.ts.

const TITLE_WITH_NOTE := "Bug: %s"
const TITLE := "Bug report (%s)"
## The body's first line when the player typed no note.
const ASK_WHAT := "**What happened?** Describe what went wrong and what you were doing just before."
## Above a cut report.
const CUT_NOTE := "Part of the report did not fit in the link. The whole report is on your clipboard: paste it below."
const FENCE_MIN := 3
const FENCE_LANGUAGE := "text"
const MORE := "…"

## The address to open.
var url: String = ""
## Part of the report was cut to fit: the whole one belongs on the clipboard.
var cut: bool = false


## The issue for `info` (its note included) under `config`'s address and limits. Fails closed: an info with no scrub
## is scrubbed for this machine.
static func make(info: BugReport.ReportInfo, config: ReportConfig) -> IssueLink:
	var scrub := info.scrub if info.scrub != null else ReportScrub.for_this_machine(config)
	# Scrubbed, then cut: a cut first could leave part of a name that no longer matches.
	var note := scrub.line(scrub.cut(info.note.strip_edges(), config.note_chars * BugReport.SCRUB_MARGIN)) \
			.left(config.note_chars)
	var title := issue_title(note, info.version, config.title_chars)
	var link := IssueLink.new()
	var cuts: Array[BugReport.Cut] = [BugReport.Cut.new()]
	for keep in config.keep_steps:
		cuts.append(BugReport.Cut.new(keep))
	var last_keep := config.keep_steps[config.keep_steps.size() - 1] if not config.keep_steps.is_empty() else -1
	cuts.append(BugReport.Cut.new(last_keep, config.drop_fields))
	for i in cuts.size():
		link.url = address(config.issue_url, title, note, BugReport.write(info, cuts[i], scrub), i > 0)
		if link.url.length() <= config.max_url_chars:
			link.cut = i > 0
			return link
	# Still too long (a huge settings line, long log lines): as many of its first lines as fit.
	var lines := BugReport.write_lines(info, cuts[cuts.size() - 1], scrub)
	var fits := 0
	var over := lines.size()
	while over - fits > 1:
		var mid := (fits + over) / 2
		if address(config.issue_url, title, note, "\n".join(lines.slice(0, mid)), true).length() <= config.max_url_chars:
			fits = mid
		else:
			over = mid
	link.url = address(config.issue_url, title, note, "\n".join(lines.slice(0, fits)), true)
	link.cut = true
	return link


## "Bug: <the note's first line>" (clipped to `chars` with "…"), or "Bug report (<version>)" without a note.
static func issue_title(note: String, version: String, chars: int) -> String:
	var lines := note.strip_edges().split("\n", false)
	var first := BugReport.one_line(lines[0]) if not lines.is_empty() else ""
	if first == "":
		return TITLE % (version if version != "" else BugReport.UNKNOWN)
	if first.length() > chars:
		first = first.left(maxi(0, chars - MORE.length())) + MORE
	return TITLE_WITH_NOTE % first


## The address with `title` and a body of `note` (or ASK_WHAT), the cut line when `was_cut`, and `report` fenced.
static func address(base: String, title: String, note: String, report: String, was_cut: bool) -> String:
	var fence := "`".repeat(maxi(FENCE_MIN, longest_backticks(report) + 1))
	var body := PackedStringArray([note if note != "" else ASK_WHAT, ""])
	if was_cut:
		body.append_array([CUT_NOTE, ""])
	body.append_array([fence + FENCE_LANGUAGE, report, fence])
	return "%s?title=%s&body=%s" % [base, query_value(title), query_value("\n".join(body))]


## `text` for a query string: percent-encoded, spaces as "+" (GitHub's own examples; the shortest form).
static func query_value(text: String) -> String:
	return text.uri_encode().replace("%20", "+")


## The longest run of backticks in `text`.
static func longest_backticks(text: String) -> int:
	var longest := 0
	var run := 0
	for c in text:
		if c == "`":
			run += 1
			longest = maxi(longest, run)
		else:
			run = 0
	return longest
