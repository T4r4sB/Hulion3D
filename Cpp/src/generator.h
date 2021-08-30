#pragma once

#include "points3d.h"
#include "tbarr.h"

#include <sstream>

struct Field
{
	int index;
	bool hasup,hasdown,wood,light;
};

static const int 
	__dx[]={0,1,1,1,0,-1,-1,-1},
	__dy[]={1,1,0,-1,-1,-1,0,1};
static const tblib::modarray<int,8> dx(__dx),dy(__dy);

enum FloorType {
	FT_OPENED, FT_UPPER, FT_NORMAL, FT_TECH, FT_HELL, FT_DOWN };
const int baseFloor = 16;

FloorType GetFloorType (int index)
{
	if (index>=30) return FT_OPENED;
	else if (index>=23) return FT_UPPER;
	else if (index>=15) return FT_NORMAL;
	else if (index>=10) return FT_TECH;
	else if (index>=4) return FT_HELL;
	else if (index>=0) return FT_DOWN;
	else assert(false);
	return FT_DOWN;
}

template <int N>
struct FloorTopology
{
	int index;
	tblib::carray<tblib::carray<Field,N>,N> fields;

	int size () { return N; }

	static int MaxD (int index)
	{
		switch (index/4) 
		{			
			case 0 : return 2;
			case 5 : return N*6/9;
			case 6 : return N*4/9;
			case 7 : return N*4/9;
			default : return N;
		}
	}

	bool CanBeEmpty (int x, int y)
	{
		int d=MaxD(index);
		switch (index%4)
		{
		case 0 : return (x>=    1 && x<=d-2 && y>=    1 && y<=d-2);
		case 1 : return (x>=    1 && x<=d-2 && y>=N-d+1 && y<=N-2);
		case 2 : return (x>=N-d+1 && x<=N-2 && y>=N-d+1 && y<=N-2);
		case 3 : return (x>=N-d+1 && x<=N-2 && y>=    1 && y<=d-2);
		}
		return false;
	}	

	bool CanBeEmptyR (int x, int y)
	{
		for (int i=x-1; i<=x+1; ++i) for (int j=y-1; j<=y+1; ++j)
			if (CanBeEmpty(i,j))
				return true;
		return false;
	}
	
  static int GetD(int index)
	{
		return 1 + int(
			(std::min (MaxD(index), MaxD(index+1)) - 3)	
			* (abs(sin(float(index*index)))+1.0f)*0.5f);
	}

	bool Good (int x, int y)
	{
		return x>=0 && x<N && y>=0 && y<N;
	}	

	bool Inner (int x, int y)
	{
		return x>=1 && x<N-1 && y>=1 && y<N-1;
	}

	bool Busy (int x, int y)
	{
		return !Good(x,y) || fields[x][y].index>0;
	}		
	
	void FillC (int x, int y, int cl)
	{
		if (Good(x,y) && fields[x][y].index>0 && fields[x][y].index!=cl)
		{
			fields[x][y].index = cl;
			for (int i=x-1; i<=x+1; ++i) for (int j=y-1; j<=y+1; ++j)
				FillC(i,j,cl);
		}              			
	}
	
	void FillH (int x, int y, int cl)
	{
		assert (cl!=-1);
		if (Good(x,y) && fields[x][y].index==-1)
		{
			fields[x][y].index = cl;
			FillH(x-1,y,cl);
			FillH(x,y-1,cl);
			FillH(x+1,y,cl);
			FillH(x,y+1,cl);
		}
	}

	bool NearBubble (int x, int y)
	{
		for (int i=x-1; i<=x+1; ++i) for (int j=y-1; j<=y+1; ++j)
			if (Good(i,j) && fields[i][j].index==-1)
				return true;
		return false;
	}

	void CreateBubble (int x, int y, int ir, int sr)
	{
		for (int i=x-sr/2; i<=x+sr/2; ++i) for (int j=y-sr/2; j<=y+sr/2; ++j)
		{
			const int
				dx = i*2+1-x*2,
				dy = j*2+1-y*2,
				d = dx*dx+dy*dy;
			if (d<=sr*sr && d>ir*ir && Inner(i,j) && !NearBubble(i,j) && fields[i][j].index==0)
				fields[i][j].index=-2;
		}		
		for (int i=x-sr/2; i<=x+sr/2; ++i) for (int j=y-sr/2; j<=y+sr/2; ++j)
			if (Inner(i,j) && fields[i][j].index==-2)
				fields[i][j].index=-1;
	}

	void TryFill (int x, int y, int &lc)
	{
		if (fields[x][y].index!=0) return;

		tblib::modarray<int,8> cl;
		for (int i=0; i<8; ++i)
			cl[i] = fields[x+dx[i]][y+dy[i]].index;
		for (int i=0; i<4; ++i)
			if (cl[i*2]<=0 && cl[i*2+1]>0 && cl[i*2+2]<=0) return;

		for (int i=0; i<4; ++i) if (cl[i*2+1]<=0)
		{
			int c;
			c = cl[i*2+2];
			if (c>0) cl[i*2+1]=c;
			c = cl[i*2+0];
			if (c>0) cl[i*2+1]=c;
		}
		tblib::array<int,8> cl2;
		for (int i=0; i<8; ++i) if (cl[i]>0 && cl[i-1]<=0)
			cl2.push_back(cl[i]);			
		for (int i=0; i<cl2.size(); ++i)
			for (int j=i+1; j<cl2.size(); ++j)
				if (cl2[i]==cl2[j])
					return;
		if (index>=0 && index<=3 || index==9 || index>=10 && index<=14)
			for (int i=0; i<4; ++i) if (!Busy(x+dx[i*2],y+dy[i*2]))
				if (int(Busy(x+2*dx[i*2],y+2*dy[i*2]))
				+ int(Busy(x+2*dx[i*2-1],y+2*dy[i*2-1]))
				+ int(Busy(x+2*dx[i*2+1],y+2*dy[i*2+1])) >= 2) return;

		if (cl2.size()==0)
			fields[x][y].index=lc++;
		else
		{
			fields[x][y].index = cl2[0];
			for (int i=0; i<cl2.size(); ++i)
				if (cl2[i]==1) fields[x][y].index=cl2[i];
			for (int i=x-1; i<=x+1; ++i) for (int j=y-1; j<=y+1; ++j)
				FillC(i,j,fields[x][y].index);
		}
	}

	void Init (int a_index)
	{
		index = a_index;

		for (int i=0; i<N; ++i) for (int j=0; j<N; ++j)
		{
			fields[i][j].index   = CanBeEmpty(i,j)?0:1;
			fields[i][j].hasup   = false;
			fields[i][j].hasdown = false;
			fields[i][j].wood    = false;
			fields[i][j].light   = false;
		}

		if (index>=4) switch (index%4)
		{
			case 0 : 
				if (index>4) 
					fields [0][GetD(index-1)].index  = -1; 
				fields   [GetD(index)][0].index   = -1; 
			break;
			case 1 :              
				fields   [GetD(index-1)] [N-1].index  = -1; 
				fields   [0] [N-1-GetD(index)].index  = -1; 
			break;
			case 2 :              
				fields   [N-1] [N-1-GetD(index-1)].index  = -1;   
				fields   [N-1-GetD(index)] [N-1].index  = -1; 
			break;
			case 3 :              
				fields   [N-1-GetD(index-1)] [0].index  = -1; 
				if (index<31)
				  fields [N-1] [GetD(index)].index  = -1; 
			break;
		}
		
    if (index==baseFloor) 
		{
      CreateBubble(N-3,N-3,0,6);
      CreateBubble(N-3,N-3,7,12);
      assert(fields[N-2][N-2].index<0);
		}
    if (index==baseFloor+4) 
      fields[1][1].index = -1;

		const int w = index>=10 && index<=14 ? (N*N)/128
			: index<8 ? (N*N)/32
			: index<10? (N*N)/96
			: index<28? (N*N)/128
			: (N*N)/32;

		for (int i=0; i<w; ++i)
		{
			const int 
				x=pasrnd.random(N),
				y=pasrnd.random(N);
			CreateBubble(x,y,0,2+pasrnd.random(4));
			if (index>=8 && index<=9 || index>=15 && index<=31) 
			{
				const int 
					nx=x+(pasrnd.random(5)-1)/2,
					ny=y+(pasrnd.random(5)-1)/2;
				CreateBubble(nx,ny,3,9-pasrnd.random(4));
			}
		}

		const int tc = (index>=4 && index<=7) || (index>=10 && index<=14) ? 3200 : 170;

		int lc=1;
		for (int t=0; t<(N*N*tc)/100; ++t)
		{
			const int
				x = pasrnd.random(N-2)+1,
				y = pasrnd.random(N-2)+1;
			TryFill(x,y,lc);
		}

		for (int i=0; i<N; ++i) for (int j=0; j<N; ++j)
		{
			int& f = fields[i][j].index;
			f = f<=0 ? 0
				: CanBeEmpty(i,j) ? 1
				: CanBeEmptyR(i,j) ? 2
				: 3;
		}
		
		for (int i=0; i<N-1; ++i) for (int j=0; j<N-1; ++j)
		{
			int 
				&f1=fields[i  ][j  ].index,
				&f2=fields[i+1][j  ].index, // ÊÐÅÑÒÎÏÈÄÎÐÛ ¨ÁÀÍÛÅ ß ÎÕÓÅË ÈÑÊÀÒÜ ÎØÈÁÊÓ!!!!
				&f3=fields[i  ][j+1].index, // ÍÀÄÎ Â ÊÀÆÄÎÉ ÑÒÐÎÊÅ ÁËßÒÜ & ÑÒÀÂÈÒÜ
				&f4=fields[i+1][j+1].index; // ÊÀÊÎÃÎ ÕÓß!!! ÒÎÌÏÑÎÍÀ È ÐÈÒ×È È ÑÒÐÀÓÑÒÐÓÏÀ ÍÀ ÊÎË ÍÀÕÓÉ ÁËßÄÜ
			if (f1<=0 && f2<=0 && f3<=0 && f4<=0) 
			{
				f1=-1;
				f2=-1;
				f3=-1;
				f4=-1; 
			}				
		}

		if (index>=4)
		{
			for (int i=0; i<N-1; ++i) for (int j=0; j<N-1; ++j)
			{
				int c = -(pasrnd.random(0x10000) & 0x7fff)-1;
				if (c==-1) c=-2;
				FillH(i,j,c);
			}
		}
		
		for (int i=0; i<N; ++i) for (int j=0; j<N; ++j)
		{
			int& f = fields[i][j].index;
			if (f<0 && f>-100) f=0;
		}		
	}
};

template <int N>
class DeltaArr
{
	tblib::carray<tblib::carray<float, N+1>, N+1> nd;

	template <typename FlAl, typename ChMM, typename DrWl, typename SmWl>
	void __Smooth (const FlAl&flal, const ChMM&chmm, const DrWl&drwl, const SmWl&smwl)
	{
		float gmaxd=0.0f, gmind=0.0f; bool fmax=true, fmin=true;
		for (int i=1; i<N; ++i) for (int j=1; j<N; ++j)
		{
			if (fmax || gmaxd<d[i][j]) { gmaxd=d[i][j]; fmax=false; }
			if (fmin || gmind>d[i][j]) { gmind=d[i][j]; fmin=false; }
		}
		nd=d;
		for (int k=0; k<N; ++k)
		{
			bool f=true;
			flal();
			for (int i=1; i<N; ++i) for (int j=1; j<N; ++j)
			{
				float mind=gmaxd;
				float maxd=gmind;
				chmm(i,j,mind,maxd);
				if (mind<=maxd) {
					if (d[i][j]>mind+1.0f || d[i][j]<maxd-1.0f) f=false;
					if (mind<=maxd-1.6f) nd[i][j] = d[i][j]*0.5f + (mind+maxd)*0.25f;
					else if (d[i][j]>mind+0.8f) nd[i][j] = d[i][j]*0.5f + (mind+0.8f)*0.5f;
					else if (d[i][j]<maxd-0.8f) nd[i][j] = d[i][j]*0.5f + (maxd-0.8f)*0.5f;
					else nd[i][j] = d[i][j];
				} else 
					nd[i][j] = d[i][j];
			}
			drwl();
			d=nd;
			if (f) break;
		}
		smwl();
	}

	class AlignFloors
	{	
		AlignFloors operator = (const AlignFloors&);		
		DeltaArr<N> &da;
		const FloorTopology<N>& f;

		void Fill (int x, int y, int& c, float &v, tblib::carray<tblib::carray<int, N+1>, N+1> &pr, int m) const
		{
			if (x<=0 || x>=N || y<=0 || y>=N) return;
			if (pr[x][y]>=m) return;
			pr[x][y] = m;
			if (m==1) {
				v += da.d[x][y];
				c += 1;
			} else
				da.nd[x][y] = v;

			for (int dir=0; dir<4; ++dir)
			{
				const int 
					nx = x + dx[dir*2],
					ny = y + dy[dir*2],
					tx1 = x + ((dx[dir*2]-1)>>1),
					ty1 = y + ((dy[dir*2]-1)>>1),
					tx2 = x + ((dx[dir*2]-0)>>1),
					ty2 = y + ((dy[dir*2]-0)>>1);
				if (nx>0 && nx<N && ny>0 && ny<N)
				{
					const int lz = (f.fields[tx1][ty1].index <= 0) + (f.fields[tx2][ty2].index <= 0);
					if (lz==2  // both free
					|| (lz==1  // one free
						&& (f.fields[tx2-1][ty2-1].index>0 && f.fields[tx2-1][ty1+1].index>0 
						 || f.fields[tx1+1][ty2-1].index>0 && f.fields[tx1+1][ty1+1].index>0))) // corner
						Fill(nx,ny,c,v,pr,m);
				}
			}
		}

	public:
		AlignFloors(DeltaArr<N> &da, const FloorTopology<N>& f):da(da),f(f) {}
		void operator () () const
		{
			tblib::carray<tblib::carray<int, N+1>, N+1> was;
			for (int i=0; i<N+1; ++i) for (int j=0; j<N+1; ++j) was[i][j]=0;
			for (int i=0; i<N+1; ++i) for (int j=0; j<N+1; ++j)
			{
				int c=0;
				float v=0.0f;
				Fill(i,j,c,v,was,1);
				if (c>0)
				{
					v /= float(c);
					Fill(i,j,c,v,was,2);
				}
			}
			da.d = da.nd;
		}
	};

	class CheckMinMaxAlways 
	{
		CheckMinMaxAlways operator = (const CheckMinMaxAlways&);
		DeltaArr<N> &da;
	public:
		CheckMinMaxAlways(DeltaArr<N> &da) : da(da) {}
		void operator () (int&i, int&j, float& mind, float& maxd) const
		{
			for (int dir=0; dir<4; ++dir)
			{
				float& d = da.d[i+dx[dir*2]] [j+dy[dir*2]];
				mind=std::min(mind, d); maxd=std::max(maxd, d); 
			}
		}
	};

	class CheckMinMax
	{
		CheckMinMax operator = (const CheckMinMax&);
		DeltaArr<N> &da;
		const FloorTopology<N>& f;
	public:
		CheckMinMax(DeltaArr<N> &da, const FloorTopology<N>& f):da(da),f(f) {}
		void operator () (int&i, int&j, float& mind, float& maxd) const
		{			
			for (int dir=0; dir<4; ++dir)
			{			
				if (f.fields[i+(dx[dir*2+1]-1)/2] [j+(dy[dir*2+1]-1)/2].index <= 0
					&& f.fields[i+(dx[dir*2-1]-1)/2] [j+(dy[dir*2-1]-1)/2].index <= 0)
				{
					float& d = da.d[i+dx[dir*2]] [j+dy[dir*2]];
					mind=std::min(mind, d); maxd=std::max(maxd, d); 
				}
			}
		}
	};

	class DropWalls
	{
		DropWalls operator = (const DropWalls&);
		DeltaArr<N> &da;
		const FloorTopology<N>& f;
	public:
		DropWalls(DeltaArr<N> &da, const FloorTopology<N>& f):da(da),f(f) {}
		void operator () () const
		{
			for (int i=1; i<N; ++i) for (int j=1; j<N; ++j)
			{
        if (f.fields[i-1][j-1].index>0 
					|| f.fields[i][j-1].index>0 
					|| f.fields[i-1][j].index>0 
					|| f.fields[i][j].index>0)
          da.nd[i][j] = 0;
			}
		}
	};

	class SmoothInWall 
	{
		SmoothInWall operator = (const SmoothInWall&);
		DeltaArr<N> &da;
		const FloorTopology<N>& f;
	public:
		SmoothInWall(DeltaArr<N> &da, const FloorTopology<N>& f):da(da),f(f) {}
		void operator () () const
		{
			for (int k=0; k<N; ++k) for (int i=1; i<N; ++i) for (int j=1; j<N; ++j)
			{
        if (f.fields[i-1][j-1].index>0 
					|| f.fields[i][j-1].index>0 
					|| f.fields[i-1][j].index>0 
					|| f.fields[i][j].index>0)
          da.nd[i][j] = da.d[i][j]*0.5f 
					+ da.d[i-1][j]*0.125f + da.d[i][j-1]*0.125f	+ da.d[i+1][j]*0.125f	+ da.d[i][j+1]*0.125f;
			}
		}
	};

	struct None
	{
		void operator () () const
		{
		}
	};
	
public :
	tblib::carray<tblib::carray<float, N+1>, N+1> d;

	void SmoothCeil (const FloorTopology<N>& f) {
		__Smooth(None(), CheckMinMax(*this,f), DropWalls(*this,f), SmoothInWall(*this,f)); 	}
	void SmoothFloor (const FloorTopology<N>& f){
		__Smooth(None(), CheckMinMax(*this,f), None(), SmoothInWall(*this,f)); }	
	void SmoothTechFloor (const FloorTopology<N>& f){
		__Smooth(AlignFloors(*this,f), CheckMinMax(*this,f), None(), SmoothInWall(*this,f));}
	void SmoothGlobal () {
		__Smooth(None(), CheckMinMaxAlways(*this), None(), None());	}

};