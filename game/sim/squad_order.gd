class_name SquadOrder
## Squad orders (the browser game's config/squad.ts, M22): what a character tells its bot teammates in play, given as
## its PlayerCommand's one-shot squad_order. The simulation turns it into a SQUAD_ORDER event (or a refused one); the
## bots' controller hands it out (BotController, SquadOrders). An order holds until it is given again, its giver is out,
## or the round ends; Team plan ends it at once.

## NONE: no order this tick. TEAM_PLAN: back to the team plan (the order wheel's Team Plan). MAG: the order wheel's Need
## a Mag (MH3), never given as an order: PlayerInput turns it into the command's mag_hand_off (MagShare). MOVE: Go
## there (FM1), never given as an order either: the order wheel's Go There, its key and a click on the full-screen map
## are a ping (PlayerCommand.ping_move) that the bots' controller hands out as this order, to a spot, which reads Hold
## here once they are all there.
enum Kind { NONE, FOLLOW, HOLD, REGROUP, TEAM_PLAN, MAG, MOVE }
