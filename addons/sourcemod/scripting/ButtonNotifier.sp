#pragma semicolon 1

#include <sourcemod>
#include <multicolors>
#include <sdktools>
#include <entWatch>
#include <cstrike>

#pragma newdecls required

#define VERSION "1.0"

ConVar g_cBlockSpam;
ConVar g_cBlockSpamDelay;
ConVar g_cPrintType;

int g_ilastButtonUse[MAXPLAYERS+1] = { -1, ... };
int g_iwaitBeforeButtonUse[MAXPLAYERS+1] = { -1, ... };

public Plugin myinfo =
{
	name = "Button Notifier",
	author = "Silence, maxime1907",
	description = "Logs button and trigger presses to the chat.",
	version = VERSION,
	url = ""
};

public void OnPluginStart()
{
	g_cBlockSpam = CreateConVar("sm_buttonnotifier_block_spam", "1", "Blocks spammers abusing certain buttons", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cBlockSpamDelay = CreateConVar("sm_buttonnotifier_block_spam_delay", "5", "Time to wait before notifying the next button press", FCVAR_NONE, true, 1.0, true, 60.0);
	g_cPrintType = CreateConVar("sm_buttonnotifier_print_type", "0", "Print type of button. (0 = chat, 1 = console, 2 = server)", FCVAR_NONE, true, 0.0, true, 2.0);

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

public Action Timer_HookButtons(Handle timer)
{
	HookEntityOutput("func_button", "OnPressed", ButtonPressed);
	HookEntityOutput("trigger_once", "OnTrigger", TriggerTouched);
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
	if (!GetClientAuthId(activator, AuthId_Steam2, userid, sizeof(userid)))
		Format(userid, sizeof(userid), "#%d", userid);

	if (g_cPrintType.IntValue == 1)
		PrintToConsoleAll("[Trigger] %N [%s] triggered %s", activator, userid, entity);
	else if (g_cPrintType.IntValue == 2)
		PrintToServer("[Trigger] %N [%s] triggered %s", activator, userid, entity);
	else
		CPrintToChatAll("{darkred}[Trigger] {green}%N [{lightgreen}%s{green}] triggered {darkblue}%s", activator, userid, entity);
}

public void ButtonPressed(const char[] output, int caller, int activator, float delay)
{
	if (!IsValidClient(activator) || EntWatch_IsSpecialItem(activator))
		return;

	int currentTime = GetTime();

	char entity[64];
	GetEntPropString(caller, Prop_Data, "m_iName", entity, sizeof(entity));

	if (StrEqual(entity, "", true))
		Format(entity, sizeof(entity), "button #%d", caller);

	char userid[64];
	if (!GetClientAuthId(activator, AuthId_Steam2, userid, sizeof(userid)))
		Format(userid, sizeof(userid), "#%d", userid);

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
			if (g_cPrintType.IntValue != 2)
			{
				for(int i = 1; i <= MaxClients; i++)
				{
					if(IsClientConnected(i) && IsClientInGame(i) && (IsClientSourceTV(i) || GetAdminFlag(GetUserAdmin(i), Admin_Generic)))
					{
						if (g_cPrintType.IntValue == 1)
							PrintToConsole(i, "[Button] %N [%s] is spamming %s", activator, userid, entity);
						else
							CPrintToChat(i, "{darkred}[Button] {green}%N [{lightgreen}%s{green}] is spamming {darkblue}%s", activator, userid, entity);
					}
				}
			}
			else
			{
				PrintToServer("[Button] %N [%s] is spamming %s", activator, userid, entity);
			}
			g_iwaitBeforeButtonUse[activator] = currentTime + g_cBlockSpamDelay.IntValue;
		}
	}
	else
	{
		if (g_cPrintType.IntValue == 1)
			PrintToConsoleAll("[Button] %N [%s] triggered %s", activator, userid, entity);
		else if (g_cPrintType.IntValue == 2)
			PrintToServer("[Button] %N [%s] triggered %s", activator, userid, entity);
		else
			CPrintToChatAll("{darkred}[Button] {green}%N [{lightgreen}%s{green}] triggered {darkblue}%s", activator, userid, entity);
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