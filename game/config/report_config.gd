class_name ReportConfig
extends Resource
## The bug report's numbers (SV4, docs/ARCHITECTURE.md › Contracts 6): what the report keeps of the moments before it
## (RecentEvents, FrameWindow), how long its lists run, and how Report a Bug's GitHub address is cut to fit (IssueLink).
## The browser game's values (config/crash.ts REPORT_LOG and BUG_REPORT); report_config.tres is the instance the game
## loads.

const DEFAULT_PATH := "res://game/config/report_config.tres"

## A new issue on the game's repository: the address the title and body are added to.
@export var issue_url: String = "https://github.com/ggbillyjoe3526/airsoft/issues/new"
## The longest address sent (GitHub answers 414 a little above 8,000 characters; Windows' ShellExecute is untested
## past it, so this drops if the owner's PC refuses: 2,000 still holds the note and the main fields).
@export var max_url_chars: int = 8000
## Entries kept of each list as the issue's body is cut to fit, newest first, one step at a time.
@export var keep_steps: PackedInt32Array = PackedInt32Array([10, 3, 0])
## Fields left out next, when the lists alone don't make it fit (BugReport's labels).
@export var drop_fields: PackedStringArray = PackedStringArray(["Settings changed", "Dev settings"])
## The note box's length, and how much of the note's first line makes the issue's title.
@export var note_chars: int = 500
@export var title_chars: int = 70
## Errors and warnings a report lists (ErrorLog keeps 20), newest kept.
@export var errors: int = 20
## Game events kept (RecentEvents): shots, hits, calls, the player's reloads and draws, round changes.
@export var events: int = 30
## A shot within this many ticks of the same character's last, from the same replica, counts up that entry.
@export var burst_ticks: int = 60
## How many entries back a shot looks for its shooter's entry to count up (past other shots only).
@export var look_back: int = 8
## Seconds of play whose frame times a report sums up (FrameWindow).
@export var frame_seconds: float = 10.0
## The fastest frame rate the window holds frame_seconds of; faster, it holds fewer seconds (and says so).
@export var frame_rate_held: int = 500
## A frame slower than this (ms) counts as a hitch.
@export var hitch_ms: float = 50.0
## Lines of the crashed run's log a crash report gives (LogTail keeps 40).
@export var log_lines: int = 40
## The account and machine names are taken out as whole words from this many characters (shorter ones would take
## out ordinary words; the folders they name are still taken out).
@export var min_name_chars: int = 3
## Account and machine names that are ordinary words in a report ("player" would take every "player" out of the log):
## taken out of paths only, as a short name is. Any case; none of them names a person.
@export var common_names: PackedStringArray = PackedStringArray(["player", "test", "tester", "user", "admin",
		"administrator", "guest", "owner", "default", "public", "home", "game", "gamer", "student", "laptop", "desktop",
		"computer", "windows", "linux", "ubuntu", "deck", "steamdeck", "localhost"])
## The longest line a report gives (characters): a longer one is cut, before and after it is scrubbed.
@export var max_line_chars: int = 2000
## The player reads as crouched past this much of a crouch (Character.crouch_amount, 0 to 1).
@export_range(0.0, 1.0) var crouched_at: float = 0.5
## The teams as reports name them, Alpha's first (English: reports are read by the developer).
@export var team_names: PackedStringArray = PackedStringArray(["Alpha", "Beta"])


## The game's report config, or the built-in values with a warning if it can't be loaded.
static func load_default() -> ReportConfig:
	var res := load(DEFAULT_PATH) as ReportConfig
	if res == null:
		push_warning("ReportConfig: %s could not be loaded; using the built-in values" % DEFAULT_PATH)
		return ReportConfig.new()
	return res
