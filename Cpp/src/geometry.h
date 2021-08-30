#pragma once

#include "memory.h"
#include "points3d.h"
#include "textures.h"
#include "algorithm.h"
#include "renderfunc.h"

struct Sector;
struct ConvexInSector;
struct Line;
struct Convex;
struct Entity;

int maxSectors=0;
const int maxMonsters = 2048;
const int maxEntitys  = 8192;
const int maxConvexes = maxEntitys*8;
const int maxBullets  = 512;



struct Face
{
	int                inProcess;
	RenderInfo         renderInfo;
	int                id;
	Sector             *nextSector;
	bool               penetrable;
	Point3D            n;
	float              nc;
	mslice<Point3D*>   points;
	Texture            *texture;
	int                light;
	Point3D            vtx, vty;
	float              vtxc, vtyc;

	float Dist (const Point3D& p) { return Dot(p,n)-nc; }
};

struct Line 
{
	Point3D   *p1, *p2;
	Face      *f1, *f2;
};

struct Sector
{
	int               inProcess;
	int               id;
	float             gravity;
	bool              skybox;
	ConvexInSector    *fConvex, *lConvex;
	mslice<Face>      faces;
	mslice<Line>      lines;

	void InitNormals ()
	{
		for (int f=faces.low(); f<faces.high(); ++f)
		{
			Face& face = faces[f];
			// вычисляем саму нормаль
			face.n = Point3D(0.0f, 0.0f, 0.0f);
			tblib::slice<Point3D*>& p = face.points;
			assert(p.high() >= p.low()+3);
			for (int i=p.low()+2; i<p.high(); ++i)
				face.n += Cross(*p[i]-*p[p.low()], *p[i-1]-*p[p.low()]);
			face.n.Normalize();
			// вычисляем константу
			face.nc = 0;
			for (int i=p.low(); i<p.high(); ++i)
				face.nc += Dot(*p[i], face.n);
			face.nc /= (p.high()-p.low());
		}
	}

	Point3D Center ()
	{
		Point3D result = Point3D(0.0f, 0.0f, 0.0f);
		int c=0;
		for (int f=faces.low(); f<faces.high(); ++f)
		{
			Face& face = faces[f];
			for (int i=face.points.low()+1; i<face.points.high(); ++i)
			{
				result += *face.points[i];
				++c;
			}
		}
		return result/float(c);
	}

	void Connect (int& l, Face &face, Point3D* p1, Point3D* p2)
	{
		for (int i=lines.low(); i<l; ++i)
		{
			assert (lines[i].p1 != p1 || lines[i].p2 != p2);
			if (lines[i].p1==p2 && lines[i].p2==p1)
			{
				assert(lines[i].f2==NULL);
				lines[i].f2 = &face;
				return;
			}
		}
		assert (l<lines.high());
		++l;
		lines[l-1].p1 = p1;
		lines[l-1].p2 = p2;
		lines[l-1].f1 = &face;
		lines[l-1].f2 = NULL;
	}
	
	void Create (const tblib::slice<Point3D*> &pts)
	{
		int cf=0, cl=0;
		inProcess=0;
		id=0;
		for (int i=pts.low(); i<pts.high(); ++i)
		{
			if (pts[i]) ++cl; else ++cf;
		}    
		cl /= 2;
		fConvex = NULL;
		lConvex = NULL;
		gravity = 0.0f;
		skybox  = false;

		// инициализируем поверхности
		faces.Init(0, cf, PK_GLOBAL);
		int j1=pts.low();
		for (int i=faces.low(); i<faces.high(); ++i)
		{
			Face& face = faces[i];
			face.inProcess = false;
			face.id = i;
			face.nextSector = NULL;
			face.n = Point3D(0.0f, 0.0f, 0.0f);
			face.nc = 0.0f;
			face.light = 0;
			// выгрызаем точки
			int j2=j1;
			while (pts[j2]) ++j2;
			face.points.Init(j1, j2, PK_GLOBAL);
			for (int j=j1; j<j2; ++j)
				face.points[j] = pts[j];
			j1=j2+1;
		}
		// разбираемся с линиями
		lines.Init(0, cl, PK_GLOBAL);
		int l=lines.low();
		for (int f=faces.low(); f<faces.high(); ++f)
		{
      for (int i=faces[f].points.low(); i<faces[f].points.high(); ++i)
			{
				int ni= (i+1>=faces[f].points.high()) ? faces[f].points.low() : i+1;
				Connect(l, faces[f], faces[f].points[i], faces[f].points[ni]);
			}
		}
		InitNormals ();
		assert(l==lines.high());
	}
};

struct ConvexInSector
{
	ConvexInSector *nc, *pc, *ns, *ps;
	Convex* convex;
	Sector* sector;
};

template <typename T>
class CheckPtr
{
	T* value;
	CheckPtr(const CheckPtr&);
	CheckPtr& operator = (const CheckPtr&);
public :
	T* operator -> () { return value; }
	operator T* () { return value; }
	CheckPtr (T* ptr) : value(ptr) { ++value->inProcess; }
	CheckPtr& operator = (T* ptr) { this->~CheckPtr(); new(this) CheckPtr(ptr); }
	~CheckPtr() { if (value) --value->inProcess; }

	static void swap (CheckPtr& l, CheckPtr& r)
	{
		T* tmp = l.value;
		l.value = r.value;
		r.value = tmp;
	}
};

namespace std
{
	template <typename T>
		void swap(CheckPtr<T>&l, CheckPtr<T>&r) { CheckPtr<T>::swap(l,r); }
};

struct SPoint
{
	Point3D p;
	Sector *s;

	SPoint () {}
	SPoint (const Point3D& p, Sector* s) : p(p),s(s) {}

	bool Correct ()
	{
		for (int i=s->faces.low(); i<s->faces.high(); ++i)
			if (s->faces[i].Dist(p) > 0.0f)
				return false;
		return true;
	}

	void DoCorrect ()
	{
		bool correct;
		do 
		{
			correct=true;
			for (int i=s->faces.low(); i<s->faces.high(); ++i)
			{
				float j=1.0f;
				Point3D np=p;
				for (;;)
				{
					float ad = s->faces[i].Dist(np);
					if (ad<=0.0f)
						break;
					correct=false;
					np = p-s->faces[i].n*(ad*j);
					j += 1.0f;
				}
				p=np;
			}
		} while (!correct);
	}

	Face* getIntersectionFace(const Point3D& delta)
	{
		mslice<float> gf(s->faces.low(), s->faces.high(), PK_TEMP);
		for (int i=gf.low(); i<gf.high(); ++i) gf[i]=0.0f;

		for (int i=s->lines.low(); i<s->lines.high(); ++i)
		{
			float d=Volume(*s->lines[i].p1-p, *s->lines[i].p2-p, delta);
			if      (d>0.0f) tblib::enlarge(gf[s->lines[i].f1->id],  d);
			else if (d<0.0f) tblib::enlarge(gf[s->lines[i].f2->id], -d);
		}
		Face* result=NULL;
		float md=-1.0f;
		for (int i=s->faces.low(); i<s->faces.high(); ++i)
		{
			if ((md<0.0f || gf[i]<md) && Dot(delta, s->faces[i].n)>0.0f)
			{
				result = &s->faces[i];
				md = gf[i];
			}
		}
		assert(result);
		return result;	
	}
	

	void AddEntitysFromSector(marray<CheckPtr<Entity> > &entitys, const Point3D& prev, bool fullCheck);	
	void GetSectorsFrom (Sector* vs, float r, bool push, marray<CheckPtr<Sector> > &sectors);
	bool TraceWithEntitys (const Point3D& delta, marray<CheckPtr<Entity> > &entitys, bool fullCheck);
	
	void GetSectors (float r, marray<CheckPtr<Sector> > &sectors)
	{
		GetSectorsFrom(s,r,false,sectors);
	}
	
	void GetSectorsAndPush (float r, marray<CheckPtr<Sector> > &sectors)
	{
		GetSectorsFrom(s,r,true,sectors);
	}
	
	void Push (float r)
	{
		marray<CheckPtr<Sector> > a(0,maxSectors,PK_TEMP);
		GetSectorsFrom(s,r,true,a);
	}

	bool Trace (const Point3D& delta)
	{		
		marray<CheckPtr<Entity> > a;
		return TraceWithEntitys (delta, a, false);
	}

};

struct Convex
{	
	int               inProcess;
	ConvexInSector    *fSector, *lSector;
	Entity            *entity;
	bool              canCollide;
	float             mass;
	SPoint            center;
	Point3D           shift;
	float             r;
	Sector            g;

	void Push (bool noMass);
	void GetSectors (marray<CheckPtr<Sector> > &a)
	{
		center.GetSectors(r, a);
	}

	void GetSectorsAndPush (marray<CheckPtr<Sector> > &a)
	{
		center.GetSectorsAndPush(r, a);
	}

	Convex () {}

private : 
	Convex (const Convex&) {}
	Convex& operator = (const Convex&) {}
};

Point3D RandomPoint ()
{	
	const float
		h = float(pasrnd.frandom())*2.0f-1.0f,
		r = sqrt(1.0f-h),
		a = float(pasrnd.frandom())*2.0f+float(M_PI);
	return Point3D(r*cos(a),r*sin(a),h);
}

