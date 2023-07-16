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

#define CHAT 1
#define CONSOLE 2

ConVar g_cBlockSpam;
ConVar g_cBlockSpamDelay;

Handle g_hButtons = INVALID_HANDLE;
Handle g_hTriggers = INVALID_HANDLE;

int g_iButtonsDisplay[MAXPLAYERS+1];
int g_iTriggersDisplay[MAXPLAYERS+1];
int g_ilastButtonUse[MAXPLAYERS+1] = { -1, ... };
int g_iwaitBeforeButtonUse[MAXPLAYERS+1] = { -1, ... };

public Plugin myinfo =
{
	name = "Button Notifier",
	author = "Silence, maxime1907, .Rushaway",
	description = "Logs button and trigger presses to the chat.",
	version = "2.0",
	url = ""
};

public void OnPluginStart()
{
	/* CONVARS */
	g_cBlockSpam = CreateConVar("sm_buttonnotifier_block_spam", "1", "Blocks spammers abusing certain buttons", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cBlockSpamDelay = CreateConVar("sm_buttonnotifier_block_spam_delay", "5", "Time to wait before notifying the next button press", FCVAR_NONE, true, 1.0, true, 60.0);

	/* COOKIES */
	SetCookieMenuItem(CookieHandler, 0, "Buttons Notifier Settings");
	g_hButtons = RegClientCookie("bn_buttons_type", "ZLeader Marker Position", CookieAccess_Protected);
	g_hTriggers = RegClientCookie("bn_triggers_type", "ZLeader Marker Position", CookieAccess_Protected);
	
	/* Late load */
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsClientConnected(i))
			OnClientPutInServer(i);
	}

	AutoExecConfig(true);
}

public void OnMapStart()
{
	CreateTimer(1.0, Timer_HookButtons);
}

public void OnMapEnd()
{
	UnhookEntityOutput("func_button", "OnPressed", ButtonPressed);
	UnhookEntityOutput("trigger_once", "OnTrigger", TriggerTouched);
}

public void OnClientPutInServer(int client)
{
	if (AreClientCookiesCached(client))
		ReadClientCookies(client);
}

public void OnClientDisconnect(int client)
{
	SetClientCookies(client);
}

public void OnClientCookiesCached(int client)
{
	ReadClientCookies(client);
}

public void ReadClientCookies(int client)
{
	char sValue[32];
	GetClientCookie(client, g_hButtons, sValue, 32);
	if (sValue[0] != '\0')
		g_iButtonsDisplay[client] = StringToInt(sValue);
	else
		g_iButtonsDisplay[client] = CONSOLE;

	GetClientCookie(client, g_hTriggers, sValue, 32);
	if (sValue[0] != '\0')
		g_iTriggersDisplay[client] = StringToInt(sValue);
	else
		g_iTriggersDisplay[client] = CONSOLE;
}

public void SetClientCookies(int client)
{
	char sValue[8];

	Format(sValue, sizeof(sValue), "%i", g_iButtonsDisplay[client]);
	SetClientCookie(client, g_hButtons, sValue);

	Format(sValue, sizeof(sValue), "%i", g_iTriggersDisplay[client]);
	SetClientCookie(client, g_hTriggers, sValue);
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
	Format(buttons, 64, "Buttons");
	Format(triggers, 64, "Triggers");

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
			if (StrEqual(info, "buttons"))
			{
				if (g_iButtonsDisplay[param1] == CONSOLE)
					Format(type, sizeof(type), "Console");
				else
					Format(type, sizeof(type), "Chat");

				Format(display, sizeof(display), "Buttons: %s", type);
				return RedrawMenuItem(display);
			}
			else if (StrEqual(info, "triggers"))
			{
				if (g_iTriggersDisplay[param1] == CONSOLE)
					Format(type, sizeof(type), "Console");
				else
					Format(type, sizeof(type), "Chat");

				Format(display, sizeof(display), "Triggers: %s", type);
				return RedrawMenuItem(display);
			}
		}
		case MenuAction_Select:
		{
			char info[64];
			menu.GetItem(param2, info, sizeof(info));
			if (StrEqual(info, "buttons"))
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
			else if (StrEqual(info, "triggers"))
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
	return Plugin_Stop;
}

public void TriggerTouched(const char[] output, int caller, int activator, float delay)
{
	if (!IsValidClient(activator))
		return;

	char entity[64];
	GetEntPropString(caller, Prop_Data, "m_iName", entity, sizeof(entity));

	if (StrEqual(entity, "", true))
		Format(entity, sizeof(entity), "trigger #%d", caller);

	char userid[64];
	GetClientAuthId(activator, AuthId_Steam2, userid, sizeof(userid));
	Format(userid, sizeof(userid), "#%d|%s", GetClientUserId(activator), userid);
	ReplaceString(userid, sizeof(userid), "STEAM_", "", true);

	for (int i = 1; i <= MaxClients; i++) {
		if(IsClientConnected(i) && IsClientInGame(i) && (IsClientSourceTV(i) || GetAdminFlag(GetUserAdmin(i), Admin_Generic)))
		{
			if (g_iTriggersDisplay[i] == CONSOLE)
				PrintToConsole(i, "[Trigger Notifier] %N (%s) triggered %s", activator, userid, entity);
			else
				CPrintToChat(i, "{red}[Trigger Notifier] {white}%N {red}({grey}%s{red}) {lightgreen}triggered {blue}%s", activator, userid, entity);
		}
	}

	PrintToServer("[Trigger Notifier] %N (%s) triggered %s", activator, userid, entity);
}

public void ButtonPressed(const char[] output, int caller, int activator, float delay)
{
#if defined _EntWatch_include
	if (!IsValidClient(activator) || !IsValidEntity(caller) || EntWatch_IsSpecialItem(activator))
#else
	if (!IsValidClient(activator) || !IsValidEntity(caller))
#endif
		return;

	int currentTime = GetTime();

	char entity[64];
	GetEntPropString(caller, Prop_Data, "m_iName", entity, sizeof(entity));

	if (StrEqual(entity, "", true))
		Format(entity, sizeof(entity), "button #%d", caller);

	char userid[64];
	GetClientAuthId(activator, AuthId_Steam2, userid, sizeof(userid));
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
