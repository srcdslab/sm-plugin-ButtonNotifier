#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <clientprefs>
#include <multicolors>
#undef REQUIRE_PLUGIN
#tryinclude <entWatch_core>
#define REQUIRE_PLUGIN

enum NotifyMode
{
	Notify_None = 0,
	Notify_Chat,
	Notify_Console,
	Notify_Both
}

#define TW_TAG "[TW]"
#define TW_ENTITY_MAX 2047
#define TW_ENTITY_ARRAY_SIZE (TW_ENTITY_MAX + 1)
#define TW_CONSOLE_HEADER "--------------------[ Trigger Watcher ]--------------------"
#define TW_CONSOLE_FOOTER "-----------------------------------------------------------"

bool g_bLate = false;
int g_iRoundStartedTime = 0;

bool g_bEntWatch = false;
bool g_bNativeEntWatch = false;

ConVar g_hCVar_SpamDelay;
ConVar g_hCVar_FreezeTime;

Cookie g_hCookie_DisplayType;

enum struct ClientState
{
	NotifyMode buttonsDisplay;
	NotifyMode triggersDisplay;
	int lastButtonUse;
	int waitBeforeButtonUse;
}

ClientState g_ClientState[MAXPLAYERS+1];

bool g_bTriggered[TW_ENTITY_ARRAY_SIZE] = { false, ... };

public Plugin myinfo =
{
	name = "TriggerWatcher",
	author = "Silence, maxime1907, .Rushaway",
	description = "Logs button and trigger presses to the chat.",
	version = "3.2.0",
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("TriggerWatcher.phrases");

	for (int i = 1; i <= MaxClients; i++)
	{
		g_ClientState[i].buttonsDisplay = Notify_Console;
		g_ClientState[i].triggersDisplay = Notify_Console;
		g_ClientState[i].lastButtonUse = -1;
		g_ClientState[i].waitBeforeButtonUse = -1;
	}

	/* CONVARS */
	g_hCVar_SpamDelay = CreateConVar("sm_TriggerWatcher_block_spam_delay", "5", "Time to wait before notifying the next button press (0 = disable spam detection)", FCVAR_NONE, true, 0.0, true, 60.0);
	g_hCVar_FreezeTime = FindConVar("mp_freezetime");

	AutoExecConfig(true);

	/* COOKIES */
	char sCookieMenuTitle[64];
	FormatEx(sCookieMenuTitle, sizeof(sCookieMenuTitle), "%t", "TW_Menu_Cookie");
	SetCookieMenuItem(CookieHandler, 0, sCookieMenuTitle);
	g_hCookie_DisplayType = new Cookie("TriggerWatcher_display", "TriggerWatcher display method", CookieAccess_Private);

	/* HOOKS */
	HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
	
	if (!g_bLate)
		return;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i) || IsFakeClient(i) || !AreClientCookiesCached(i))
			continue;

		ReadClientCookies(i);
	}

	g_bLate = false;
}

public void OnMapStart()
{
	g_iRoundStartedTime = GetTime();
	CreateTimer(1.0, Timer_HookEntities, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnAllPluginsLoaded()
{
	g_bEntWatch = LibraryExists("entWatch-core");
	VerifyNative_EntWatch();
}

public void OnLibraryAdded(const char[] name)
{
	if (strcmp(name, "entWatch-core", false) == 0)
	{
		g_bEntWatch = true;
		VerifyNative_EntWatch();
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (strcmp(name, "entWatch-core", false) == 0)
	{
		g_bEntWatch = false;
		VerifyNative_EntWatch();
	}
}

stock void VerifyNative_EntWatch()
{
	g_bNativeEntWatch = g_bEntWatch && CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "EW_IsEntityItem") == FeatureStatus_Available;
}

public void Event_RoundStart(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	g_iRoundStartedTime = GetTime();

	// Reset values
	for (int i = 1; i <= TW_ENTITY_MAX; i++)
	{
		g_bTriggered[i] = false;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		g_ClientState[i].lastButtonUse = -1;
		g_ClientState[i].waitBeforeButtonUse = -1;
	}
}

public void OnMapEnd()
{
	UnhookEntityOutput("func_button", "OnPressed", ButtonPressed);
	UnhookEntityOutput("func_rot_button", "OnPressed", ButtonPressed);
	UnhookEntityOutput("trigger_once", "OnTrigger", TriggerTouched);
	UnhookEntityOutput("trigger_multiple", "OnStartTouch", TriggerTouched);
	UnhookEntityOutput("trigger_teleport", "OnStartTouch", TriggerTouched);
}

public void OnClientCookiesCached(int client)
{
	ReadClientCookies(client);
}

public void ReadClientCookies(int client)
{
	char sValue[32];
	g_hCookie_DisplayType.Get(client, sValue, sizeof(sValue));

	if (strlen(sValue) >= 2)
	{
		char sTemp[2];
		FormatEx(sTemp, sizeof(sTemp), "%c", sValue[0]);
		g_ClientState[client].buttonsDisplay = ClampNotifyMode(view_as<NotifyMode>(StringToInt(sTemp)));

		FormatEx(sTemp, sizeof(sTemp), "%c", sValue[1]);
		g_ClientState[client].triggersDisplay = ClampNotifyMode(view_as<NotifyMode>(StringToInt(sTemp)));
	}
	else
	{
		// Set default values if no cookie exists or invalid format
		g_ClientState[client].buttonsDisplay = Notify_Console;
		g_ClientState[client].triggersDisplay = Notify_Console;
	}
}

public void SetClientCookies(int client)
{
	char sValue[8];
	FormatEx(sValue, sizeof(sValue), "%d%d", g_ClientState[client].buttonsDisplay, g_ClientState[client].triggersDisplay);
	g_hCookie_DisplayType.Set(client, sValue);
}

public void CookieHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	switch (action)
	{
		case CookieMenuAction_DisplayOption:
		{
			FormatEx(buffer, maxlen, "%T", "TW_Menu_Cookie", client);
		}
		case CookieMenuAction_SelectOption:
		{
			NotifierSetting(client);
		}
	}
}

public void NotifierSetting(int client)
{
	Menu menu = new Menu(NotifierSettingHandler, MENU_ACTIONS_ALL);

	char title[128];
	FormatEx(title, sizeof(title), "%T", "TW_Menu_Title", client);
	menu.SetTitle(title);

	char buttons[64], triggers[64];
	FormatEx(buttons, sizeof(buttons), "%T", "TW_Menu_Buttons", client);
	FormatEx(triggers, sizeof(triggers), "%T", "TW_Menu_Triggers", client);

	menu.AddItem("buttons", buttons);
	menu.AddItem("triggers", triggers);

	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int NotifierSettingHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_DisplayItem:
		{
			char type[32], info[64], display[64];
			menu.GetItem(param2, info, sizeof(info));
			if (strcmp(info, "buttons", false) == 0)
			{
				GetNotifyModeLabel(param1, g_ClientState[param1].buttonsDisplay, type, sizeof(type));
				FormatEx(display, sizeof(display), "%T", "TW_Menu_Buttons_Display", param1, type);
				return RedrawMenuItem(display);
			}
			else if (strcmp(info, "triggers", false) == 0)
			{
				GetNotifyModeLabel(param1, g_ClientState[param1].triggersDisplay, type, sizeof(type));
				FormatEx(display, sizeof(display), "%T", "TW_Menu_Triggers_Display", param1, type);
				return RedrawMenuItem(display);
			}
		}
		case MenuAction_Select:
		{
			char info[64];
			menu.GetItem(param2, info, sizeof(info));
			if (strcmp(info, "buttons", false) == 0)
			{
				g_ClientState[param1].buttonsDisplay = NextNotifyMode(g_ClientState[param1].buttonsDisplay);
				NotifyModeChat(param1, g_ClientState[param1].buttonsDisplay, "TW_Menu_Buttons_Display");
			}
			else if (strcmp(info, "triggers", false) == 0)
			{
				g_ClientState[param1].triggersDisplay = NextNotifyMode(g_ClientState[param1].triggersDisplay);
				NotifyModeChat(param1, g_ClientState[param1].triggersDisplay, "TW_Menu_Triggers_Display");
			}

			SetClientCookies(param1);
			NotifierSetting(param1);
		}
		case MenuAction_Cancel:
		{
			ShowCookieMenu(param1);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

public Action Timer_HookEntities(Handle timer)
{
	HookEntityOutput("func_button", "OnPressed", ButtonPressed);
	HookEntityOutput("func_rot_button", "OnPressed", ButtonPressed);
	HookEntityOutput("trigger_once", "OnTrigger", TriggerTouched);
	HookEntityOutput("trigger_multiple", "OnStartTouch", TriggerTouched);
	HookEntityOutput("trigger_teleport", "OnStartTouch", TriggerTouched);
	return Plugin_Stop;
}

public void TriggerTouched(const char[] output, int caller, int activator, float delay)
{
	if (g_bTriggered[caller] || !IsValidClient(activator))
	{
		return;
	}

	g_bTriggered[caller] = true;

	char entityName[64], className[32];
	int entId;
	GetEntityDetails(caller, entityName, sizeof(entityName), className, sizeof(className), entId);
	NotifyTrigger(activator, entityName, className, entId);
}

public void ButtonPressed(const char[] output, int caller, int activator, float delay)
{
	if (!IsValidClient(activator) || !IsValidEntity(caller))
	{
		return;
	}

#if defined _entWatch_included
	if (g_bNativeEntWatch)
	{
		int parent = GetEntPropEnt(caller, Prop_Data, "m_hParent");
		if (IsValidEntity(parent) && EW_IsEntityItem(parent))
			return;
	}
#endif

	int currentTime = GetTime();

	char entityName[64], className[32];
	int entId;
	GetEntityDetails(caller, entityName, sizeof(entityName), className, sizeof(className), entId);

	// activator (client) is spamming the button
	if (g_hCVar_SpamDelay.IntValue > 0 && g_ClientState[activator].lastButtonUse != -1 && ((currentTime - g_ClientState[activator].lastButtonUse) <= g_hCVar_SpamDelay.IntValue))
	{
		// if the delay time is passed, we reset the time
		if (g_ClientState[activator].waitBeforeButtonUse != -1 && g_ClientState[activator].waitBeforeButtonUse <= currentTime)
		{
			g_ClientState[activator].waitBeforeButtonUse = -1;
		}

		// if everything is okay send a first alert
		if (g_ClientState[activator].waitBeforeButtonUse == -1)
		{
			NotifyButton(activator, entityName, className, entId, true);
			g_ClientState[activator].waitBeforeButtonUse = currentTime + g_hCVar_SpamDelay.IntValue;
		}
	}
	else
	{
		NotifyButton(activator, entityName, className, entId, false);
	}

	g_ClientState[activator].lastButtonUse = currentTime;
}

bool IsValidClient(int client, bool nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}

bool ShouldNotifyClient(int client)
{
	return IsClientConnected(client) && IsClientInGame(client) && (IsClientSourceTV(client) || GetAdminFlag(GetUserAdmin(client), Admin_Generic));
}

void GetEntityDetails(int caller, char[] entityName, int entityNameLen, char[] className, int classNameLen, int &entId)
{
	GetEntPropString(caller, Prop_Data, "m_iName", entityName, entityNameLen);
	GetEdictClassname(caller, className, classNameLen);

	if (entityName[0] == '\0')
	{
		if (StrContains(className, "trigger_", false) == 0)
			strcopy(entityName, entityNameLen, "*unnamed trigger*");
		else if (StrContains(className, "button", false) != -1)
			strcopy(entityName, entityNameLen, "*unnamed button*");
		else
			strcopy(entityName, entityNameLen, "*unnamed entity*");
	}

	entId = caller;
}

int GetCurrentRoundTime()
{
	int freezeTime = 0;
	if (g_hCVar_FreezeTime != null)
		freezeTime = g_hCVar_FreezeTime.IntValue;

	return GameRules_GetProp("m_iRoundTime") - ((GetTime() - g_iRoundStartedTime) - freezeTime);
}

void BuildRoundTimeString(char[] buffer, int maxlen)
{
	int currentRoundTime = GetCurrentRoundTime();
	if (currentRoundTime < 0)
		currentRoundTime = 0;

	int minutes = currentRoundTime / 60;
	int seconds = currentRoundTime - (minutes * 60);
	FormatEx(buffer, maxlen, "%d:%02d", minutes, seconds);
}

void BuildChatPlayerIdentity(int client, char[] buffer, int maxlen)
{
	FormatEx(buffer, maxlen, "%N [#%d]", client, GetClientUserId(client));
}

void BuildConsolePlayerIdentity(int client, char[] buffer, int maxlen)
{
	char steam[64];
	if (!GetClientAuthId(client, AuthId_Steam3, steam, sizeof(steam), false))
		strcopy(steam, sizeof(steam), "unknown");
	else
	{
		ReplaceString(steam, sizeof(steam), "[", "", false);
		ReplaceString(steam, sizeof(steam), "]", "", false);
		ReplaceString(steam, sizeof(steam), "STEAM_", "", false);
	}

	FormatEx(buffer, maxlen, "%N [#%d | %s]", client, GetClientUserId(client), steam);
}

void PrintTriggerWatcher(int target, const char[] phrase, int activator, const char[] entityName, const char[] className, int entId, const char[] roundTime)
{
	char playerInfo[96];
	BuildConsolePlayerIdentity(activator, playerInfo, sizeof(playerInfo));

	if (target == 0)
		PrintToServer("%s\n%T\n%s", TW_CONSOLE_HEADER, phrase, 0, playerInfo, entityName, className, entId, roundTime, TW_CONSOLE_FOOTER);
	else
		PrintToConsole(target, "%s\n%T\n%s", TW_CONSOLE_HEADER, phrase, target, playerInfo, entityName, className, entId, roundTime, TW_CONSOLE_FOOTER);
}

void NotifyTrigger(int activator, const char[] entityName, const char[] className, int entId)
{
	char roundTime[16], playerInfo[96];
	BuildRoundTimeString(roundTime, sizeof(roundTime));
	BuildChatPlayerIdentity(activator, playerInfo, sizeof(playerInfo));

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!ShouldNotifyClient(i))
			continue;

		NotifyMode mode = g_ClientState[i].triggersDisplay;
		if (mode == Notify_Console || mode == Notify_Both)
			PrintTriggerWatcher(i, "TW_Trigger_Console", activator, entityName, className, entId, roundTime);
		if (mode == Notify_Chat || mode == Notify_Both)
			CPrintToChat(i, "%t", "TW_Trigger", TW_TAG, playerInfo, entityName, entId, roundTime);
	}

	PrintTriggerWatcher(0, "TW_Trigger_Console", activator, entityName, className, entId, roundTime);
}

void NotifyButton(int activator, const char[] entityName, const char[] className, int entId, bool isSpam)
{
	char roundTime[16], playerInfo[96];
	BuildRoundTimeString(roundTime, sizeof(roundTime));
	BuildChatPlayerIdentity(activator, playerInfo, sizeof(playerInfo));

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!ShouldNotifyClient(i))
			continue;

		NotifyMode mode = g_ClientState[i].buttonsDisplay;
		if (mode == Notify_Console || mode == Notify_Both)
		{
			if (isSpam)
				PrintTriggerWatcher(i, "TW_Spamming_Console", activator, entityName, className, entId, roundTime);
			else
				PrintTriggerWatcher(i, "TW_Button_Console", activator, entityName, className, entId, roundTime);
		}
		if (mode == Notify_Chat || mode == Notify_Both)
		{
			if (isSpam)
				CPrintToChat(i, "%t", "TW_Spamming", TW_TAG, playerInfo, entityName, entId, roundTime);
			else
				CPrintToChat(i, "%t", "TW_Button", TW_TAG, playerInfo, entityName, entId, roundTime);
		}
	}

	if (isSpam)
		PrintTriggerWatcher(0, "TW_Spamming_Console", activator, entityName, className, entId, roundTime);
	else
		PrintTriggerWatcher(0, "TW_Button_Console", activator, entityName, className, entId, roundTime);
}

NotifyMode ClampNotifyMode(NotifyMode value)
{
	if (value < Notify_None || value > Notify_Both)
		return Notify_Console;

	return value;
}

NotifyMode NextNotifyMode(NotifyMode current)
{
	current++;
	if (current > Notify_Both)
		current = Notify_None;

	return current;
}

void GetNotifyModeLabel(int client, NotifyMode mode, char[] buffer, int maxlen)
{
	switch (mode)
	{
		case Notify_None: FormatEx(buffer, maxlen, "%T", "TW_Mode_None", client);
		case Notify_Chat: FormatEx(buffer, maxlen, "%T", "TW_Mode_Chat", client);
		case Notify_Console: FormatEx(buffer, maxlen, "%T", "TW_Mode_Console", client);
		case Notify_Both: FormatEx(buffer, maxlen, "%T", "TW_Mode_Both", client);
		default: FormatEx(buffer, maxlen, "%T", "TW_Mode_Console", client);
	}
}

void NotifyModeChat(int client, NotifyMode mode, const char[] detailPhrase)
{
	char label[16];
	GetNotifyModeLabel(client, mode, label, sizeof(label));
	char detail[64];
	FormatEx(detail, sizeof(detail), "%T", detailPhrase, client, label);
	CPrintToChat(client, "{red}%s {lightgreen}%s", TW_TAG, detail);
}