#pragma once

#include "tbal.h"
#include "engine.h"
#include <algorithm>
#include "fillrate.h"
#include "hud.h"


void LayoutLine (const ShowSectorInfo& si, const TemporaryShowSectorInfo &tsi, 
	const Line& l, ScreenLine& sl,
	Bound& b1, Bound& b2 )
{
	Point3D p1 = tsi.s.skybox ? si.m.RotatePNoTr(*l.p1) : si.m.RotateP(*l.p1);
	Point3D p2 = tsi.s.skybox ? si.m.RotatePNoTr(*l.p2) : si.m.RotateP(*l.p2);

	const Point3D __cut[5] = {
		Point3D( 0.0f, 0.0f, 1.0f),
		Point3D( 0.0f,-1.0f, 1.0f),
		Point3D( 0.0f, 1.0f, 1.0f),
		Point3D(-1.0f, 0.0f, 1.0f),
		Point3D( 1.0f, 0.0f, 1.0f)};
	const float __cutd[5] = {-minD, 0.0f,0.0f,0.0f,0.0f};

	tblib::carray<Point3D,5> cut(__cut);
	tblib::carray<float,5> cutd(__cutd);

	sl.f1=l.f1, sl.f2=l.f2;
	int w = si.b.sizeX(), h = si.b.sizeY();
	int py1=h, py2=-1;
	float x1,y1,x2,y2;

	for (int i=0; i<cut.size(); ++i) // нарезка
	{
		float t1 = Dot(p1, cut[i]) + cutd[i];
		float t2 = Dot(p2, cut[i]) + cutd[i];
		if (t1<0.0f && t2<0.0f) // вне экрана
		{
			if (i==3) 
				for (int j=py1; j<py2; ++j) 
					sl[j] = tsi.curZ[j].v2;
			if (i==4) 
				for (int j=py1; j<py2; ++j) 
					sl[j] = tsi.curZ[j].v1;
			return;
		} else if (t1<0.0f) 
		{ 
			p1 += (p2-p1)*(t1/(t1-t2));
			p1.z = (cutd[i] - p1.x*cut[i].x - p1.y*cut[i].y)/cut[i].z;
		} else if (t2<0.0f)
		{
			p2 += (p1-p2)*(t2/(t2-t1));
			p2.z = (cutd[i] - p2.x*cut[i].x - p2.y*cut[i].y)/cut[i].z;
		}
		if (i==2) 
		{
      y1 = h*(p1.y+p1.z)/(p1.z+p1.z);
      y2 = h*(p2.y+p2.z)/(p2.z+p2.z);
			if (y1>y2)
			{
				std::swap(y1,y2);
				std::swap(sl.f1,sl.f2);
				std::swap(p1,p2);
			}
			py1 = int(y1)+1; 
			tblib::enlarge(py1, tsi.curZ.low());
			py2 = int(y2)+1; 
			tblib::shrink (py2, tsi.curZ.high());

			if (py1<py2)
			{
				sl.Init(py1,py2,PK_TEMP);
				// раздвинем границы!
				tblib::shrink (b1.v1, py1);
				tblib::enlarge(b1.v2, py2);
				tblib::shrink (b2.v1, py1);
				tblib::enlarge(b2.v2, py2);
			}
			else
				return;
		}
	} // конец нарезки

	x1 = w*(p1.x+p1.z)/(p1.z+p1.z);
	y1 = h*(p1.y+p1.z)/(p1.z+p1.z);
	x2 = w*(p2.x+p2.z)/(p2.z+p2.z);
	y2 = h*(p2.y+p2.z)/(p2.z+p2.z);
  
	int ty1 = int (y1)+1; 
	tblib::inbound(ty1, py1, tsi.curZ.high()); 
	int ty2 = int (y2)+1; 
	tblib::inbound(ty2, tsi.curZ.low(), py2); 

	if (int(x1)< w/2) for (int j=py1; j<ty1; ++j) sl[j] = tsi.curZ[j].v1;
	else              for (int j=py1; j<ty1; ++j) sl[j] = tsi.curZ[j].v2;
	if (int(x2)< w/2) for (int j=ty2; j<py2; ++j) sl[j] = tsi.curZ[j].v1;
	else              for (int j=ty2; j<py2; ++j) sl[j] = tsi.curZ[j].v2;

	if (ty1<ty2)
	{
		float x = x1+(x2-x1)*(float(ty1)-y1)/(y2-y1);
		sl[ty1] = int(x)+1;
		if (ty1+1<ty2)
		{
			int  x16 = HackTrunc(x,16)+0x10000;
			int dx16 = HackTrunc((x2-x1)/(y2-y1),16);
			for (int j=ty1+1; j<ty2; ++j)
			{
				x16 += dx16;
				sl[j] = x16>>16;
			}
		}
	}	
}

void ApplyLineToZones (const ScreenLine& sl, ScreenZone& z1, ScreenZone& z2)
{
	for (int i=sl.low(); i<sl.high(); ++i)
	{
		tblib::enlarge (z1[i].v1, sl[i]);
		tblib::shrink  (z2[i].v2, sl[i]);
	}
}

struct SortConvexItem {	
	float z; 
	int i; 
	bool operator < (const SortConvexItem& other) { return z<other.z; }
};

void SortConvexes(const Matrix3D&m, bool skybox, marray<CheckPtr<Convex> > &a)
{
	// временнный масив с предрассчитанными ключевыми значениями
	mslice<SortConvexItem> tmp(a.low(), a.high(), PK_TEMP);
	for (int i=a.low(); i<a.high(); ++i)
	{
		Point3D p = skybox ? m.RotatePNoTr(a[i]->center.p) : m.RotateP(a[i]->center.p);
		tmp[i].z = p.z;
		tmp[i].i = i;
	}
	std::sort(tmp.begin(), tmp.end());
	// теперь tmp хранит пермутацию, надо её применить
	mslice<int> revtmp(tmp.low(), tmp.high(), PK_TEMP);
	for (int i=tmp.low(); i<tmp.high(); ++i)
		revtmp[tmp[i].i] = i;
	// завели обратную пермутацию, теперь надо выровнять её
	for (int i=revtmp.low(); i<revtmp.high(); ++i) while (revtmp[i] != i)
	{
		int ni = revtmp[i];
		std::swap(     a[i],      a[ni]);
		std::swap(revtmp[i], revtmp[ni]); // теперь revtmp[ni] хранит ni, это +1 к числу верно расставленных
	}
}

bool NoZoneIntersect (const TemporaryShowSectorInfo& tsi, mslice<ScreenZone> &zones)
{
	for (int k = tsi.curZ.low(); k<tsi.curZ.high(); ++k)
	{
		for (int i=zones.low(); i<zones.high(); ++i) if (zones[i].f && k>=zones[i].low() && k<zones[i].high())
		for (int j=i+1;         j<zones.high(); ++j) if (zones[j].f && k>=zones[j].low() && k<zones[j].high())
		{
			Bound& b1 = zones[i][k];
			Bound& b2 = zones[j][k];
			if (b1.v2<=b2.v1) // тогда одна перед другой
			{} else if (b2.v2<=b1.v1) // Тогда наоборот
			{} else 
			{
				return(false);
			}
		}
	}
	return true;
}

void ShowSector(ShowSectorInfo& si, const TemporaryShowSectorInfo& tsi)
{	
	mslice<Bound> bounds(tsi.s.faces.low(), tsi.s.faces.high(), PK_TEMP);
	for (int i=bounds.low(); i<bounds.high(); ++i)
	{
		bounds[i].v1 = si.b.sizeY();
		bounds[i].v2 = -1;
	}
	
	mslice<ScreenLine> lines(tsi.s.lines.low(), tsi.s.lines.high(), PK_TEMP);

	for (int i=lines.low(); i<lines.high(); ++i)
		LayoutLine (si, tsi, 
			tsi.s.lines[i], lines[i], 
			bounds[tsi.s.lines[i].f1->id], bounds[tsi.s.lines[i].f2->id]);

	/*
	for (int i=lines.low(); i<lines.high(); ++i)
		for (int j=lines[i].low(); j<lines[i].high(); ++j)
		{
			int x = lines[i][j];
			if (x>=0 && x<si.b.sizeX())
				si.b[j][x] = tbal::COLOR_RED;
		}*/
	
	mslice<ScreenZone> zones(tsi.s.faces.low(), tsi.s.faces.high(), PK_TEMP);
	for (int i=zones.low(); i<zones.high(); ++i)
	{
		if (bounds[i].v1<bounds[i].v2)
		{
			zones[i].Init(&tsi.s.faces[i], bounds[i].v1, bounds[i].v2);
			for (int j=zones[i].low(); j<zones[i].high(); ++j)
				zones[i][j] = tsi.curZ[j];
		} else
			zones[i].f = NULL;
	}

	for (int i=lines.low(); i<lines.high(); ++i)
		ApplyLineToZones(lines[i], zones[lines[i].f1->id], zones[lines[i].f2->id]);
	
	for (int i=zones.low(); i<zones.high(); ++i)
	{
		ScreenZone&z = zones[i];
		if (z.f && z.f->Dist(tsi.nTest)>=0.0f)
			z.f = NULL; // нахуй такую зону :3
	}

	//if (!NoZoneIntersect(tsi, zones))	{}

	int cc = 0;
	for (ConvexInSector* pcs = tsi.s.fConvex; pcs; pcs=pcs->nc)
		if (!pcs->convex->inProcess) 
			++cc;

	marray<CheckPtr<Convex> > visibleConvexes(0, cc, PK_TEMP);
	
	for (ConvexInSector* pcs = tsi.s.fConvex; pcs; pcs=pcs->nc)
		if (!pcs->convex->inProcess) 
			visibleConvexes.emplace_back(pcs->convex);

	SortConvexes(si.m, tsi.s.skybox, visibleConvexes);

	// теперь показываем все сектора по рекурсии
	for (int i=tsi.s.faces.low(); i<tsi.s.faces.high(); ++i)
	{
		Sector* next = tsi.s.faces[i].nextSector;
		if (next && next->inProcess==1) 
		{
			// эта херня делается для того, чтобы пометить что этот сектор уже блядь показан
			// и из-за этой поебени я проебал const 
			si.nearSectors.emplace_back(next);
			ShowSector(si, TemporaryShowSectorInfo(*next, tsi.onlyAff, si.mainZ, tsi.nTest));
		}
	}

	for (int i=zones.low(); i<zones.high(); ++i)
		if (zones[i].f)
			Fill(si, tsi, zones[i]);

	for (int i=visibleConvexes.high()-1; i>=visibleConvexes.low(); --i)
	{
		// показываем все предметы в комнате
		assert (!visibleConvexes[i]->g.skybox);
		ShowSector(si, TemporaryShowSectorInfo(visibleConvexes[i]->g, true, tsi.curZ, tsi.nTest));
	}
}

void ShowLevel (const tbal::Bitmap &b, float vx, float vy)
{
	marray<CheckPtr<Sector> > a(0,maxSectors,PK_TEMP);  
	l.player.head->GetSectors(minD*2.0f, a); // сектора что дохера задеваем

	Sector* viewS = l.player.head->s;

	// а теперь долго-долго инициализируем одну сраную структуру
	ShowSectorInfo si;
	si.b = b.Window(0,0,b.sizeX(), b.sizeY()*3/4);
	si.mainZ.Init(NULL,0,si.b.sizeY());
	si.faces.Init(0, maxSectors*14, PK_TEMP);
	si.nearSectors.Init(a.low(), a.high(), PK_TEMP);
	si.nearSectors.emplace_back(viewS);

	const Point3D viewP = l.player.entity.convexes[0].center.p;
	//const float ax = 0.0f, az=0.0f;
	//const float ax = float(M_PI_2), az=float(M_PI_2);
	const float ax=l.player.anglex, az=l.player.anglez;

	si.m.Scale(1.0f/vx, 1.0f/vy, 1.0f);
	si.m.Rotate(ax, 0);
	si.m.Rotate(az, 2);
	si.m.Translate(viewP*-1.0f);

	Matrix3D revm;

	revm.Rotate(-az, 2);
	revm.Rotate(-ax, 0);	
	revm.Scale(vx, vy, 1.0f);		
	
	si.plt   = revm.RotateP(Point3D(-1.0f,-1.0f, 1.0f));
	si.dx    = revm.RotateP(Point3D( 2.0f, 0.0f, 0.0f));
	si.dy    = revm.RotateP(Point3D( 0.0f, 2.0f, 0.0f));

#ifndef NDEBUG
	Point3D test_plt = si.m.RotatePNoTr(si.plt);
	Point3D test_dx  = si.m.RotatePNoTr(si.dx);
	Point3D test_dy  = si.m.RotatePNoTr(si.dy);
#endif
	
	for (int i=0; i<si.b.sizeY(); ++i)
	{
		si.mainZ[i].v1 = 0;
		si.mainZ[i].v2 = si.b.sizeX();
	}

	ShowSector(si, TemporaryShowSectorInfo (*viewS, false, si.mainZ, viewP));

	ShowHUD(b.Window(0, b.sizeY()*3/4, b.sizeX(), b.sizeY()-b.sizeY()*3/4), l.player);
}