


#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <sqlx>

#define PLUGIN			"Addon_GMCSB"
#define VERSION			"0.0.1"
#define AUTHOR 			"shram47&zhorzh78" // credits zhorzh78

#define SetBit(%0,%1)		((%0) |= (1<<(%1)))
#define ClearBit(%0,%1)		((%0) &= ~(1<<(%1)))
#define IsSetBit(%0,%1)		((%0) & (1<<(%1)))
#define InvertBit(%0,%1)	((%0) ^= (1<<(%1)))
#define IsNotSetBit(%0,%1)	(~(%0) & (1<<(%1)))
#if cellbits == 32
#define OFFSET_CSMONEY  115
#else
#define OFFSET_CSMONEY  140
#endif
forward cb_touchcoin(id, ent);
forward cb_touchcoin_vip(id, ent);

//native csstats by Скальпель
//native csstats_add_user_value(id, ident, value);

//native army ranks by Скальпель
native ar_set_user_realxp(id, addxp);
native ar_add_user_anew(admin, player, anew);

enum _: CVARS { Float:INFORMER_POS_X, Float:INFORMER_POS_Y, INFORMER_COLOR_R, INFORMER_COLOR_G, INFORMER_COLOR_B, COINS_MONEY, COINS_GAME_MONEY, COINS_EXP, COINS_ANEW };
enum _: DATA_QUERY { DB_LOAD, DB_SAVE };

new iBit_Register, iBit_Connected, iBit_Info;
new g_iCvars[CVARS], Handle:MYSQL_Tuple, Handle:MYSQL_Connect, g_iTable[64];
new g_iPlayerMoney[33], g_iSayText, g_iMaxPlayers, g_iMsg_Money;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_cvar("cb_sql_host", "test");
	register_cvar("cb_sql_user", "0");
	register_cvar("cb_sql_password", "0");
	register_cvar("cb_sql_db", "0");
	register_cvar("cb_sql_table", "0");
	register_cvar("cb_informer_x", "0.0");
	register_cvar("cb_informer_y", "0.0");
	register_cvar("cb_informer_r", "0");
	register_cvar("cb_informer_g", "0");
	register_cvar("cb_informer_b", "0");
	register_cvar("cb_coins_money", "0");
	register_cvar("cb_coins_money_from_game", "0");
	register_cvar("cb_ar_exp", "0");
	register_cvar("cb_ar_anew", "0");

	g_iSayText = get_user_msgid("SayText");
	g_iMaxPlayers = get_maxplayers();
	g_iMsg_Money = get_user_msgid("Money");
}


public plugin_cfg()
{
	new iCfgDir[64], iCfgFile[128]; get_configsdir(iCfgDir, charsmax(iCfgDir));
	formatex(iCfgFile, charsmax(iCfgFile), "%s/CB/config_addon.cfg", iCfgDir);
	if(file_exists(iCfgFile)) server_cmd("exec %s", iCfgFile);
	set_task(0.5, "LoadSettings");
}

public LoadSettings()
{
	new szError[512], szErr, szHostname[30], szUsername[30], szPassword[30], szDatabase[30];
	get_cvar_string("cb_sql_host", szHostname, charsmax(szHostname));
	get_cvar_string("cb_sql_user", szUsername, charsmax(szUsername));
	get_cvar_string("cb_sql_password", szPassword, charsmax(szPassword));
	get_cvar_string("cb_sql_db", szDatabase, charsmax(szDatabase));
	get_cvar_string("cb_sql_table", g_iTable, charsmax(g_iTable));

	g_iCvars[INFORMER_POS_X] = _:get_cvar_float("cb_informer_x");
	g_iCvars[INFORMER_POS_Y] = _:get_cvar_float("cb_informer_y");
	g_iCvars[INFORMER_COLOR_R] = get_cvar_num("cb_informer_r");
	g_iCvars[INFORMER_COLOR_G] = get_cvar_num("cb_informer_g");
	g_iCvars[INFORMER_COLOR_B] = get_cvar_num("cb_informer_b");
	g_iCvars[COINS_MONEY] = get_cvar_num("cb_coins_money");
	g_iCvars[COINS_ANEW] = get_cvar_num("cb_ar_anew");
	g_iCvars[COINS_EXP] = get_cvar_num("cb_ar_exp");
	g_iCvars[COINS_GAME_MONEY] = get_cvar_num("cb_coins_money_from_game");

	MYSQL_Tuple = SQL_MakeDbTuple(szHostname, szUsername, szPassword, szDatabase);
	MYSQL_Connect= SQL_Connect(MYSQL_Tuple, szErr, szError, charsmax(szError))
	if(MYSQL_Connect == Empty_Handle) set_fail_state(szError);
	set_task(1.0, "ShowInfo", _, _, _, "b");
}

public client_putinserver(id)
{
	SetBit(iBit_Connected, id);
	SetBit(iBit_Info, id);
	new szQuery[512], iUserSteamid[35], szData[2]; szData[0] = DB_LOAD; szData[1] = id;
	get_user_authid(id, iUserSteamid, charsmax(iUserSteamid));
	formatex(szQuery, charsmax(szQuery), "SELECT * FROM `%s` WHERE `steam_id` = '%s'", g_iTable, iUserSteamid);
	SQL_ThreadQuery(MYSQL_Tuple, "SQL_Handler", szQuery, szData, sizeof(szData));
}

public client_disconnect(id)
{
	ClearBit(iBit_Connected, id);
	if(IsSetBit(iBit_Register, id))
	{
		new szQuery[512], iUserSteamid[35], szData[2]; get_user_authid(id, iUserSteamid, charsmax(iUserSteamid));
		formatex(szQuery, charsmax(szQuery), "UPDATE `%s` SET `shilings` = '%d' WHERE `%s`.`steam_id` = '%s'", g_iTable, g_iPlayerMoney[id], g_iTable, iUserSteamid);
		szData[0] = DB_SAVE; szData[1] = id;
		SQL_ThreadQuery(MYSQL_Tuple, "SQL_Handler", szQuery, szData, sizeof(szData));
		SetBit(iBit_Register, id);
	}
	BitClear(iBit_Info, id);
	g_iPlayerMoney[id] = 0;
}



public cb_touchcoin_vip(id, ent)
{
	if(IsNotSetBit(iBit_Info, id) && IsNotSetBit(iBit_Register, id)) return;
	if(IsNotSetBit(iBit_Register, id))
	{
		ChatColor(id, "!y[!gCoins bonus!y] Бонусы доступны зарегестрированным игрокам!");
		ClearBit(iBit_Info, id);
		return;
	}
	g_iPlayerMoney[id] += g_iCvars[COINS_MONEY];
	ChatColor(id, "!y[!gCoins bonus!y] Вы получили !t%d !yруб на сайт!", g_iCvars[COINS_MONEY]);
	if(pev_valid(ent)) set_pev(ent, pev_flags, FL_KILLME);
}

public cb_touchcoin(id, ent)
{
	if(IsNotSetBit(iBit_Info, id) && IsNotSetBit(iBit_Register, id)) return;
	if(IsNotSetBit(iBit_Register, id))
	{
		ChatColor(id, "!y[!gCoins bonus!y] Бонусы доступны зарегестрированным игрокам!");
		ClearBit(iBit_Info, id);
		return;
	}
	switch(random_num(0, 2))
	{
	case 0:
		{
			fm_cs_set_user_money(id, fm_cs_get_user_money(id) + g_iCvars[COINS_GAME_MONEY]);
			ChatColor(id, "!y[!gCoins bonus!y] Вы получили !t%d$!y!", g_iCvars[COINS_GAME_MONEY]);
		}
	case 1:
		{
			//csstats_add_user_value(id, 20, g_iCvars[COINS_EXP]);
			ar_set_user_realxp(id, g_iCvars[COINS_EXP]);
			ChatColor(id, "!y[!gCoins bonus!y] Вы получили !t%d!y к опыту ArmyRanks!", g_iCvars[COINS_EXP]);
		}
	case 2:
		{
			//csstats_add_user_value(id, 21, g_iCvars[COINS_ANEW]);
			ar_add_user_anew(-1, id, g_iCvars[COINS_ANEW]);	
			ChatColor(id, "!y[!gCoins bonus!y] Вы получили !t%d!y к бонусу anew!", g_iCvars[COINS_ANEW]);
		}
	}
	if(pev_valid(ent)) set_pev(ent, pev_flags, FL_KILLME);
}

public SQL_Handler(iFailState, Handle:sqlQuery, const szError[], iError, const szData[], iDataSize)
{
	switch(iFailState)
	{
	case TQUERY_CONNECT_FAILED:
		{
			SQL_FreeHandle(MYSQL_Tuple);
			log_to_file("Coins_addon.log", "[Error] MySQL connection failed! [%d] %s", iError, szError);
			return;
		}
	case TQUERY_QUERY_FAILED:
		{
			new szLastQuery[512];
			SQL_GetQueryString(sqlQuery, szLastQuery, charsmax(szLastQuery));
			SQL_FreeHandle(sqlQuery);
			log_to_file("Coins_addon.log", "[Error] MySQL query failed! [%d] %s^n[Error] %s", iError, szError, szLastQuery);
			return;
		}
	}
	new id = szData[1], iType = szData[0];
	if(IsNotSetBit(iBit_Connected, id)) return;
	new iResultNum = SQL_NumResults(sqlQuery);
	if(!iResultNum) return;
	switch(iType)
	{
	case DB_LOAD:
		{
			new TmpSteam[35]; SQL_ReadResult(sqlQuery, 22, TmpSteam, charsmax(TmpSteam));
			if(TmpSteam[5] == '_')
			{
				SetBit(iBit_Register, id);
				g_iPlayerMoney[id] = SQL_ReadResult(sqlQuery, 14);
			}
		}
	}
}

public ShowInfo()
{
	set_hudmessage(g_iCvars[INFORMER_COLOR_R], g_iCvars[INFORMER_COLOR_G], g_iCvars[INFORMER_COLOR_B], 
	g_iCvars[INFORMER_POS_X], g_iCvars[INFORMER_POS_Y], 1, 6.0, 1.0, 1.0);
	for(new id = 1; id <= g_iMaxPlayers; id++)
	{
		if(IsNotSetBit(iBit_Connected, id) || IsNotSetBit(iBit_Register, id)) continue;
		show_hudmessage(id, "Ваш баланс: %d руб", g_iPlayerMoney[id]);
	}
}

stock BitClear(iBit, id) if(IsSetBit(iBit, id)) ClearBit(iBit, id);

stock ChatColor(const id, const input[], any:...)
{
	new count = 1, players[32]; static msg[256]; vformat(msg, 255, input, 3);
	replace_all(msg, 255, "!g", "^4"); replace_all(msg, 255, "!y", "^1"); replace_all(msg, 255, "!t", "^3");
	if(id) players[0] = id; else get_players(players, count, "ch");
	for(new i = 0; i < count; i++)
	{
		if(IsSetBit(iBit_Connected, players[i]))
		{
			message_begin(MSG_ONE_UNRELIABLE, g_iSayText, _, players[i]);
			write_byte(players[i]);
			write_string(msg);
			message_end();
		}
	}
}

stock fm_cs_set_user_money(id, money, flash=1)
{
	set_pdata_int(id, OFFSET_CSMONEY, money, 5);
	message_begin(MSG_ONE, g_iMsg_Money, {0,0,0}, id);
	write_long(money);
	write_byte(flash);
	message_end();
}

stock fm_cs_get_user_money(id) return get_pdata_int(id,OFFSET_CSMONEY,5)
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ ansicpg1251\\ deff0\\ deflang1049{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ f0\\ fs16 \n\\ par }
*/
