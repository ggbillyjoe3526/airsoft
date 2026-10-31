Task: FM1 · QA commit be608ee · Verdict: Pass (re-run on head 9d4cd12; the first run, on 5166090, was Fail)

Blocking: none. The three failing tests I pinned (pointer opens on you at first open and on reopen; click before the first frame) now pass, the pointer being framed every frame even while shut (hud_field_map.gd update) and MapPointer start/frame/framed.

Advisory (not blocking, not pinned):
- game/input/map_pointer.gd:50 (move/_kept) · the pointer's px are not re-clamped or rescaled when the square changes under it (a window resize while M is held): it can sit past the new edge, or over another place, until the mouse moves. Needs a resize with the map open; can wait.
- game/input/player_input.gd (_order_key) · the order keys F, X and V on the open map act on the frozen view (the coordinator left it, as the wheel). Can wait.
- game/ai/squad_order_book.gd:32 · MATCH_OVER leaves a bot's order MOVE (pre-existing, as Hold here).
- game/play/play_session.gd:780 · allow_map(false) under Tab closes the map and it stays shut when Tab is let go with M still held (a fresh M press is needed). Intended by the fix; the owner should know.

Fixes checked: Mouse 4 on the open map is a Go there at the pointer (tested; out, it sends nothing); a click before any frame sends nothing (framed()); a frame after a pointer move does not drag it back to you (_fresh cleared by move); the area words are laid out again on a resize (Overlay.laid_out cache; tested); the scoreboard/summary closing is allow_map(false) in play_session (not unit-testable without a session: summary_up() exists; the closing itself is covered by test_the_map_shutting_under_you_closes_it...).

Tests added in tests/unit/test_fm1_qa.gd (21 now): go_there_s_key_on_the_open_map_is_a_go_there_at_the_pointer, go_there_s_key_does_nothing_on_the_open_map_while_you_are_out, the_pointer_follows_you_while_the_map_is_shut..., a_moved_pointer_stays_where_it_was_put..., the_area_words_are_laid_out_again_when_the_screen_resizes. Each fails at 5166090 (framed(), PING_MOVE in the map, the shut frame and laid_out do not exist there).

Result: test_fm1_qa 21/21, test_fm1_field_map 15/15, test_fm1_go_there 9/9, test_order_wheel_input 18/18; gdlint clean. I ran no full check.sh (the coordinator's is running on 9d4cd12).
Could not test: how it feels with a real mouse and window, the dimmed screen and words (display), and Tab/summary over a live session.
