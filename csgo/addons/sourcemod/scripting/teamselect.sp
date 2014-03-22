#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <adminmenu>

new Handle:g_Enabled = INVALID_HANDLE;
new g_cap1 = 0;
new g_cap2 = 0;
new g_PlayersLeft = 8;
new g_Teams[MAXPLAYERS+1];
new g_MatchLive = false;
new String:g_demoname[PLATFORM_MAX_PATH];

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
	g_Enabled = CreateConVar("teamselect_enabled", "1", "Sets whether teamselect is enabled");

	// Create and exec plugin's configuration file
	AutoExecConfig(true, "teamselect");

	if (GetConVarInt(g_Enabled) == 1) {
		RegAdminCmd("sm_capt1", Command_Cap1, ADMFLAG_CUSTOM1);
		RegAdminCmd("sm_capt2", Command_Cap2, ADMFLAG_CUSTOM1);
		RegAdminCmd("sm_startgame", Command_StartPicking, ADMFLAG_CUSTOM1);
		RegAdminCmd("sm_pick", Command_StartPicking, ADMFLAG_CUSTOM1);
		RegAdminCmd("sm_endgame", Command_EndMatch, ADMFLAG_CUSTOM1);
		HookEvent("cs_win_panel_match", Event_MatchOver);
	}
}

public OnMapStart() {
	g_MatchLive = false;
}

public OnMapEnd() {
}

public Action:Event_MatchOver(Handle:event, const String:name[], bool:dontBroadcast) {
	EndMatch();
	return Plugin_Continue;
}

public Action:Command_EndMatch(client, args) {
	EndMatch();
}

public EndMatch() {
	g_MatchLive = false;
	ServerCommand("sv_alltalk 1");
	ServerCommand("tv_stoprecord");
}

public Action:Command_Cap1(client, args) {
	if (g_MatchLive)
		return Plugin_Handled;

	new String:arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	new target = FindTarget(client, arg1);
	if (target == -1) {
		ReplyToCommand(client, "Invalid captain1 - try again");
		return Plugin_Handled;
	}
	g_cap1 = target;
	PrintToChatAll("Captain 1 is %N", g_cap1);
	return Plugin_Handled;
}

public Action:Command_Cap2(client, args) {
	if (g_MatchLive)
		return Plugin_Handled;

	new String:arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	new target = FindTarget(client, arg1);
	if (target == -1) {
		ReplyToCommand(client, "Invalid captain2 - try again");
		return Plugin_Handled;
	}
	g_cap2 = target;
	PrintToChatAll("Captain 2 is %N", g_cap2);
	return Plugin_Handled;
}

public Action:Command_StartPicking(client, args) {
	if (g_MatchLive)
		return Plugin_Handled;

	if (!IsValidClient(g_cap1) || !IsValidClient(g_cap2) && g_cap1 != g_cap2) {
		PrintToChatAll("Captains have not been selected yet!");
		return Plugin_Handled;
	}

	ServerCommand("mp_pause_match");
	ServerCommand("mp_restartgame 1");
	PrintToChatAll("Team selection has begun!");

	for (new i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i)) {
			g_Teams[i] = CS_TEAM_SPECTATOR;
			SwitchPlayerTeam(i, CS_TEAM_SPECTATOR);
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
			SwitchPlayerTeam(client, g_Teams[param1]);
			if (g_PlayersLeft > 0) {
				new nextCapt = -1;
				if (param1 == g_cap1)
					nextCapt = g_cap2;
				else
					nextCapt = g_cap1;
				CreateTimer(0.5, MoreMenuPicks, GetClientSerial(nextCapt));
			} else {
				CreateTimer(1.0, FinishPicking);
			}
		}

	} else if (action == MenuAction_Cancel) {
		CreateTimer(0.5, MoreMenuPicks, param2);
	} else if (action == MenuAction_End) {
		CloseHandle(menu);
	}
}

public Action:MoreMenuPicks(Handle:timer, any:serial) {
	new client = GetClientFromSerial(serial);
	if (!IsValidClient(client) || !IsClientInGame(client)) {
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
			Format(display, sizeof(display), "%s (%s)", name, user_id);
			AddMenuItem(menu, user_id, display);
			count++;
		}
	}
	g_PlayersLeft = count;
	if (g_PlayersLeft > 8)
		g_PlayersLeft = 8;
}

public Action:FinishPicking(Handle:timer) {
	new time = GetTime();
	decl String:timestamp[128];
	FormatTime(timestamp, sizeof(timestamp), "%F_%H.%M", time);
	decl String:map[256];
	GetCurrentMap(map, sizeof(map));
	// Strip workshop prefixes
	decl String:strs[3][256];
	new numStrs = ExplodeString(map, "/", strs, 3, 256);
	Format(g_demoname, sizeof(g_demoname), "%s_%s", timestamp, strs[numStrs - 1]);
	ServerCommand("tv_record %s.dem\n", g_demoname);

	CreateTimer(7.0, Rest1);
	ServerCommand("exec sourcemod/10man.cfg");
	ServerCommand("mp_unpause_match");
	PrintToChatAll("The match will begin shortly - live on 3!");
}

public OnClientConnected(client) {
	ResetClientVariables(client);
}

ResetClientVariables(client) {
	if (IsClientInGame(client))
		g_Teams[client] = CS_TEAM_SPECTATOR;
}

SwitchPlayerTeam(client, team) {
	#if _DEBUG
	Format(dmsg, sizeof(dmsg), "[SwitchPlayerTeam] %N is being switched to team %i", client, team);
	DebugMessage(dmsg);
	#endif

	if (team > CS_TEAM_SPECTATOR) {
		CS_SwitchTeam(client, team);
		CS_UpdateClientModel(client);
		CS_RespawnPlayer(client);
	} else {
		ChangeClientTeam(client, team);
	}
}

public Action:Rest1(Handle:timer) {
	PrintToChatAll("Restart 1/3");
	ServerCommand("mp_restartgame 1");
	CreateTimer(3.0, Rest2);
}

public Action:Rest2(Handle:timer) {
	PrintToChatAll("Restart 2/3");
	ServerCommand("mp_restartgame 3");
	CreateTimer(6.0, Rest3);
}

public Action:Rest3(Handle:timer) {
	PrintToChatAll("Restart 3/3");
	ServerCommand("mp_restartgame 5");
	CreateTimer(7.0, Match);
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
