#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>

#define PLUGIN					"Bonus_GMCSB"
#define VERSION					"0.0.1"
#define AUTHOR					"shram47&zhorzh78" // credits zhorzh78
#define SetBit(%0,%1)				((%0) |= (1<<(%1)))
#define ClearBit(%0,%1)				((%0) &= ~(1<<(%1)))
#define IsSetBit(%0,%1)				((%0) & (1<<(%1)))
#define InvertBit(%0,%1)			((%0) ^= (1<<(%1)))
#define IsNotSetBit(%0,%1)			(~(%0) & (1<<(%1)))
//#define fm_find_ent_by_class(%0,%1)  		engfunc(EngFunc_FindEntityByString, %0, "classname", %1)

new const g_iClassName[] = { "cb_coin" };
new const g_iClassName_Vip[] = { "cb_coin_vip" };
new const g_iCoinModel[] = { "models/coinsbonus/coin.mdl" };
new const g_iCoinModel_Vip[] = { "models/coinsbonus/coin_vip.mdl" };

enum _:CVARS { COIN_MIN, COIN_MAX, ACCESS[4], COIN_KILL, COIN_VIP};
new g_iTouchForward, gReturn, g_iTouchForward2;
new iBit_Connected, iBit_Access, iBit_Use;
new Float:g_iPos[128][3], g_iPosMax, g_iCoordsList[128], g_iAlreadyCreated[128], EntList[127];
new g_iCvars[CVARS], g_iSayText;
new bool:g_iShowCoins = false;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_touch(g_iClassName, "player", "PickCoin");
	register_touch(g_iClassName_Vip, "player", "PickCoin_Vip");
	register_logevent("Evnt_StartRound", 2, "1=Round_Start");
	register_logevent("Evnt_EndRound", 2, "1=Round_End");
	register_event("TextMsg", "Evnt_EndRound", "a", "2&#Game_C", "2&#Game_w", "2&#Game_will_restart_in")
	register_menucmd(register_menuid("Show_CoinsEdit"), 1023, "Handle_CoinsEdit");
	register_cvar("cb_menu_access", "l");
	register_cvar("cb_coins_max", "3");
	register_cvar("cb_coins_min", "1");
	register_cvar("cb_coins_autoremove", "1");
	register_cvar("cb_coins_vip", "1");
	register_clcmd("cb_edit", "cb_menu");
	g_iSayText = get_user_msgid("SayText");
	g_iTouchForward = CreateMultiForward("cb_touchcoin", ET_CONTINUE, FP_CELL, FP_CELL);
	g_iTouchForward2 = CreateMultiForward("cb_touchcoin_vip", ET_CONTINUE, FP_CELL, FP_CELL);
}

public plugin_precache()
{
	engfunc(EngFunc_PrecacheModel, g_iCoinModel);
	engfunc(EngFunc_PrecacheModel, g_iCoinModel_Vip);
}


public plugin_cfg()
{
	new iCfgDir[64], iCfg[128], iMapName[32] ;
	get_configsdir(iCfgDir, charsmax(iCfgDir)); get_mapname(iMapName, charsmax(iMapName));
	formatex(iCfg, charsmax(iCfg), "%s/CB/config.cfg", iCfgDir);
	formatex(g_iCoordsList, charsmax(g_iCoordsList), "%s/CB/coords/%s.ini", iCfgDir, iMapName);
	if(file_exists(iCfg)) server_cmd("exec %s", iCfg);
	if(file_exists(g_iCoordsList)) Read_Coord_File(g_iCoordsList);
	set_task(0.3, "LoadSettings");
}

public LoadSettings()
{
	g_iCvars[COIN_MAX] = get_cvar_num("cb_coins_max");
	g_iCvars[COIN_MIN] = get_cvar_num("cb_coins_min");
	g_iCvars[COIN_KILL] = get_cvar_num("cb_coins_autoremove");
	g_iCvars[COIN_VIP] = get_cvar_num("cb_coins_vip");
	if(g_iCvars[COIN_MIN] > g_iCvars[COIN_MAX]) set_fail_state("cb_coins_max < cb_coins_min change settings!");
	get_cvar_string("cb_menu_access", g_iCvars[ACCESS], charsmax(g_iCvars[ACCESS]));
}

public Read_Coord_File(szFile[])
{
	new szBuffer[128], iLine, iLen = -1, TmpCoord1[64],TmpCoord2[64], TmpCoord3[64], Count;
	while(read_file(szFile, iLine++, szBuffer, charsmax(szBuffer), iLen))
	{
		if(!iLen || szBuffer[0] == ';' || !szBuffer[0]) continue;
		parse(szBuffer, TmpCoord1, charsmax(TmpCoord1),TmpCoord2, charsmax(TmpCoord2),TmpCoord3, charsmax(TmpCoord3));
		g_iPos[Count][0] = str_to_float(TmpCoord1);
		g_iPos[Count][1] = str_to_float(TmpCoord2);
		g_iPos[Count][2] = str_to_float(TmpCoord3);
		server_print("Pos: %f %f %f", g_iPos[Count][0], g_iPos[Count][1], g_iPos[Count][2]);
		Count++;
	}
	g_iPosMax = Count;
}


public client_putinserver(id)
{
	SetBit(iBit_Connected, id);
	SetBit(iBit_Use, id);
	if(get_user_flags(id) & read_flags(g_iCvars[ACCESS])) SetBit(iBit_Access, id);
}

public client_disconnect(id)
{
	ClearBit(iBit_Connected, id);
	BitClear(iBit_Access, id);
	BitClear(iBit_Use, id);
}

public Create_Coin(Float:origin[3], iVip)
{
	static ent; ent = fm_create_entity("info_target");
	if(!iVip)
	{
		set_pev(ent, pev_classname, g_iClassName);
		engfunc(EngFunc_SetModel, ent, g_iCoinModel);
	}
	else {
		set_pev(ent, pev_classname, g_iClassName_Vip);
		engfunc(EngFunc_SetModel, ent, g_iCoinModel_Vip);
	}
	set_pev(ent,pev_mins,Float:{-10.0,-10.0,0.0});
	set_pev(ent,pev_maxs,Float:{10.0,10.0,20.0});
	set_pev(ent,pev_size,Float:{-10.0, -10.0, 0.0, 10.0, 10.0, 20.0});
	engfunc(EngFunc_SetSize,ent,Float:{-10.0,-10.0,0.0},Float:{10.0,10.0,20.0});
	set_pev(ent,pev_solid, SOLID_TRIGGER);
	set_pev(ent,pev_movetype, MOVETYPE_FLY);
	set_pev(ent, pev_origin, origin);
	set_pev(ent, pev_sequence, 1);
	set_pev(ent, pev_animtime, 1);
	set_pev(ent, pev_framerate, 1.0);
	EntList[g_iPosMax] = ent;
	g_iPos[g_iPosMax] = origin;
	server_print("Orig: %f %f %f", origin[0], origin[1], origin[2]);
	server_print("Pos: %f %f %f", g_iPos[g_iPosMax][0], g_iPos[g_iPosMax][1], g_iPos[g_iPosMax][2]);
	server_print("ent: %d", ent);
}

public CreateCoin(id)
{
	new Float:fOrigin[3], origin[3]; get_user_origin(id, origin, 3);
	IVecFVec(origin, fOrigin);
	g_iPosMax++
	Create_Coin(fOrigin, 0);
}

public DeleteCoin()
{
	if(g_iPosMax <= 0 ) return PLUGIN_HANDLED;
	if(pev_valid(EntList[g_iPosMax])) set_pev(EntList[g_iPosMax], pev_flags, FL_KILLME);
	g_iPosMax--;
	return PLUGIN_CONTINUE;
}

public ShowCoin()
{
	if(!g_iShowCoins)
	{
		for(new i; i <= g_iPosMax; i++) Create_Coin(g_iPos[i], 0);
		g_iShowCoins = true;
	} else {
		new ent = -1;
		while((ent = fm_find_ent_by_class(ent, g_iClassName)))
		{
			if(pev_valid(ent)) set_pev(ent, pev_flags, FL_KILLME);
		}

		g_iShowCoins = false;
	}
}

public SaveCoin()
{
	delete_file(g_iCoordsList);
	new TmpText[128];
	for(new i = 1; i <= g_iPosMax; i++)
	{
		if(!g_iPos[i][0] && !g_iPos[i][1] && !g_iPos[i][2]) continue;
		formatex(TmpText, charsmax(TmpText), "%f %f %f", g_iPos[i][0], g_iPos[i][1], g_iPos[i][2])
		write_file(g_iCoordsList, TmpText, -1);
		server_print("Save: %f %f %f", g_iPos[i][0], g_iPos[i][1], g_iPos[i][2]);
	}
}

public cb_menu(id)
{
	if(IsNotSetBit(iBit_Access, id)) return 0;
	return Show_CoinsEdit(id);
}

public Show_CoinsEdit(id)
{
	static iMenu[512]; new iKey = (1<<3|1<<9), iLen;
	iLen = formatex(iMenu[iLen], charsmax(iMenu) - iLen, "\yМеню создания:^n");
	iLen += formatex(iMenu[iLen], charsmax(iMenu) - iLen, "\dВсего спавнов: %d^n^n", g_iPosMax);
	if(g_iShowCoins)
	{
		iLen += formatex(iMenu[iLen], charsmax(iMenu) - iLen, "\y[1] \wСоздать спавн^n");
		iKey |= (1<<0);
	} else iLen += formatex(iMenu[iLen], charsmax(iMenu) - iLen, "\y[1] \dСоздать спавн^n");
	if(g_iShowCoins)
	{
		iLen += formatex(iMenu[iLen], charsmax(iMenu) - iLen, "\y[2] \wУдалить последний спавн^n");
		iKey |= (1<<1);
	} else iLen += formatex(iMenu[iLen], charsmax(iMenu) - iLen, "\y[2] \dУдалить последний спавн^n");
	if(g_iShowCoins)
	{
		iLen += formatex(iMenu[iLen], charsmax(iMenu) - iLen, "\y[3] \wСохранить текущие спавны^n");
		iKey |= (1<<2);
	} else iLen += formatex(iMenu[iLen], charsmax(iMenu) - iLen, "\y[3] \dСохранить текущие спавны^n");
	iLen += formatex(iMenu[iLen], charsmax(iMenu) - iLen, "\y[4] \r%s \wредактор^n", g_iShowCoins ? "Выкл" : "Вкл");
	iLen += formatex(iMenu[iLen], charsmax(iMenu) - iLen, "^n^n^n^n^n\y[0] \wВыход");
	return show_menu(id, iKey, iMenu, -1, "Show_CoinsEdit");
}

public Handle_CoinsEdit(id, iKey)
{
	switch(iKey)
	{
	case 0: CreateCoin(id);
	case 1: DeleteCoin();
	case 2: SaveCoin();
	case 3: ShowCoin();
	case 9: return PLUGIN_HANDLED;
	}
	return Show_CoinsEdit(id);
}


public PickCoin(ent, id)
{
	if(!pev_valid(ent) || g_iShowCoins || IsNotSetBit(iBit_Connected, id) || IsNotSetBit(iBit_Use, id)) return 0;
	static Float: iToucher[33]; if(iToucher[id] > get_gametime()) return 0;
	ExecuteForward(g_iTouchForward, gReturn, id, ent);
	iToucher[id] = get_gametime();
	return g_iCvars[COIN_KILL] ? set_pev(ent, pev_flags, FL_KILLME) : 0;
}

public PickCoin_Vip(ent, id)
{
	if(!pev_valid(ent) || g_iShowCoins || IsNotSetBit(iBit_Connected, id) || IsNotSetBit(iBit_Use, id)) return 0;
	static Float: iToucher[33]; if(iToucher[id] > get_gametime()) return 0;
	ExecuteForward(g_iTouchForward2, gReturn, id, ent);
	iToucher[id] = get_gametime();
	return g_iCvars[COIN_KILL] ? set_pev(ent, pev_flags, FL_KILLME) : 0;
}

public Evnt_StartRound()
{
	if(g_iShowCoins || g_iShowCoins || !g_iPosMax) return;
	for(new i = g_iCvars[COIN_MIN], iCoord; i < g_iCvars[COIN_MAX]; i++)
	{
		if(iCoord == GetRandomCoord())
		{
			g_iAlreadyCreated[iCoord] = true;
			Create_Coin(g_iPos[iCoord], GetVipPercent(g_iCvars[COIN_VIP]));
		} else i--;
	}

}

public Evnt_EndRound()
{
	if(g_iShowCoins) return; new ent = -1;
	while((ent = fm_find_ent_by_class(ent, g_iClassName)))
	{
		if(pev_valid(ent)) set_pev(ent, pev_flags, FL_KILLME);
	}
	if(g_iCvars[COIN_VIP])
	{
		while((ent = fm_find_ent_by_class(ent, g_iClassName_Vip)))
		{
			if(pev_valid(ent)) set_pev(ent, pev_flags, FL_KILLME);
		}
	}
	for(new i; i < g_iPosMax; i++) g_iAlreadyCreated[i] = false;
}


stock GetRandomCoord()
{
	new iNum = random_num(0, g_iPosMax);
	if(!g_iAlreadyCreated[iNum]) return iNum;  else return 0; return -1;
}

stock GetVipPercent(Percent)
return Percent <= 0 ? 0: Percent >= random_num(1,100) ? 1 : 0

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