#define PLUGIN_NAME 	"GHOSTMODE RATING"
#define PLUGIN_VERSION 	"0.0.2"

public Plugin myinfo = 
{ 
	name = PLUGIN_NAME, 
	author = "Quake1011",
	description = "Ghostmode rating plugin for CS:GO", 
	version = PLUGIN_VERSION, 
	url = "https://github.com/Quake1011" 
};

Database db;
ArrayList Rating;
ArrayList Scores;
int iMenuPos[MAXPLAYERS+1], iMax = 100;
char aadata[100][256];
int currenttype[MAXPLAYERS+1];

public void OnPluginStart()
{
	Database.Connect(SQLConnectCB, "ghostmode");
	HookEvent("player_death", EventPlayerDeath, EventHookMode_Post);
	RegConsoleCmd("sm_stat", CMDRating);
	LoadTranslations("ghostmode_rating.phrases.txt");
	Rating = CreateArray(256);
	Scores = CreateArray(256);
}

public void SQLConnectCB(Database hdb, const char[] error, any data)
{
	if(!error[0] && hdb != INVALID_HANDLE) 
	{
		db = hdb;
		LogMessage("Ghost rating successfully connected");
		CreateTable();
	}
	else LogMessage("Connecting rating: %s", error);
}


void CreateTable()
{
	char sQuery[512];
	SQL_FormatQuery(db, sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `ghostmode_rating` (\
													`id`     AUTO_INCREMENT,\
													`steam`  VARCHAR (22)   PRIMARY KEY,\
													`nick`   VARCHAR (256),\
													`ghosts` INTEGER (10),\
													`cts`    INTEGER (10))");
	db.Query(SQLCreateTable, sQuery, _, DBPrio_High);
}

public void SQLCreateTable(Database hdb, DBResultSet results, const char[] error, any data)
{
	if(!error[0] && hdb != INVALID_HANDLE) LogMessage("Table successfully created or already exists");
	else LogMessage("Rating tables: %s", error);
}

public Action CMDRating(int client, int args)
{
	if(client > 0 && IsClientInGame(client)) OpenRatingMenu(client);
	return Plugin_Handled;
}

void OpenRatingMenu(int client)
{
	char buffer[256];
	Menu hMenu = CreateMenu(RatingHandler);
	Format(buffer, sizeof(buffer), "%t", "RatingTitle");
	hMenu.SetTitle(buffer);
	Format(buffer, sizeof(buffer), "%t", "GhostTOP");
	hMenu.AddItem("gh", buffer);
	Format(buffer, sizeof(buffer), "%t", "CtsTOP");
	hMenu.AddItem("ct", buffer);
	hMenu.ExitBackButton = true;
	hMenu.ExitButton = true;
	hMenu.Display(client, 0);
}

public int RatingHandler(Menu menu, MenuAction action, int client, int item)
{
	switch(action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select: 
		{
			char info[2][256];
			menu.GetItem(item, info[0], sizeof(info[]), _, info[1], sizeof(info[]));
			if(StrEqual(info[0], "gh")) OutputTop(2, client);
			else if(StrEqual(info[0], "ct")) OutputTop(3, client);
		}
	}
	return 0;
}

void OutputTop(int type, int client)
{
	char sQuery[256];
	DataPack dp = CreateDataPack();
	dp.WriteCell(type);
	dp.WriteCell(client);
	switch(type)
	{
		case 2:	SQL_FormatQuery(db, sQuery, sizeof(sQuery), "SELECT `nick`, `ghosts` FROM `ghostmode_rating` ORDER BY `ghosts` DESC LIMIT 100");
		case 3: SQL_FormatQuery(db, sQuery, sizeof(sQuery), "SELECT `nick`, `cts` FROM `ghostmode_rating` ORDER BY `cts` DESC LIMIT 100");
	}
	db.Query(SQLGetTOPToArray, sQuery, dp, DBPrio_High);
}

public void SQLGetTOPToArray(Database hdb, DBResultSet results, const char[] error, any hdp)
{
	DataPack dp = view_as<DataPack>(hdp);
	dp.Reset();
	int type = dp.ReadCell();
	int client = dp.ReadCell();
	delete dp;
	if(!error[0] && results != INVALID_HANDLE)
	{
		if(results.HasResults && results.RowCount > 0)
		{
			Rating.Clear();
			Scores.Clear();
			for(int i = 0; i < results.RowCount; i++)
			{
				results.FetchRow();
				char temp[256];
				results.FetchString(0, temp, sizeof(temp));
				Rating.PushString(temp);
				Scores.Push(results.FetchInt(1));
			}
			
			OpenTopToMenu(client, type);
			iMenuPos[client] = 1;
		}
	}
	else LogMessage("Error SELECTOR: %s", error);
}

public void OnClientPutInServer(int client)
{
	iMenuPos[client] = 0;
}

void OpenTopToMenu(int client, int type)
{
	char buffer[256];
	for(int i = 0; i < Rating.Length && i < sizeof(aadata); i++)
	{
		Rating.GetString(i, buffer, sizeof(buffer));
		Format(aadata[i], sizeof(aadata[]), "#%d. %s [%i]", i+1, buffer, Scores.Get(i));
		TrimString(aadata[i]);
	}
	Panel hPanel = CreatePanel(INVALID_HANDLE);
	switch(type)
	{
		case 2: Format(buffer, sizeof(buffer), "%t", "GhostTOP");	
		case 3: Format(buffer, sizeof(buffer), "%t", "CtsTOP");
	}
	hPanel.SetTitle(buffer);
	hPanel.DrawItem(" ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	hPanel.DrawText("-----------------------------");
	hPanel.DrawItem(" ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	
	int i = iMenuPos[client] * 10;
	int start = i;
	int end = i + 9;
	
	if(end > iMax) end = iMax;
	
	for(int k = i; k <= end; k++) hPanel.DrawText(aadata[k]);
	
	hPanel.DrawItem(" ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	hPanel.DrawText("-----------------------------");
	hPanel.DrawItem(" ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);

	if(iMenuPos[client])
	{
		hPanel.CurrentKey = 6;
		FormatEx(buffer, sizeof(buffer), "<== (%d - %d)", start - 9, start);
		hPanel.DrawItem(buffer);
	}
	if(end < iMax-1)
	{
		i = end + 11;
		if(i > iMax) i = iMax;
		hPanel.CurrentKey = 7;
		FormatEx(buffer, sizeof(buffer), "==> (%d - %d)", end + 2, i);
		hPanel.DrawItem(buffer);
	}
	hPanel.DrawItem(" ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);	
	hPanel.CurrentKey = 8;
	hPanel.DrawItem("Назад");
	hPanel.CurrentKey = 9;
	hPanel.DrawItem("Выход");
	hPanel.Send(client, PanelHandler, 30);
	currenttype[client] = type;
	delete hPanel;
}

public int PanelHandler(Menu menu, MenuAction action, int client, int item)
{
	switch(item)
	{
		case 6:
		{
			iMenuPos[client]--;
			OpenTopToMenu(client, currenttype[client]);
		}
		case 7:
		{
			iMenuPos[client]++;
			OpenTopToMenu(client, currenttype[client]);
		}
		case 8:
		{
			iMenuPos[client] = 0;
			OpenRatingMenu(client);
		}
		case 9: iMenuPos[client] = 0;
	}
	return 0;
}

public int Handler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:  if(param2 == 3) OpenRatingMenu(param1);
	}
	return 0;
}

public int MenuHandlerRating(Menu menu, MenuAction action, int client, int item)
{
	return 0;
}

public void OnClientPostAdminCheck(int client)
{
	if(!IsFakeClient(client))
	{
		char sQuery[256], auth[22];
		GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
		SQL_FormatQuery(db, sQuery, sizeof(sQuery), "INSERT INTO `ghostmode_rating` (`steam`, `nick`, `ghosts`, `cts`) VALUES ('%s', '%N', 0, 0)", auth, client);
		SQL_FastQuery(db, sQuery);		
	}
}

public void EventPlayerDeath(Event hEvent, const char[] sEvent, bool bdb)
{
	int client = GetClientOfUserId(hEvent.GetInt("attacker"));
	if(0 < client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client))
	{
		if(GetClientTeam(client) == 2) AddKillToDb(client, 2);
		else if(GetClientTeam(client) == 3) AddKillToDb(client, 3);
	}
}

void AddKillToDb(int client, int team)
{
	char sQuery[256], auth[22];
	GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
	switch(team)
	{
		case 2: SQL_FormatQuery(db, sQuery, sizeof(sQuery), "UPDATE `ghostmode_rating` SET `ghosts` = `ghosts`+1 WHERE `steam` = '%s'", auth);
		case 3: SQL_FormatQuery(db, sQuery, sizeof(sQuery), "UPDATE `ghostmode_rating` SET `cts` = `cts`+1 WHERE `steam` = '%s'", auth);
	}
	SQL_FastQuery(db, sQuery);
}
