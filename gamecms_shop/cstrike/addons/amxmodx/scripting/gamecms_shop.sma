#include <amxmodx>
#include <cstrike>
#include <fakemeta_util>
#include <hamsandwich>
#include <gamecms>

#define ARMY_RANKS
#if defined ARMY_RANKS
	#include <army_ranks_ultimate>
	#define set_user_exp	ar_set_user_addxp
#endif
//#define AES
#if defined AES
	#include <aes_main>
	#define set_user_exp	aes_add_player_exp
#endif
		
#if AMXX_VERSION_NUM < 183
	#include <colorchat>
#endif

#define PLUGIN "GameCMS_Shop"
#define VERSION "2.1"
#define AUTHOR "zhorzh78"

#define MAX_PLAYERS 32
#define is_valid_player(%1)	(1 <= %1 <= MAX_PLAYERS)

#define BIT_ADD(%1,%2)		(%1 |= (1 << (%2 & 31)))
#define BIT_VALID(%1,%2)	(%1 & (1 << (%2 & 31)))
#define BIT_SUB(%1,%2)		(%1 &= ~(1 << (%2 & 31)))

#define m_LastHitGroup	75
#define c_round			3		//с какого раунда доступно меню

#define GOLD
#if defined GOLD
	#define MAX_ITEM_TYPES          6
	#define m_linux_entity          4
	#define m_pPlayer               41
	
	new const m_rgpPlayerItems[MAX_ITEM_TYPES] = {34, 35, ...}

	new V_AK[]    = "models/gold/v_ak47_gold.mdl" 
	new P_AK[]    = "models/gold/p_ak47_gold.mdl" 
	new W_AK[]    = "models/gold/w_ak47_gold.mdl"

	new V_M4[]    = "models/gold/v_m4a1_gold.mdl" 
	new P_M4[]    = "models/gold/p_m4a1_gold.mdl" 
	new W_M4[]    = "models/gold/w_m4a1_gold.mdl"

	new V_AWP[]    = "models/gold/v_awp_gold.mdl" 
	new P_AWP[]    = "models/gold/p_awp_gold.mdl" 
	new W_AWP[]    = "models/gold/w_awp_gold.mdl"
#endif

enum _:shop_disallow
{
	g_iShop_disallow,
	g_iGoldAK_disallow,
	g_iGoldM4_disallow,
	g_iGoldAWP_disallow,
	g_iDoubleXP_allow,
	g_iDoubleCoins_allow,
	g_iBuyXP_disallow
}

enum _:pl_status
{
	bool:g_haveGold,
	bool:g_iShop[shop_disallow],
	Float:g_iWallet
}

new g_PlayerStatus[MAX_PLAYERS+1][pl_status]
new bool:g_map_valid, bool:army

new g_Round, g_buyTime
new Shop_Menu
new g_iBitClientRegistered
new MFHandle_ValidMap

//--стоимость разовой покупки оружия--//
new Float:cost_M4 = 0.03
new Float:cost_AK = 0.03
new Float:cost_AWP = 0.05
new Float:cost_XP = 0.05
new Float:cost_Coin = 0.05
new Float:cost_BuyXP = 0.20
new xp_exch = 10	//сколько опыта добавить при обмене
//----------------------------------//

public native_filter(const name[], index, trap)
	return !trap ? PLUGIN_HANDLED : PLUGIN_CONTINUE

public api_error()
{
	log_amx("Plugin paused. GameCMS_API is not loaded")
	return pause("a")
}

public plugin_init()
{		
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("HLTV", "round_start", "a", "1=0", "2=0")
	register_event("TextMsg", "round_restart", "a", "2=#Game_will_restart_in","2=#Game_Commencing")
	
	RegisterHam(Ham_Killed, "player", "player_killed", 1)
	RegisterHam(Ham_Spawn, "player", "player_spawn", 1)
	
	register_clcmd("say /shop", "ShopMenu")
	
	new szPrefixMap[][] = {"de_", "cs_", "css_","as_"}
	new map[32]; get_mapname(map, charsmax(map));
	for(new i; i < sizeof szPrefixMap; i++)
	{
		if(containi(map, szPrefixMap[i]) != -1)
			g_map_valid = true	
	}
	if(!g_map_valid)
		return PLUGIN_HANDLED

	MFHandle_ValidMap = CreateMultiForward("map_validate", ET_IGNORE, FP_CELL)
	set_task(2.0, "set_params")
	
	#if defined GOLD
		RegisterHam(Ham_Item_Deploy, "weapon_ak47", "deploy_weapon", 1)
		RegisterHam(Ham_Item_Deploy, "weapon_m4a1", "deploy_weapon", 1)
		RegisterHam(Ham_Item_Deploy, "weapon_awp", "deploy_weapon", 1)

		register_forward(FM_SetModel, "set_model", 1)
	#endif
	
	return PLUGIN_CONTINUE
}

public plugin_cfg()
{
	get_cvar_string("cms_url", SiteUrl, charsmax(SiteUrl))
	#if defined ARMY_RANKS
	if(find_plugin_byfile("army_ranks_ultimate.amxx") != INVALID_PLUGIN_ID)
		army = true
	#endif
	#if defined AES
	if(find_plugin_byfile("aes_main.amxx") != INVALID_PLUGIN_ID)
		army = true
	#endif
}

public set_params()
{
	new ret_loadWallet
	ExecuteForward(MFHandle_ValidMap, ret_loadWallet, g_map_valid)
}

#if defined GOLD
public plugin_precache()
{
	precache_model (V_AK); precache_model (P_AK); precache_model (W_AK)
	precache_model (V_M4); precache_model (P_M4); precache_model (W_M4)
	precache_model (V_AWP); precache_model (P_AWP); precache_model (W_AWP)
}
#endif

public registered_user_connected(id)
	BIT_ADD(g_iBitClientRegistered, id)

public resetBit(id)
{
	BIT_SUB(g_iBitClientRegistered, id);
}

public client_disconnect(id)
{
	resetBit(id)
	arrayset(g_PlayerStatus[id], 0, pl_status)
}
	
public round_start()
{
	g_Round++
	g_buyTime = get_systime()
}

public round_restart()
	g_Round = 0
	
public player_spawn(Player)
{
	if(!is_user_alive(Player) || !g_map_valid)	return
	g_PlayerStatus[Player][g_iShop][g_iShop_disallow] = false
}

public ShopMenu(id)
{
	if(!BIT_VALID(g_iBitClientRegistered, id))
		return client_print_color(id, 0, "^1[^4SHOP^1] ^1Магазин ^4недоступен^1! Зарегистрируйтесь на сайте ^4%s", SiteUrl)
	
	if(!g_map_valid)
		return client_print_color(id, 0, "^1[^4SHOP^1] ^1На данной карте Магазин ^4недоступен^1!")
	
	if(g_Round < c_round)		
		return client_print_color(id, 0, "^1[^4SHOP^1] ^1Магазин доступен с ^4%d-го ^1раунда!", c_round)
	
	if(!is_user_alive(id))
		return client_print_color(id, 0, "^1[^4SHOP^1] ^1Магазин не для трупов ))")
	
	new Float:i_wallet = g_PlayerStatus[id][g_iWallet] = _:get_user_shilings(id)

	if(i_wallet <= 0.03)
		return client_print_color(id, 0, "^1[^4SHOP^1] ^4Ты - нищета!)) Иди работай))!")
		
	if(g_PlayerStatus[id][g_iShop][g_iShop_disallow] || get_systime() > (g_buyTime + 20))
		return client_print_color(id, 0, "^1[^4SHOP^1] ^1Магазин ^4недоступен^1! Ждите нового раунда.")

	new s_Title[72], s_M4[64], s_AK[64], s_AWP[64], s_DoubleXP[72], s_DoubleCoin[94], s_BuyXP[95], num
	formatex(s_Title, charsmax(s_Title), "\yСупермаркет :) \wБаланс: \y[%.2f руб.]", i_wallet)		
	Shop_Menu = menu_create(s_Title, "ShopMenu_handler", 1); 
	
	//собсно Меню
	//1
	if((i_wallet > cost_M4) && !g_PlayerStatus[id][g_iShop][g_iGoldM4_disallow])
	{
		formatex(s_M4, charsmax(s_M4), "\yЗолотой \wM4A1       \y[%.2f руб.]", cost_M4)			
		menu_additem(Shop_Menu, s_M4, "1", 0); num++
	}
	//2
	if((i_wallet > cost_AK) && !g_PlayerStatus[id][g_iShop][g_iGoldAK_disallow])
	{
		formatex(s_AK, charsmax(s_AK), "\yЗолотой \wAK-47       \y[%.2f руб.]", cost_AK)			
		menu_additem(Shop_Menu, s_AK, "2", 0); num++
	}
	//3
	if((i_wallet > cost_AWP) && !g_PlayerStatus[id][g_iShop][g_iGoldAWP_disallow])
	{
		formatex(s_AWP, charsmax(s_AWP), "\yЗолотой \wMagnum AWP       \y[%.2f руб.]", cost_AWP)			
		menu_additem(Shop_Menu, s_AWP, "3", 0); num++
	}
	//4
	if(army && (i_wallet > cost_XP) && !g_PlayerStatus[id][g_iShop][g_iDoubleXP_allow])
	{
		formatex(s_DoubleXP, charsmax(s_DoubleXP), "\yДвойной опыт \w(+1 XP)       \y[%.2f руб.]", cost_XP)			
		menu_additem(Shop_Menu, s_DoubleXP, "4", 0); num++
	}
	//5
	if((i_wallet > cost_Coin) && !g_PlayerStatus[id][g_iShop][g_iDoubleCoins_allow])
	{
		formatex(s_DoubleCoin, charsmax(s_DoubleCoin), "\yДвойная награда \w(+0.01 руб.)       \y[%.2f руб.]", cost_Coin)			
		menu_additem(Shop_Menu, s_DoubleCoin, "5", 0); num++
	}
	//6
	if(army && (i_wallet > cost_BuyXP) && !g_PlayerStatus[id][g_iShop][g_iBuyXP_disallow])
	{
		formatex(s_BuyXP, charsmax(s_BuyXP), "\yОбменять на Опыт (+%d XP)       \y[%.2f руб.]", xp_exch, cost_BuyXP)			
		menu_additem(Shop_Menu, s_BuyXP, "6", 0); num++
	}
	
	if(!num)
		return client_print_color(id, 0, "^1[^4SHOP^1] ^3Ты использовал все запасы из магазина))!")

	menu_setprop(Shop_Menu, MPROP_EXITNAME, "\yВыход")
	return menu_display(id, Shop_Menu, 0)                                 
}


public ShopMenu_handler(id, menu, item)
{
	if(item == MENU_EXIT)
		return menu_destroy(menu)
	
	new cmd[3], access, callback
	menu_item_getinfo(menu, item, access, cmd, 2,_,_, callback)

	new Float:i_wallet = g_PlayerStatus[id][g_iWallet]
	new i_Key = str_to_num(cmd)	
	switch (i_Key)
	{
		case 1:
		{
			set_shop_status(id, 1)
			if(DropWeapons(id, "weapon_m4a1", CSW_M4A1, 90))
				set_user_shilings(id, (i_wallet -= cost_M4))
		}
		case 2:
		{
			set_shop_status(id, 2)
			if(DropWeapons(id, "weapon_ak47", CSW_AK47, 90))
				set_user_shilings(id, (i_wallet -= cost_AK))
		}
		case 3:
		{
			set_shop_status(id, 3)
			if(DropWeapons(id, "weapon_awp", CSW_AWP, 30))
				set_user_shilings(id, (i_wallet -= cost_AWP))
		}		

		case 4:
		{
			set_user_shilings(id, (i_wallet -= cost_XP))
			g_PlayerStatus[id][g_iShop][g_iDoubleXP_allow] = true
			ShopMenu(id)
		}
		case 5:
		{
			set_user_shilings(id, (i_wallet -= cost_Coin))
			g_PlayerStatus[id][g_iShop][g_iDoubleCoins_allow] = true
			ShopMenu(id)
		}
		#if defined ARMY_RANKS || defined AES
		case 6:
		{
			if(army && set_user_exp(id, xp_exch))
			{
				g_PlayerStatus[id][g_iShop][g_iBuyXP_disallow] = true
				set_user_shilings(id, (i_wallet -= cost_BuyXP))
			}

			else client_print_color(id, 0, "^1[^4SHOP^1] ^1Произвести обмен ^4не удалось!")
			ShopMenu(id)
		}
		#endif
	}
	
	return menu_destroy(menu)
}    

set_shop_status(id, status)
{
	g_PlayerStatus[id][g_iShop][g_iShop_disallow] = true
	g_PlayerStatus[id][g_haveGold] = true
	
	switch(status)
	{
		case 1:	g_PlayerStatus[id][g_iShop][g_iGoldM4_disallow] = true
		case 2:	g_PlayerStatus[id][g_iShop][g_iGoldAK_disallow] = true
		case 3:	g_PlayerStatus[id][g_iShop][g_iGoldAWP_disallow] = true
	}
}

#if defined GOLD

public deploy_weapon(ent)
{
	static id; id = get_pdata_cbase(ent, m_pPlayer, m_linux_entity)
	static wpn; wpn = pev(ent, pev_iuser1)
	if(!wpn)
		return

	switch(wpn)
	{
		case CSW_AK47:
		{
			set_pev(id, pev_viewmodel2, V_AK)
			set_pev(id, pev_weaponmodel2, P_AK)
		}
		case CSW_M4A1:
		{
			set_pev(id, pev_viewmodel2, V_M4)
			set_pev(id, pev_weaponmodel2, P_M4)
		}
		case CSW_AWP:
		{
			set_pev(id, pev_viewmodel2, V_AWP)
			set_pev(id, pev_weaponmodel2, P_AWP)
		}
	}
}

public set_model(ent, model[])
{
	if(!pev_valid(ent))
		return FMRES_HANDLED
	
	static classname[10]; pev(ent, pev_classname, classname, charsmax(classname))
	if(!equal(classname, "weaponbox"))
		return FMRES_HANDLED

	static drop
	for(new i = 0 ; i < MAX_ITEM_TYPES; i++)
	{
		drop = get_pdata_cbase(ent, m_rgpPlayerItems[i], m_linux_entity)
		if(drop < 1)
			continue
		break
	}
	
	if(drop<1)
		return FMRES_HANDLED
	
	static wpn; wpn = pev(drop, pev_iuser1)
	if(!wpn)
		return FMRES_HANDLED
	
	switch(wpn)
	{
		case CSW_AK47: engfunc(EngFunc_SetModel, ent, W_AK)
		case CSW_M4A1: engfunc(EngFunc_SetModel, ent, W_M4)
		case CSW_AWP: engfunc(EngFunc_SetModel, ent, W_AWP)
	}
	return FMRES_SUPERCEDE
}
#endif

public player_killed(victim, killer, corpse)
{
	if(!is_valid_player(killer) || !is_valid_player(victim) || killer == victim)
		return PLUGIN_HANDLED
	
	if(BIT_VALID(g_iBitClientRegistered, victim))
	{
		g_PlayerStatus[victim][g_iWallet] = _:get_user_shilings(victim)
		set_user_shilings(victim, (g_PlayerStatus[victim][g_iWallet] -= 0.01000) > 0.000000 ? 
			g_PlayerStatus[victim][g_iWallet]: 0.000000)
	}

	if(BIT_VALID(g_iBitClientRegistered, killer))
	{
		static multipler
		switch(get_pdata_int(victim, m_LastHitGroup))
		{
			case  HIT_HEAD: multipler = 2
			default: multipler = 1
		}
		coins_multipler(killer, multipler)
	}
	
	if(BIT_VALID(g_iBitClientRegistered, victim))
		arrayset(g_PlayerStatus[victim], 0, pl_status)
	
	 
	#if defined ARMY_RANKS || defined AES
	return army? 
		g_PlayerStatus[killer][g_iShop][g_iDoubleXP_allow]? set_user_exp(killer, 2):
			PLUGIN_CONTINUE:
		PLUGIN_CONTINUE
	#else
	return PLUGIN_CONTINUE
	#endif
		
}

public bomb_planted(planter)
{
	if(!BIT_VALID(g_iBitClientRegistered, planter))
		return
	
	static multipler
	switch(get_playersnum())
	{
		case  1..10: multipler = 1
		default: multipler = 2
	}
	coins_multipler(planter, multipler)
}

public bomb_defused(defuser)
{
	if(!BIT_VALID(g_iBitClientRegistered, defuser))
		return
	
	static multipler
	switch(get_playersnum())
	{
		case  1..10: multipler = 1
		default: multipler = 2
	}
	coins_multipler(defuser, multipler)
}

coins_multipler(id, multipler)
{
	g_PlayerStatus[id][g_iWallet] = _:get_user_shilings(id)
	set_user_shilings(id, g_PlayerStatus[id][g_iWallet] +=
		g_PlayerStatus[id][g_iShop][g_iDoubleCoins_allow]? multipler*2*0.01000 : multipler*0.01000)
}

stock DropWeapons(id, wpnName[], wpnID, iAmmo)
{
#define PRIMARY_WEAPON ((1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|\
(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|\
(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90))

	new weapons[32], num, i
	get_user_weapons(id, weapons, num)
	
	static weap_name[32]
	for(i = 0; i < num; i++)
	{
		if(PRIMARY_WEAPON & (1<<weapons[i]))
		{
			get_weaponname(weapons[i], weap_name, sizeof weap_name - 1)
			if(!equali(weap_name, wpnName))
				engclient_cmd(id, "drop", weap_name)
		}
	}
	
	#if defined GOLD
		
		if(g_PlayerStatus[id][g_haveGold])
		{
			static ent; ent = fm_give_item(id, wpnName)
			if(!pev_valid(ent))
				return 0
				
			set_pev(ent, pev_iuser1, wpnID)
			cs_set_user_bpammo(id, wpnID, iAmmo)
			deploy_weapon(ent)
			engclient_cmd(id, wpnName)

			return 1
		}
	#endif
	
	fm_give_item(id, wpnName)
	cs_set_user_bpammo(id, wpnID, iAmmo)
	
	return 0
}