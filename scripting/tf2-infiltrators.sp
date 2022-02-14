//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define PLUGIN_VERSION "1.0.0"

#define TEAM_PUBLIC 2
#define TEAM_GOVERNMENT 3

#define NO_ROLE -1

//Includes
#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <misc-colors>

//ConVars

//Globals

Handle g_Hudsync;

int g_TotalRoles;
enum struct Roles
{
	char name[64];
	TFClassType class;
	int render_color[4];
	RenderMode render_mode;

	void Init()
	{
		this.name[0] = '\0';
		this.class = TFClass_Unknown;

		for (int i = 0; i < 4; i++)
			this.render_color[i] = 255;
		
		this.render_mode = RENDER_NORMAL;
	}

	void CreateRole(const char[] name, TFClassType class, int color[4], RenderMode render_mode)
	{
		strcopy(this.name, 64, name);
		this.class = class;

		for (int i = 0; i < 4; i++)
			this.render_color[i] = color[i];
		
		this.render_mode = render_mode;

		g_TotalRoles++;
	}

	void UpdatePlayer(int client)
	{
		if (this.class != TFClass_Unknown)
			TF2_SetPlayerClass(client, this.class);
		
		SetEntityRenderColor(client, this.render_color[0], this.render_color[1], this.render_color[2], this.render_color[3]);
		SetEntityRenderMode(client, this.render_mode);
	}
}

Roles g_Roles[32];

enum struct Role
{
	int client;
	int role;

	void Init(int client)
	{
		this.client = client;
		this.role = NO_ROLE;
	}

	void SetRole(int role)
	{
		this.role = role;
		g_Roles[this.role].UpdatePlayer(this.client);
		CPrintToChat(this.client, "Your role has been set to: %s", g_Roles[this.role].name);
		
		SetHudTextParams(0.2, 0.9, 99999.0, g_Roles[this.role].render_color[0], g_Roles[this.role].render_color[1], g_Roles[this.role].render_color[2], g_Roles[this.role].render_color[3]);
		ShowSyncHudText(this.client, g_Hudsync, "Role: %s", g_Roles[this.role].name);
	}

	void SetRoleByName(const char[] name)
	{
		this.role = GetRoleByName(name);
		g_Roles[this.role].UpdatePlayer(this.client);
	}
}

int GetRoleByName(const char[] name)
{
	for (int i = 0; i < g_TotalRoles; i++)
		if (StrEqual(g_Roles[i].name, name, false))
			return i;
	
	return -1;
}

Role g_Role[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[TF2] Infiltrators", 
	author = "Keith Warren (Drixevel)", 
	description = "A gamemode which pits cops vs robbers.",
	version = PLUGIN_VERSION, 
	url = "https://github.com/drixevel"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	CSetPrefix("[]");

	HookEvent("arena_round_start", Event_OnArenaRoundStart);

	g_Hudsync = CreateHudSynchronizer();

	g_Roles[g_TotalRoles].CreateRole("Commonfolk", TFClass_Unknown, {255, 255, 255, 255}, RENDER_TRANSCOLOR);
	g_Roles[g_TotalRoles].CreateRole("Cops", TFClass_Soldier, {255, 255, 255, 255}, RENDER_TRANSCOLOR);
	g_Roles[g_TotalRoles].CreateRole("Robbers", TFClass_Unknown, {255, 255, 255, 255}, RENDER_TRANSCOLOR);
}

public Action OnClientCommand(int client, int args)
{
	char sCommand[32];
	GetCmdArg(0, sCommand, sizeof(sCommand));

	if (StrEqual(sCommand, "joinclass", false))
	{
		char sClass[32];
		GetCmdArg(1, sClass, sizeof(sClass));
		
		if (StrEqual(sClass, "soldier", false) || StrEqual(sClass, "spy", false))
		{
			EmitGameSoundToClient(client, "Player.UseDeny");
			PrintToChat(client, "You are not allowed to access the %s class.", sClass);
			return Plugin_Stop;
		}
	}

	return Plugin_Continue;
}

public void Event_OnArenaRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	int alive = GetClientAliveCount();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			ChangeClientTeam_Alive(i, TEAM_PUBLIC);
			g_Role[i].SetRoleByName("Commonfolk");
		}
	}
	
	int cops;
	int robbers;

	if (alive < 3)
	{
		cops = 1;
		robbers = 1;
	}
	else if (alive < 6)
	{
		cops = 1;
		robbers = 2;
	}
	else if (alive < 12)
	{
		cops = 2;
		robbers = 3;
	}
	else if (alive < 24)
	{
		cops = 3;
		robbers = 5;
	}
	else if (alive < 32)
	{
		cops = 3;
		robbers = 7;
	}

	int client;

	int cop = GetRoleByName("Cops");
	int robber = GetRoleByName("Robbers");

	for (int i = 0; i < cops; i++)
	{
		client = GetRandomClient(true, true, false, TEAM_PUBLIC);
		g_Role[client].SetRole(cop);
	}

	for (int i = 0; i < robbers; i++)
	{
		client = GetRandomClient(true, true, false, TEAM_PUBLIC);
		g_Role[client].SetRole(robber);
	}
}

bool ChangeClientTeam_Alive(int client, int team)
{
	if (client == 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client) || team < 2 || team > 3)
		return false;

	int lifestate = GetEntProp(client, Prop_Send, "m_lifeState");
	SetEntProp(client, Prop_Send, "m_lifeState", 2);
	ChangeClientTeam(client, team);
	SetEntProp(client, Prop_Send, "m_lifeState", lifestate);
	
	return true;
}

int GetClientAliveCount()
{
	int count;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsClientSourceTV(i) || !IsPlayerAlive(i))
			continue;

		count++;
	}

	return count;
}

int GetRandomClient(bool ingame = true, bool alive = false, bool fake = false, int team = 0)
{
	int[] clients = new int[MaxClients];
	int amount;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (ingame && !IsClientInGame(i) || alive && !IsPlayerAlive(i) || !fake && IsFakeClient(i) || team > 0 && team != GetClientTeam(i))
			continue;

		clients[amount++] = i;
	}

	return (amount == 0) ? -1 : clients[GetRandomInt(0, amount - 1)];
}