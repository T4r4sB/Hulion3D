#pragma once
#include "renderfunc.h"


const float minD = 0.001f;

struct ScreenLine : mslice<int>
{
	Face *f1, *f2;
};

struct Bound 
{ 
	int v1, v2; 
};

struct ScreenZone : mslice<Bound>
{
  Face *f;

	ScreenZone() {}

	void Init (Face* f, int b1, int b2) {
		this->f = f;
		mslice<Bound>::Init(b1,b2,PK_TEMP);
	}

	ScreenZone (Face* f, int b1, int b2) : f(f), mslice<Bound> (b1,b2,PK_TEMP) {}
};

struct ShowSectorInfo
{  
	tbal::Bitmap                b;
	Matrix3D                    m;
	Point3D                     plt,dx,dy;
	ScreenZone                  mainZ;
	marray<CheckPtr<Face> >     faces;
	marray<CheckPtr<Sector> >   nearSectors;
};

struct TemporaryShowSectorInfo
{
	Sector             &s;
	bool               onlyAff;
	const ScreenZone   &curZ;
	Point3D            nTest;

	TemporaryShowSectorInfo (Sector&s, bool onlyAff, const ScreenZone &curZ, Point3D nTest) 
		: s(s),onlyAff(onlyAff),curZ(curZ),nTest(nTest) {}
private :
	TemporaryShowSectorInfo(const TemporaryShowSectorInfo&);
	TemporaryShowSectorInfo&operator=(const TemporaryShowSectorInfo&);
};

void ShowSector(ShowSectorInfo& si, const TemporaryShowSectorInfo& tsi);

int HackTrunc(float f, int order)
{
	union
  {
    float f;
    int32_t i;
  } u;
	u.f = f;
	int e = ( u.i >> 23 ) & 0xFF;
	int m =
		e ?
			( u.i & 0x7FFFFF ) | 0x800000 :
			( u.i & 0x7FFFFF ) << 1;

	e += order-150;

	if (e>=32) return 0;
	else if (e>0) return (u.i>=0) ? (m<<e) : -(m<<e);
	else return (u.i>=0) ? (m>>(-e)) : -(m>>(-e));
}

void LoopDith(tbal::Bitmap::line l, int first, int last, int w, int dw, Texture& txr, int tx, int dtx, int ty, int dty, int odx, int ody)
{
	for (int i=first; i<last; ++i)
	{
		l[i] = fogTable[w>>16][txr.at((tx+odx)>>16, (ty+ody)>>16)];
		tx += dtx;
		ty += dty;
		w  += dw;
		odx ^= 0x8000;
		ody ^= 0x8000;
	}
}


void LoopNoDith(tbal::Bitmap::line l, int first, int last, int w, int dw, Texture& txr, int tx, int dtx, int ty, int dty)
{
	for (int i=first; i<last; ++i)
	{
		l[i] = fogTable[w>>16][txr.at(tx>>16, ty>>16)];
		tx += dtx;
		ty += dty;
		w  += dw;
	}
}

void RenderLine (tbal::Bitmap::line l, RenderPoint& p1, RenderPoint& p2, int tail, const RenderInfo &ri)								 
{
	// w между 0 и 8
	int dtx,dty,dw;
	if (p1.x<p2.x+tail-1)
	{
		const float dx = 1.0f / (p2.x-p1.x);
		dtx = HackTrunc((p2.txw-p1.txw)*dx, 16);
		dty = HackTrunc((p2.tyw-p1.tyw)*dx, 16);
		dw  = HackTrunc((p2.w  -p1.w  )*dx, 20);
	} else 
	{
		dtx = 0;
		dty = 0;
		dw  = 0;
	}
	int w = HackTrunc(p1.w, 20) + (ri.light << 14);
	tblib::inbound(w, 0, 0x13fffff);

	while (w+(p2.x+tail-p1.x-1)*dw <          0) ++dw;
	while (w+(p2.x+tail-p1.x-1)*dw >= 0x1400000) --dw; // блядозащита
	int tx  = HackTrunc(p1.txw, 16);
	int ty  = HackTrunc(p1.tyw, 16);
	int odx = ((p1.x+p1.y)&1) << 15;
	int ody = ((p1.x+p1.y)&1) << 15;
	
	
	if (ri.texture->Dithering())
		LoopDith  (l, p1.x, p2.x+tail, w, dw, *ri.texture, tx, dtx, ty, dty, odx, ody);
	else
		LoopNoDith(l, p1.x, p2.x+tail, w, dw, *ri.texture, tx, dtx, ty, dty);
}

void Fill (ShowSectorInfo& si, const TemporaryShowSectorInfo& tsi, const ScreenZone &z)
{
	int y1 = z.low(), y2 = z.high()-1;
	if (y1>y2) return;
	while (y1<=y2 && z[y1].v1 >= z[y1].v2) 
		++y1;
	while (y1<=y2 && z[y2].v1 >= z[y2].v2) 
		--y2;

	if (y1<=y2)
	{
		Sector* s = z.f->nextSector;
		
		if (s)
		{			
			if (s->inProcess==0)
				ShowSector(si, TemporaryShowSectorInfo(*s, tsi.onlyAff, z, s->skybox ? Point3D(0.0f,0.0f,0.0f) : tsi.nTest));
		} else	
		{
			assert(z.f->texture);			
			tbal::Bitmap::line l = si.b[y1];		
			
			const int afflen = si.b.sizeX()<=400 ? 16 : 32; // длина аффинных блоков

			RenderInfo& ri = z.f->renderInfo;
			if (!z.f->inProcess)
			{
				const float den = 1.0f / (-z.f->Dist(tsi.nTest));//dist отрицательно если мы внутри

				const float dxn  = Dot(si.dx,  z.f->n);
				const float dyn  = Dot(si.dy,  z.f->n);
				const float pltn = Dot(si.plt, z.f->n);

				const float dxtx  = Dot(si.dx,  z.f->vtx);
				const float dytx  = Dot(si.dy,  z.f->vtx);
				const float plttx = Dot(si.plt, z.f->vtx);
				const float nvtx  = Dot(tsi.nTest, z.f->vtx);
				
				const float dxty  = Dot(si.dx,  z.f->vty);
				const float dyty  = Dot(si.dy,  z.f->vty);
				const float pltty = Dot(si.plt, z.f->vty);				
				const float nvty  = Dot(tsi.nTest, z.f->vty);

				ri.w.vdx  = dxn  * den;
				ri.w.vdy  = dyn  * den;
				ri.w.vplt = pltn * den;

				ri.tx.vdx  = ri.w.vdx  * (nvtx - z.f->vtxc) + dxtx;
				ri.tx.vdy  = ri.w.vdy  * (nvtx - z.f->vtxc) + dytx;
				ri.tx.vplt = ri.w.vplt * (nvtx - z.f->vtxc) + plttx;
																	
				ri.ty.vdx  = ri.w.vdx  * (nvty - z.f->vtyc) + dxty;
				ri.ty.vdy  = ri.w.vdy  * (nvty - z.f->vtyc) + dyty;
				ri.ty.vplt = ri.w.vplt * (nvty - z.f->vtyc) + pltty;

				ri.w .Correct(si.b.sizeX(), si.b.sizeY());
				ri.tx.Correct(si.b.sizeX(), si.b.sizeY());
				ri.ty.Correct(si.b.sizeX(), si.b.sizeY());

				ri.texture = z.f->texture;
				ri.light   = z.f->light;

				si.faces.emplace_back(z.f);
			}

			for (int y = y1; y<=y2; ++y)
			{
				assert(z[y].v1>=0 && z[y].v2<=si.b.sizeX());

				if (z[y].v1<z[y].v2)
				{

					RenderPoint p1(ri, z[y].v1  , y);
					RenderPoint p2(ri, z[y].v2-1, y);

					while (p1.w<0.0f || p1.w>16.0f)
					{
						if (p1.x>=p2.x)
							goto BAD_LINE; // ГОТОФОБЫ ПОШЛИ НАХУЙ
						p1.Shift(1, ri.w.vdx, ri.tx.vdx, ri.ty.vdx);
					}
					while (p2.w<0.0f || p2.w>16.0f)
					{
						if (p1.x>=p2.x)
							goto BAD_LINE; 
						p2.Shift(-1, -ri.w.vdx, -ri.tx.vdx, -ri.ty.vdx);
					}
					

					p1.Precompute();
					p2.Precompute();
					if (tsi.onlyAff)
						RenderLine(l,p1,p2,1,ri);
					else for (;;)
					{
						const int nx = (p1.x+afflen) & ~(afflen-1);
						if (nx<=p2.x)
						{
							RenderPoint mid(ri,nx,y);
							mid.Precompute();
							RenderLine(l,p1,mid,0,ri);
							p1=mid;
						} else
						{
							RenderLine(l,p1,p2,1,ri);
							break;
						}
					}
BAD_LINE :;
				}
				++l;
			}
		
		}
	}
}