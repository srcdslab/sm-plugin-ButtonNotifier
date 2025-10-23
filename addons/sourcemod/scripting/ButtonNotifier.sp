#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <clientprefs>
#include <multicolors>
#undef REQUIRE_PLUGIN
#tryinclude <EntWatch>
#define REQUIRE_PLUGIN

#pragma newdecls required

#define CONSOLE 0
#define CHAT 1

bool g_bLate = false;

ConVar g_cBlockSpam;
ConVar g_cBlockSpamDelay;

Handle g_hPreferences = INVALID_HANDLE;

int g_iButtonsDisplay[MAXPLAYERS+1];
int g_iTriggersDisplay[MAXPLAYERS+1];
int g_ilastButtonUse[MAXPLAYERS+1] = { -1, ... };
int g_iwaitBeforeButtonUse[MAXPLAYERS+1] = { -1, ... };

bool g_bTriggered[2048] = { false, ... };

public Plugin myinfo =
{
	name = "Button & Triggers Notifier",
	author = "Silence, maxime1907, .Rushaway",
	description = "Logs button and trigger presses to the chat.",
	version = "2.1.2",
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	/* CONVARS */
	g_cBlockSpam = CreateConVar("sm_buttonnotifier_block_spam", "1", "Blocks spammers abusing certain buttons", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cBlockSpamDelay = CreateConVar("sm_buttonnotifier_block_spam_delay", "5", "Time to wait before notifying the next button press", FCVAR_NONE, true, 1.0, true, 60.0);

	AutoExecConfig(true);

	/* COOKIES */
	SetCookieMenuItem(CookieHandler, 0, "Buttons Notifier Settings");
	g_hPreferences = RegClientCookie("bn_preferences", "Button and Trigger notification preferences", CookieAccess_Protected);

	/* HOOKS */
	HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
	
	if (!g_bLate)
		return;

	for (int i = 1; i < MaxClients; i++)
	{
		if (!IsClientConnected(i) || IsFakeClient(i) || !AreClientCookiesCached(i))
			continue;

		ReadClientCookies(i);
	}

	g_bLate = false;
}

public void OnMapStart()
{
	CreateTimer(1.0, Timer_HookButtons, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_RoundStart(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	// Reset values
	for (int i = 1; i <= 2047; i++)
	{
		g_bTriggered[i] = false;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		g_ilastButtonUse[i] = -1;
		g_iwaitBeforeButtonUse[i] = -1;
	}
}

public void OnMapEnd()
{
	UnhookEntityOutput("func_button", "OnPressed", ButtonPressed);
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
	GetClientCookie(client, g_hPreferences, sValue, 32);

	if (strlen(sValue) >= 2)
	{
		char sTemp[2];
		FormatEx(sTemp, sizeof(sTemp), "%c", sValue[0]);
		g_iButtonsDisplay[client] = StringToInt(sTemp);

		FormatEx(sTemp, sizeof(sTemp), "%c", sValue[1]);
		g_iTriggersDisplay[client] = StringToInt(sTemp);
	}
	else
	{
		// Set default values if no cookie exists or invalid format
		g_iButtonsDisplay[client] = CONSOLE;
		g_iTriggersDisplay[client] = CONSOLE;
	}
}

public void SetClientCookies(int client)
{
	char sValue[8];
	FormatEx(sValue, sizeof(sValue), "%d%d", g_iButtonsDisplay[client], g_iTriggersDisplay[client]);
	SetClientCookie(client, g_hPreferences, sValue);
}

public void CookieHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	switch (action)
	{
		case CookieMenuAction_SelectOption:
		{
			NotifierSetting(client);
		}
	}
}

public void NotifierSetting(int client)
{
	Menu menu = new Menu(NotifierSettingHandler, MENU_ACTIONS_ALL);

	menu.SetTitle("Buttons - Triggers Notifier Settings");

	char buttons[64], triggers[64];
	FormatEx(buttons, 64, "Buttons");
	FormatEx(triggers, 64, "Triggers");

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
				if (g_iButtonsDisplay[param1] == CONSOLE)
					FormatEx(type, sizeof(type), "Console");
				else
					FormatEx(type, sizeof(type), "Chat");

				FormatEx(display, sizeof(display), "Buttons: %s", type);
				return RedrawMenuItem(display);
			}
			else if (strcmp(info, "triggers", false) == 0)
			{
				if (g_iTriggersDisplay[param1] == CONSOLE)
					FormatEx(type, sizeof(type), "Console");
				else
					FormatEx(type, sizeof(type), "Chat");

				FormatEx(display, sizeof(display), "Triggers: %s", type);
				return RedrawMenuItem(display);
			}
		}
		case MenuAction_Select:
		{
			char info[64];
			menu.GetItem(param2, info, sizeof(info));
			if (strcmp(info, "buttons", false) == 0)
			{
				if (g_iButtonsDisplay[param1] == CONSOLE)
				{
					g_iButtonsDisplay[param1] = CHAT;
					CPrintToChat(param1, "{red}[Button Notifier] {lightgreen}You set display in {blue}Chat");
				}
				else
				{
					g_iButtonsDisplay[param1] = CONSOLE;
					CPrintToChat(param1, "{red}[Button Notifier] {lightgreen}You set display in {blue}Console");
				}
			}
			else if (strcmp(info, "triggers", false) == 0)
			{
				if (g_iTriggersDisplay[param1] == CONSOLE)
				{
					g_iTriggersDisplay[param1] = CHAT;
					CPrintToChat(param1, "{red}[Trigger Notifier] {lightgreen}You set display in {blue}Chat");
				}
				else
				{
					g_iTriggersDisplay[param1] = CONSOLE;
					CPrintToChat(param1, "{red}[Trigger Notifier] {lightgreen}You set display in {blue}Console");
				}
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

public Action Timer_HookButtons(Handle timer)
{
	HookEntityOutput("func_button", "OnPressed", ButtonPressed);
	HookEntityOutput("trigger_once", "OnTrigger", TriggerTouched);
	HookEntityOutput("trigger_multiple", "OnStartTouch", TriggerTouched);
	HookEntityOutput("trigger_teleport", "OnStartTouch", TriggerTouched);
	return Plugin_Stop;
}

public void TriggerTouched(const char[] output, int caller, int activator, float delay)
{
	if (g_bTriggered[caller] || !IsValidClient(activator))
		return;

	g_bTriggered[caller] = true;

	char sClassname[32];
	GetEdictClassname(caller, sClassname, sizeof(sClassname));
	ReplaceString(sClassname, sizeof(sClassname), "trigger_", "", false);

	char entity[64];
	GetEntPropString(caller, Prop_Data, "m_iName", entity, sizeof(entity));

	if (strcmp(entity, "", false) == 0)
		FormatEx(entity, sizeof(entity), "trigger #%d", caller);

	char userid[64];
	GetClientAuthId(activator, AuthId_Steam3, userid, sizeof(userid), false);
	ReplaceString(userid, sizeof(userid), "[", "", true);
	ReplaceString(userid, sizeof(userid), "]", "", true);
	Format(userid, sizeof(userid), "#%d|%s", GetClientUserId(activator), userid);

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i) && (IsClientSourceTV(i) || GetAdminFlag(GetUserAdmin(i), Admin_Generic)))
		{
			if (g_iTriggersDisplay[i] == CONSOLE)
				PrintToConsole(i, "[Notifier - Trigger %s] %N (%s) triggered %s", sClassname, activator, userid, entity);
			else
				CPrintToChat(i, "{red}[Notifier - Trigger %s] {white}%N {red}({grey}%s{red}) {lightgreen}triggered {blue}%s", sClassname, activator, userid, entity);
		}
	}

	PrintToServer("[Trigger Notifier] %N (%s) triggered %s", activator, userid, entity);
}

public void ButtonPressed(const char[] output, int caller, int activator, float delay)
{
#if defined _EntWatch_include
	if (!IsValidClient(activator) || !IsValidEntity(caller) || EntWatch_IsSpecialItem(caller))
#else
	if (!IsValidClient(activator) || !IsValidEntity(caller))
#endif
		return;

	int currentTime = GetTime();

	char entity[64];
	GetEntPropString(caller, Prop_Data, "m_iName", entity, sizeof(entity));

	if (strcmp(entity, "", false) == 0)
		FormatEx(entity, sizeof(entity), "button #%d", caller);

	char userid[64];
	GetClientAuthId(activator, AuthId_Steam3, userid, sizeof(userid), false);
	ReplaceString(userid, sizeof(userid), "[", "", false);
	ReplaceString(userid, sizeof(userid), "]", "", false);
	Format(userid, sizeof(userid), "#%d|%s", GetClientUserId(activator), userid);
	ReplaceString(userid, sizeof(userid), "STEAM_", "", true);

	// activator (client) is spamming the button
	if (g_cBlockSpam.BoolValue && g_ilastButtonUse[activator] != -1 && ((currentTime - g_ilastButtonUse[activator]) <= g_cBlockSpamDelay.IntValue))
	{
		// if the delay time is passed, we reset the time
		if (g_iwaitBeforeButtonUse[activator] != -1 && g_iwaitBeforeButtonUse[activator] <= currentTime)
		{
			g_iwaitBeforeButtonUse[activator] = -1;
		}

		// if everything is okay send a first alert
		if (g_iwaitBeforeButtonUse[activator] == -1)
		{
			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientConnected(i) && IsClientInGame(i) && (IsClientSourceTV(i) || GetAdminFlag(GetUserAdmin(i), Admin_Generic)))
				{
					if (g_iTriggersDisplay[i] == CONSOLE)
						PrintToConsole(i, "[Button Notifier] %N (%s) is spamming %s", activator, userid, entity);
					else
						CPrintToChat(i, "{red}[Button Notifier] {white}%N {red}({grey}%s{red}) {lightgreen}is spamming {blue}%s", activator, userid, entity);
				}
			}

			PrintToServer("[Button Notifier] %N (%s) is spamming %s", activator, userid, entity);
			g_iwaitBeforeButtonUse[activator] = currentTime + g_cBlockSpamDelay.IntValue;
		}
	}
	else
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientConnected(i) && IsClientInGame(i) && (IsClientSourceTV(i) || GetAdminFlag(GetUserAdmin(i), Admin_Generic)))
			{
				if (g_iButtonsDisplay[i] == CONSOLE)
					PrintToConsole(i, "[Button Notifier] %N (%s) triggered %s", activator, userid, entity);
				else
					CPrintToChat(i, "{red}[Button Notifier] {white}%N {red}({grey}%s{red}) {lightgreen}triggered {blue}%s", activator, userid, entity);
			}
		}

		PrintToServer("[Button Notifier] %N (%s) triggered %s", activator, userid, entity);
	}

	g_ilastButtonUse[activator] = currentTime;
}

bool IsValidClient(int client, bool nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}
