#pragma semicolon 1
#include <cstrike>
#include <sourcemod>

#include "include/pugsetup.inc"
#include "pugsetup/generic.sp"

bool g_InPracticeMode = false;


#define OPTION_NAME_LENGTH 128 // length of a setting name
#define CVAR_NAME_LENGTH 64 // length of a cvar

// These data structures maintain a list of settings for a toggle-able option:
// the name, the cvar/value for the enabled option, and the cvar/value for the disabled option.
// Note: the first set of values for these data structures is the overall-practice mode cvars,
// which aren't toggle-able or named.
ArrayList g_BinaryOptionNames;
ArrayList g_BinaryOptionEnabled;
ArrayList g_BinaryOptionChangeable;
ArrayList g_BinaryOptionEnabledCvars;
ArrayList g_BinaryOptionEnabledValues;
ArrayList g_BinaryOptionDisabledCvars;
ArrayList g_BinaryOptionDisabledValues;

public Plugin:myinfo = {
    name = "CS:GO PugSetup: practice mode",
    author = "splewis",
    description = "A relatively simple practice mode that can be laucnehd through the setup menu",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-pug-setup"
};

public void OnPluginStart() {
    LoadTranslations("pugsetup.phrases");
    g_InPracticeMode = false;
    AddChatAlias(".noclip", "noclip");
    AddChatAlias(".god", "god");
}

public void OnMapStart() {
    ReadPracticeSettings();
}

public void OnMapEnd() {
    DisablePracticeMode();
    ClearPracticeSettings();
}

public void ReadPracticeSettings() {
    g_BinaryOptionNames = new ArrayList(OPTION_NAME_LENGTH);
    g_BinaryOptionEnabled = new ArrayList();
    g_BinaryOptionChangeable = new ArrayList();
    g_BinaryOptionEnabledCvars = new ArrayList();
    g_BinaryOptionEnabledValues = new ArrayList();
    g_BinaryOptionDisabledCvars = new ArrayList();
    g_BinaryOptionDisabledValues = new ArrayList();

    char filePath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, filePath, sizeof(filePath), "configs/pugsetup/practicemode.cfg");

    KeyValues kv = new KeyValues("practice_settings");
    if (!kv.ImportFromFile(filePath)) {
        LogError("Failed to import keyvalue from practice config file \"%s\"", filePath);
        delete kv;
        return;
    }

    // Read in the binary options
    if (kv.JumpToKey("binary_options")) {
        if (kv.GotoFirstSubKey()) {
            // read each option
            do {
                char buffer[128];
                kv.GetSectionName(buffer, sizeof(buffer));

                char name[OPTION_NAME_LENGTH];
                kv.GetString("name", name, sizeof(name));

                char enabledString[64];
                kv.GetString("default", enabledString, sizeof(enabledString), "enabled");
                bool enabled = StrEqual(enabledString, "enabled", false);

                bool changeable = (kv.GetNum("changeable", 1) != 0);

                char cvarName[CVAR_NAME_LENGTH];
                char cvarValue[CVAR_NAME_LENGTH];

                // read the enabled cvar list
                ArrayList enabledCvars = new ArrayList(CVAR_NAME_LENGTH);
                ArrayList enabledValues = new ArrayList(CVAR_NAME_LENGTH);
                if (kv.JumpToKey("enabled")) {
                    if (kv.GotoFirstSubKey(false)) {
                        do {
                            kv.GetSectionName(cvarName, sizeof(cvarName));
                            enabledCvars.PushString(cvarName);
                            kv.GetString(NULL_STRING, cvarValue, sizeof(cvarValue));
                            enabledValues.PushString(cvarValue);
                        } while (kv.GotoNextKey(false));
                        kv.GoBack();
                    }
                    kv.GoBack();
                }

                // read the disabled cvar list
                ArrayList disabledCvars = new ArrayList(CVAR_NAME_LENGTH);
                ArrayList disabledValues = new ArrayList(CVAR_NAME_LENGTH);
                if (kv.JumpToKey("disabled")) {
                    if (kv.GotoFirstSubKey(false)) {
                        do {
                            kv.GetSectionName(cvarName, sizeof(cvarName));
                            disabledCvars.PushString(cvarName);
                            kv.GetString(NULL_STRING, cvarValue, sizeof(cvarValue));
                            disabledValues.PushString(cvarValue);
                        } while (kv.GotoNextKey(false));
                        kv.GoBack();
                    }
                    kv.GoBack();
                }

                g_BinaryOptionNames.PushString(name);
                g_BinaryOptionEnabled.Push(enabled);
                g_BinaryOptionChangeable.Push(changeable);
                g_BinaryOptionEnabledCvars.Push(enabledCvars);
                g_BinaryOptionEnabledValues.Push(enabledValues);
                g_BinaryOptionDisabledCvars.Push(disabledCvars);
                g_BinaryOptionDisabledValues.Push(disabledValues);


            } while (kv.GotoNextKey());
        }
    }
    kv.Rewind();

    delete kv;
}

public void ClearPracticeSettings() {
    CloseHandle(g_BinaryOptionNames);
    CloseHandle(g_BinaryOptionEnabled);
    CloseHandle(g_BinaryOptionChangeable);
    CloseNestedArray(g_BinaryOptionEnabledCvars);
    CloseNestedArray(g_BinaryOptionEnabledValues);
    CloseNestedArray(g_BinaryOptionDisabledCvars);
    CloseNestedArray(g_BinaryOptionDisabledValues);
}

public bool OnSetupMenuOpen(int client, Menu menu, bool displayOnly) {
    int style = ITEMDRAW_DEFAULT;
    if (!IsPugAdmin(client) || displayOnly) {
        style = ITEMDRAW_DISABLED;
    }

    if (g_InPracticeMode) {
        GivePracticeMenu(client, style);
        return false;
    } else {
        AddMenuItem(menu, "launch_practice", "Launch practice mode", style);
        return true;
    }
}

public void OnReadyToStart() {
    DisablePracticeMode();
}

public void OnSetupMenuSelect(Menu menu, MenuAction action, int param1, int param2) {
    int client = param1;
    char buffer[64];
    menu.GetItem(param2, buffer, sizeof(buffer));
    if (StrEqual(buffer, "launch_practice")) {
        g_InPracticeMode = !g_InPracticeMode;
        if (g_InPracticeMode) {
            // TODO: I'm not sure if it's possible to force
            // set cheat-protected cvars without this,
            // it'd be nice if it was so this isn't needed.
            SetCvar("sv_cheats", 1);

            for (int i = 0; i < g_BinaryOptionNames.Length; i++) {
                bool enabled = bool:g_BinaryOptionEnabled.Get(i);
                ChangeSetting(i, enabled, false);
            }

            ServerCommand("exec sourcemod/pugsetup/practice_start.cfg");
            GivePracticeMenu(client, ITEMDRAW_DEFAULT);
            PugSetupMessageToAll("Practice mode is now enabled");
        } else {
            ServerCommand("exec sourcemod/pugsetup/practice_end.cfg");
        }
    }
}

static void ChangeSetting(int index, bool enabled, bool print=true) {
    ArrayList cvars = (enabled) ? g_BinaryOptionEnabledCvars.Get(index) : g_BinaryOptionDisabledCvars.Get(index);
    ArrayList values = (enabled) ? g_BinaryOptionEnabledValues.Get(index) : g_BinaryOptionDisabledValues.Get(index);

    char cvar[CVAR_NAME_LENGTH];
    char value[CVAR_NAME_LENGTH];

    for (int i = 0; i < cvars.Length; i++) {
        cvars.GetString(i, cvar, sizeof(cvar));
        values.GetString(i, value, sizeof(value));
        ServerCommand("%s %s", cvar, value);
    }

    char name[OPTION_NAME_LENGTH];
    g_BinaryOptionNames.GetString(index, name, sizeof(name));

    if (print) {
        char enabledString[32];
        GetEnabledString(enabledString, sizeof(enabledString), enabled);

        // don't display empty names
        if (!StrEqual(name, ""))
            PugSetupMessageToAll("%s is now %s", name, enabledString);
    }
}

public void GivePracticeMenu(int client, int style) {
    Menu menu = new Menu(PracticeMenuHandler);
    SetMenuTitle(menu, "Practice Settings");
    SetMenuExitButton(menu, true);

    for (int i = 0; i < g_BinaryOptionNames.Length; i++) {
        if (!g_BinaryOptionChangeable.Get(i))
            continue;

        char name[OPTION_NAME_LENGTH];
        g_BinaryOptionNames.GetString(i, name, sizeof(name));

        char enabled[32];
        GetEnabledString(enabled, sizeof(enabled), g_BinaryOptionEnabled.Get(i), client);

        char buffer[128];
        Format(buffer, sizeof(buffer), "%s: %s", name, enabled);
        AddMenuItem(menu, name, buffer, style);
    }

    AddMenuItem(menu, "end_menu", "Exit practice mode", style);
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int PracticeMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        char buffer[OPTION_NAME_LENGTH];
        menu.GetItem(param2, buffer, sizeof(buffer));

        for (int i = 0; i < g_BinaryOptionNames.Length; i++) {
            char name[OPTION_NAME_LENGTH];
            g_BinaryOptionNames.GetString(i, name, sizeof(name));
            if (StrEqual(name, buffer)) {
                bool setting = !g_BinaryOptionEnabled.Get(i);
                g_BinaryOptionEnabled.Set(i, setting);
                ChangeSetting(i, setting);
                GivePracticeMenu(client, ITEMDRAW_DEFAULT);
                return 0;
            }
        }

        if (StrEqual(buffer, "end_menu")) {
            DisablePracticeMode();
            GiveSetupMenu(client);
        }

    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }

    return 0;
}

public void DisablePracticeMode() {
    for (int i = 0; i < g_BinaryOptionNames.Length; i++) {
        ChangeSetting(i, false, false);
    }

    SetCvar("sv_cheats", 0);
    g_InPracticeMode = false;

    // force turn noclip off for everyone
    for (int i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i))
            SetEntityMoveType(i, MOVETYPE_WALK);
    }

    PugSetupMessageToAll("Practice mode is now disabled.");
}

public void SetCvar(const char[] name, int value) {
    Handle cvar = FindConVar(name);
    if (cvar == INVALID_HANDLE) {
        LogError("cvar \"%s\" could not be found", name);
    } else {
        SetConVarInt(cvar, value);
    }
}
