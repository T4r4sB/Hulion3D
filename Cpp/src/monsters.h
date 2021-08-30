#pragma once


#include "geometry.h"
#include "entitys.h"
#include "weapons.h"

struct Controls
{
	bool forw,back,left,right,jump,sit;
	bool shot, reload;
	int wpnumber;
	float dax,daz;

	void Clear ()
	{
		forw     = false;
		back     = false;
		left     = false;
		right    = false;
		jump     = false;
		sit      = false;
		shot     = false;
		reload   = false;
		wpnumber = -1;
		dax      = 0.0f;
		daz      = 0.0f;
	}
};

const float mHeadW = 0.28f, mBodyW = 0.36f, mLegsW = 0.36f, mHBW = 1.0f-mLegsW;

struct Monster
{
	Controls                    controls;
	int                         currentWeapon;
	SPoint                      *head, *body, *legs;
	float                       anglex, anglez;
	float                       stepStage;
	float                       fric;
	float                       health, armor;
	Entity                      entity;
	float                       processTime; // <0 не в процессе
	float                       deathStage;  // <0 живой
	float                       lastDamageTime; // сколько секунд назад получил урон
	tblib::carray<Weapon, 10>   weapons;
	bool                        prevShot;
	Point3D                     oldPosition, beforePush; // это position-pased подход 

	bool Live () 
	{ 
		return deathStage<0.0f;
	}

	Point3D Center () 
	{
		return head->p*mHeadW + body->p*mBodyW + legs->p*mLegsW;
	}

	void Trace (const Point3D &delta)
	{
		Point3D ml=delta, mh=delta;
		if (controls.sit || !Live()) 
		{
			mh.z += 0.1f*mLegsW;
			ml.z -= 0.1f*mHBW; 
		} else
		{
			mh.z -= 0.1f*mLegsW;
			ml.z += 0.1f*mHBW; 
		}
		head->Trace(mh);
		body->Trace(mh);
		legs->Trace(ml);
	}
	
	
	void Create(Sector* s, EntityModel* model);
	void Push (bool noMass);
	void Shot(EntityModel& wpModel, float dx);
	void TryShot ();
	void RecieveDamage (const SPoint &from, float dmg, float dt);
	void Move (float dt);

	Monster () {}

private :
	Monster(const Monster&);
	Monster&operator=(const Monster&);
};

