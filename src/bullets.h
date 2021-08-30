#pragma once

#include "entitys.h"


struct Bullet
{
	Entity         entity;
	EntityModel*   weaponModel;
	Point3D        deltaPos;
	float          tripDist;
	Monster*       owner;
	bool           active;

	void Create ();
	void Trace (float dt);
	void Deactivate ();

	Bullet () {}
private :
	Bullet(const Bullet&);
	Bullet& operator=(const Bullet&);
};


void DischargeNewBullet (const SPoint &initPos, const Point3D &delta, Monster &owner, EntityModel& wpModel);