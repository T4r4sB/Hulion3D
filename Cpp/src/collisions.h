#pragma once
#include "points3d.h"
#include "geometry.h"
#include "entitys.h"

Point3D DivDist(const Point3D& p1, const Point3D& p2)
{
	const Point3D delta = p1-p2;
	const float dot1 = Dot(delta,p1), dot2 = -Dot(delta,p2);
	if (dot1<0.0f) return p1;
	else if (dot2<0.0f) return p2;
	else return p1+(p2-p1)*(dot1/(dot1+dot2));
}

bool SPoint::TraceWithEntitys (const Point3D& delta, marray<CheckPtr<Entity> > &entitys, bool fullCheck)
{
	assert(Correct());
	Point3D op = p;
	p += delta;
	AddEntitysFromSector(entitys, op, fullCheck);
	while (!Correct())
	{
		Face* newF = getIntersectionFace(delta);
		if (!newF->penetrable || !newF->nextSector)
		{ // УПРЛС В СТЕНКУ
			float t1 = newF->Dist(op), t2 = newF->Dist(p);
			if (t1<=0.0f && t2>0.0f)
        p += delta * ( t2/(t1-t2) );
			DoCorrect();
			AddEntitysFromSector(entitys, op, fullCheck);
			return false;
		}
		s = newF->nextSector;
		AddEntitysFromSector(entitys, op, fullCheck);
	}
	assert(Correct());
	return true;
}

void SPoint::AddEntitysFromSector(marray<CheckPtr<Entity> > &entitys, const Point3D& prev, bool fullCheck)
{
	if (entitys.capacity()==0) 
		return;
	for (ConvexInSector* pcs = s->fConvex; pcs; pcs=pcs->nc)
	{
		Convex& c = *pcs->convex;
		if (c.canCollide && !c.entity->inProcess 
		&& (!fullCheck || DivDist(p-c.center.p, prev-c.center.p).SqrLength()<c.r*c.r))
			entitys.emplace_back(c.entity);
	}
}

bool Visible (const SPoint& p1, const SPoint& p2)
{
	SPoint p(p1);
	if (!p.Trace(p2.p-p.p)) return false;
	if (p.s!=p2.s) return false;
	return true;
}

struct Edge
{
	Point3D p1, p2;
};

Point3D ToR(const Point3D& p, float r)
{
	float l=p.SqrLength();
	if (l==0.0f) return Point3D(0.0f,0.0f,-abs(r));
	else
	{
		float sl=sqrt(l);
		return p*(-(r-sl)/sl);
	}
}

void SPoint::GetSectorsFrom (Sector* vs, float r, bool push, marray<CheckPtr<Sector> > &a)
{
	if (vs->inProcess) return;
	a.emplace_back(vs);

	for (int i=vs->faces.low(); i<vs->faces.high(); ++i)
	{
		Face& f = vs->faces[i];
		float dst = f.Dist(p); // напоминаю, отрицательное dist для тех кто внутри
		float dr = r + dst; 
		if (dr>0.0f)
		{    
			// кажется, мы близки к этой грани. ну по крайней мере, мы точно близки к плоскости, что её содержит
			mslice<Edge> edges(f.points.low(), f.points.high(), PK_TEMP);
			for (int j=edges.low(); j<edges.high(); ++j)
			{
				Edge& e = edges[j];
				int nj = (j+1>=edges.high()) ? edges.low() : j+1;
				e.p1 = *f.points[j]-p;
				e.p2 = *f.points[nj]-p;
			}

			bool in=true;
			for (int j=f.points.low(); j<f.points.high(); ++j)
				if (Volume(edges[j].p1, edges[j].p2,f.n)>0.0f)
					{ in=false; break; }
			if (in)
			{
				if (f.penetrable) 	GetSectorsFrom(f.nextSector, r, push, a); 
				else if (push)			Trace(f.n*(-dr));
			} else
			{				
				for (int j=edges.low(); j<edges.high(); ++j)
				{
					Edge& e = edges[j];
					Point3D dd = DivDist(e.p1,e.p2);
					if (dd.SqrLength() <= r*r)
					{
						if (f.penetrable) GetSectorsFrom(f.nextSector, r, push, a); 
						else if (push) Trace(ToR(dd, r));
					}
				}
			}
		}
	}
}