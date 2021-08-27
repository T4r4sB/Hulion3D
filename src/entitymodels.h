#pragma once

#include "memory.h"
#include "monsters.h"
#include "entitys.h"
#include "bullets.h"
#include "weapons.h"
#include "textures.h"
#include "funcptr.h"

enum ModelKind { MK_BOX, MK_MONSTER, MK_BULLET, MK_WEAPON };

typedef tblib::fptr<void(Entity&)> EntityProc;
typedef tblib::fptr<bool(Monster&)> ApplyEntityProc;

struct EntityModel // это метакласс с метаполями, крестоблядское ООП так не может
{
	ModelKind	  	                    kind;
	const char*                       name;
	int                               cconvexes;
	int                               cpoints;
	marray<int>                       connections;
	EntityProc                        entityProc;
	Texture*                          texture;
	// бля монстров
	bool                              player;
	float                             mass,headr,bodyr,legsr,hb,minbl,maxbl,speed,spring,lightness;
	float                             initialhealth;
	tblib::carray<EntityModel*, 10>   weaponModels;
	tblib::carray<bool, 10>           defaultHasWeapon;
	// бля предметов
	ApplyEntityProc                   applyEntityProc;
	// бля оружия
  float                             bulletspeed,range,damage,dispersion,reloadtime;
	int                               bulletspershot;
	EntityModel*                      bulletModel;
	bool                              sabre;
};

EntityModel emPlayer;
tblib::carray<EntityModel,  8> emSnowman;
tblib::carray<EntityModel, 16> emTrilobit;
tblib::carray<EntityModel,  5> emBox;
tblib::carray<EntityModel,  8> emGasbag;
tblib::carray<EntityModel,  8> emCock;
tblib::carray<EntityModel,  1> emBoss;

tblib::carray<EntityModel,  6> emBullet;
tblib::carray<EntityModel,  9> emWeapon;



enum BulletKind { BK_SABRE=0, BK_CLAWS, BK_BLOOD, BK_BULLET, BK_ENERGY_BALL, BK_BFG };

enum WeaponKind { WK_SABRE=0, WK_BLOOD, 
	WK_SMALL_CLAWS, WK_BIG_CLAWS, WK_SMALL_ENERGY_BALL, WK_BIG_ENERGY_BALL,
	WK_SATAN_CLAWS, WK_GUN, WK_BFG };

enum BoxKind { BXK_HEALTH=0, BXK_BIG_HEALTH, BXK_ARMOR, BXK_GUN, BXK_BFG };


void AddPc (int li, marray<int> &a, int i1, int i2, int i3, int k, int m)
{
	if (k==1)
	{
		i1=m-1-i1;
		i2=m-1-i2;
		i3=m-1-i3;
		int t=i2; i2=i1; i1=t;
	}

	a.push_back(i1+li);
	a.push_back(i2+li);
	a.push_back(i3+li);
	a.push_back(-1);
}

void AddSphere (int li, marray<int> &a)
{
	for (int k=0; k<2; ++k)
	{
		AddPc(li, a,  1,6,2, k,12);
		AddPc(li, a,  0,5,9, k,12);
		AddPc(li, a,  0,9,1, k,12);
		for (int i=0; i<4; ++i) 
			AddPc(li, a,  0,i+1,i+2, k,12);
		for (int i=0; i<3; ++i) 
			AddPc(li, a,  1,i+7,i+6, k,12);
	}
	a.push_back(-2);
}

void InitPointsByStatic (const tblib::slice<EntityPoint> &pts, const tblib::slice<EntityPoint> &stpt, const Point3D& c, const Matrix3D& m)
{
	const int shift = stpt.low()-pts.low();
	for (int i=pts.low(); i<pts.high(); ++i)
	{
		pts[i].tx = stpt[i+shift].tx;
		pts[i].ty = stpt[i+shift].ty;
		pts[i].initialP = c + m.RotateP(stpt[i+shift].initialP);
	}
}

void MoveSphere (const tblib::slice<EntityPoint> &pts, const Point3D& c, const Matrix3D& m, float txsx, float txsy)
{
	static tblib::carray<EntityPoint,12> stpt;
	static bool f=true;

	if (f)
	{
		stpt[ 0].initialP = Point3D(0.0f, 0.5f, 1.0f); 
		stpt[ 1].initialP = Point3D(0.0f,-0.5f, 1.0f); 
		stpt[10].initialP = Point3D(0.0f, 0.5f,-1.0f); 
		stpt[11].initialP = Point3D(0.0f,-0.5f,-1.0f); 

		for (int i=0; i<4; ++i)
		{
			const float a1 = float(i+0)*2.0f*float(M_PI)/8.0f, a2 = -float(i+1)*2.0f*float(M_PI)/8.0f;
			stpt[i+2].initialP = Point3D(cos(a1), sin(a1), 0.0f);
			stpt[i+6].initialP = Point3D(cos(a2), sin(a2), 0.0f);
		}

		for (int i=0; i<12; ++i)
		{
			stpt[i].tx = (stpt[i].initialP.y+1.0f)*12.0f+txsx;
			stpt[i].ty = (stpt[i].initialP.z+1.0f)*12.0f+txsy;
		}
		f=false;
	}		
	InitPointsByStatic(pts, stpt.get_slice(0, stpt.size()), c, m);
}

void AddSeg (int li, marray<int> &a)
{
	AddPc(li, a, 0,1,2, 0,0);
	AddPc(li, a, 0,2,3, 0,0);
	AddPc(li, a, 0,3,1, 0,0);
	AddPc(li, a, 4,2,1, 0,0);
	AddPc(li, a, 4,3,2, 0,0);
	AddPc(li, a, 4,1,3, 0,0);
	a.push_back(-2);
}

void MoveSeg (const tblib::slice<EntityPoint> &pts, const Point3D& c, const Matrix3D& m, float txsx, float txsy)
{
	
	static tblib::carray<EntityPoint,5> stpt;
	static bool f=true;

	if (f)
	{
		stpt[0].initialP = Point3D(0.0f, 0.0f, 1.0f);
		for (int i=0; i<3; ++i)
		{
			const float a = float(i)*2.0f*float(M_PI)/3.0f;
			stpt[i+1].initialP = Point3D(cos(a), sin(a), 0.0f);
		}
		stpt[4].initialP = Point3D(0.0f, 0.0f, -1.0f);

		for (int i=0; i<5; ++i)
		{
			stpt[i].tx = (stpt[i].initialP.y+1.0f)*12.0f + txsx;
			stpt[i].ty = (stpt[i].initialP.z+1.0f)*12.0f + txsy;
		}
		f=false;
	}
	InitPointsByStatic(pts, stpt.get_slice(0, stpt.size()), c, m);
}

void CorrectMonsterColliders (Entity& en)
{
	en.monster->head = &en.convexes[0].center;
	en.monster->body = &en.convexes[1].center;
	en.monster->legs = &en.convexes[2].center;
	en.center = *en.monster->legs;
	en.convexes[0].canCollide = en.monster->Live();
	en.convexes[0].shift      = en.monster->head->p - en.monster->legs->p;
	en.convexes[0].r          = en.model->headr;
	en.convexes[1].canCollide = en.monster->Live();
	en.convexes[1].shift      = en.monster->body->p - en.monster->legs->p;
	en.convexes[1].r          = en.model->bodyr;
	en.convexes[2].canCollide = en.monster->Live();
	en.convexes[2].shift      = Point3D(0.0f,0.0f,0.0f);
	en.convexes[2].r          = en.model->legsr;
}

void ProcPlayer (Entity& en)
{
	CorrectMonsterColliders(en);
	en.position.SetID();
	en.position.Translate(en.center.p);
}

void InitPlayers ()
{
	EntityModel &em = emPlayer;
	em.kind = MK_MONSTER;
	em.name = "Player";
	em.cpoints = 0;
	em.connections.Init(0,3,PK_GLOBAL);
	em.connections.push_back(-2);
	em.connections.push_back(-2);
	em.connections.push_back(-2);
	em.cconvexes = 3;
	em.entityProc = ProcPlayer;
	em.texture = NULL;
	em.player = true;
	em.initialhealth = 100.0f;
	em.mass  = 1.0f;
	em.headr = 0.25f;
	em.bodyr = 0.35f;
	em.legsr = 0.35f;
	em.hb    = 0.5f;
	em.minbl = 0.0f;
	em.maxbl = 0.6f;
	em.speed = 5.0f;
	em.spring = 6.0f;
	em.lightness = 0.0f;
	for (int j=0; j<em.weaponModels.size(); ++j)
	{
		em.weaponModels[j] = NULL;
		em.defaultHasWeapon[j] = false;
	}
	em.weaponModels[1] = &emWeapon[0];
	em.defaultHasWeapon[1] = true;
}

void ProcSnowman (Entity& en)
{
	if (en.monster->deathStage ==0.0f) // шоб не крутить
	{
		en.position.pt = en.center.p; // ???
		return;
	}

	CorrectMonsterColliders(en);

	Matrix3D m;
	m.Scale(en.model->headr+0.02f);
	MoveSphere(en.entityPoints.get_slice( 0,12), en.monster->head->p - en.monster->legs->p, m, 0.0f, 0.0f);

	m.SetID();
	m.Scale(en.model->bodyr+0.02f);
	MoveSphere(en.entityPoints.get_slice(12,24), en.monster->body->p - en.monster->legs->p, m, 0.0f, 16.0f);
	
	m.SetID();
	m.Scale(en.model->legsr+0.02f);
	MoveSphere(en.entityPoints.get_slice(24,36), Point3D(0.0f, 0.0f, 0.0f)                , m, 0.0f, 32.0f);

	en.position.SetID();
	en.position.Translate(en.center.p);
	en.position.Rotate(float(M_PI)-en.monster->anglez, 2);
}

void InitSnowmans ()
{
	for (int i=0; i<emSnowman.size(); ++i)
	{
		EntityModel &em = emSnowman[i];

		em.kind = MK_MONSTER;
		em.name = "Snowman";
		em.cpoints = 36;
		em.connections.Init(0,(4*20+1)*3,PK_GLOBAL);
		for (int j=0; j<3; ++j)
			AddSphere(j*12, em.connections);
		em.cconvexes = 3;
		em.entityProc = ProcSnowman;
		em.texture = &mstrTxr[pasrnd.random(mstrTxr.size())];
		float r = 0.8f + float(pasrnd.frandom())*0.5f;
		em.player = false;
		em.initialhealth = 20.0f+80.f+float(i)/float(emSnowman.size()-1);
		em.mass  = 0.1f*r;
		em.headr = 0.15f*r;
		em.bodyr = 0.25f*r;
		em.legsr = 0.25f*r;
		em.hb    = 0.45f*r;
		em.minbl = 0.001f*r;
		em.maxbl = 0.4f*r;
		em.speed = 2.0f;
		em.spring = 0.0f;
		em.lightness = 0.0f;
		for (int j=0; j<em.weaponModels.size(); ++j)
		{
			em.weaponModels[j] = NULL;
			em.defaultHasWeapon[j] = false;
		}
		em.weaponModels[1] = &emWeapon[WK_SMALL_ENERGY_BALL];
		em.defaultHasWeapon[1] = true;
	}
}

void ProcTrilobit (Entity& en)
{
	if (en.monster->deathStage == 0.0f)
	{
		en.position.pt = en.center.p;
		return;
	}

	float s = sin(en.monster->stepStage*15.0f);
	CorrectMonsterColliders(en);

	for (int i=3; i<9; ++i)
	{
		bool o = (i%2==0)!=(i<6); // ^^
		en.convexes[i].canCollide = false;
		en.convexes[i].shift = Point3D(
			(float(i/6)-0.5f)*0.7f,
			float(i%3-1)*0.1f - (float(o)-0.5f)*0.2f*s*(float(i/6)-0.5f),
			0.1f) 
			*	en.model->headr*4.0f;
		en.convexes[i].r = en.model->headr;
	}

	Matrix3D m;
	m.Scale(en.model->headr, en.model->headr, en.model->headr*0.6f);
	MoveSphere(en.entityPoints.get_slice(0,12), Point3D(0.0f,0.0f,0.0f), m, 0.0f, 4.0f);
	for (int i=0; i<6; ++i)
	{
		bool o = (i%2==0)!=(i<3); // ^______^
		m.SetID();
		m.Translate(en.convexes[i+3].shift);
		m.Rotate(float(M_PI_2)+(float(o)-0.5f)*s, 2);
		m.Rotate(float(M_PI_2), 0);
		m.Scale(en.model->headr*0.12f, en.model->headr*0.12f, en.model->headr*0.8f); // длинная лапка ^^
		MoveSeg(en.entityPoints.get_slice(12+i*5, 12+(i+1)*5), Point3D(0.0f,0.0f,0.0f), m, 0.0f, 32.0f);
	}

	en.position.SetID();

	en.position.Translate(en.center.p);
	en.position.Rotate(float(M_PI), 0);
	en.position.Rotate(float(M_PI)-en.monster->anglez, 2);
	if (!en.monster->Live())
		en.position.Rotate((en.monster->deathStage+1.0f)*float(M_PI), 1);
}

void InitTrilobits ()
{
	for (int i=0; i<emTrilobit.size(); ++i)
	{
		EntityModel& em = emTrilobit[i];
		
		em.kind = MK_MONSTER;
		em.name = "Trilobit";
		em.cpoints = 12+6*5;
		em.connections.Init(0,4*20+3+(6*4+1)*6,PK_GLOBAL);
		em.connections.push_back(-2);
		em.connections.push_back(-2);
		AddSphere(0, em.connections);
		for (int j=0; j<6; ++j)
			AddSeg(12+j*5, em.connections);
		em.cconvexes = 9;
		em.entityProc = ProcTrilobit;
		em.texture = &mstrTxr[pasrnd.random(mstrTxr.size())];
		float r = 1.0f;
		em.player = false;
		em.initialhealth = 30.0f+100.f+float(i)/float(emTrilobit.size()-1);
		em.mass  = 0.1f*r;
		em.headr = 0.3f*r;
		em.bodyr = 0.3f*r;
		em.legsr = 0.3f*r;
		em.hb    = 0.1f*r;
		em.minbl = 0.0f*r;
		em.maxbl = 0.0f*r;
		em.speed = 2.0f;
		em.spring = 0.0f;
		em.lightness = 0.0f;
		for (int j=0; j<em.weaponModels.size(); ++j)
		{
			em.weaponModels[j] = NULL;
			em.defaultHasWeapon[j] = false;
		}
		em.weaponModels[1] = &emWeapon[WK_SMALL_CLAWS];
		em.defaultHasWeapon[1] = true;
	}
}

bool HealthApplyEntityProc (Monster& m)
{
	if (m.health<m.entity.model->initialhealth)
	{
		m.health += 15.0f;
		tblib::shrink(m.health, m.entity.model->initialhealth);
		return true;
	} else
		return false;
}

bool BigHealthApplyEntityProc (Monster &m)
{
	if (m.health<m.entity.model->initialhealth+100.0f)
	{
		m.health += 100.0f;
		tblib::shrink(m.health, m.entity.model->initialhealth);
		return true;
	} else
		return false;
}

bool ArmorApplyEntityProc (Monster& m)
{
	if (m.armor<100.0f)
	{
		m.armor += 10.0f;
		tblib::shrink(m.armor, 100.0f);
		return true;
	} else
		return false;
}

bool GunApplyEntityProc (Monster& m)
{
	m.weapons[2].SetModel(&emWeapon[WK_GUN]);
  return true;
}
	
bool BFGApplyEntityProc (Monster& m)
{
	m.weapons[3].SetModel(&emWeapon[WK_BFG]);
  return true;
}

float frac(float x) { return x-float(int(x)); }

void ProcBox (Entity& en)
{
	const float 
		sx = 0.12f + frac(en.model->headr*sqrt(2.0f))*0.38f,
		sy = 0.12f + frac(en.model->headr*sqrt(3.0f))*0.38f,
		sz = 0.50f;
	for (int i=0; i<8; ++i)
	{
		EntityPoint&ep = en.entityPoints[i];
		ep.initialP = Point3D(
			float(       (i&1)*2-1) *en.model->headr*sx,
			float(       (i&2)  -1) *en.model->headr*sy,
			float((3.00f-(i&4)/2-1))*en.model->headr*sz);
		ep.tx = (ep.initialP.y+ep.initialP.z)*32.0f;
		ep.ty = (ep.initialP.x+ep.initialP.z)*32.0f;
	}
	en.convexes[0].r          = en.model->headr;
	en.convexes[0].shift      = Point3D(0.0f,0.0f,0.0f);
	en.convexes[0].canCollide = true;

	en.position.SetID();
	en.position.Translate(en.center.p);
}

void InitBoxes ()
{
	for (int i=0; i<emBox.size(); ++i)
	{
		EntityModel& em = emBox[i];
		
		em.kind = MK_BOX;
		em.name = "Box";
		em.cpoints = 8;
		em.connections.Init(0,4*12+1,PK_GLOBAL);
		AddPc(0, em.connections,  1,3,0, 0,0);
		AddPc(0, em.connections,  2,0,3, 0,0);
		AddPc(0, em.connections,  0,4,1, 0,0);
		AddPc(0, em.connections,  5,1,4, 0,0);
		AddPc(0, em.connections,  1,5,3, 0,0);
		AddPc(0, em.connections,  7,3,5, 0,0);
		AddPc(0, em.connections,  7,6,3, 0,0);
		AddPc(0, em.connections,  2,3,6, 0,0);
		AddPc(0, em.connections,  2,6,0, 0,0);
		AddPc(0, em.connections,  4,0,6, 0,0);
		AddPc(0, em.connections,  5,4,7, 0,0);
		AddPc(0, em.connections,  6,7,4, 0,0);
		em.connections.push_back(-2);
		em.cconvexes = 1;
		em.entityProc = ProcBox;
		em.texture = &boxTxr[i];
		float r = 0.3f + 0.1f*float(i)/float(emBox.size()-1);
		em.mass  = 1.0f;
		em.headr = 2.0f*r;
		switch (i)
		{
		case BXK_HEALTH     : em.applyEntityProc = HealthApplyEntityProc; break;
		case BXK_BIG_HEALTH : em.applyEntityProc = BigHealthApplyEntityProc; break;
		case BXK_ARMOR      : em.applyEntityProc = ArmorApplyEntityProc; break;
		case BXK_GUN        : em.applyEntityProc = GunApplyEntityProc; break;
		case BXK_BFG        : em.applyEntityProc = BFGApplyEntityProc; break;
		default : em.applyEntityProc = NULL;
		}
	}
}

void ProcGasbag (Entity& en)
{
	if (en.monster->deathStage == 0.0f)
	{
		en.position.pt = en.center.p;
		return;
	}
	CorrectMonsterColliders (en);
	Matrix3D m;
	m.Scale(en.model->headr+0.02f);
	MoveSphere(en.entityPoints, Point3D(0.0f,0.0f,0.0f), m, 2.0f, -8.0f);
	en.position.SetID();
	en.position.Translate(en.center.p);
	en.position.Rotate(float(M_PI)-en.monster->anglez, 2);
}

void InitGasbags ()
{
	for (int i=0; i<emGasbag.size(); ++i)
	{
		EntityModel& em = emGasbag[i];
		
		em.kind = MK_MONSTER;
		em.name = "Gasbag";
		em.cpoints = 12;
		em.connections.Init(0,4*20+3,PK_GLOBAL);
		em.connections.push_back(-2);
		em.connections.push_back(-2);
		AddSphere(0, em.connections);
		em.cconvexes = 3;
		em.entityProc = ProcGasbag;
		em.texture = &mstrTxr[pasrnd.random(mstrTxr.size())];
		float r = 1.0f+float(pasrnd.frandom());
		em.player = false;
		em.initialhealth = 120.0f+100.f+float(i)/float(emGasbag.size()-1);
		em.mass  = 0.1f*r;
		em.headr = 0.25f*r;
		em.bodyr = 0.25f*r;
		em.legsr = 0.25f*r;
		em.hb    = 0.0f*r;
		em.minbl = 0.0f*r;
		em.maxbl = 0.0f*r;
		em.speed = 3.0f;
		em.spring = 0.0f;
		em.lightness = 1.0f;
		for (int j=0; j<em.weaponModels.size(); ++j)
		{
			em.weaponModels[j] = NULL;
			em.defaultHasWeapon[j] = false;
		}
		em.weaponModels[1] = (i*2>emGasbag.size()) ? &emWeapon[WK_BIG_ENERGY_BALL] : &emWeapon[WK_SMALL_ENERGY_BALL];
		em.defaultHasWeapon[1] = true;
	}
}

void ProcCock (Entity& en)
{
	if (en.monster->deathStage==0)
	{
		en.position.pt = en.center.p;
		return;
	}
	float s =sin(en.monster->stepStage*15.0f);
	CorrectMonsterColliders(en);
	for (int i=0; i<2; ++i)
	{
		en.convexes[i+3].canCollide = false;
		en.convexes[i+3].shift = Point3D((float(i)-0.5f)*0.8f*en.model->headr, 0.0f, 0.0f);
		en.convexes[i+3].r = en.model->headr;
	}
	Matrix3D m;
	m.Translate(en.convexes[0].shift);
	m.Scale(en.model->headr*0.6f, en.model->headr, en.model->headr);
	MoveSphere(en.entityPoints.get_slice(0,12), Point3D(0.0f,0.0f,0.0f), m, -2.0f, 0.0f);
	for (int i=0; i<2; ++i)
	{
		m.SetID();
		m.Rotate(s*0.5f, 1);
		m.Scale(en.model->headr*0.32f, en.model->headr*0.32f, en.model->headr*0.8f);
		m.Translate(en.convexes[i+3].shift);
		MoveSeg(en.entityPoints.get_slice(12+i*5, 12+(i+1)*5), Point3D(0.0f,0.0f,0.0f), m, 0.0f, 32.0f);
	}
	en.position.SetID();
	// очевидно надо наоборот
	en.position.Translate(en.center.p);
	en.position.Rotate(float(M_PI)-en.monster->anglez, 2);
	if (!en.monster->Live())
		en.position.Rotate((en.monster->deathStage+1.0f)*float(M_PI_2), 1);
}

void InitCocks ()
{
	for (int i=0; i<emCock.size(); ++i)
	{
		EntityModel& em = emCock[i];
		
		em.kind = MK_MONSTER;
		em.name = "Cock";
		em.cpoints = 12+2*5;
		em.connections.Init(0, 4*20+3+(6*4+1)*2, PK_GLOBAL);
		em.connections.push_back(-2);
		em.connections.push_back(-2);
		AddSphere(0, em.connections);
		for (int j=0; j<2; ++j)
			AddSeg(12+j*5, em.connections);
		em.cconvexes = 5;
		em.entityProc = ProcCock;
		em.texture = &mstrTxr[pasrnd.random(mstrTxr.size())];

		float r = 0.7f+float(pasrnd.frandom())*0.6f;
		em.player = false;
		em.initialhealth = 20.0f+120.f+float(i)/float(emCock.size()-1);
		em.mass  = 0.1f*r;
		em.headr = 0.3f*r;
		em.bodyr = 0.3f*r;
		em.legsr = 0.3f*r;
		em.hb    = 0.3f*r;
		em.minbl = 0.0f*r;
		em.maxbl = 0.0f*r;
		em.speed = 2.0f;
		em.spring = 8.0f;
		em.lightness = 0.0f;
		for (int j=0; j<em.weaponModels.size(); ++j)
		{
			em.weaponModels[j] = NULL;
			em.defaultHasWeapon[j] = false;
		}
		em.weaponModels[1] = (i*2>emCock.size()) ? &emWeapon[WK_BIG_CLAWS] : &emWeapon[WK_SMALL_CLAWS];
		em.defaultHasWeapon[1] = true;
	}
}

void ProcBoss (Entity& en)
{
	CorrectMonsterColliders(en);
	tblib::carray<float,3> a,c,s;

	for (int i=0; i<3; ++i)
	{
		a[i] = en.monster->stepStage*4.0f + float(i)+(float(M_PI)*2.0f/3.0f);
		c[i] = cos(a[i]);
		s[i] = sin(a[i]);
		en.convexes[i+3].canCollide = false;
		en.convexes[i+3].shift = Point3D(s[i],0.0f,c[i])*en.model->headr*1.7f;
		en.convexes[i+3].r = en.model->headr;
	}

	Matrix3D m;
	m.Rotate(float(M_PI_2), 0);
	m.Scale(en.model->headr+0.02f);
	MoveSphere(en.entityPoints.get_slice(0,12), Point3D(0.0f,0.0f,0.0f), m, -1.0f, -12.0f);
	for (int i=0; i<3; ++i)
	{
		m.SetID();
		m.Scale(en.model->headr*0.3f, en.model->headr*0.3f, en.model->headr*0.6f);
		m.Rotate(c[i], s[i], 1);
		m.Translate(en.convexes[i+3].shift);
		MoveSeg(en.entityPoints.get_slice(12+i*5, 12+(i+1)*5), Point3D(0.0f,0.0f,0.0f), m, 0.0f, 32.0f);
	}

	en.position.SetID();
	en.position.Translate(en.center.p);
	en.position.Rotate(float(M_PI)-en.monster->anglez, 2);
}

void InitBosses ()
{
	for (int i=0; i<emBoss.size(); ++i)
	{
		EntityModel& em = emBoss[i];
		
		em.kind = MK_MONSTER;
		em.name = "Boss";
		em.cpoints = 12+3*5;
		em.connections.Init(0,4*20+3+(6*4+1)*3,PK_GLOBAL);
		em.connections.push_back(-2);
		em.connections.push_back(-2);
		AddSphere(0, em.connections);
		for (int i=0; i<3; ++i)
			AddSeg(12+i*5, em.connections);
		em.cconvexes = 6;
		em.entityProc = ProcBoss;
		em.texture = &mstrTxr[pasrnd.random(mstrTxr.size())];
		float r = 2.0f;
		em.player = false;
		em.initialhealth = 20000.0f;
		em.mass  = 2.0f*r;
		em.headr = 0.25f*r;
		em.bodyr = 0.25f*r;
		em.legsr = 0.25f*r;
		em.hb    = 0.0f*r;
		em.minbl = 0.0f*r;
		em.maxbl = 0.0f*r;
		em.speed = 1.0f;
		em.spring = 0.0f;
		em.lightness = 1.0f;
		for (int j=0; j<em.weaponModels.size(); ++j)
		{
			em.weaponModels[j] = NULL;
			em.defaultHasWeapon[j] = false;
		}
		em.weaponModels[1] = &emWeapon[WK_SATAN_CLAWS];
		em.defaultHasWeapon[1] = true;
	}
}

void RotateBullet (Entity& en)
{
	en.convexes[0].shift = Point3D(0.0f,0.0f,0.0f);
	en.convexes[0].canCollide = false;
	Point3D& dp = en.bullet->deltaPos;
	const float 
		l1 = sqrt(dp.x*dp.x + dp.y*dp.y),
		l2 = sqrt(dp.x*dp.x + dp.y*dp.y + dp.z*dp.z),
		c1 = -dp.y/l1, s1 = dp.x/l1,
		c2 = -l1/l2, s2 = dp.z/l2;

	en.position.SetID();
	en.position.Translate(en.center.p);
	en.position.Rotate(c1,s1,0);
	en.position.Rotate(c2,s2,2);
}

void ProcBulletLong (Entity& en)
{
	Matrix3D m;
	m.Rotate(0.0f, 1.0f, 0);
	m.Scale(en.model->headr*0.1f, en.model->headr*0.1f, en.model->headr*0.9f);
	MoveSeg(en.entityPoints, Point3D(0.0f,0.0f,0.0f), m, 0.0f, 0.0f);
	RotateBullet(en);
}

void ProcBulletInvisible (Entity& en)
{
	Matrix3D m;
	m.Rotate(0.0f, 1.0f, 0);
	m.Scale(0.001f);
	MoveSeg(en.entityPoints, Point3D(0.0f,0.0f,0.0f), m, 0.0f, 0.0f);
	RotateBullet(en);
}

void ProcBulletNormal (Entity& en)
{
	Matrix3D m;
	m.Rotate(0.0f, 1.0f, 0);
	m.Scale(0.9f);
	MoveSeg(en.entityPoints, Point3D(0.0f,0.0f,0.0f), m, 0.0f, 0.0f);
	RotateBullet(en);
}

void InitBullets()
{
	for (int i=0; i<emBullet.size(); ++i)
	{
		EntityModel& em = emBullet[i];
		em.kind = MK_BULLET;
		em.name = "Bullet";
		em.cpoints = 5;
		em.cconvexes = 1;
		em.connections.Init(0, 4*6+1, PK_GLOBAL);
		AddSeg(0, em.connections);
		switch (i)
		{
		case BK_SABRE : case BK_BFG : em.entityProc = ProcBulletLong; break;
		case BK_CLAWS : em.entityProc = ProcBulletInvisible; break;
		case BK_BULLET : case BK_ENERGY_BALL : case BK_BLOOD : em.entityProc = ProcBulletNormal; break;
		default : em.entityProc = NULL; break;
		}

		switch (i)
		{
		case BK_SABRE : case BK_BULLET : em.texture = &techTxr[0]; break;
		case BK_CLAWS : case BK_BLOOD : em.texture = &baseTxr[TXR_BLOOD]; break;
		case BK_ENERGY_BALL : case BK_BFG : em.texture = &baseTxr[TXR_BLUE]; break;
		default : em.texture = NULL; break;
		}

		float r;

		switch(i)
		{
		case BK_SABRE : case BK_BFG : r = 4.0f; break;
		case BK_ENERGY_BALL : r = 0.7f; break;
		default : r = 0.3f; break;
		}

		em.headr = 0.25f*r;
		em.bodyr = 0.15f*r;
		em.legsr = 0.15f*r;
	}
}

void ProcWeapon (Entity& en) { (void)en; }

void InitSabre ()
{
	EntityModel& em = emWeapon[WK_SABRE];
	em.kind = MK_WEAPON;
	em.name = "Шашка";
	em.cpoints = 0;
	em.cconvexes = 1;
	em.connections.Init(0,1,PK_GLOBAL);
	em.connections.push_back(-2);
	em.entityProc = ProcWeapon;
	em.texture = &techTxr[0];

	em.headr = 0.5f;
	em.bulletspeed = 100.0f;
	em.range = 2.0f;
	em.damage = 2000.0f;
	em.bulletspershot = 1;
	em.dispersion = 0.0f;
	em.reloadtime = 0.3f;
	em.sabre = true;
	em.bulletModel = &emBullet[BK_SABRE];
}

void InitBlood ()
{
	EntityModel& em = emWeapon[WK_BLOOD];
	em.kind = MK_WEAPON;
	em.name = "Кровяша";
	em.cpoints = 0;
	em.cconvexes = 1;
	em.connections.Init(0,1,PK_GLOBAL);
	em.connections.push_back(-2);
	em.entityProc = ProcWeapon;
	em.texture = &baseTxr[TXR_BLOOD];

	em.headr = 0.1f;
	em.bulletspeed = 5.0f;
	em.range = 0.5f;
	em.damage = 0.0f;
	em.bulletspershot = 1;
	em.dispersion = 0.0f;
	em.reloadtime = 0.0f;
	em.sabre = false;
	em.bulletModel = &emBullet[BK_BLOOD];
}

void InitSmallClaws ()
{
	EntityModel& em = emWeapon[WK_SMALL_CLAWS];
	em.kind = MK_WEAPON;
	em.name = "Клешни";
	em.cpoints = 0;
	em.cconvexes = 1;
	em.connections.Init(0,1,PK_GLOBAL);
	em.connections.push_back(-2);
	em.entityProc = ProcWeapon;
	em.texture = &baseTxr[TXR_BLOOD];

	em.headr = 0.1f;
	em.bulletspeed = 100.0f;
	em.range = 0.5f;
	em.damage = 10.0f;
	em.bulletspershot = 1;
	em.dispersion = 0.0f;
	em.reloadtime = 0.7f;
	em.sabre = false;
	em.bulletModel = &emBullet[BK_CLAWS];
}

void InitBigClaws ()
{
	EntityModel& em = emWeapon[WK_BIG_CLAWS];
	em.kind = MK_WEAPON;
	em.name = "Клешни";
	em.cpoints = 0;
	em.cconvexes = 1;
	em.connections.Init(0,1,PK_GLOBAL);
	em.connections.push_back(-2);
	em.entityProc = ProcWeapon;
	em.texture = &baseTxr[TXR_BLOOD];

	em.headr = 0.1f;
	em.bulletspeed = 100.0f;
	em.range = 0.5f;
	em.damage = 18.0f;
	em.bulletspershot = 1;
	em.dispersion = 0.0f;
	em.reloadtime = 0.7f;
	em.sabre = false;
	em.bulletModel = &emBullet[BK_CLAWS];
}

void InitSmallEnergyBall ()
{
	EntityModel& em = emWeapon[WK_SMALL_ENERGY_BALL];
	em.kind = MK_WEAPON;
	em.name = "Энергошар";
	em.cpoints = 0;
	em.cconvexes = 1;
	em.connections.Init(0,1,PK_GLOBAL);
	em.connections.push_back(-2);
	em.entityProc = ProcWeapon;
	em.texture = &baseTxr[TXR_BLUE];

	em.headr = 0.1f;
	em.bulletspeed = 6.0f;
	em.range = 50.0f;
	em.damage = 9.0f;
	em.bulletspershot = 1;
	em.dispersion = 0.0f;
	em.reloadtime = 1.1f;
	em.sabre = false;
	em.bulletModel = &emBullet[BK_ENERGY_BALL];
}

void InitBigEnergyBall ()
{
	EntityModel& em = emWeapon[WK_BIG_ENERGY_BALL];
	em.kind = MK_WEAPON;
	em.name = "Энергошар";
	em.cpoints = 0;
	em.cconvexes = 1;
	em.connections.Init(0,1,PK_GLOBAL);
	em.connections.push_back(-2);
	em.entityProc = ProcWeapon;
	em.texture = &baseTxr[TXR_BLUE];

	em.headr = 0.1f;
	em.bulletspeed = 6.0f;
	em.range = 50.0f;
	em.damage = 16.0f;
	em.bulletspershot = 1;
	em.dispersion = 0.0f;
	em.reloadtime = 1.1f;
	em.sabre = false;
	em.bulletModel = &emBullet[BK_ENERGY_BALL];
}

void InitSatanClaws ()
{
	EntityModel& em = emWeapon[WK_SATAN_CLAWS];
	em.kind = MK_WEAPON;
	em.name = "Клешни сатаны";
	em.cpoints = 0;
	em.cconvexes = 1;
	em.connections.Init(0,1,PK_GLOBAL);
	em.connections.push_back(-2);
	em.entityProc = ProcWeapon;
	em.texture = &baseTxr[TXR_BLUE];

	em.headr = 0.1f;
	em.bulletspeed = 7.0f;
	em.range = 50.0f;
	em.damage = 54.0f;
	em.bulletspershot = 1;
	em.dispersion = 0.0f;
	em.reloadtime = 1.0f;
	em.sabre = false;
	em.bulletModel = &emBullet[BK_BFG];
}

void InitGun ()
{
	EntityModel& em = emWeapon[WK_GUN];
	em.kind = MK_WEAPON;
	em.name = "Гармата";
	em.cpoints = 0;
	em.cconvexes = 1;
	em.connections.Init(0,1,PK_GLOBAL);
	em.connections.push_back(-2);
	em.entityProc = ProcWeapon;
	em.texture = &baseTxr[TXR_BLUE];

	em.headr = 0.1f;
	em.bulletspeed = 30.0f;
	em.range = 50.0f;
	em.damage = 14.0f;
	em.bulletspershot = 1;
	em.dispersion = 0.0f;
	em.reloadtime = 0.1f;
	em.sabre = false;
	em.bulletModel = &emBullet[BK_BULLET];
}
	
void InitBFG ()
{
	EntityModel& em = emWeapon[WK_BFG];
	em.kind = MK_WEAPON;
	em.name = "Транклюкатор";
	em.cpoints = 0;
	em.cconvexes = 1;
	em.connections.Init(0,1,PK_GLOBAL);
	em.connections.push_back(-2);
	em.entityProc = ProcWeapon;
	em.texture = &baseTxr[TXR_BLUE];

	em.headr = 0.1f;
	em.bulletspeed = 15.0f;
	em.range = 20.0f;
	em.damage = 6666.0f;
	em.bulletspershot = 1;
	em.dispersion = 0.0f;
	em.reloadtime = 4.5f;
	em.sabre = false;
	em.bulletModel = &emBullet[BK_BULLET];
}

void InitWeapons ()
{
	InitSabre();
	InitBlood();
	InitSmallClaws();
	InitBigClaws();
	InitSmallEnergyBall();
  InitBigEnergyBall();
	InitSatanClaws();
	InitGun();
	InitBFG();
}

void InitModels()
{
	InitPlayers();
	InitSnowmans();
	InitTrilobits();
	InitBoxes();
	InitGasbags();
	InitCocks();
	InitBosses();
	InitBullets();
	InitWeapons();
}
