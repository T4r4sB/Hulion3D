#pragma once

#include "memory.h"
#include "geometry.h"

struct Monster;
struct Bullet;
struct Weapon;
struct EntityModel;

Pool<ConvexInSector, 0x10000> convexInSectorPool;

struct EntityPoint : Point3D
{
	Point3D initialP;
	float tx,ty;

};

struct Entity
{
	int                    inProcess;
	SPoint                 center;
	Matrix3D               position;
	mslice <Convex>        convexes;

	Monster*               monster;
	Bullet*                bullet;
	Weapon*                weapon;

	mslice <EntityPoint>   entityPoints;
	EntityModel*           model;

	void Create (Sector* s, EntityModel* model);

	static ConvexInSector*& PFNC (const ConvexInSector &cs) {	return cs.nc ? cs.nc->pc : cs.sector->lConvex; }	
	static ConvexInSector*& PFPC (const ConvexInSector &cs) {	return cs.pc ? cs.pc->nc : cs.sector->fConvex; }
	static ConvexInSector*& PFNS (const ConvexInSector &cs)	{	return cs.ns ? cs.ns->ps : cs.convex->lSector; }			
	static ConvexInSector*& PFPS (const ConvexInSector &cs)	{	return cs.ps ? cs.ps->ns : cs.convex->fSector; }

	static bool NoInThisSector(const Sector& s, Convex* c)
	{
		for (ConvexInSector* pcs=s.fConvex; pcs; pcs=pcs->nc)
			if (pcs->convex==c)
				return false;
		return true;
	}

	void PutToSectors ()
	{		
		marray<CheckPtr<Sector> > a(0,maxSectors,PK_TEMP);
		for (int i=convexes.low(); i<convexes.high(); ++i)
		{
			Convex& c=convexes[i];
      c.GetSectors(a);
			assert(a.high()<=a.low()+10);
			for (int j=a.low(); j<a.high(); ++j)
			{
				assert(NoInThisSector(*a[j], &c));
				ConvexInSector* pcs = convexInSectorPool.NewPtr();
				pcs->convex = &c;
				pcs->sector = a[j];

				(c.fSector ? c.lSector->ns : c.fSector)=pcs;
				pcs->ps = c.lSector;
				c.lSector = pcs;

				(a[j]->fConvex ? a[j]->lConvex->nc : a[j]->fConvex)=pcs;
				pcs->pc = a[j]->lConvex;
				a[j]->lConvex = pcs;

				pcs->ns = NULL;
				pcs->nc = NULL;
			}
		}		
	}

	void FreeAndNextS (ConvexInSector*&cs)
	{
		ConvexInSector* next = cs->ns;
		convexInSectorPool.FreePtr(cs);
		cs = next;
	}

	void DelFromSectors ()
	{
		for (int i=convexes.low(); i<convexes.high(); ++i)
		{
			for (ConvexInSector* cs = convexes[i].fSector; cs; FreeAndNextS(cs) )
			{
				ConvexInSector *&nc = PFNC(*cs), *&pc = PFPC(*cs);
				nc = cs->pc;
				pc = cs->nc;
				
				ConvexInSector *&ns = PFNS(*cs), *&ps = PFPS(*cs);
				ns = cs->ps;
				ps = cs->ns;
			}
			assert (convexes[i].fSector==NULL);
			assert (convexes[i].lSector==NULL);
		}
	}

	void MovePoints ()
	{
		for (int i = entityPoints.low(); i<entityPoints.high(); ++i)
			static_cast<Point3D&>(entityPoints[i]) = position.RotateP(entityPoints[i].initialP);

		for (int i=convexes.low(); i<convexes.high(); ++i)
		{
			convexes[i].center = center;
			convexes[i].center.Trace(position.RotatePNoTr(convexes[i].shift));
		}
	}

	void RegroupTxr ()
	{
		MovePoints ();
		for (int i=convexes.low(); i<convexes.high(); ++i)
		{
			Convex&c = convexes[i];
			c.g.InitNormals();
			for (int j = c.g.faces.low(); j<c.g.faces.high(); ++j)
			{
				Face& f = c.g.faces[j];
				EntityPoint 
					&ep1 = *static_cast<EntityPoint*>(f.points[f.points.low()+0]),
					&ep2 = *static_cast<EntityPoint*>(f.points[f.points.low()+1]),
					&ep3 = *static_cast<EntityPoint*>(f.points[f.points.low()+2]);
				const Point3D 
					tpx(ep1.tx, ep2.tx, ep3.tx),
					tpy(ep1.ty, ep2.ty, ep3.ty),
					s12(ep2-ep1),
					s13(ep3-ep1);
				const float
					a11b = Dot(s12,s12),
					a12b = Dot(s12,s13),
					a22b = Dot(s13,s13),
					v = 1.0f / (a11b*a22b-a12b*a12b),
					a11 = a11b*v,
					a12 = a12b*v,
					a22 = a22b*v;
				tblib::carray<Point3D, 3> rev;
				for (int k=0; k<3; ++k)
					rev[k] = Point3D(
						s12[k]*(-a22+a12) + s13[k]*(-a11+a12),
						s12[k]*(+a22    ) + s13[k]*(    -a12),
						s12[k]*(    -a12) + s13[k]*(+a11    ));
				for (int k=0; k<3; ++k) 
					f.vtx[k] = Dot(rev[k], tpx);
				f.vtxc = Dot(ep1, f.vtx) - ep1.tx;
				for (int k=0; k<3; ++k) 
					f.vty[k] = Dot(rev[k], tpy);
				f.vtyc = Dot(ep1, f.vty) - ep1.ty;
			}
		}
	}

	void Update ();

	~Entity() {DelFromSectors(); }
};