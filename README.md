teamselect
===========================

Sourcemod plugin for CS:GO for 10man style team selection and a live-on-3 match start.

Admin Commands (given by custom admin flag 1, "o")
- sm_10man, begins the setup phase (note the cvar sm_teamselect_require_load_command controls if this is needed)
- sm_cancel, force ends the setup phase and cancels the game, essentailly the opposite of sm_10man
- sm_capt1 <player>
- sm_capt2 <player>
- sm_endgame, force ends the game safely (stops any demo recording, execs postgame config)

Client Commands:
- sm_ready / .ready in chat
- sm_unready / .unready in chat

