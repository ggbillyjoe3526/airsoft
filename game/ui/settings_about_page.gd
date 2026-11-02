class_name SettingsAboutPage
extends VBoxContainer
## Settings › About (UI concept B v2, owner 2026-11-02: no title screen, and no title box here): the version and the
## renderer in words; in the menus' settings also Report a Bug, Licences (the credits) and Quit to desktop, which the
## title screen had. The pause menu's settings show only the two rows. The screen hosts the page on its tab and
## passes the buttons' presses on as its own signals.

signal report_pressed
signal credits_pressed
signal quit_pressed

var _report: Button = null
var _credits: Button = null
var _quit: Button = null


## Fills the page through `screen`'s rows; `buttons` adds Report a Bug, Licences and Quit.
func build(screen: SettingsScreen, buttons: bool) -> void:
	name = "About"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", SettingsScreen.ROW_GAP)
	screen.add_row(self, "SETTINGS_ABOUT_VERSION").add_child(_value(Version.current(), "Version"))
	var words := SettingsGraphicsPage.renderer_words(GraphicsApply.machine())
	screen.add_row(self, "SETTINGS_ABOUT_RENDERER").add_child(_value(words, "Renderer"))
	if not buttons:
		return
	add_child(_gap(SettingsScreen.SECTION_GAP))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SettingsScreen.ROW_SEPARATION)
	add_child(row)
	_report = _button(row, "REPORT_BUG", "Report")
	_report.pressed.connect(func() -> void: report_pressed.emit())
	_credits = _button(row, "MENU_LICENCES", "Licences")
	_credits.pressed.connect(func() -> void: credits_pressed.emit())
	add_child(_gap(SettingsScreen.SECTION_GAP * 2))
	var quit_row := HBoxContainer.new()
	add_child(quit_row)
	_quit = _button(quit_row, "SETTINGS_ABOUT_QUIT", "Quit")
	_quit.pressed.connect(func() -> void: quit_pressed.emit())


## Report a Bug, Licences and Quit; null in the pause menu's settings.
func report_button() -> Button:
	return _report


func credits_button() -> Button:
	return _credits


func quit_button() -> Button:
	return _quit


func _value(text: String, node_name: String) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", GameTheme.font(600))
	l.add_theme_font_size_override("font_size", GameTheme.LABEL_SIZE)
	return l


func _button(parent: Control, key: String, node_name: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = tr(key).to_upper()
	GameTheme.small_button(b)
	parent.add_child(b)
	return b


static func _gap(height: float) -> Control:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0.0, height)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g
