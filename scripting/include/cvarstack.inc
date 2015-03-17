#define CVAR_NAME_MAX_LENGTH 255
#define CVAR_VALUE_MAX_LENGTH 255

ArrayList __cvarList;

// Returns a cvar stack Handle that can be used to restore cvars.
stock void SaveCvarsToStack(ArrayList cvarNames) {
    if (__cvarList == null) {
        __cvarList = CreateArray(2);
    }

    ArrayList cvarNameList = new ArrayList(CVAR_NAME_MAX_LENGTH);
    ArrayList cvarValueList = new ArrayList(CVAR_VALUE_MAX_LENGTH);

    char nameBuffer[CVAR_NAME_MAX_LENGTH];
    char valueBuffer[CVAR_VALUE_MAX_LENGTH];
    for (int i = 0; i < cvarNames.Length; i++) {
        cvarNames.GetString(i, nameBuffer, sizeof(nameBuffer));

        Handle cvar = FindConVar(nameBuffer);
        if (cvar == INVALID_HANDLE) {
            LogError("Can't get cvar for name = %s", nameBuffer);
        } else {
            GetConVarString(cvar, valueBuffer, sizeof(valueBuffer));
            cvarNameList.PushString(nameBuffer);
            cvarValueList.PushString(valueBuffer);
        }

    }

    __cvarList.Push(cvarNameList);
    SetArrayCell(__cvarList, __cvarList.Length - 1, cvarValueList, 1);
}

stock int GetCvarStackSize() {
    if (__cvarList == null)
        return 0;
    return __cvarList.Length;
}

// Restores cvars to their previous value after being changed by SetCvars.
stock void RestoreCvarsFromStack() {
    int size = GetArraySize(__cvarList);
    if (size == 0) {
        LogError("Can't restore cvars with an empty stack");
        return;
    }

    int lastIndex = size - 1;

    ArrayList cvarNameList = view_as<ArrayList>(GetArrayCell(__cvarList, lastIndex, 0));
    ArrayList cvarValueList = view_as<ArrayList>(GetArrayCell(__cvarList, lastIndex, 1));

    char name[CVAR_NAME_MAX_LENGTH];
    char value[CVAR_VALUE_MAX_LENGTH];
    for (int i = 0; i < cvarNameList.Length; i++) {
        cvarNameList.GetString(i, name, sizeof(name));
        cvarValueList.GetString(i, value, sizeof(value));

        Handle cvar = FindConVar(name);
        if (cvar == INVALID_HANDLE) {
            LogError("Can't restore value of cvar: %s", name);
        } else {
            SetConVarString(cvar, value);
        }
    }

    CloseHandle(cvarNameList);
    CloseHandle(cvarValueList);
    __cvarList.Erase(lastIndex);
}

// Returns the first "word" in a line, as seperated by whitespace.
static bool __firstWord(const char[] line, char[] buffer, int len) {
    char[] lineBuffer = new char[strlen(line)];
    strcopy(lineBuffer, strlen(line), line);
    TrimString(lineBuffer);
    int splitIndex = StrContains(line, " ");
    if (splitIndex == -1)
        splitIndex = StrContains(line, "\t");

    if (splitIndex == -1) {
        Format(buffer,len,  "");
        return false;
    }

    strcopy(buffer, splitIndex, lineBuffer);
    return true;
}

// Wrapper for SetCvars from an arbitrary file.
// Returns if successful.
stock bool SetCfgCvarsToStack(const char[] cfgFile) {
    char lineBuffer[CVAR_NAME_MAX_LENGTH + CVAR_VALUE_MAX_LENGTH];
    char nameBuffer[CVAR_NAME_MAX_LENGTH];

    char filePath[PLATFORM_MAX_PATH];
    Format(filePath, sizeof(filePath), "cfg/%s", cfgFile);

    File file = OpenFile(filePath, "r");
    if (file != null) {
        ArrayList nameList = new ArrayList(CVAR_NAME_MAX_LENGTH);

        while (!file.EndOfFile() && file.ReadLine(lineBuffer, sizeof(lineBuffer))) {
            if (__firstWord(lineBuffer, nameBuffer, sizeof(nameBuffer))) {
                TrimString(nameBuffer);
                nameList.PushString(nameBuffer);
            } else {
                LogError("Couldn't split cvar name/value for line = %s", lineBuffer);
            }
        }

        SaveCvarsToStack(nameList);
        ServerCommand("exec %s", cfgFile);
        delete nameList;
        delete file;
        return true;
    } else {
        LogError("Failed to open file for reading: %s", filePath);
        return false;
    }
}
