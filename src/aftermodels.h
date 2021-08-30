#pragma once

#include "entitymodels.h"
#include "collisions.h"
#include "level.h"

void PushTwoConvexes (Convex& c1, Convex& c2, bool noMassC1)
{
	Point3D delta = c1.center.p-c2.center.p;
	const float 
		m1 = noMassC1 ? 0.0f : c1.mass,
		m2 = c2.mass,
		mr1 = m1/(m1+m2),
		mr2 = 1.0f-mr1,
		l2 = delta.SqrLength(),
		sr = c1.r+c2.r;
	if (l2<sr*sr)
	{
		assert (c1.entity->model->kind != MK_BOX);
		if (!noMassC1 
			&& c2.entity->model->kind == MK_BOX 
			&& c1.entity->model->kind == MK_MONSTER
			&& c1.entity->model->player
			&& c2.entity->model->applyEntityProc(*c1.entity->monster))
		{ // подобрать предмет
			c2.entity->center.s = &l.emptyS;
			c2.entity->center.p = c2.entity->center.s->Center();
			c2.entity->Update();
		} else
		{
			const float 
				l = sqrt(l2),
				dr = sr-l;
			float revl;
			if (l==0.0f)
			{
				revl = 1.0f;
				delta = Point3D(0.0f,0.0f,1.0f);
			}	else
				revl =1.0f/l;
			c1.center.Trace(delta*(+dr*mr2*revl));
			c2.center.Trace(delta*(-dr*mr1*revl));
		}
	}
}

void Convex::Push (bool noMass)
{	
	marray<CheckPtr<Sector> > a(0,maxSectors,PK_TEMP);
	center.GetSectorsAndPush(r, a);
	if (canCollide)
	{
		marray<CheckPtr<Convex> > c(0,maxConvexes,PK_TEMP);
		for (int i=a.low(); i<a.high(); ++i) for (ConvexInSector* pcs = a[i]->fConvex; pcs; pcs=pcs->nc)
		{
			if (!pcs->convex->inProcess && pcs->convex->entity != entity && pcs->convex->canCollide)
				c.emplace_back(pcs->convex); // c нужно чтобы запомнить кто в процессе 
		}

		for (int i=c.low(); i<c.high(); ++i)
			PushTwoConvexes(*this, *c[i], noMass);
	}
}

void Entity::Create(Sector* s, EntityModel* model)
{
	this->model = model;

	if (model->kind != MK_MONSTER) monster=NULL;
	if (model->kind != MK_BULLET)  bullet =NULL;
	if (model->kind != MK_WEAPON)  weapon =NULL;

	inProcess = 0;
	center.s = s;
	center.p = s->Center();
	center.Trace(Point3D(0.0f, 0.0f, 1000.0f));
	center.Trace(Point3D(0.0f, 0.0f, -model->headr));

	entityPoints.Init(0, model->cpoints, PK_GLOBAL);
	convexes.Init(0, model->cconvexes, PK_GLOBAL);

	position.SetID();

	for (int i = convexes.low(); i<convexes.high(); ++i)
		convexes[i].center = center;

	model->entityProc(*this); // выставить базовые координаты
	MovePoints();            // подвинуть точки

	int j = model->connections.low();
	for (int i = convexes.low(); i<convexes.high(); ++i)
	{
		Convex&c = convexes[i];
		c.entity = this;
		c.fSector = NULL;
		c.lSector = NULL;
		c.inProcess = 0;
		c.mass = model->mass;

		marray<Point3D*> pts(model->connections.low(), model->connections.high(), PK_TEMP);
		for (; model->connections[j]>=-1; ++j)
			pts.push_back(model->connections[j]>=0 ? &entityPoints[model->connections[j]] : NULL);
		++j;
		c.g.Create(pts.get_slice(pts.low(), pts.high()));
		for (int f=c.g.faces.low(); f<c.g.faces.high(); ++f)
		{
			c.g.faces[f].texture = model->texture;
			c.g.faces[f].light = 2;
		}
		assert(c.r<10.0f);
	}
	
	RegroupTxr();
	PutToSectors();
}

void Entity::Update()
{
	DelFromSectors();
	model->entityProc(*this);
	RegroupTxr();
	PutToSectors();
}

void SetMonsterActive (Monster& m);

void Monster::Create(Sector* s, EntityModel* model)
{
	anglex         = float(M_PI_2);
	anglez         = float(M_PI);
	stepStage      = 0.0f;
	entity.monster = this;
	deathStage     = -1.0f;
	health         = model->initialhealth;
	armor          = 0.0f;
	currentWeapon  = 0;
	lastDamageTime = 1.0f;
	prevShot       = 0.0f;
	entity.Create(s, model);
	entity.convexes[0].r = model->headr;
	entity.convexes[1].r = model->bodyr;
	entity.convexes[2].r = model->legsr;
	for (int i=0; i<weapons.size(); ++i)
	{
		weapons[i].isWeapon = (model->defaultHasWeapon[i] && model->weaponModels[i]!=NULL);
		if (model->weaponModels[i])
			weapons[i].Create(model->weaponModels[i]);
	}	
	oldPosition = Center();
	beforePush  = Center();
}

void Monster::Push(bool noMass)
{
	Point3D c = Center();
	float 
		zh = head->p.z, 
		zl = legs->p.z, 
		dz;
	dz = zl - (zh + entity.model->hb + entity.model->maxbl);
	if (dz>0.0f)
	{
		zh += dz*mLegsW;
		zl -= dz*mHBW;
	}
	dz = (zh + entity.model->hb + entity.model->minbl) - zl;
	if (dz>0.0f)
	{
		zh -= dz*mLegsW;
		zl += dz*mHBW;
	}
	float zb = zh + entity.model->hb;

	head->Trace(Point3D(c.x, c.y, zh) - head->p);
	body->Trace(Point3D(c.x, c.y, zb) - body->p);
	legs->Trace(Point3D(c.x, c.y, zl) - legs->p);
	entity.convexes[0].Push(noMass);
	entity.convexes[1].Push(noMass);
	entity.convexes[2].Push(noMass);
}

void Monster::Shot(EntityModel& wpModel, float dx)
{
	(void)wpModel;
	(void)dx;

	const float
		cx = cos(anglex),
		sx = sin(anglex),
		cz = cos(anglez+dx*2.0f),
		sz = sin(anglez+dx*2.0f);
	SPoint newBulletPos = *body;
	const Point3D 
		dh  (sz,   cz,   0.0f),
		dir (sz*sx,cz*sx,cx);

	newBulletPos.Trace(dh*(entity.model->bodyr+0.1f) + dir*(entity.model->headr));
	DischargeNewBullet (newBulletPos, dir, *this, wpModel);
}

void Monster::TryShot()
{
	Weapon& w = weapons[currentWeapon];
	if (w.isWeapon)
	{
		if (w.entity.model->sabre)
		{
			if (w.reloadLeft<=0.0f)
				w.reloadLeft = w.entity.model->reloadtime;
			Shot(*w.entity.model, w.reloadLeft/w.entity.model->reloadtime-0.5f);
		} else
		{
			if (w.reloadLeft<=0.0f)
			{
				w.reloadLeft = w.entity.model->reloadtime;
				Shot(*w.entity.model, 0.0f);
			}
		}
	}
}

void Monster::Move(float dt)
{
	
	if (Live())
	{
		anglex += controls.dax*dt;
		tblib::inbound(anglex, 0.0f, float(M_PI));

		anglez += controls.daz*dt;
		anglez = fmod(anglez, 2.0f*float(M_PI));
	}

	float c = cos(anglez), s = sin(anglez);

	Point3D move(0.0f,0.0f,0.0f);

	if (Live())
	{
		if (controls.forw)  move += Point3D( s,-c,0.0f); 
		if (controls.back)  move += Point3D(-s, c,0.0f); 
		if (controls.left)  move += Point3D(-c,-s,0.0f); 
		if (controls.right) move += Point3D( c, s,0.0f);
		if (controls.jump)  move += Point3D(0.0f, 0.0f, -entity.model->lightness);
		if (controls.sit)   move += Point3D(0.0f, 0.0f,  entity.model->lightness);
	} else
	{
		deathStage -= dt;
		tblib::enlarge(deathStage, 0.0f);
	}

	float l = move.Length();
	if (l>0.0f) move *= (0.03f/l);

	float st = (legs->p.z - body->p.z + 0.4f) / (entity.model->maxbl+0.4f); // если присели то пополам
	move *= (fric*0.95f+0.05f);

	if (Live())
	{
		if (controls.jump)
			move += Point3D(0.0f,0.0f, -entity.model->spring*dt*st*fric);
	}

	move += Point3D(0.0f,0.0f, legs->s->gravity*(1.0f-entity.model->lightness));

	// теперь двигаем, причём два раза, сначала понарушку, чтоб трение узнать, потом по-настоящему
	/*
	SPoint oh=*head, ob=*body, ol=*legs;

	Point3D beforeTrace = Center();
	Trace();
	Point3D beforePush = Center();
	Push(true);
	Point3D afterPush = Center();

	deltaPos = afterPush - beforeTrace;
  Point3D dp = beforePush-afterPush;
	fric = (dp.z - sqrt(dp.x*dp.x + dp.y*dp.y)*0.3f)*1000.0f;
	tblib::inbound(fric,0.0f,1.0f);
	fric += (1.0f-fric)*entity.model->lightness; // сила трения 

	l = deltaPos.Length();
	s = l-(entity.model->speed*dt+(1.0f-fric))*st; // превышение скорости
	tblib::enlarge(s, 0.0f);
  s += fric*0.01f;

	if (l>s) deltaPos *= (1.0f-s/l); else deltaPos = Point3D(0.0f,0.0f,0.0f);// замедлить

	*head=oh; *body=ob; *legs=ol;
	Trace();
	Push(false);*/
	
	move += Center()-oldPosition; // теперь в op+move хранится место, куда мы хотим попасть
	Point3D dp = Center()-beforePush;
	fric = (-dp.z - sqrt(dp.x*dp.x + dp.y*dp.y)*0.3f)*1000.0f;
	tblib::inbound(fric,0.0f,1.0f);
	fric += (1.0f-fric)*entity.model->lightness; // сила трения 
	
	// сейчас oldPosition - это место, где мы были, op+movenofr - это место, кда мы бы попали если б не трение
	// надо передвинуть center в другое место, и move кастрировать
	Point3D movenofr = move;

	l = move.Length();
	s = l-(entity.model->speed*dt+(1.0f-fric))*st; // превышение скорости
	tblib::enlarge(s, 0.0f);
  s += fric*0.01f;
	// вычислили силу трения, теперь режем перемещение
	if (l>s) move *= (1.0f-s/l); else move = Point3D(0.0f,0.0f,0.0f);// замедлить

	// теперь мы знаем про отличие move от movenofr
	oldPosition += move;	// якобы мы были в точке, в которую попали с трением
	Trace( (oldPosition + move) - Center() ); // TraceTo (op+move)
	beforePush = Center();
	Push(false);

  
	// движение закончили, теперь берёмся за оружие

	for (int i=0; i<10; ++i)
	{
		weapons[i].reloadLeft -= dt;
		tblib::enlarge(weapons[i].reloadLeft, 0.0f);
	}

	if (Live())
	{
		lastDamageTime += dt;
		tblib::shrink(lastDamageTime, 1.0f);

		if (controls.wpnumber>=0 && controls.wpnumber<=9 
			&& weapons[controls.wpnumber].isWeapon)
			currentWeapon = controls.wpnumber;

		if (fric>0.0f) stepStage += move.Length();
		if (controls.shot)
			TryShot();
	}
	prevShot = controls.shot;
}

void Monster::RecieveDamage(const SPoint &from, float dmg, float dt)
{
	SetMonsterActive(*this);
	Trace((body->p-from.p)*(dt/entity.model->mass));
	lastDamageTime = 0.0f;

	health -= dmg*(1.0f-armor*0.01f);
	if (health<=0.0f)
		deathStage = 1.0f;
	armor -= 2.0f;
	tblib::enlarge(armor, 0.0f);

	int cnt = std::min( int(dmg)+int(float(pasrnd.frandom())<frac(dmg)), 32);
	for (int i=0; i<cnt; ++i)
	{
		DischargeNewBullet(from, RandomPoint(), *this, emWeapon[WK_BLOOD]);
	}
}

void Weapon::Create(EntityModel* model)
{
	reloadLeft = 0;
	entity.weapon = this;
	entity.Create(&l.emptyS, model);
}

void Bullet::Create()
{
	weaponModel = NULL;
	deltaPos = Point3D(0.0f, 0.0f, 0.0f);
	tripDist = 0.0f;
	owner    = NULL;
	active   = false;
	entity.bullet = this;
	entity.Create(&l.emptyS, &emBullet[0]);
	entity.model = NULL;
}

void Bullet::Trace(float dt)
{
	float s = dt*weaponModel->bulletspeed;
	if (tripDist+s > weaponModel->range)
	{
		s = weaponModel->range-tripDist;
		active = false;
	}

	if (weaponModel->damage>0.0f)
	{
    marray<CheckPtr<Entity> > a(0, maxEntitys, PK_TEMP);
		SPoint oc = entity.center;
		if (!entity.center.TraceWithEntitys(deltaPos*s, a, true))
			active=false;
		const float dmg = (weaponModel->sabre) ? weaponModel->damage*dt : weaponModel->damage;

		for (int i=a.low(); i<a.high(); ++i) if (a[i]->monster && a[i]->monster->deathStage<0.0f)
		{
			a[i]->monster->RecieveDamage(oc, dmg, dt);
			if (!weaponModel->sabre) active=false;
		}
	} else 
	{
		if (!entity.center.Trace(deltaPos*s))
			active=false;
	}
	tripDist += s;
}

void Bullet::Deactivate()
{
	active = false;
	entity.center.s = &l.emptyS;
	entity.center.p = entity.center.s->Center();
}

