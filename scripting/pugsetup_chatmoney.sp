#pragma semicolon 1
#include <cstrike>
#include <sourcemod>

#include "include/pugsetup.inc"
#include "pugsetup/generic.sp"

Handle g_hEnabled = INVALID_HANDLE;
int g_iAccount = -1;

public Plugin:myinfo = {
    name = "CS:GO PugSetup: write team money to chat",
    author = "Versatile_BFG/jkroepke",
    description = "Write the teamsmebers money to the chat (like WarMod)",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-pug-setup"
};

public void OnPluginStart() {
    LoadTranslations("pugsetup.phrases");
    g_hEnabled = CreateConVar("sm_pugsetup_chatmoney_enabled", "1", "Whether the plugin is enabled");
    AutoExecConfig(true, "pugsetup_chatmoney", "sourcemod/pugsetup");
    g_iAccount = FindSendPropOffs("CCSPlayer", "m_iAccount");
    HookEvent("round_start", Event_Round_Start);
}

public Event_Round_Start(Handle event, const char[] name, bool dontBroadcast) {
    if (!IsMatchLive() || GetConVarInt(g_hEnabled) == 0)
        return;

    new the_money[MAXPLAYERS + 1];
    new num_players;

    // sort by money
    for (new i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i) && GetClientTeam(i) > 1) {
            the_money[num_players] = i;
            num_players++;
        }
    }

    SortCustom1D(the_money, num_players, SortMoney);

    new String:player_name[64];
    new String:player_money[10];
    new String:has_weapon[1];
    new pri_weapon;

    // display team players money
    for (new i = 1; i <= MaxClients; i++) {
        for (new x = 0; x < num_players; x++) {
            GetClientName(the_money[x], player_name, sizeof(player_name));
            if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == GetClientTeam(the_money[x])) {
                pri_weapon = GetPlayerWeaponSlot(the_money[x], 0);
                if (pri_weapon == -1) {
                    has_weapon = ">";
                } else {
                    has_weapon = "\0";
                }
                IntToMoney(GetEntData(the_money[x], g_iAccount), player_money, sizeof(player_money));
                PrintToChat(i, "\x01$%s \x04%s> \x03%s", player_money, has_weapon, player_name);
            }
        }
    }
}

public SortMoney(elem1, elem2, const array[], Handle:hndl) {
	int money1 = GetEntData(elem1, g_iAccount);
	int money2 = GetEntData(elem2, g_iAccount);

	if (money1 > money2) {
		return -1;
	} else if (money1 == money2) {
    		return 0;
	} else {
		return 1;
	}
}

/**
*  get the comma'd string version of an integer
*
* @param  OldMoney          the integer to convert
* @param  String:NewMoney   the buffer to save the string in
* @param  size              the size of the buffer
* @noreturn
*/

public void IntToMoney(int OldMoney, char[] NewMoney, int size) {
    char Temp[32];
    char OldMoneyStr[32];
    new tempChar;
    int RealLen = 0;

    IntToString(OldMoney, OldMoneyStr, sizeof(OldMoneyStr));

    for (int i = strlen(OldMoneyStr) - 1; i >= 0; i--) {
        if (RealLen % 3 == 0 && RealLen != strlen(OldMoneyStr) && i != strlen(OldMoneyStr)-1) {
            tempChar = OldMoneyStr[i];
            Format(Temp, sizeof(Temp), "%s,%s", tempChar, Temp);
        } else{
            tempChar = OldMoneyStr[i];
            Format(Temp, sizeof(Temp), "%s%s", tempChar, Temp);
        }
        RealLen++;
    }
    Format(NewMoney, size, "%s", Temp);
}