class_name MatchPicks
extends RefCounted
## What the Match page has picked: the map, the mode, your team, the opponents' and teammates' levels, the rule set
## and, on a map offering both, Day or Night. A plain object the entry scene keeps, so the picks survive the menus being
## freed for a match and built again. The map and team of the last match played are kept across launches with the
## player's progress (`recall`, Progress.remember_picks; not options, so not in Settings); the rest for the session
## only. The Custom rule set's switches are options, kept in Settings.custom_rules.

var map_id: String = "depot"
var mode: String = MatchOptions.DEFAULT_MODE
## PlaySession.TEAM_ALPHA or TEAM_BETA.
var team: int = PlaySession.TEAM_ALPHA
## The other team's level, and your teammates': "" while they follow the opponents' (MatchOptions.teammates_level).
var bots: String = MatchOptions.DEFAULT_LEVEL
var teammates: String = ""
## MatchOptions.RULES_SKIRMISH or RULES_CUSTOM.
var rules: String = MatchOptions.RULES_SKIRMISH
## The lighting preset picked (LightingConfig.PRESETS), or &"" for the map's first; a map that doesn't offer it plays
## its first (MapData.preset_played).
var lighting: StringName = &""


## The Custom switches the match plays (`settings`'), or null when Skirmish is picked.
func custom_rules(settings: Settings) -> CustomRules:
	return settings.custom_rules if rules == MatchOptions.RULES_CUSTOM else null


## Takes the map and team `progress` kept from the last match played: a map the catalogue no longer has keeps the
## first card's (the Match page also passes over one not listed or that can't load), a team that isn't one Alpha.
func recall(progress: Progress) -> void:
	if not progress.last_map.is_empty() and MapCatalog.shared().find(progress.last_map) != null:
		map_id = progress.last_map
	if progress.last_team == PlaySession.TEAM_ALPHA or progress.last_team == PlaySession.TEAM_BETA:
		team = progress.last_team
