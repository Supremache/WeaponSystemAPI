#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <weapon>
#include <reapi>

#define BULLET_MODEL "sprites/laserbeam.spr"
#define GOLDENAK_WEAPON "weapon_ak47"
#define GOLDENAK_DAMAGE 26

new g_iGoldenBullet, iWeaponID

public plugin_init( )
{
	register_plugin( "ZE Weapon API: Golden AK47", "1.0", "Supremache" );
	register_cvar("WeaponsSystemAPI_GoldenAK47", "1.0", FCVAR_SERVER | FCVAR_SPONLY | FCVAR_UNLOGGED );
	
	register_forward(FM_CmdStart, "fw_CmdStart")	
}

public plugin_precache( )
{
	iWeaponID = register_weapon( SECTION_PRIMARY, GOLDENAK_WEAPON, "weapon_goldenak", "Golden AK47", "v_golden_ak47", "p_golden_ak47", "w_golden_ak47" );
	g_iGoldenBullet = precache_model(BULLET_MODEL)
}

public fw_CmdStart(id, uc_handle, seed)
{
	if( !is_user_alive( id ) )
		return HAM_IGNORED;
	
	if( ( pev( id, pev_oldbuttons ) & IN_ATTACK ) )
	{
		static iWeaponEnt = -1, iClip, iWeapon; iWeapon = get_user_weapon( id, iClip );
		iWeaponEnt = rg_find_ent_by_owner( iWeaponEnt, GOLDENAK_WEAPON, id );

		if( !iClip || iWeapon != get_weaponid( GOLDENAK_WEAPON ) || get_selected_weapon( id, SECTION_PRIMARY ) != iWeaponID || !is_entity( iWeaponEnt ) )
			return HAM_IGNORED
		
		DefineLaser( id , iWeaponEnt );
	}

	return FMRES_IGNORED
}

public DefineLaser( id, iEnt )
{
	static Float:StartOrigin[3], Float:EndOrigin[3], Float:EndOrigin2[3]
	
	GetPostion(id, 40.0, 7.5, -5.0, StartOrigin)
	GetPostion(id, 4096.0, 0.0, 0.0, EndOrigin)
	
	static TrResult; TrResult = create_tr2( );
	engfunc(EngFunc_TraceLine, StartOrigin, EndOrigin, DONT_IGNORE_MONSTERS, id, TrResult) 
	
	// Calc
	get_weapon_attachment(id, EndOrigin)
	global_get(glb_v_forward, EndOrigin2)

	EndOrigin2[ 0 ] *= 1024.0;
	EndOrigin2[ 1 ] *= 1024.0;
	EndOrigin2[ 2 ] *= 1024.0;
	
	EndOrigin2[ 0 ] += EndOrigin[ 0 ];
	EndOrigin2[ 1 ] += EndOrigin[ 1 ];
	EndOrigin2[ 2 ] += EndOrigin[ 2 ];
	
	get_tr2(TrResult, TR_vecEndPos, EndOrigin)
	get_tr2(TrResult, TR_vecPlaneNormal, EndOrigin2)
	
	// Create Laser
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMENTPOINT)
	write_short(id | 0x1000)
	engfunc(EngFunc_WriteCoord, EndOrigin[0])
	engfunc(EngFunc_WriteCoord, EndOrigin[1])
	engfunc(EngFunc_WriteCoord, EndOrigin[2])
	write_short(g_iGoldenBullet)
	write_byte(0)
	write_byte(0)
	write_byte(1)
	write_byte(10)
	write_byte(0)
	write_byte(255)
	write_byte(215)
	write_byte(0)
	write_byte(255)
	write_byte(0)
	message_end()		
	
	EndOrigin2[ 0 ] *= 2.5;
	EndOrigin2[ 1 ] *= 2.5;
	EndOrigin2[ 2 ] *= 2.5;
	
	EndOrigin2[ 0 ] += EndOrigin[ 0 ];
	EndOrigin2[ 1 ] += EndOrigin[ 1 ];
	EndOrigin2[ 2 ] += EndOrigin[ 2 ];
	
	// Take Damage
	static iHit; iHit = get_tr2(TrResult, TR_pHit)
	if( is_entity( iHit ) )
	{
		ExecuteHamB( Ham_TakeDamage, iHit, 0, id, GOLDENAK_DAMAGE, ( DMG_NEVERGIB | DMG_BULLET ) ) 
	}
	
	// Free
	free_tr2(TrResult)
}

GetPostion(id, Float:fOutForward,Float:fOutRight, Float:fOutUp,Float:fStart[] )
{
	static Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	
	get_entvar( id, var_origin, vOrigin );
	get_entvar( id, var_view_ofs, vUp );
	vOrigin[ 0 ] += vUp[ 0 ];
	vOrigin[ 1 ] += vUp[ 1 ];
	vOrigin[ 2 ] += vUp[ 2 ];
	get_entvar( id, var_v_angle, vAngle );

	angle_vector( vAngle, ANGLEVECTOR_FORWARD,vForward )
	angle_vector( vAngle, ANGLEVECTOR_RIGHT,vRight )
	angle_vector( vAngle, ANGLEVECTOR_UP, vUp )
	
	fStart[ 0 ] = vOrigin[ 0 ] + vForward[ 0 ] * fOutForward + vRight[ 0 ] * fOutRight + vUp[ 0 ] * fOutUp
	fStart[ 1 ] = vOrigin[ 1 ] + vForward[ 1 ] * fOutForward + vRight[ 1 ] * fOutRight + vUp[ 1 ] * fOutUp
	fStart[ 2 ] = vOrigin[ 2 ] + vForward[ 2 ] * fOutForward + vRight[ 2 ] * fOutRight + vUp[ 2 ] * fOutUp
} 

get_weapon_attachment(id, Float:fOutput[3], Float:fDis = 40.0)
{ 
	static Float:fOrigin[3], Float:fAngle[3], Float:fAttack[3], Float:vfEnd[3], viEnd[3], Float:fRate
	get_user_origin(id, viEnd, 3)  
	IVecFVec(viEnd, vfEnd) 

	get_entvar( id, var_origin, fOrigin );
	get_entvar( id, var_view_ofs, fAngle );

	fOrigin[0] += fAngle[0];
	fOrigin[1] += fAngle[1];
	fOrigin[2] += fAngle[2];

	fAttack[0] = ( vfEnd[0] - fOrigin[0] ) * 2;
	fAttack[1] = ( vfEnd[1] - fOrigin[1] ) * 2;
	fAttack[2] = ( vfEnd[2] - fOrigin[2] ) * 2;
	
	fRate = fDis / vector_length(fAttack)
	fAttack[0] *= fRate;
	fAttack[1] *= fRate;
	fAttack[2] *= fRate;

	fOutput[0] = fOrigin[0] + fAttack[0];
	fOutput[1] = fOrigin[1] + fAttack[1];
	fOutput[2] = fOrigin[2] + fAttack[2];
}
