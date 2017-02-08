#include <amxmodx>
#include <fakemeta>
#include < cstrike >
#include < fun >
#include < engine >

#define PLUGIN_NAME "Nade Health"
#define PLUGIN_VERSION "0.1"
#define PLUGIN_AUTHOR "Dorus"

#define V_MODEL "models/v_he_mk_nade.mdl"
#define P_MODEL "models/p_he_mk_nade.mdl"
#define W_MODEL "models/w_he_mk_nade.mdl"

#define GIVE_HP 30

#define SMOKE_SCALE 30
#define SMOKE_FRAMERATE 12

new ExplSpr, ExplSpr2, ExplSpr3, ExplYO, g_iSpriteCircle

// do not edit
new const g_sound_explosion[] = "weapons/sg_explode.wav"
new const g_classname_grenade[] = "grenade"
new g_eventid_createsmoke

public plugin_init() {
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)

	register_forward(FM_EmitSound, "forward_emitsound")
	register_forward(FM_PlaybackEvent, "forward_playbackevent")
	register_event( "CurWeapon", "CurWeapon", "be", "1=1" )
	register_forward( FM_SetModel, "forward_model", 1 )

	// we do not precaching, but retrieving the indexes
	g_eventid_createsmoke = engfunc(EngFunc_PrecacheEvent, 1, "events/createsmoke.sc")
}

public plugin_precache()
{
	ExplSpr = precache_model("sprites/gp_1.spr");
	ExplSpr2 = precache_model("sprites/gp_2.spr");
	ExplSpr3 = precache_model("sprites/gp_3.spr");
	precache_sound("woomen_expr.wav")
	ExplYO = precache_model("sprites/woomensx.spr");
	
	g_iSpriteCircle = precache_model( "sprites/shockwave.spr" );
	
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
	engfunc(EngFunc_EmitSound, ent, CHAN_WEAPON, "woomen_expr.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	//engfunc(EngFunc_RemoveEntity, ent)
	//create_smoke(origin)
	
	message_begin(MSG_ALL,SVC_TEMPENTITY,{0,0,0})
	write_byte(TE_SPRITETRAIL) //Спрайт захвата
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
	write_byte(TE_SPRITETRAIL) //Спрайт захвата
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
	write_byte(TE_SPRITETRAIL) //Спрайт захвата
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
	message_end();//MESSAGE ENDING
	
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
	// we do not need a large amount of smoke
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
	write_byte( 0 );	// start framerate
	write_byte( 1 );	// framerate
	write_byte( 5 );	// life
	write_byte( 30 );	// width
	write_byte( 1 ); 	// amplitude
	
	write_byte(R);
	write_byte(G);
	write_byte(B);
	
	write_byte( 255 );	// brightness
	write_byte( 5 );	// speed
	message_end();
}