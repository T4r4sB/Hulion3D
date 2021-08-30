#pragma once
#include "aftermodels.h"

tblib::array<Bullet*, maxBullets> activeBullets;
int lastActiveBulletIndex = -1;

tblib::array<Monster*, maxMonsters> activeMonsters;

const float processMonsterTime = 2.0f;

void DischargeNewBullet (const SPoint &initPos, const Point3D &delta, Monster &owner, EntityModel& wpModel)
{
	int newIndex = lastActiveBulletIndex+1;
	if (newIndex >= activeBullets.size()) newIndex = 0;
	if (!l.bullets[newIndex].active && activeBullets.size()<maxBullets)
	{
		activeBullets.push_back(&l.bullets[newIndex]);
		Bullet& last = *activeBullets[activeBullets.size()-1];
		last.active        = true;
		last.entity.center = initPos;
		last.deltaPos      = delta;
		last.tripDist      = 0.0f;
		last.owner         = &owner;
		last.weaponModel   = &wpModel;
		last.entity.model  = wpModel.bulletModel;
		for (int i=last.entity.convexes.low(); i<last.entity.convexes.high(); ++i)
		{
			Sector& s = last.entity.convexes[i].g;
			for (int f=s.faces.low(); f<s.faces.high(); ++f)
				s.faces[f].texture = last.entity.model->texture;
		}
		last.entity.Update();
		lastActiveBulletIndex = newIndex;
	}
};

bool MustContinue (const Monster& m)
{
	return (m.entity.model->player || Visible(*m.head, *l.player.head));
}

void IIMonster (Monster& m)
{
	if (!m.Live()) return;

	m.controls.forw = true;
	Point3D delta = m.body->p - l.player.body->p;

	float needAz = fmod(atan2(delta.y,delta.x)+float(M_PI_2)-m.anglez, 2.0f*float(M_PI)) - float(M_PI);

	m.controls.daz = needAz*1000.0f;
	tblib::inbound(m.controls.daz, -3.0f, 3.0f);

	float needAx = fmod(atan2(delta.z, sqrt(delta.x*delta.x+delta.y*delta.y))+float(M_PI_2)-m.anglex, 2.0f*float(M_PI)) - float(M_PI);

	m.controls.dax = needAx*1000.0f;
	tblib::inbound(m.controls.dax, -3.0f, 3.0f);

	if (m.entity.model->lightness>0.1f)
	{
		m.controls.jump = m.head->p.z > l.player.head->p.z+0.3f;
		m.controls.sit  = m.head->p.z < l.player.head->p.z+0.3f;
	} else if (m.entity.model->spring>0.1f)
		m.controls.jump = true;
	
	int& wn = m.controls.wpnumber;
	wn = 9;
	while (wn>=0 && !m.weapons[wn].isWeapon)	--wn;
	m.controls.shot = true;
}

bool IsMonsterActive (const Monster &m)
{
	return m.processTime>0.0f;
}

void SetMonsterActive (Monster& m)
{
	bool was = IsMonsterActive(m);
	m.processTime = processMonsterTime;
	if (!was)
		activeMonsters.push_back(&m);
}

void MoveActiveMonsters(float dt)
{
	int j=0;
	for (int i=0; i<activeMonsters.size(); ++i)
	{
		Monster&m = *activeMonsters[i];
		if (!m.entity.model->player)
			IIMonster(m);
		m.Move(dt);
		m.entity.Update();
		if (MustContinue(m))
			SetMonsterActive(m); // на массив влияния тут нет
		m.processTime -= dt;

		if (IsMonsterActive(m))
			activeMonsters[j++]=&m;
	}
	activeMonsters.shrink(j);
}

void FindVisibleMonsters (SPoint vp)
{
	SetMonsterActive(l.player);
	
	for (int tries=0; tries<5; ++tries)
	{
		const Point3D dp = RandomPoint()*100.0f; 
		marray<CheckPtr<Entity> > ea(0, maxEntitys, PK_TEMP);
		vp.TraceWithEntitys(dp, ea, false);
		for (int i=ea.low(); i<ea.high(); ++i)
			if (ea[i]->monster && ea[i]->monster->Live() && Visible(vp, *ea[i]->monster->head))
				SetMonsterActive(*ea[i]->monster);
	}
}

void ProcessBullets(float dt)
{
	int j=0;
	for (int i=0; i<activeBullets.size(); ++i)
	{
		Bullet& b = *activeBullets[i];
		b.Trace(dt);
		if (b.active)
			activeBullets[j++] = &b;
		else
			b.Deactivate();
		b.entity.Update();
	}
	activeBullets.shrink(j);
}

void EnginePhys (float dt)
{
	l.gameTime += dt;
	FindVisibleMonsters(*l.player.head);
	ProcessBullets(dt);
	MoveActiveMonsters(dt);
	ProcessTextures(dt);
}
