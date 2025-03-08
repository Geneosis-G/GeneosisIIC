class IICComponent extends GGMutatorComponent;

var GGGoat gMe;
var GGMutator myMut;
var StaticMeshComponent coreMesh;
var SoundCue swapSound;
var SoundCue mActivateCoreSound;
var SoundCue mDeactivateCoreSound;

var float coreRange;
var bool canSwap;
var bool isCoreActive;

/**
 * See super.
 */
function AttachToPlayer( GGGoat goat, optional GGMutator owningMutator )
{
	super.AttachToPlayer(goat, owningMutator);

	if(mGoat != none)
	{
		gMe=goat;
		myMut=owningMutator;

		coreMesh.SetLightEnvironment( gMe.mesh.LightEnvironment );
		gMe.mesh.AttachComponent( coreMesh, 'Spine_01', vect(0.f, 0.f, 23.f));

		ToggleCoreActive();
	}
}

function KeyState( name newKey, EKeyState keyState, PlayerController PCOwner )
{
	local GGPlayerInputGame localInput;

	if(PCOwner != gMe.Controller)
		return;

	localInput = GGPlayerInputGame( PCOwner.PlayerInput );

	if( keyState == KS_Down )
	{
		if( localInput.IsKeyIsPressed( "GBA_Special", string( newKey ) ) )
		{
			//myMut.WorldInfo.Game.Broadcast(myMut, "core=" $ coreMesh);
			DoRandomSwap();
		}

		if( localInput.IsKeyIsPressed( "GBA_Baa", string( newKey ) ) )
		{
			//myMut.WorldInfo.Game.Broadcast(myMut, "core=" $ coreMesh);
			gMe.SetTimer(1.f, false, NameOf(ToggleCoreActive), self);
		}
	}
	else if( keyState == KS_Up )
	{
		if( localInput.IsKeyIsPressed( "GBA_Baa", string( newKey ) ) )
		{
			//myMut.WorldInfo.Game.Broadcast(myMut, "core=" $ coreMesh);
			if(gMe.IsTimerActive(NameOf(ToggleCoreActive), self))
			{
				gMe.ClearTimer(NameOf(ToggleCoreActive), self);
			}
		}
	}
}

function ToggleCoreActive()
{
	isCoreActive=!isCoreActive;
	if(isCoreActive)
	{
		coreMesh.SetMaterial(0, none);
		gMe.PlaySound(mActivateCoreSound);
	}
	else
	{
		coreMesh.SetMaterial(0, Material'House_01.Materials.Ceiling_01');
		gMe.PlaySound(mDeactivateCoreSound);
	}
}

function DoRandomSwap()
{
	local Actor targetActor, randomActor;
	local vector targetDest, randomDest;
	local float targetHeight, randomHeight, r;
	local bool targetWasRagdoll, randomWasRagdoll;
	local EPhysics targetPhysics, randomPhysics;
	local PrimitiveComponent pc;

	if(!canSwap || !isCoreActive)
		return;

	canSwap=false;

	targetActor=GetClosestActor();
	if(targetActor == none)
	{
		canSwap=true;
		return;
	}

	randomActor=GetRandomActor();
	if(randomActor == none)
	{
		canSwap=true;
		return;
	}

	gMe.PlaySound(swapSound);

	//Fix teleport issues
	targetActor.bCanTeleport=true;
	targetActor.bBlocksTeleport=false;
	randomActor.bCanTeleport=true;
	randomActor.bBlocksTeleport=false;

	//Manage ragdoll before swap
	targetWasRagdoll=WasActorRagdoll(targetActor);
	randomWasRagdoll=WasActorRagdoll(randomActor);

	//Compute object destinations
	randomDest=targetActor.Location;
	targetDest=randomActor.Location;
	targetActor.GetBoundingCylinder( r, targetHeight );
	randomActor.GetBoundingCylinder( r, randomHeight );
	randomDest.z += randomHeight;
	targetDest.z += targetHeight;

	//Set physics
	targetPhysics=targetActor.Physics;
	targetActor.SetPhysics(PHYS_None);
	randomPhysics=randomActor.Physics;
	randomActor.SetPhysics(PHYS_None);

	//Do the swap
	randomActor.SetLocation(vect(0, 0, 0));
	foreach randomActor.ComponentList(class'PrimitiveComponent', pc)
	{
		pc.SetRBPosition(vect(0, 0, 0));
	}
	targetActor.SetLocation(targetDest);
	foreach targetActor.ComponentList(class'PrimitiveComponent', pc)
	{
		pc.SetRBPosition(targetDest);
	}
	randomActor.SetLocation(randomDest);
	foreach randomActor.ComponentList(class'PrimitiveComponent', pc)
	{
		pc.SetRBPosition(randomDest);
	}

	//Reset physics
	targetActor.SetPhysics(targetPhysics);
	randomActor.SetPhysics(randomPhysics);

	//Manage ragdoll after swap
	ResetActorRagdoll(targetActor, targetWasRagdoll);
	ResetActorRagdoll(randomActor, randomWasRagdoll);

	canSwap=true;
}

function Actor GetClosestActor()
{
	local Actor foundActor, hitActor;

	foundActor = none;

	foreach myMut.VisibleCollidingActors( class'Actor', hitActor, coreRange, gMe.Location)
	{
		if( hitActor != gMe && !ShouldIgnoreActor(hitActor))
		{
			if( foundActor == none || VSizeSq( hitActor.Location - gMe.Location ) < VSizeSq( foundActor.Location - gMe.Location ) )
			{
				foundActor = hitActor;
			}
		}
	}

	return foundActor;
}

function Actor GetRandomActor()
{
	local Actor hitActor;
	local int N, r;

	//Count valid actors
	N=0;
	foreach myMut.AllActors( class'Actor', hitActor )
	{
		if( hitActor != gMe && !ShouldIgnoreActor(hitActor))
		{
			N++;
		}
	}

	//Get random actor
	r=Rand(N);
	N=0;
	foreach myMut.AllActors( class'Actor', hitActor )
	{
		if( hitActor != gMe && !ShouldIgnoreActor(hitActor))
		{
			if(N == r)
			{
				return hitActor;
			}

			N++;
		}
	}

	return none;
}

function bool ShouldIgnoreActor(Actor act)
{
	return act == none
		|| act == gMe
		|| act.Owner == gMe
		|| (GGPawn(act) == none
		 && GGKActor(act) == none
		 && GGSVehicle(act) == none
		 && GGKAsset(act) == none);
}

function bool WasActorRagdoll(Actor act)
{
	local GGNpc npc;
	local GGGoat goat;
	local bool wasRagdoll;

	npc=GGNpc(act);
	goat=GGGoat(act);

	wasRagdoll=false;
	if(npc != none && npc.mIsRagdoll)
	{
		wasRagdoll=true;
		npc.StandUp();
	}
	if(goat != none && goat.mIsRagdoll)
	{
		wasRagdoll=true;
		goat.StandUp();
	}

	return wasRagdoll;
}

function ResetActorRagdoll(Actor act, bool wasRagdoll)
{
	local GGPawn gpawn;

	if(!wasRagdoll)
		return;

	gpawn=GGPawn(act);
	if(gpawn != none)
	{
		gpawn.SetRagdoll( true );
	}
}

defaultproperties
{
	coreRange=500
	canSwap=true

	mActivateCoreSound=SoundCue'MMO_SFX_SOUND.Cue.SFX_Wheel_Of_Time_Time_Stopped_Cue'
	mDeactivateCoreSound=SoundCue'MMO_SFX_SOUND.Cue.SFX_Wheel_Of_Time_Time_Resumed_Cue'

	Begin Object class=StaticMeshComponent Name=StaticMeshComp1
		StaticMesh=StaticMesh'Asamu.PowerCore'
	End Object
	coreMesh=StaticMeshComp1

	swapSound=SoundCue'Goat_Sounds.Effect_slot_machine_jackpot_Cue'
}