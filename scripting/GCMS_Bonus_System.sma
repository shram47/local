/*Планируется:Для обычных игроков:
-Золотое оружие за реал.деньги (Покупка через меню)
-Покупка Gold VIP через меню (на 30 дней)
-Взять VIP на сутки (Бесплатно, единоразово)
Для Gold VIP игроков:
-Получить случайный бонус:
-Выдача лечебн. гранаты
-Обычное оружие
-Скорость ходьбы
-Наносит урон ( :D наносит тому кто подобрал)
-Двойной прижок
-Харакири ( :-D )
Обычная монетка:
-Выдача anew
-Выдача exp
-Выдача $ Игр.валюта
-HP (игр.жизнь)
-Обычное оружие
-Наносит урон ( :D наносит тому кто подобрал)
-Деньги (реальный на счёт аккаунта на сайте)
Gold VIP монетка (могут поднимать только VIP и Gold VIP)
-Выдача лечебн. гранаты
-Если есть $Игр.валюта: Выдача золотого оружия
-Скорость ходьбы
-Наносит урон ( :D наносит тому кто подобрал)
-Двойной прижок
*/
#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fun>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <gamecms>
#if AMXX_VERSION_NUM < 183
#include <chatcolor>
#endif
// ОБРАТИТЬ ВИМАНИЕ! <<< Все define вывести в cvars
// ОБРАТИТЬ ВИМАНИЕ! >>> Граната жизни сделать для VIP (cvars)
#define PLUGIN                      "GCMS_Bonus_MOD"
#define VERSION                     "0.0.3 beta" 
#define AUTHOR                      "shram47 & credits: zhorzh78" 
//credits: Dorus (Nade Health 0.1), zhorzh78(GameCMS_API 4.4.5, GameCMS_Informer 2.0), okeeey
#define SetBit(%0,%1)               ((%0) |= (1<<(%1)))
#define IsSetBit(%0,%1)             ((%0) & (1<<(%1)))
#define ClearBit(%0,%1)             ((%0) &= ~(1<<(%1)))
#define s_SetBit(%0,%1)             ((%0) |= (1<<(%1)))
#define s_ClearBit(%0,%1)           ((%0) &= ~(1<<(%1)))
#define s_IsSetBit(%0,%1)           ((%0) & (1<<(%1)))
#define s_InvertBit(%0,%1)          ((%0) ^= (1<<(%1)))
#define s_IsNotSetBit(%0,%1)        (~(%0) & (1<<(%1)))
#define MAX_PLAYERS 32
#define HUD_OFFSET  5478
#define hudUpdateInterval   5.0
#define V_MODEL "models/gbonus/v_he_mk_nade.mdl"
#define P_MODEL "models/gbonus/p_he_mk_nade.mdl"
#define W_MODEL "models/gbonus/w_he_mk_nade.mdl"
#define GIVE_HP 30
#define SMOKE_SCALE 30
#define SMOKE_FRAMERATE 12

new ExplSpr, ExplSpr2, ExplSpr3, ExplYO, g_iSpriteCircle
new const g_sound_explosion[] = "weapons/sg_explode.wav"
new const g_classname_grenade[] = "grenade"
new g_eventid_createsmoke
new const g_iClassName[] = { "gb_coin" };
new const g_iClassName_Vip[] = { "gb_coin_vip" };
new const g_iCoinModel[] = { "models/gbonus/gcoin.mdl" };
new const g_iCoinModel_Vip[] = { "models/gbonus/gcoin_vip.mdl" };
new g_iTouchForward, gReturn, g_iTouchForward2;
new iBit_Connected, iBit_Access, iBit_Use;
new Float:g_iPos[128][3], g_iPosMax, g_iCoordsList[128], g_iAlreadyCreated[128], EntList[127];
new iBit_Register;
new bool:g_iShowCoins = false;
forward gb_touchcoin(id, ent);
forward gb_touchcoin_vip(id, ent);
native ar_set_user_realxp(id, addxp);
native ar_add_user_anew(admin, player, anew);

enum _:CVARS
{
Float:COINS_MONEY,
    COINS_GAME_MONEY,
    COINS_EXP,
    COINS_ANEW,
    COIN_MIN,
    COIN_MAX,
    ACCESS[4], 
    COIN_KILL, 
    COIN_VIP
};

enum _:InfoSetup
{
    is_registered,
    hud_active
}

new HUD_Setup[MAX_PLAYERS+1][InfoSetup]
new informerSyncObj
new map_valid, bool:gamecms_wallet, bool:shop_loaded
new g_iCvars[CVARS], g_iSayText;

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);
    register_cvar("gb_coins_money", "0");
    register_cvar("gb_coins_money_from_game", "0");
    register_cvar("gb_ar_exp", "0");
    register_cvar("gb_ar_anew", "0");
    register_touch(g_iClassName, "player", "PickCoin");
    register_touch(g_iClassName_Vip, "player", "PickCoin_Vip");
    register_logevent("Evnt_StartRound", 2, "1=Round_Start");
    register_logevent("Evnt_EndRound", 2, "1=Round_End");
    register_event("TextMsg", "Evnt_EndRound", "a", "2&#Game_C", "2&#Game_w", "2&#Game_will_restart_in")
    register_menucmd(register_menuid("Show_CoinsEdit"), 1023, "Handle_CoinsEdit");
    register_cvar("gb_menu_access", "l");
    register_cvar("gb_coins_max", "3");
    register_cvar("gb_coins_min", "1");
    register_cvar("gb_coins_autoremove", "1");
    register_cvar("gb_coins_vip", "1");
    register_clcmd("gb_edit", "gb_menu");
    g_iSayText = get_user_msgid("SayText");
    g_iTouchForward = CreateMultiForward("gb_touchcoin", ET_CONTINUE, FP_CELL, FP_CELL);
    g_iTouchForward2 = CreateMultiForward("gb_touchcoin_vip", ET_CONTINUE, FP_CELL, FP_CELL);
    register_clcmd("say /offinfo","HUD_Off")
    informerSyncObj = CreateHudSyncObj()
    set_task(200.0, "anons", _, _, _, "b")
    register_forward(FM_EmitSound, "forward_emitsound")
    register_forward(FM_PlaybackEvent, "forward_playbackevent")
    register_event( "CurWeapon", "CurWeapon", "be", "1=1" )
    register_forward( FM_SetModel, "forward_model", 1 )
    g_eventid_createsmoke = engfunc(EngFunc_PrecacheEvent, 1, "events/createsmoke.sc")
}

public LoadSettings()
{
    g_iCvars[COIN_MAX] = get_cvar_num("gb_coins_max");
    g_iCvars[COIN_MIN] = get_cvar_num("gb_coins_min");
    g_iCvars[COIN_KILL] = get_cvar_num("gb_coins_autoremove");
    g_iCvars[COIN_VIP] = get_cvar_num("gb_coins_vip");
    if(g_iCvars[COIN_MIN] > g_iCvars[COIN_MAX]) set_fail_state("gb_coins_max < gb_coins_min change settings!");
    get_cvar_string("gb_menu_access", g_iCvars[ACCESS], charsmax(g_iCvars[ACCESS]));
    g_iCvars[COINS_MONEY] = get_cvar_num("gb_coins_money");
    g_iCvars[COINS_ANEW] = get_cvar_num("gb_ar_anew");
    g_iCvars[COINS_EXP] = get_cvar_num("gb_ar_exp");
    g_iCvars[COINS_GAME_MONEY] = get_cvar_num("gb_coins_money_from_game");
}

public anons()
{
    client_print_color(0, 0, "^4[Инфо] ^1Зарегистрируйся на  сайте ^4%s ^1и получай бонусы за игру", SiteUrl)
    client_print_color(0, 0, "^4[Инфо] ^1Для отключения информера о регистрации, напиши в чат ^4/offinfo")
}

public plugin_cfg()
{
    new iCfgDir[64], iCfg[128], iMapName[32] ;
    get_configsdir(iCfgDir, charsmax(iCfgDir)); get_mapname(iMapName, charsmax(iMapName));
    formatex(iCfg, charsmax(iCfg), "%s/GB/config.cfg", iCfgDir);
    formatex(g_iCoordsList, charsmax(g_iCoordsList), "%s/GB/mapsini/%s.ini", iCfgDir, iMapName);
    if(file_exists(iCfg)) server_cmd("exec %s", iCfg);
    if(file_exists(g_iCoordsList)) Read_Coord_File(g_iCoordsList);
    set_task(0.3, "LoadSettings");
    get_cvar_string("cms_url", SiteUrl, charsmax(SiteUrl))
}

public registered_user_connected(id)
{
    SetBit(iBit_Register, id);
    HUD_Setup[id][is_registered] = 1    
}


public api_error()
{
    log_amx("Plugin paused. GameCMS_API is not loaded")
    return  pause("a")
}

public map_validate(is_map_valid)
{
    gamecms_wallet = true
    shop_loaded = true
    map_valid = is_map_valid
}

public HUD_Off(id)
{
    HUD_Setup[id][hud_active] = 0
}

public gb_touchcoin_vip(id, ent)
{
    if(!IsSetBit(iBit_Register, id))
    {
        client_print_color(id, 0, "^1[^4Gcoins bonus^1] Бонусы доступны зарегестрированным игрокам!");
        return;
    }
    if(set_user_shilings(id, get_user_shilings(id) + g_iCvars[COINS_MONEY]))
    client_print_color(id, 0, "^1[^4Gcoins bonus^1] Вы получили ^3%.2f ^1руб на сайт!", g_iCvars[COINS_MONEY]);

    if(pev_valid(ent))
    set_pev(ent, pev_flags, FL_KILLME);
}

public gb_touchcoin(id, ent)
{
    if(!IsSetBit(iBit_Register, id))
    {
        client_print_color(id, 0, "^1[^4Gcoins bonus^1] Бонусы доступны зарегестрированным игрокам!");
        return;
    }

    switch(random_num(0, 2))
    {
    case 0:
        {
            cs_set_user_money(id, cs_get_user_money(id) + g_iCvars[COINS_GAME_MONEY], 1);
            client_print_color(id, 0, "^1[^4Gcoins bonus^1] Вы получили ^3%d$^1!", g_iCvars[COINS_GAME_MONEY]);
        }
    case 1:
        {
            ar_set_user_realxp(id, g_iCvars[COINS_EXP]);
            client_print_color(id, 0, "^1[^4Gcoins bonus^1] Вы получили ^3%d^1 к опыту ArmyRanks!", g_iCvars[COINS_EXP]);
        }
    case 2:
        {
            ar_add_user_anew(-1, id, g_iCvars[COINS_ANEW]); 
            client_print_color(id, 0, "^1[^4Gcoins bonus^1] Вы получили ^3%d^1 к бонусу anew!", g_iCvars[COINS_ANEW]);
        }
    }

    if(pev_valid(ent))
    set_pev(ent, pev_flags, FL_KILLME);
}

public plugin_precache()
{
    engfunc(EngFunc_PrecacheModel, g_iCoinModel);
    engfunc(EngFunc_PrecacheModel, g_iCoinModel_Vip);
    ExplSpr = precache_model("sprites/gbonus/gp_1.spr");
    ExplSpr2 = precache_model("sprites/gbonus/gp_2.spr");
    ExplSpr3 = precache_model("sprites/gbonus/gp_3.spr");
    precache_sound("gbonus/woomen_expr.wav")
    ExplYO = precache_model("sprites/gbonus/woomensx.spr");
    g_iSpriteCircle = precache_model( "sprites/gbonus/shockwave.spr" );
    precache_model(V_MODEL)
    precache_model(W_MODEL)
    precache_model(P_MODEL)
}

public CurWeapon(id)
{
    if(is_user_connected(id) && is_user_alive(id))
    {
        if(get_user_weapon(id) == CSW_SMOKEGRENADE)
        {
            set_pev(id, pev_viewmodel2, V_MODEL)
            set_pev(id, pev_weaponmodel2, P_MODEL)
        }
    }
}

public forward_model( entity, const model[] )
{
    if( !pev_valid( entity ) ) return FMRES_IGNORED;
    
    if(equal( model, "models/w_smokegrenade.mdl" ))
    {
        engfunc ( EngFunc_SetModel, entity, W_MODEL );
    }
    return FMRES_IGNORED;
}

public forward_emitsound(ent, channel, const sound[])
{
    if (!equal(sound, g_sound_explosion) || !is_grenade(ent))
        return FMRES_IGNORED
    static Float:origin[3]
    static id
    id = pev(ent, pev_owner)
    pev(ent, pev_origin, origin)
    engfunc(EngFunc_EmitSound, ent, CHAN_WEAPON, "gbonus/woomen_expr.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
//engfunc(EngFunc_RemoveEntity, ent)
//create_smoke(origin)
    message_begin(MSG_ALL,SVC_TEMPENTITY,{0,0,0})
    write_byte(TE_SPRITETRAIL)
    write_coord(floatround(origin[0]))
    write_coord(floatround(origin[1]))
    write_coord(floatround(origin[2])+20)
    write_coord(floatround(origin[0]))
    write_coord(floatround(origin[1]))
    write_coord(floatround(origin[2])+80)
    write_short(ExplSpr)
    write_byte(20)
    write_byte(20)
    write_byte(4)
    write_byte(20)
    write_byte(10)
    message_end()
    
    message_begin(MSG_ALL,SVC_TEMPENTITY,{0,0,0})
    write_byte(TE_SPRITETRAIL)
    write_coord(floatround(origin[0]))
    write_coord(floatround(origin[1]))
    write_coord(floatround(origin[2])+20)
    write_coord(floatround(origin[0]))
    write_coord(floatround(origin[1]))
    write_coord(floatround(origin[2])+80)
    write_short(ExplSpr2)
    write_byte(20)
    write_byte(20)
    write_byte(4)
    write_byte(20)
    write_byte(10)
    message_end()
    
    message_begin(MSG_ALL,SVC_TEMPENTITY,{0,0,0})
    write_byte(TE_SPRITETRAIL)
    write_coord(floatround(origin[0]))
    write_coord(floatround(origin[1]))
    write_coord(floatround(origin[2])+20)
    write_coord(floatround(origin[0]))
    write_coord(floatround(origin[1]))
    write_coord(floatround(origin[2])+80)
    write_short(ExplSpr3)
    write_byte(20)
    write_byte(20)
    write_byte(4)
    write_byte(20)
    write_byte(10)
    message_end()
    
    message_begin(MSG_ALL, SVC_TEMPENTITY);
    write_byte(TE_SPRITE);
    write_coord(floatround(origin[0]));
    write_coord(floatround(origin[1]));
    write_coord(floatround(origin[2]) + 70);
    write_short(ExplYO);
    write_byte(5);
    write_byte(100);
    message_end();
    
    create_blast_circle(ent, 10, 255, 40)
    
    new tre
    while((tre = find_ent_in_sphere(tre,origin,250.0)) != 0)
    {
        if(is_user_alive(tre) && get_user_team(tre) == get_user_team(id))
        {
            message_begin(MSG_ONE, get_user_msgid("ScreenFade"), {0,0,0}, tre)
            write_short(1<<10)
            write_short(1<<10)
            write_short(0x0000)
            write_byte(170)
            write_byte(255)
            write_byte(0)
            write_byte(75)
            message_end()
            set_user_rendering(tre,kRenderFxGlowShell,0,255,50,kRenderNormal,20)
            set_task(1.5, "UnEffect", tre)
            set_user_health(tre,100)
        }
    }

    return FMRES_SUPERCEDE
}

public UnEffect(tre)
{
    if(is_user_alive(tre))
    {
        set_user_rendering(tre)
    }
}

public forward_playbackevent(flags, invoker, eventindex) {
    if (eventindex == g_eventid_createsmoke)
        return FMRES_SUPERCEDE
    return FMRES_IGNORED
}

bool:is_grenade(ent) {
    if (!pev_valid(ent))
        return false

    static classname[sizeof g_classname_grenade + 1]
    pev(ent, pev_classname, classname, sizeof g_classname_grenade)
    if (equal(classname, g_classname_grenade))
        return true

    return false
}

stock bool:is_hull_vacant(const Float:origin[3], hull) {
    new tr = 0
    engfunc(EngFunc_TraceHull, origin, origin, 0, hull, 0, tr)
    if (!get_tr2(tr, TR_StartSolid) && !get_tr2(tr, TR_AllSolid) && get_tr2(tr, TR_InOpen))
        return true
    
    return false
}

stock create_blast_circle(ent, R, G, B) 
{
    static Float: fOrigin[3], iOrigin[3];
    
    pev(ent, pev_origin, fOrigin);
    
    FVecIVec( fOrigin, iOrigin );
        
    message_begin( MSG_BROADCAST, SVC_TEMPENTITY, iOrigin ); 
    write_byte( TE_BEAMCYLINDER );
    write_coord( iOrigin[ 0 ] );
    write_coord( iOrigin[ 1 ] );
    write_coord( iOrigin[ 2 ]);
    write_coord( iOrigin[ 0 ] );
    write_coord( iOrigin[ 1 ] );
    write_coord( iOrigin[ 2 ] + 250) ; // radius
    write_short( g_iSpriteCircle );
    write_byte( 0 );    // start framerate
    write_byte( 1 );    // framerate
    write_byte( 5 );    // life
    write_byte( 30 );   // width
    write_byte( 1 );    // amplitude
    
    write_byte(R);
    write_byte(G);
    write_byte(B);
    
    write_byte( 255 );  // brightness
    write_byte( 5 );    // speed
    message_end();
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
    s_SetBit(iBit_Connected, id);
    s_SetBit(iBit_Use, id);
    if(get_user_flags(id) & read_flags(g_iCvars[ACCESS])) s_SetBit(iBit_Access, id);

    HUD_Setup[id][hud_active] = 1
    set_task(hudUpdateInterval,"Show_Hud_Informer",HUD_OFFSET + id,.flags="b")
}

public client_disconnect(id)
{   

    ClearBit(iBit_Register, id);
    s_ClearBit(iBit_Connected, id);
    BitClear(iBit_Access, id);
    BitClear(iBit_Use, id);


    if(task_exists(HUD_OFFSET + id))
    remove_task(HUD_OFFSET + id)
    arrayset(HUD_Setup[id], 0, InfoSetup)
}

public Show_Hud_Informer(taskId)
{
    new id = taskId - HUD_OFFSET

    if(!HUD_Setup[id][hud_active])
    return PLUGIN_HANDLED

    new watchId = id
    new isAlive = is_user_alive(id)

    if(!is_user_connected(id))
    {
        remove_task(taskId)
        return PLUGIN_HANDLED
    }

    if(informerSyncObj != 0)
    ClearSyncHud(id,informerSyncObj)

    if(!isAlive)
    {
        watchId = pev(id, pev_iuser2)

        if(!watchId)
        return PLUGIN_HANDLED
    }

    new hudMessage[156], len, Data[4], Name[32]
    new bool:status = get_forum_data(watchId, Data, Name, charsmax(Name)) != 0 ? true : false
    new Float:wallet = get_user_shilings(watchId)

    if(!status)
    return PLUGIN_HANDLED

    switch(isAlive)
    {
    case 1:
        if(HUD_Setup[id][is_registered])
        {
            if(Data[3] > 0)
            len += formatex(hudMessage[len], charsmax(hudMessage) - len, "^nНовых сообщений: %d", Data[3])
            if(map_valid)
            {
                if(gamecms_wallet)
                len += formatex(hudMessage[len], charsmax(hudMessage) - len, "^nВ кошельке: %.2f руб.",
                _:wallet >= 0 ? wallet + 0.005 : wallet - 0.005)
                if(shop_loaded)
                len += formatex(hudMessage[len], charsmax(hudMessage) - len, "^nМагазин: / shop")
            }
        }
        else len += formatex(hudMessage[len], charsmax(hudMessage) - len, "^nЗарегистрируйтесь ^nна сайте %s ^nи получайте бонусы", SiteUrl)

    case 0:
        if(HUD_Setup[watchId][is_registered])
        {
            len += formatex(hudMessage[len], charsmax(hudMessage) - len, "Участник форума")
            len += formatex(hudMessage[len], charsmax(hudMessage) - len, "^nИмя: %s", Name)
            len += formatex(hudMessage[len], charsmax(hudMessage) - len, "^nРейтинг: %d", Data[2])
            len += formatex(hudMessage[len], charsmax(hudMessage) - len, "^nБлагодарностей: %d", Data[0])
            if(get_user_flags(id) & ADMIN_RCON)
            len += formatex(hudMessage[len], charsmax(hudMessage) - len, "^nВ кошельке: %.2f руб.", wallet)
        }
        else len += formatex(hudMessage[len], charsmax(hudMessage) - len, "^nДанный игрок ^nне зарегистрирован")
    }

    set_hudmessage(250, 100, 100, 0.75 , 0.42, .holdtime = hudUpdateInterval, .channel = 4)
    return ShowSyncHudMsg(id, informerSyncObj, hudMessage)
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

public gb_menu(id)
{
    if(s_IsNotSetBit(iBit_Access, id)) return 0;
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
    if(!pev_valid(ent) || g_iShowCoins || s_IsNotSetBit(iBit_Connected, id) || s_IsNotSetBit(iBit_Use, id)) return 0;
    static Float: iToucher[33]; if(iToucher[id] > get_gametime()) return 0;
    ExecuteForward(g_iTouchForward, gReturn, id, ent);
    iToucher[id] = get_gametime();
    return g_iCvars[COIN_KILL] ? set_pev(ent, pev_flags, FL_KILLME) : 0;
}

public PickCoin_Vip(ent, id)
{
    if(!pev_valid(ent) || g_iShowCoins || s_IsNotSetBit(iBit_Connected, id) || s_IsNotSetBit(iBit_Use, id)) return 0;
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

stock BitClear(iBit, id) if(s_IsSetBit(iBit, id)) s_ClearBit(iBit, id);

stock ChatColor(const id, const input[], any:...)
{
    new count = 1, players[32]; static msg[256]; vformat(msg, 255, input, 3);
    replace_all(msg, 255, "!g", "^4"); replace_all(msg, 255, "!y", "^1"); replace_all(msg, 255, "!t", "^3");
    if(id) players[0] = id; else get_players(players, count, "ch");
    for(new i = 0; i < count; i++)
    {
        if(s_IsSetBit(iBit_Connected, players[i]))
        {
            message_begin(MSG_ONE_UNRELIABLE, g_iSayText, _, players[i]);
            write_byte(players[i]);
            write_string(msg);
            message_end();
        }
    }
}
