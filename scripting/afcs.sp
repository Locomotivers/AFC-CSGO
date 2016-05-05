#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <adminmenu>

#include <csgomorecolors>

#pragma newdecls required

#define PLUGIN_VERSION "1.1.2"

#define AFC_MAX_CMD_LENGTH 32

ConVar g_cvTimerIntervalAmmo;
ConVar g_cvTimerIntervalNade;
ConVar g_cvRestockPrim;
ConVar g_cvRestockSecon;

bool g_bUnlimitedAmmo [MAXPLAYERS + 1] = {false, ...};
bool g_bUnlimitedNade [MAXPLAYERS +1] = {false, ...};
bool g_bGod [MAXPLAYERS + 1] = {false, ...};
bool g_bInvi [MAXPLAYERS + 1] = {false, ...};

int g_iActiveOffset = -1;
int g_iClipOneOffset = -1;
int g_iClipTwoOffSet = -1;
int g_iPriAmmoTypeOffset = -1;
int g_iSecAmmoTypeOffset = -1;

public Plugin myinfo =
{
	name = "Advance Fun Commands",
	author = "Locomotiver",
	description = "Rcon only accessible commands with admin menu",
	version		= PLUGIN_VERSION,
	url			= "https://lab.gflclan.com"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("advancefuncommand.phrases");

	CreateConVar("afc_version", PLUGIN_VERSION, "Current version of Advance Fun Commands", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_iActiveOffset = FindSendPropOffs("CAI_BaseNPC", "m_hActiveWeapon");

	g_iClipOneOffset = FindSendPropOffs("CBaseCombatWeapon", "m_iClip1");
	g_iClipTwoOffSet = FindSendPropOffs("CBaseCombatWeapon", "m_iClip2");

	g_iPriAmmoTypeOffset = FindSendPropOffs("CBaseCombatWeapon", "m_iPrimaryAmmoCount");
	g_iSecAmmoTypeOffset = FindSendPropOffs("CBaseCombatWeapon", "m_iSecondaryAmmoCount");

	RegAdminCmd("sm_speed", Command_Speed, ADMFLAG_ROOT, "Changes the speed of the target");
	RegAdminCmd("sm_mspec", Command_MSpec, ADMFLAG_ROOT, "Moves a target into Spectator slot");
	RegAdminCmd("sm_extend", Command_ExtendMap, ADMFLAG_ROOT, "Extends the Map with Certain ammounts of time");
	RegAdminCmd("sm_mcash", Command_MaxCash, ADMFLAG_ROOT, "Set to Maximum cash of the target");
	RegAdminCmd("sm_ammo", Command_Ammo, ADMFLAG_ROOT, "Set the unlimited ammo on the target");
	RegAdminCmd("sm_nade", Command_Nade, ADMFLAG_ROOT, "Set the unlimited nade on the target");
	RegAdminCmd("sm_hp", Command_Health, ADMFLAG_ROOT, "Changes the health of the target");
	RegAdminCmd("sm_god", Command_GodMode, ADMFLAG_ROOT, "God Mode ON!");
	RegAdminCmd("sm_give", Command_GiveWeapon, ADMFLAG_ROOT, "Gives the weapon to the target");
	RegAdminCmd("sm_inv", Command_Invisible, ADMFLAG_ROOT, "Hides the target's player model");
	RegAdminCmd("sm_swap", Command_Swap, ADMFLAG_ROOT, "Swaps the target's team");
	RegAdminCmd("sm_rr", Command_Restart, ADMFLAG_ROOT, "Restart Round");
	RegAdminCmd("sm_respawn", Command_Respawn, ADMFLAG_ROOT, "Respawns the player");

}

public void OnMapStart()
{
	g_cvTimerIntervalAmmo = CreateConVar("afc_rintervalammo", "2", "How often to reset ammo  (in seconds).", _, true, 10.0);
	g_cvTimerIntervalNade = CreateConVar("afc_rintervalnade", "2", "How often to reset nades (in seconds).", _, true, 10.0);
	g_cvRestockPrim = CreateConVar("afc_reprim", "100", "How much primary ammo restocks.", _, true, 5.0, true, 200.0);
	g_cvRestockSecon = CreateConVar("afc_resec", "30", "How much secondary ammo restocks.", _, true, 5.0, true, 40.0);

	Handle hTimerAmmo;
	Handle hTimerNade;

	if (hTimerAmmo != null)
	{
		KillTimer(hTimerAmmo);
	}

	if (hTimerNade != null)
	{
		KillTimer(hTimerNade);
	}

	float fInterval = GetConVarFloat(g_cvTimerIntervalAmmo);
	hTimerAmmo = CreateTimer(fInterval, Timer_Ammos, _, TIMER_REPEAT);
	fInterval = GetConVarFloat(g_cvTimerIntervalNade);
	hTimerNade = CreateTimer(fInterval, Timer_Nade, _, TIMER_REPEAT);
}

public void OnClientDisconnect(int iClient)
{
	g_bUnlimitedAmmo[iClient] = false;
	g_bUnlimitedNade[iClient] = false;
	g_bGod[iClient] = false;
	g_bInvi[iClient] = false;
}

public Action Command_Speed(int iClient, int iArgs)
{
	if (iArgs != 2)
	{
		char sCommandName[AFC_MAX_CMD_LENGTH];

		GetCmdArg(0, sCommandName, sizeof(sCommandName));
		CReplyToCommand(iClient, "%t %t", "AFC_CMSG_TAG", "AFC_CMD_SPEED_USAGE", sCommandName); //[AFC] Usage: sm_speed <target> <multiplier>

		return Plugin_Handled;
	}

	int iTargetCount;
	char sTarget[MAX_NAME_LENGTH];
	int iTargetList[MAXPLAYERS + 1];
	char sTargetName[MAX_NAME_LENGTH];
	bool bTranslateTargetName;

	GetCmdArg(1, sTarget, sizeof(sTarget));
	iTargetCount = ProcessTargetString(sTarget, iClient, iTargetList, sizeof(sTarget), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), bTranslateTargetName);

	if (iTargetCount <= 0)
	{
		ReplyToTargetError(iClient, iTargetCount);

		return Plugin_Handled;
	}

	char sMulti[AFC_MAX_CMD_LENGTH];

	GetCmdArg(2, sMulti, sizeof(sMulti));
	float fMulti = StringToFloat(sMulti);

	for (int iTarget; iTarget < iTargetCount; iTarget++)
	{
		SetEntPropFloat(iTargetList[iTarget], Prop_Data, "m_flLaggedMovementValue", fMulti);
		LogMessage("%N, initiated speed set on to %N with multiplier of %f", iClient, iTarget, fMulti);
	}

	char sActivityTag[16];
	
	Format(sActivityTag, sizeof(sActivityTag), "%t ", "AFC_CMD_TAG");
	
	if (!bTranslateTargetName)
		CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_SPEED_ACTIVITY", sTargetName, sMulti);
	else
		CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_SPEED_ACTIVITY_ML", sTargetName, sMulti);

	return Plugin_Handled;
}

public Action Command_MSpec(int iClient, int iArgs)
{
	if (iArgs != 1)
	{
		char sCommandName[AFC_MAX_CMD_LENGTH];

		GetCmdArg(0, sCommandName, sizeof(sCommandName));
		CReplyToCommand(iClient, "%t %t", "AFC_CMSG_TAG", "AFC_CMD_MSPEC_USAGE", sCommandName); //[AFC] Usage: sm_mspec <target>

		return Plugin_Handled;
	}

	int iTargetCount;
	char sTarget[MAX_NAME_LENGTH];
	int iTargetList[MAXPLAYERS + 1];
	char sTargetName[MAX_NAME_LENGTH];
	bool bTranslateTargetName;

	GetCmdArg(1, sTarget, sizeof(sTarget));
	iTargetCount = ProcessTargetString(sTarget, iClient, iTargetList, sizeof(sTarget), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), bTranslateTargetName);

	if (iTargetCount <= 0)
	{
		ReplyToTargetError(iClient, iTargetCount);

		return Plugin_Handled;
	}

	for (int iTarget; iTarget < iTargetCount; iTarget++)
	{
		ChangeTeam_NoKill(iTargetList[iTarget], 1);
	}

	char sActivityTag[16];
	Format(sActivityTag, sizeof(sActivityTag), "%t ", "AFC_CMD_TAG");
	
	if (!bTranslateTargetName)
		CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_MSPEC_ACTIVITY", sTargetName);
	else
		CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_MSPEC_ACTIVITY_ML", sTargetName);


	return Plugin_Handled;
}

public Action Command_ExtendMap(int iClient, int iArgs)
{
	if (iArgs != 1)
	{
		char sCommandName[AFC_MAX_CMD_LENGTH];

		GetCmdArg(0, sCommandName, sizeof(sCommandName));
		CReplyToCommand(iClient, "%t %t", "AFC_CMSG_TAG", "AFC_CMD_EXM_USAGE", sCommandName); //[AFC] Usage: sm_exm <length>

		return Plugin_Handled;
	}

	char sMins[AFC_MAX_CMD_LENGTH];
	GetCmdArg(1, sMins, sizeof(sMins));

	int iMins = StringToInt(sMins);

	if (iMins == -1)
	{
		CReplyToCommand(iClient, "%t %t", "AFC_CMSG_TAG", "AFC_CMD_EXM_WRONG_INT");
		return Plugin_Handled;
	}
	else
	{
		ExtendMapTimeLimit(iMins * 60);
		CReplyToCommand(iClient, "%t Successfully initiated extension of the map for %i mins.!", "AFC_CMD_TAG", iMins);
		LogMessage("%t %N, initiated extension of the map for %i mins.", "AFC_CMD_TAG", iClient, iMins);
		return Plugin_Handled;
	}
}

public Action Command_MaxCash(int iClient, int iArgs)
{
	if (iArgs != 1)
	{
		char sCommandName[AFC_MAX_CMD_LENGTH];

		GetCmdArg(0, sCommandName, sizeof(sCommandName));
		CReplyToCommand(iClient, "%t %t", "AFC_CMSG_TAG", "AFC_CMD_MCASH_USAGE", sCommandName); //[AFC] Usage: sm_mcash <target>

		return Plugin_Handled;
	}

	int iTargetCount;
	char sTarget[MAX_NAME_LENGTH];
	int iTargetList[MAXPLAYERS + 1];
	char sTargetName[MAX_NAME_LENGTH];
	bool bTranslateTargetName;

	GetCmdArg(1, sTarget, sizeof(sTarget));
	iTargetCount = ProcessTargetString(sTarget, iClient, iTargetList, sizeof(sTarget), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), bTranslateTargetName);

	if (iTargetCount <= 0)
	{
		ReplyToTargetError(iClient, iTargetCount);

		return Plugin_Handled;
	}

	int iCash = 16000;

	for (int iTarget; iTarget < iTargetCount; iTarget++)
	{
			SetEntProp(iTargetList[iTarget], Prop_Send, "m_iAccount", iCash);
			LogMessage("%t %N, gave the money to %N.", "AFC_CMD_TAG", iClient, iTargetList[iTarget]);

	}

	char sActivityTag[16];
	
	Format(sActivityTag, sizeof(sActivityTag), "%t ", "AFC_CMD_TAG");
	
	if (!bTranslateTargetName)
		CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_MCASH_ACTIVITY", sTargetName);
	else
		CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_MCASH_ACTIVITY_ML", sTargetName);

	return Plugin_Handled;
}

public Action Command_Ammo(int iClient, int iArgs)
{
	if (iArgs != 1)
	{
		char sCommandName[AFC_MAX_CMD_LENGTH];

		GetCmdArg(0, sCommandName, sizeof(sCommandName));
		CReplyToCommand(iClient, "%t %t", "AFC_CMSG_TAG", "AFC_CMD_AMMO_USAGE", sCommandName); //[AFC] Usage: sm_ammo <target> <Unlimited Ammo: 0 - OFF | 1 - On>

		return Plugin_Handled;
	}

	int iTargetCount;
	char sTarget[MAX_NAME_LENGTH];
	int iTargetList[MAXPLAYERS + 1];
	char sTargetName[MAX_NAME_LENGTH];
	bool bTranslateTargetName;
	bool bOnSuccess = false;

	GetCmdArg(1, sTarget, sizeof(sTarget));
	iTargetCount = ProcessTargetString(sTarget, iClient, iTargetList, sizeof(sTarget), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), bTranslateTargetName);

	if (iTargetCount <= 0)
	{
		ReplyToTargetError(iClient, iTargetCount);

		return Plugin_Handled;
	}




	for (int iTarget; iTarget < iTargetCount; iTarget++)
	{
		if (!g_bUnlimitedAmmo[iTargetList[iTarget]])
		{
			g_bUnlimitedAmmo[iTargetList[iTarget]] = true;
			LogMessage("%t %N, allowed unlimited ammo to %N!", "AFC_CMD_TAG", iClient, iTargetList[iTarget]);
			bOnSuccess = true;

		}
		else
		{
			g_bUnlimitedAmmo[iTargetList[iTarget]] = false;
			LogMessage("%t %N, disabled unlimited ammo to %N!", "AFC_CMD_TAG", iClient, iTargetList[iTarget]);
			bOnSuccess = false;

		
		}
	}

	char sActivityTag[16];
	
	Format(sActivityTag, sizeof(sActivityTag), "%t ", "AFC_CMD_TAG");

	if (bOnSuccess)
	{
		if (!bTranslateTargetName)
			CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_AMMO_E_ACTIVITY", sTargetName);
		else
			CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_AMMO_E_ACTIVITY_ML", sTargetName);
	}

	else
	{
		if (!bTranslateTargetName)
			CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_AMMO_D_ACTIVITY", sTargetName);
		else
			CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_AMMO_D_ACTIVITY_ML", sTargetName);
	}

	return Plugin_Handled;
}

public Action Command_Nade(int iClient, int iArgs)
{
	if (iArgs != 1)
	{
		char sCommandName[AFC_MAX_CMD_LENGTH];

		GetCmdArg(0, sCommandName, sizeof(sCommandName));
		CReplyToCommand(iClient, "%t %t", "AFC_CMSG_TAG", "AFC_CMD_NADE_USAGE", sCommandName); //[AFC] Usage: sm_nade <target> <Unlimited Nade: 0 - OFF | 1 - On>

		return Plugin_Handled;
	}

	int iTargetCount;
	char sTarget[MAX_NAME_LENGTH];
	int iTargetList[MAXPLAYERS + 1];
	char sTargetName[MAX_NAME_LENGTH];
	bool bTranslateTargetName;
	bool bOnSuccess;

	GetCmdArg(1, sTarget, sizeof(sTarget));
	iTargetCount = ProcessTargetString(sTarget, iClient, iTargetList, sizeof(sTarget), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), bTranslateTargetName);

	if (iTargetCount <= 0)
	{
		ReplyToTargetError(iClient, iTargetCount);

		return Plugin_Handled;
	}

	for (int iTarget; iTarget < iTargetCount; iTarget++)
	{
		if (!g_bUnlimitedNade[iTargetList[iTarget]])
		{
			g_bUnlimitedNade[iTargetList[iTarget]] = true;
			LogMessage("%t %N, allowed unlimited nade to %N!", "AFC_CMD_TAG", iClient, iTargetList[iTarget]);
			bOnSuccess = true;
		}
		else
		{
			g_bUnlimitedNade[iTargetList[iTarget]] = false;
			LogMessage("%t %N, disabled unlimited nade to %N!", "AFC_CMD_TAG", iClient, iTargetList[iTarget]);
			bOnSuccess = false;
		}
	}

	char sActivityTag[16];
	
	Format(sActivityTag, sizeof(sActivityTag), "%t ", "AFC_CMD_TAG");

	if (bOnSuccess)
	{
		if (!bTranslateTargetName)
			CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_NADE_E_ACTIVITY", sTargetName);
		else
			CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_NADE_E_ACTIVITY_ML", sTargetName);
	}

	else
	{
		if (!bTranslateTargetName)
			CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_NADE_D_ACTIVITY", sTargetName);
		else
			CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_NADE_D_ACTIVITY_ML", sTargetName);
	}

	return Plugin_Handled;
}

public Action Timer_Ammos(Handle hTimer)
{
	for (int iClient = 1; iClient < MaxClients; iClient++)
	{
		if(IsClientConnected(iClient) && !IsFakeClient(iClient) && IsClientInGame(iClient) && IsPlayerAlive(iClient) && g_bUnlimitedAmmo[iClient])
		{
			if (GetClientTeam(iClient) == CS_TEAM_CT)
			{
				int iRpri = GetConVarInt(g_cvRestockPrim);
				int iRsec = GetConVarInt(g_cvRestockSecon);
				int iAmmo = GetEntDataEnt2(iClient, g_iActiveOffset);

				if (g_iClipOneOffset != -1 && iAmmo != -1)
					SetEntData(iAmmo, g_iClipOneOffset, iRpri, 4, true);
				if (g_iClipTwoOffSet != -1 && iAmmo != -1)
					SetEntData(iAmmo, g_iClipTwoOffSet, iRsec, 4, true);
				if (g_iPriAmmoTypeOffset != -1 && iAmmo != -1)
					SetEntData(iAmmo, g_iPriAmmoTypeOffset, 300, 4, true);
				if (g_iSecAmmoTypeOffset != -1 && iAmmo != -1)
					SetEntData(iAmmo, g_iSecAmmoTypeOffset, 300, 4, true);
			}
		}
	}
}

public Action Timer_Nade(Handle hTimer)
{
	for (int iClient = 1; iClient < MaxClients; iClient++)
	{
		if(IsClientConnected(iClient) && !IsFakeClient(iClient) && IsClientInGame(iClient) && IsPlayerAlive(iClient) && g_bUnlimitedNade[iClient])
		{
			if (GetClientTeam(iClient) == CS_TEAM_CT)
			{
				if (GetPlayerWeaponSlot(iClient, 3) == -1)
					GivePlayerItem(iClient, "weapon_hegrenade");
			}
		}
	}
}

public Action Command_Health(int iClient, int iArgs)
{
	if (iArgs != 2)
	{
		char sCommandName[AFC_MAX_CMD_LENGTH];

		GetCmdArg(0, sCommandName, sizeof(sCommandName));
		CReplyToCommand(iClient, "%t %t", "AFC_CMSG_TAG", "AFC_CMD_HEALTH_USAGE", sCommandName); //[AFC] Usage: sm_health <target> <HP points>

		return Plugin_Handled;
	}

	int iTargetCount;
	int iTargetList[MAXPLAYERS + 1];
	char sTargetName[MAX_NAME_LENGTH];
	char sTarget[MAX_NAME_LENGTH];
	bool bTranslateTargetName;

	GetCmdArg(1, sTarget, sizeof(sTarget));
	iTargetCount = ProcessTargetString(sTarget, iClient, iTargetList, sizeof(sTarget), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), bTranslateTargetName);

	if (iTargetCount <= 0)
	{
		ReplyToTargetError(iClient, iTargetCount);

		return Plugin_Handled;
	}

	char sHealth [6];

	GetCmdArg(2, sHealth, sizeof(sHealth));
	int iHealth = StringToInt(sHealth);
	LogMessage("string health %s and int health %i", sHealth, iHealth);


	for (int iTarget; iTarget < iTargetCount; iTarget++)
	{
		SetEntProp(iTargetList[iTarget], Prop_Send, "m_iHealth", iHealth);
		LogMessage("%t %N, set the health of %N, to %i!", "AFC_CMD_TAG", iClient, iTargetList[iTarget], iHealth);
	}

	char sActivityTag[16];
	
	Format(sActivityTag, sizeof(sActivityTag), "%t ", "AFC_CMD_TAG");
	
	if (!bTranslateTargetName)
		CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_HEALTH_ACTIVITY", sTargetName, iHealth);
	else
		CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_HEALTH_ACTIVITY_ML", sTargetName, iHealth);


	return Plugin_Handled;
}

public Action Command_GodMode(int iClient, int iArgs)
{
	if (iArgs != 1)
	{
		char sCommandName[AFC_MAX_CMD_LENGTH];

		GetCmdArg(0, sCommandName, sizeof(sCommandName));
		CReplyToCommand(iClient, "%t %t", "AFC_CMSG_TAG", "AFC_CMD_GOD_USAGE", sCommandName); //[AFC] Usage: sm_god <target> <0 Off | 1 On>

		return Plugin_Handled;
	}

	int iTargetCount;
	int iTargetList[MAXPLAYERS + 1];
	char sTargetName[MAX_NAME_LENGTH];
	char sTarget[MAX_NAME_LENGTH];
	bool bTranslateTargetName;
	bool bOnSuccess;

	GetCmdArg(1, sTarget, sizeof(sTarget));

	iTargetCount = ProcessTargetString(sTarget, iClient, iTargetList, sizeof(sTarget), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), bTranslateTargetName);

	if (iTargetCount <= 0)
	{
		ReplyToTargetError(iClient, iTargetCount);

		return Plugin_Handled;
	}

	for (int iTarget; iTarget < iTargetCount; iTarget++)
	{
		if (!g_bGod[iTargetList[iTarget]])
		{
			SetEntProp(iTargetList[iTarget], Prop_Data, "m_takedamage", 2, 1);
			g_bGod[iTargetList[iTarget]] = true;
			LogMessage("%t %N, set the god mode status of %N, to off!", "AFC_CMD_TAG", iClient, iTargetList[iTarget]);
			bOnSuccess = true;
		}
		else
		{
			SetEntProp(iTargetList[iTarget], Prop_Data, "m_takedamage", 0, 1);
			g_bGod[iTargetList[iTarget]] = false;
			LogMessage("%t %N, set the god mode status of %N, to on!", "AFC_CMD_TAG", iClient, iTargetList[iTarget]);
			bOnSuccess = false;
		}
	}

	char sActivityTag[16];
	
	Format(sActivityTag, sizeof(sActivityTag), "%t ", "AFC_CMD_TAG");

	if (bOnSuccess)
	{
		if (!bTranslateTargetName)
			CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_GOD_E_ACTIVITY", sTargetName);
		else
			CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_GOD_E_ACTIVITY_ML", sTargetName);
	}

	else
	{
		if (!bTranslateTargetName)
			CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_GOD_D_ACTIVITY", sTargetName);
		else
			CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_GOD_D_ACTIVITY_ML", sTargetName);
	}


	return Plugin_Handled;
}

public Action Command_GiveWeapon(int iClient, int iArgs)
{
	if (iArgs != 2)
	{
		char sCommandName[AFC_MAX_CMD_LENGTH];
		GetCmdArg(0, sCommandName, sizeof(sCommandName));
		CReplyToCommand(iClient, "%t %t", "AFC_CMSG_TAG", "AFC_CMD_WEAPON_USAGE", sCommandName); //[AFC] Usage: sm_weapon <target> <entity>

		return Plugin_Handled;
	}

	int iTargetCount;
	int iTargetList[MAXPLAYERS + 1];
	char sTargetName[MAX_NAME_LENGTH];
	char sTarget[MAX_NAME_LENGTH];
	bool bTranslateTargetName;

	GetCmdArg(1, sTarget, sizeof(sTarget));
	iTargetCount = ProcessTargetString(sTarget, iClient, iTargetList, sizeof(sTarget), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), bTranslateTargetName);


	if (iTargetCount <= 0)
	{
		ReplyToTargetError(iClient, iTargetCount);

		return Plugin_Handled;
	}

	char sWeapon[AFC_MAX_CMD_LENGTH];
	char sEnt[AFC_MAX_CMD_LENGTH];

	GetCmdArg(2, sWeapon, sizeof(sWeapon));
	CSWeaponID isValidWep = CS_AliasToWeaponID(sWeapon);
	Format(sEnt, sizeof(sEnt), "weapon_%s", sWeapon);

	if (isValidWep == CSWeapon_NONE)
	{
		CReplyToCommand(iClient, "%t %t", "AFC_CMSG_TAG", "AFC_CMD_WEAPON_INVALID", sWeapon); //[AFC] %s not valid weapon.
		return Plugin_Handled;
	}

	for (int iTarget; iTarget < iTargetCount; iTarget++)
	{
		GivePlayerItem(iTargetList[iTarget], sEnt);
		LogMessage("%t %N, gave a %s to %N", "AFC_CMD_TAG", iClient, sWeapon, iTargetList[iTarget]);
	}

	char sActivityTag[16];
	
	Format(sActivityTag, sizeof(sActivityTag), "%t ", "AFC_CMD_TAG");
	
	if (!bTranslateTargetName)
		CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_WEAPON_ACTIVITY", sWeapon, sTargetName);
	else
		CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_WEAPON_ACTIVITY_ML", sWeapon, sTargetName);


	return Plugin_Handled;
}

public Action Command_Invisible(int iClient, int iArgs)
{
	if (iArgs != 1)
	{
		char sCommandName[AFC_MAX_CMD_LENGTH];
		GetCmdArg(0, sCommandName, sizeof(sCommandName));

		CReplyToCommand(iClient, "%t %t", "AFC_CMSG_TAG", "AFC_CMD_INVI_USAGE", sCommandName); //[AFC] Usage: sm_speed <target> <0 OFF | 1 ON>

		return Plugin_Handled;
	}

	int iTargetCount;
	int iTargetList[MAXPLAYERS + 1];
	char sTargetName[MAX_NAME_LENGTH];
	char sTarget[MAX_NAME_LENGTH];
	bool bTranslateTargetName;
	bool bOnSuccess;

	GetCmdArg(1, sTarget, sizeof(sTarget));

	iTargetCount = ProcessTargetString(sTarget, iClient, iTargetList, sizeof(sTarget), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), bTranslateTargetName);

	if (iTargetCount <= 0)
	{
		ReplyToTargetError(iClient, iTargetCount);

		return Plugin_Handled;
	}

	for (int iTarget; iTarget < iTargetCount; iTarget++)
	{
		if (!g_bInvi[iTargetList[iTarget]])
		{
			SetEntityRenderMode(iTargetList[iTarget], RENDER_NONE);
			g_bInvi[iTargetList[iTarget]] = true;
		}
		else
		{
			SetEntityRenderMode(iTargetList[iTarget], RENDER_NORMAL);
			g_bInvi[iTargetList[iTarget]] = false;
		}
	}


	char sActivityTag[16];
	
	Format(sActivityTag, sizeof(sActivityTag), "%t ", "AFC_CMD_TAG");

	if (bOnSuccess)
	{
		if (!bTranslateTargetName)
			CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_INVI_E_ACTIVITY", sTargetName);
		else
			CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_INVI_E_ACTIVITY_ML", sTargetName);
	}

	else
	{
		if (!bTranslateTargetName)
			CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_INVI_D_ACTIVITY", sTargetName);
		else
			CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_INVI_D_ACTIVITY_ML", sTargetName);
	}

	return Plugin_Handled;
}

public Action Command_Swap(int iClient, int iArgs)
{
	if (iArgs != 1)
	{
		char sCommandName[AFC_MAX_CMD_LENGTH];

		GetCmdArg(0, sCommandName, sizeof(sCommandName));
		CReplyToCommand(iClient, "%t %t", "AFC_CMSG_TAG", "AFC_CMD_SWAP_USAGE", sCommandName); //[AFC] Usage: sm_mspec <target>

		return Plugin_Handled;
	}

	int iTargetCount;
	char sTarget[MAX_NAME_LENGTH];
	int iTargetList[MAXPLAYERS + 1];
	char sTargetName[MAX_NAME_LENGTH];
	bool bTranslateTargetName;

	GetCmdArg(1, sTarget, sizeof(sTarget));
	iTargetCount = ProcessTargetString(sTarget, iClient, iTargetList, sizeof(sTarget), COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), bTranslateTargetName);

	if (iTargetCount <= 0)
	{
		ReplyToTargetError(iClient, iTargetCount);

		return Plugin_Handled;
	}

	for (int iTarget; iTarget < iTargetCount; iTarget++)
	{
		SwapPlayer(iTargetList[iTarget]);
		CS_RespawnPlayer(iTargetList[iTarget]);
		LogMessage("%t %N Swapped Team by %N", "AFC_CMD_TAG", iTargetList[iTarget], iClient);
	}

	char sActivityTag[16];
	
	Format(sActivityTag, sizeof(sActivityTag), "%t ", "AFC_CMD_TAG");
	
	if (!bTranslateTargetName)
		CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_WEAPON_ACTIVITY", sTargetName , iClient);
	else
		CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_WEAPON_ACTIVITY_ML", sTargetName, iClient);



	return Plugin_Handled;
}

void SwapPlayer(int iTarget)
{
	switch (GetClientTeam(iTarget))
	{
		case 2 : ChangeTeam_NoKill(iTarget, 3);
		case 3 : ChangeTeam_NoKill(iTarget, 2);
		default: ChangeTeam_NoKill(iTarget, 2);
	}
}

void ChangeTeam_NoKill(int iClient, int iTeam)
{
    if(IsValidClient(iClient))
    {
        int iEntProp = GetEntProp(iClient, Prop_Send, "m_lifeState");
        SetEntProp(iClient, Prop_Send, "m_lifeState", 2);
        ChangeClientTeam(iClient, iTeam);
        SetEntProp(iClient, Prop_Send, "m_lifeState", iEntProp);
    }
}
// team1 2 team2 3
public Action Command_Restart(int iClient, int iArgs)
{
	int iTime = 1;
	ServerCommand("mp_restartgame %d",iTime);

	char sActivityTag[16];
	
	Format(sActivityTag, sizeof(sActivityTag), "%t ", "AFC_CMD_TAG");

	LogMessage("%N, initiated restart round", iClient);
	CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_RESTART");
	return Plugin_Handled;
}

public Action Command_Respawn(int iClient, int iArgs)
{
	if (iArgs != 1)
	{
		char sCommandName[AFC_MAX_CMD_LENGTH];

		GetCmdArg(0, sCommandName, sizeof(sCommandName));
		CReplyToCommand(iClient, "%t %t", "AFC_CMSG_TAG", "AFC_CMD_RESPAWN", sCommandName);

		return Plugin_Handled;
	}

	int iTargetCount;
	char sTarget[MAX_NAME_LENGTH];
	int iTargetList[MAXPLAYERS + 1];
	char sTargetName[MAX_NAME_LENGTH];
	bool bTranslateTargetName;

	GetCmdArg(1, sTarget, sizeof(sTarget));
	iTargetCount = ProcessTargetString(sTarget, iClient, iTargetList, sizeof(sTarget), COMMAND_FILTER_DEAD, sTargetName, sizeof(sTargetName), bTranslateTargetName);

	if (iTargetCount <= 0)
	{
		ReplyToTargetError(iClient, iTargetCount);

		return Plugin_Handled;
	}

	for (int iTarget; iTarget < iTargetCount; iTarget++)
	{
		CS_RespawnPlayer(iTargetList[iTarget]);
		LogMessage("%t %N Resurrected Player by %N", "AFC_CMD_TAG", iTargetList[iTarget], iClient);
	}

	char sActivityTag[16];
	
	Format(sActivityTag, sizeof(sActivityTag), "%t ", "AFC_CMD_TAG");
	
	if (!bTranslateTargetName)
		CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_RESPAWN_ACTIVITY", sTargetName);
	else
		CReplyToCommand(iClient, sActivityTag, "%t" , "AFC_CMD_RESPAWN_ACTIVITY_ML", sTargetName);


	return Plugin_Handled;
}

bool IsValidClient(int iClient, bool bAllowBots = false)
{
    if(!(1 <= iClient <= MaxClients) || !IsClientInGame(iClient) || (IsFakeClient(iClient) && !bAllowBots) || IsClientSourceTV(iClient) || IsClientReplay(iClient))
    {
        return false;
    }
    return true;
}
