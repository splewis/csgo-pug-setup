#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <adminmenu>

new Handle:g_Enabled = INVALID_HANDLE;
new g_cap1 = 0;
new g_cap2 = 0;
new g_PlayersPicked = 0;
new g_Ready[MAXPLAYERS+1];
new g_Teams[MAXPLAYERS+1];
new g_Active = false;
new g_MatchLive = false;

public Plugin:myinfo = {
	name = "CS:GO TeamSelect",
	author = "splewis",
	description = "Lets captains pick their teams",
	version = "0.1",
	url = "https://github.com/splewis/teamselect"
};

public OnPluginStart() {
	LoadTranslations("common.phrases");

	/** convars **/
	g_Enabled = CreateConVar("sm_teamselect_enabled", "1", "Sets whether teamselect is enabled");

	// Create and exec plugin's configuration file
	AutoExecConfig(true, "teamselect");

	if (GetConVarInt(g_Enabled) == 1) {
		RegConsoleCmd("sm_10man", Command_10man, "Starts 10man setup (!ready, !capt commands become avaliable)");
		RegConsoleCmd("sm_ready", Command_Ready, "Marks the client as ready");
		RegConsoleCmd("sm_unready", Command_Unready, "Marks the client as not ready");
		RegAdminCmd("sm_capt1", Command_Cap1, ADMFLAG_CUSTOM1, "Sets captain 1 (picks first, T)");
		RegAdminCmd("sm_capt2", Command_Cap2, ADMFLAG_CUSTOM1, "Sets captain 2 (picks second, CT)");
		RegAdminCmd("sm_endgame", Command_EndMatch, ADMFLAG_CUSTOM1, "Pre-emptively ends the match");
		RegAdminCmd("sm_cancel", Command_Cancel, ADMFLAG_CUSTOM1, "Cancels 10man setup, opposite of sm_10man");
		HookEvent("cs_win_panel_match", Event_MatchOver);
	}
}

InitializeVariables() {
	g_Active = false;
	g_cap1 = -1;
	g_cap2 = -1;
	g_PlayersPicked = 0;
	for (new i = 1; i <= MaxClients; i++) {
		g_Ready[i] = false;
		g_Teams[i] = -1;
	}
	g_MatchLive = false;
}

public OnMapStart() {
	InitializeVariables();
}

public OnMapEnd() {
}

public Action:Timer_CheckReady(Handle:timer) {
	new rdy = 0;
	new count = 0;
	for (new i = 1; i <= MaxClients; i++) {
		if (IsValidClient(i) && IsClientInGame(i) && !IsFakeClient(i)) {
			count++;
			if (g_Ready[i]) {
				CS_SetClientClanTag(i, "Ready");
				rdy++;
			} else {
				CS_SetClientClanTag(i, "Not ready");
			}
		}
	}

	if (!g_Active)
		return Plugin_Stop;

	if (rdy == count && IsValidClient(g_cap1) && IsValidClient(g_cap2) && g_cap1 != g_cap2) {
		PrintToChatAll("Team selection has begun!");
		CreateTimer(3.0, StartPicking);
		return Plugin_Stop;
	} else {
		decl String:cap1[20];
		decl String:cap2[20];

		if (IsValidClient(g_cap1) && !IsFakeClient(g_cap1) && IsClientInGame(g_cap1))
			Format(cap1, sizeof(cap1), "%N", g_cap1);
		else
			Format(cap1, sizeof(cap1), "not selected");

		if (IsValidClient(g_cap2) && !IsFakeClient(g_cap2) && IsClientInGame(g_cap2))
			Format(cap2, sizeof(cap2), "%N", g_cap2);
		else
			Format(cap2, sizeof(cap2), "not selected");


		PrintHintTextToAll("%i out of %i players are ready\nCaptain 1: %s\nCaptain 2: %s", rdy, count, cap1, cap2);
	}
	return Plugin_Continue;
}

public Action:Command_10man(client, args) {
	g_Active = true;
	PrintToChatAll("Setting up 10man game...");
	CreateTimer(3.0, Timer_CheckReady, _, TIMER_REPEAT);
}

public Action:Command_Ready(client, args) {
	if (g_Active && !g_MatchLive) {
		g_Ready[client] = true;
		CS_SetClientClanTag(client, "Ready");
	}
	return Plugin_Handled;
}

public Action:Command_Unready(client, args) {
	if (g_Active && !g_MatchLive) {
		g_Ready[client] = false;
		CS_SetClientClanTag(client, "Not ready");
	}
	return Plugin_Handled;
}


public Action:Event_MatchOver(Handle:event, const String:name[], bool:dontBroadcast) {
	EndMatch();
	return Plugin_Handled;
}

public Action:Command_EndMatch(client, args) {
	if (!g_MatchLive || !g_Active)
		ReplyToCommand(client, "Match has not begun yet!");
	else
		EndMatch();
	return Plugin_Handled;
}

public Action:Command_Cancel(client, args) {
	InitializeVariables();
	return Plugin_Handled;
}

public EndMatch() {
	if (g_Active) {
		g_MatchLive = false;
		ServerCommand("tv_stoprecord");
		ServerCommand("exec sourcemod/postgame.cfg");
	}
}

public Action:Command_Cap1(client, args) {
	if (g_MatchLive || !g_Active)
		return Plugin_Handled;

	new String:arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	new target = FindTarget(client, arg1);
	if (target == -1)
		return Plugin_Handled;

	g_cap1 = target;
	PrintToChatAll("Captain 1 will be %N", g_cap1);
	return Plugin_Handled;
}

public Action:Command_Cap2(client, args) {
	if (g_MatchLive || !g_Active)
		return Plugin_Handled;

	new String:arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	new target = FindTarget(client, arg1);
	if (target == -1)
		return Plugin_Handled;

	g_cap2 = target;
	PrintToChatAll("Captain 2 will be %N", g_cap2);
	return Plugin_Handled;
}

public Action:StartPicking(Handle:timer) {
	if (g_MatchLive || !g_Active)
		return Plugin_Handled;

	ServerCommand("mp_pause_match");
	ServerCommand("mp_restartgame 1");

	for (new i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i)) {
			g_Teams[i] = CS_TEAM_SPECTATOR;
			SwitchPlayerTeam(i, CS_TEAM_SPECTATOR);
			CS_SetClientClanTag(i, "");
		}
	}
	g_Teams[g_cap1] = CS_TEAM_T;
	SwitchPlayerTeam(g_cap1, CS_TEAM_T);
	g_Teams[g_cap2] = CS_TEAM_CT;
	SwitchPlayerTeam(g_cap2, CS_TEAM_CT);
	GiveCaptainMenu(g_cap1);
	return Plugin_Handled;
}

public TeamMenuHandler(Handle:menu, MenuAction:action, param1, param2) {
	if (action == MenuAction_Select) {
		new String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		new UserID = StringToInt(info);
		new client = GetClientOfUserId(UserID);

		if (client > 0) {
			g_Teams[client] = g_Teams[param1];
			PrintToChatAll("%N picks %N", param1, client);
			SwitchPlayerTeam(client, g_Teams[param1]);
			g_PlayersPicked++;

			if (!IsPickingFinished()) {
				new nextCapt = -1;
				if (param1 == g_cap1)
					nextCapt = g_cap2;
				else
					nextCapt = g_cap1;
				CreateTimer(0.5, MoreMenuPicks, GetClientSerial(nextCapt));
			} else {
				CreateTimer(1.0, FinishPicking);
			}
		} else {
			CreateTimer(0.5, MoreMenuPicks, param2);
		}

	} else if (action == MenuAction_Cancel) {
		CreateTimer(0.5, MoreMenuPicks, param2);
	} else if (action == MenuAction_End) {
		CloseHandle(menu);
	}
}

public bool:IsPickingFinished() {
	return g_PlayersPicked >= 8;
}

public Action:MoreMenuPicks(Handle:timer, any:serial) {
	new client = GetClientFromSerial(serial);
	if (IsPickingFinished() || !IsValidClient(client) || !IsClientInGame(client)) {
		CreateTimer(5.0, FinishPicking);
		return Plugin_Handled;
	}
	GiveCaptainMenu(client);
	return Plugin_Handled;
}

public GiveCaptainMenu(client) {
	new Handle:menu = CreateMenu(TeamMenuHandler);
	SetMenuTitle(menu, "Pick your players");
	SetMenuExitButton(menu, false);
	AddPlayersToMenu(menu);
	DisplayMenu(menu, client, 30);
}

public AddPlayersToMenu(Handle:menu) {
	new String:user_id[12];
	new String:name[MAX_NAME_LENGTH];
	new String:display[MAX_NAME_LENGTH+15];
	new count = 0;
	for (new client = 1; client <= MaxClients; client++) {
		if (IsValidClient(client) && g_Teams[client] == CS_TEAM_SPECTATOR && !IsFakeClient(client) && IsClientInGame(client)) {
			IntToString(GetClientUserId(client), user_id, sizeof(user_id));
			GetClientName(client, name, sizeof(name));
			Format(display, sizeof(display), "%s", name);
			AddMenuItem(menu, user_id, display);
			count++;
		}
	}
}

public Action:FinishPicking(Handle:timer) {
	ServerCommand("exec sourcemod/10man.cfg");
	ServerCommand("mp_unpause_match");
	for (new i = 0; i < 3; i++)
		PrintToChatAll("*** The match will begin shortly - live on 3! ***");
	CreateTimer(7.0, Rest1);
}

public OnClientPostAdminCheck(client) {
	g_Teams[client] = CS_TEAM_SPECTATOR;
	g_Ready[client] = false;
	if (IsClientInGame(client) && !IsFakeClient(client) && !g_MatchLive)
		CS_SetClientClanTag(client, "Not ready");
}

SwitchPlayerTeam(client, team) {
	if (team > CS_TEAM_SPECTATOR) {
		CS_SwitchTeam(client, team);
		CS_UpdateClientModel(client);
		CS_RespawnPlayer(client);
	} else {
		ChangeClientTeam(client, team);
	}
}

public Action:Rest1(Handle:timer) {
	PrintToChatAll("*** Restart 1/3 ***");
	ServerCommand("mp_restartgame 1");
	CreateTimer(4.0, Rest2);
}

public Action:Rest2(Handle:timer) {
	PrintToChatAll("*** Restart 2/3 ***");
	ServerCommand("mp_restartgame 3");
	CreateTimer(7.0, Rest3);
}

public Action:Rest3(Handle:timer) {
	PrintToChatAll("*** Restart 3/3 ***");
	ServerCommand("mp_restartgame 5");
	CreateTimer(5.1, Match);
}

public Action:Match(Handle:timer) {
	for (new i = 0; i < 5; i++)
		PrintToChatAll("****** Match is LIVE ******");
}

/***************************
 * Stocks                  *
 *  &                      *
 * SMLib Functions (berni) *
****************************/

/**
 * Function to identify if a client is valid and in game
 *
 * @param	client		Vector to be evaluated
 * @return 				true if valid client, false if not
 */
stock bool:IsValidClient(client) {
	if (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client))
		return true;
	return false;
}
