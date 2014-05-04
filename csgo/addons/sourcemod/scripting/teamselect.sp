#define PLUGIN_VERSION 		"0.1.0"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <adminmenu>
#include "teamselect/liveon3.sp"

#pragma semicolon 1

new Handle:g_hRequireCommand = INVALID_HANDLE;
new Handle:g_hCvarVersion = INVALID_HANDLE;
new Handle:g_hAutoLO3 = INVALID_HANDLE;

new g_capt1 = 0;
new g_capt2 = 0;
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

	/** ConVars **/
	g_hRequireCommand = CreateConVar("sm_teamselect_require_load_command", "1", "Sets whether teamselect needs a command to run");
	g_hAutoLO3 = CreateConVar("sm_teamselect_autolo3", "1", "If the game starts immediately after teams are picked");
	g_hCvarVersion = CreateConVar("sm_teamselect_version", PLUGIN_VERSION, "Current brush version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	SetConVarString(g_hCvarVersion, PLUGIN_VERSION);

	// Create and exec plugin's configuration file
	AutoExecConfig(true, "teamselect");

	/** Commands **/
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say2");
	AddCommandListener(Command_Say, "say_team");

	RegConsoleCmd("sm_ready", Command_Ready, "Marks the client as ready");
	RegConsoleCmd("sm_unready", Command_Unready, "Marks the client as not ready");

	RegAdminCmd("sm_10man", Command_10man, ADMFLAG_CUSTOM1, "Starts 10man setup (!ready, !capt commands become avaliable)");
	RegAdminCmd("sm_start", Command_10man, ADMFLAG_CUSTOM1, "Starts the game if auto-lo3 is disabled");
	RegAdminCmd("sm_pause", Command_Pause, ADMFLAG_CUSTOM1, "");
	RegAdminCmd("sm_unpause", Command_Unpause, ADMFLAG_CUSTOM1, "");
	RegAdminCmd("sm_capt1", Command_Capt1, ADMFLAG_CUSTOM1, "Sets captain 1 (picks first, T)");
	RegAdminCmd("sm_capt2", Command_Capt2, ADMFLAG_CUSTOM1, "Sets captain 2 (picks second, CT)");
	RegAdminCmd("sm_endgame", Command_EndMatch, ADMFLAG_CUSTOM1, "Pre-emptively ends the match");

	/** Event hooks **/
	HookEvent("cs_win_panel_match", Event_MatchOver);
}

InitializeVariables() {
	g_Active = false;
	g_capt1 = -1;
	g_capt2 = -1;
	g_PlayersPicked = 0;
	for (new i = 1; i <= MaxClients; i++) {
		g_Ready[i] = false;
		g_Teams[i] = -1;
	}
	g_MatchLive = false;
}

public OnMapStart() {
	InitializeVariables();
	if (GetConVarInt(g_hRequireCommand) == 0) {
		// fake a sm_10man command with fake args (they aren't used)
		Command_10man(0, 0);
	}
}

public OnMapEnd() {
}

public Action:Timer_CheckReady(Handle:timer) {
	if (!g_Active)
		return Plugin_Stop;

	new rdy = 0;
	new count = 0;
	for (new i = 1; i <= MaxClients; i++) {
		if (IsValidClient(i) && IsClientInGame(i) && !IsFakeClient(i)) {
			count++;
			if (g_Ready[i]) {
				CS_SetClientClanTag(i, "[Ready]");
				rdy++;
			} else {
				CS_SetClientClanTag(i, "[Not ready]");
			}
		}
	}

	if (rdy == count && rdy >= 10 && IsValidClient(g_capt1) && IsValidClient(g_capt2) && g_capt1 != g_capt2) {
		PrintToChatAll(" \x01\x0B\x04Team selection will begin in a few seconds!");
		CreateTimer(3.0, StartPicking);
		return Plugin_Stop;
	} else {
		decl String:cap1[60];
		decl String:cap2[60];

		if (IsValidClient(g_capt1) && !IsFakeClient(g_capt1) && IsClientInGame(g_capt1))
			Format(cap1, sizeof(cap1), "%N", g_capt1);
		else
			Format(cap1, sizeof(cap1), "not selected");

		if (IsValidClient(g_capt2) && !IsFakeClient(g_capt2) && IsClientInGame(g_capt2))
			Format(cap2, sizeof(cap2), "%N", g_capt2);
		else
			Format(cap2, sizeof(cap2), "not selected");


		PrintHintTextToAll("%i out of %i players are ready\nCaptain 1: %s\nCaptain 2: %s", rdy, count, cap1, cap2);
	}
	return Plugin_Continue;
}

public Action:Command_10man(client, args) {
	if (g_MatchLive)
		return Plugin_Handled;

	for (new i = 1; i <= MaxClients; i++)
		g_Ready[i] = false;

	g_Active = true;
	ServerCommand("exec sourcemod/postgame.cfg");
	ServerCommand("mp_restartgame 1");
	CreateTimer(1.0, Timer_CheckReady, _, TIMER_REPEAT);
	return Plugin_Handled;
}

public Action:Command_Pause(client, args) {
	ServerCommand("mp_pause_match");
	PrintToChatAll(" \x01\x0B\x03%N \x01has called for a pause", client);
}

public Action:Command_Unpause(client, args) {
	ServerCommand("mp_unpause_match");
	PrintToChatAll(" \x01\x0B\x03%N \x01unpaused", client);
}

public Action:Command_Say(client, const String:command[], argc) {
	decl String:text[192];
	if (GetCmdArgString(text, sizeof(text)) < 1) {
		return Plugin_Continue;
	}

	StripQuotes(text);
	new bool:isReady = false;
	isReady |= (strcmp(text[0], ".ready", false) == 0);
	isReady |= (strcmp(text[0], ".gs4lyfe", false) == 0);

	if (isReady) {
		Command_Ready(client, 0);
	}
	if (strcmp(text[0], ".unready", false) == 0) {
		Command_Unready(client, 0);
	}

	// continue normally
	return Plugin_Continue;
}

public Action:Command_Ready(client, args) {
	if (g_Active && !g_MatchLive) {
		g_Ready[client] = true;
		CS_SetClientClanTag(client, "[Ready]");
	}
	return Plugin_Handled;
}

public Action:Command_Unready(client, args) {
	if (g_Active && !g_MatchLive) {
		g_Ready[client] = false;
		CS_SetClientClanTag(client, "[Not ready]");
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

public EndMatch() {
	if (g_Active) {
		g_MatchLive = false;
		ServerCommand("exec sourcemod/postgame.cfg");
		CreateTimer(130.0, StopDemoMessage);
		CreateTimer(131.0, StopDemo);
	}
}

public Action:StopDemoMessage(Handle:timer) {
	PrintToChatAll("Stopping demo...");
	return Plugin_Continue;
}

public Action:StopDemo(Handle:timer) {
	ServerCommand("tv_stoprecord");
	return Plugin_Continue;
}

public Action:Command_Capt1(client, args) {
	if (g_MatchLive || !g_Active)
		return Plugin_Handled;

	new String:arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	new target = FindTarget(client, arg1);
	if (target == -1)
		return Plugin_Handled;

	g_capt1 = target;
	PrintToChatAll("Captain 1 will be \x02%N", g_capt1);
	return Plugin_Handled;
}

public Action:Command_Capt2(client, args) {
	if (g_MatchLive || !g_Active)
		return Plugin_Handled;

	new String:arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	new target = FindTarget(client, arg1);
	if (target == -1)
		return Plugin_Handled;

	g_capt2 = target;
	PrintToChatAll("Captain 2 will be \x03%N", g_capt2);
	return Plugin_Handled;
}

public Action:StartPicking(Handle:timer) {
	if (g_MatchLive || !g_Active)
		return Plugin_Handled;


	g_MatchLive = true;
	ServerCommand("mp_pause_match");
	ServerCommand("mp_restartgame 1");

	for (new i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i)) {
			g_Teams[i] = CS_TEAM_SPECTATOR;
			SwitchPlayerTeam(i, CS_TEAM_SPECTATOR);
			CS_SetClientClanTag(i, "");
		}
	}

	// temporary teams
	SwitchPlayerTeam(g_capt2, CS_TEAM_CT);
	SwitchPlayerTeam(g_capt1, CS_TEAM_T);

	new Handle:menu = CreateMenu(SideMenuHandler);
	SetMenuTitle(menu, "Which side do you want first");
	SetMenuExitButton(menu, false);
	AddMenuItem(menu, "CT", "CT");
	AddMenuItem(menu, "T", "T");
	DisplayMenu(menu, g_capt2, 30);
	return Plugin_Handled;
}


public SideMenuHandler(Handle:menu, MenuAction:action, param1, param2) {
	if (action == MenuAction_Select) {
		new hisTeam = CS_TEAM_CT;
		if (param2 == 1)  // T was option index 1 in the menu
			hisTeam = CS_TEAM_T;

		if (hisTeam == CS_TEAM_T)
			PrintToChatAll(" \x01\x0B\x03%N \x01has picked \x02T \x01first.", g_capt2);
		else
			PrintToChatAll(" \x01\x0B\x03%N \x01has picked \x03CT \x01first.", g_capt2);

		new otherTeam = CS_TEAM_T;
		if (hisTeam == CS_TEAM_T)
			otherTeam = CS_TEAM_CT;

		g_Teams[g_capt2] = hisTeam;
		SwitchPlayerTeam(g_capt2, hisTeam);
		g_Teams[g_capt1] = otherTeam;
		SwitchPlayerTeam(g_capt1, otherTeam);
		ServerCommand("mp_restartgame 1");
		CreateTimer(2.0, Timer_GivePlayerSelectionMenu, GetClientSerial(g_capt1));
	} else if (action == MenuAction_End) {
		CloseHandle(menu);
	}
}


public PlayerMenuHandler(Handle:menu, MenuAction:action, param1, param2) {
	if (action == MenuAction_Select) {
		new String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		new UserID = StringToInt(info);
		new client = GetClientOfUserId(UserID);

		if (client > 0) {
			g_Teams[client] = g_Teams[param1];
			SwitchPlayerTeam(client, g_Teams[param1]);
			g_PlayersPicked++;
			if (param1 == g_capt1)
				PrintToChatAll(" \x01\x0B\x02%N \x01has picked \x02%N", param1, client);
			else
				PrintToChatAll(" \x01\x0B\x03%N \x01has picked \x03%N", param1, client);

			if (!IsPickingFinished()) {
				new nextCapt = -1;
				if (param1 == g_capt1)
					nextCapt = g_capt2;
				else
					nextCapt = g_capt1;
				CreateTimer(0.5, MoreMenuPicks, GetClientSerial(nextCapt));
			} else {
				CreateTimer(1.0, FinishPicking);
			}
		} else {
			CreateTimer(0.5, MoreMenuPicks, GetClientSerial(param1));
		}

	} else if (action == MenuAction_Cancel) {
		CreateTimer(0.5, MoreMenuPicks, GetClientSerial(param1));
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
	GivePlayerSelectionMenu(client);
	return Plugin_Handled;
}

public Action:Timer_GivePlayerSelectionMenu(Handle:timer, any:serial) {
	GivePlayerSelectionMenu(GetClientFromSerial(serial));
}

public GivePlayerSelectionMenu(client) {
	new Handle:menu = CreateMenu(PlayerMenuHandler);
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
		if (IsValidClient(client) && g_Teams[client] == CS_TEAM_SPECTATOR && g_Ready[client] && !IsFakeClient(client) && IsClientInGame(client)) {
			IntToString(GetClientUserId(client), user_id, sizeof(user_id));
			GetClientName(client, name, sizeof(name));
			Format(display, sizeof(display), "%s", name);
			AddMenuItem(menu, user_id, display);
			count++;
		}
	}
}

public Action:FinishPicking(Handle:timer) {
	for (new i = 1; i <= MaxClients; i++) {
		if (IsValidClient(i) && !IsFakeClient(i)) {
			g_Ready[i] = false;
			SwitchPlayerTeam(i, g_Teams[i]);
		}
	}
	ServerCommand("exec sourcemod/10man.cfg");
	ServerCommand("mp_unpause_match");
	if (GetConVarInt(g_hAutoLO3) != 0) {
		Command_Start(0, 0); // fake a sm_start command
	}
}

public Action:Command_Start(client, args) {
	if (!g_Active)
		return;

	for (new i = 0; i < 5; i++)
		PrintToChatAll("*** The match will begin shortly - live on 3! ***");
	CreateTimer(7.0, BeginLO3);
}

public OnClientPostAdminCheck(client) {
	g_Teams[client] = CS_TEAM_SPECTATOR;
	g_Ready[client] = false;
	if (IsClientInGame(client) && !IsFakeClient(client) && !g_MatchLive)
		CS_SetClientClanTag(client, "[Not ready]");
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
