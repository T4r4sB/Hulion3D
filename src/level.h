#pragma once

#include "tbarr.h"
#include "geometry.h"
#include "generator.h"
#include "monsters.h"
#include "entitys.h"

template <int M>
void Add3P (tblib::array<Point3D*, M> &a, int &fc, Point3D* p1, Point3D* p2, Point3D* p3)
{
	a.push_back(p1);
	a.push_back(p2);
	a.push_back(p3);		
	a.push_back(NULL);
	++fc;
}

template <int M>
void Add4P (tblib::array<Point3D*, M> &a, int &fc, Point3D* p1, Point3D* p2, Point3D* p3, Point3D* p4)
{
	a.push_back(p1);
	a.push_back(p2);
	a.push_back(p3);		
	a.push_back(p4);		
	a.push_back(NULL);
	++fc;
}	

template <int M>
void Add4PC (tblib::array<Point3D*, M> &a, int &fc, Point3D* p1, Point3D* p2, Point3D* p3, Point3D* p4)
{
	if (Volume(*p1,*p2,*p3,*p4)>0.0f)
	{
		Add3P(a,fc,p1,p2,p3);
		Add3P(a,fc,p1,p3,p4);
	} else
	{
		Add3P(a,fc,p1,p2,p4);
		Add3P(a,fc,p2,p3,p4);
	}
}

template <int M>
void Add8P (tblib::array<Point3D*, M> &a, int &fc, Point3D* p1, Point3D* p2, Point3D* p3, Point3D* p4, Point3D* p5, Point3D* p6, Point3D* p7, Point3D* p8)
{
	a.push_back(p1);
	a.push_back(p2);
	a.push_back(p3);		
	a.push_back(p4);		
	a.push_back(p5);
	a.push_back(p6);
	a.push_back(p7);		
	a.push_back(p8);		
	a.push_back(NULL);
	++fc;
}

template <int N>
struct Level
{	
	int size;
	Level () {size=N;}

	struct FloorGeometry
	{
		FloorTopology<N> topology;
		tblib::carray<tblib::carray<tblib::carray<Point3D,2>,N+1>,N+1> floorPoints; 
		tblib::carray<tblib::carray<Sector, N>, N> sectors;
		int index;

		void Create() // инициализирует точки, делает базовые сдвиги
		{
			topology.Init(index);

			const int 
				i4 = index%4, 
				shx = (i4==0 || i4==1) ? N : 0,
				shy = (i4==0 || i4==3) ? N : 0,
				shz = index;

			const float ld = 0.9f;

			for (int i=0; i<N+1; ++i) for (int j=0; j<N+1; ++j) for (int k=0; k<2; ++k)
			{
				Point3D& pt = floorPoints[i][j][k];
				pt = Point3D(
					float(i+shx)*1.5f-1.0f,
					float(j+shy)*1.5f-1.0f,
					float(-shz)*ld - ((k==0) ? 2.4f : 0.0f));
				switch (index%4)
				{
				case 0 : if (j==0) pt.z -= ld; break;
				case 1 : if (i==0) pt.z -= ld; break;
				case 2 : if (j==N) pt.z -= ld; break;
				case 3 : if (i==N) pt.z -= ld; break;
				}   
			}
      
			
			DeltaArr<N> dz;
			for (int i=0; i<N+1; ++i) for (int j=0; j<N+1; ++j)
				dz.d[i][j] = floorPoints[i][j][1].z;			
			for (int i=1; i<N; ++i) for (int j=1; j<N; ++j)
				dz.d[i][j] += float(pasrnd.frandom()) - 2.0f;
			if (GetFloorType(index) == FT_TECH)
				dz.SmoothTechFloor(topology);
			else
				dz.SmoothTechFloor(topology);
			
			for (int i=1; i<N; ++i) for (int j=1; j<N; ++j) for (int k=0; k<2; ++k)
			{
				Point3D& pt = floorPoints[i][j][k];
				pt.z = dz.d[i][j];
				if (k==0)
				{
					bool cond = false;
					if (GetFloorType(index)==FT_HELL && GetFloorType(index-4)==FT_HELL)
						cond = pasrnd.random(3)==0;
					else if (GetFloorType(index)==FT_TECH || pasrnd.random(3)!=0)
						cond = true;
					pt.z -= cond ? 2.2f : 1.4f;
				}
			}
			
			for (int i=0; i<N+1; ++i) for (int j=0; j<N+1; ++j)
				dz.d[i][j] = 0.0f;

			if (GetFloorType(index)==FT_TECH)
			{
				dz.SmoothTechFloor(topology);
			} else if (GetFloorType(index)==FT_OPENED)
			{			
				for (int i=1; i<N; ++i) for (int j=1; j<N; ++j)
					dz.d[i][j] = 2.0f + float(pasrnd.frandom())*3.0f;
				dz.SmoothFloor(topology);
			} else
			{
				for (int i=1; i<N; ++i) for (int j=1; j<N; ++j)
					dz.d[i][j] = 2.0f;
				dz.SmoothCeil(topology);
			}
			
			for (int i=1; i<N; ++i) for (int j=1; j<N; ++j)	for (int k=0; k<2; ++k)
			{
				Point3D& pt = floorPoints[i][j][k];
				if (GetFloorType(index)==FT_DOWN) 
					pt.z += 100.0f;
				else if (GetFloorType(index)==FT_OPENED)
					pt.z += dz.d[i][j]*(float(k)-1.0f);
				else
					pt.z += dz.d[i][j]*(float(k)*6.0f-5.5f);
			}
		}

		void ShiftPoints (const DeltaArr<2*N> &globalx, const DeltaArr<2*N> &globaly)
		{			
			
			for (int i=0; i<N+1; ++i) for (int j=0; j<N+1; ++j)
			{
				int ix=-1, iy=-1;
				switch (index%4)
				{
				case 0 : ix=i+N; iy=j+N; break;
				case 1 : ix=i+N; iy=j+0; break;
				case 2 : ix=i+0; iy=j+0; break;
				case 3 : ix=i+0; iy=j+N; break;
				}
				tblib::carray<Point3D, 2> &pt2 = floorPoints[i][j];
				pt2[0].x += globalx.d[ix][iy]*0.2f;
				pt2[0].y += globaly.d[ix][iy]*0.2f;
				pt2[1].x += globalx.d[ix][iy]*0.2f;
				pt2[1].y += globaly.d[ix][iy]*0.2f;
			}

			for (int i=1; i<N; ++i) for (int j=1; j<N; ++j)
			{
				tblib::modarray<Field,4> f;
				for (int dir=0; dir<4; ++dir)
					f[dir] = topology.fields [i+(dx[dir*2+1]-1)/2] [j+(dy[dir*2+1]-1)/2];

				bool ok = true;
				for (int dir=0; dir<4; ++dir)	
				  if ((f[dir].hasup || f[dir].hasdown) && (f[dir].index<=0)) 
						{	ok = false;	break; }

        if (ok)
				{
					int k=0;					
					for (int dir=0; dir<4; ++dir)
						if (f[dir].index>0)
							++k;
					if (k>=3)
					{						
						tblib::carray<Point3D, 2> &pt2 = floorPoints[i][j];
						pt2[0].x += (float(pasrnd.random(2))-0.5f)*0.14f;
						pt2[0].y += (float(pasrnd.random(2))-0.5f)*0.14f;
						pt2[1].x += (float(pasrnd.random(2))-0.5f)*0.14f;
						pt2[1].y += (float(pasrnd.random(2))-0.5f)*0.14f;
					} else if (k==2)
					{
						for (int dir=0; dir<4; ++dir)
							if (f[dir].index>0 && f[dir+1].index>0)
								for (int k=0; k<2; ++k)
									floorPoints[i][j][k] += (floorPoints[i+dx[dir*2+6]][j+dy[dir*2+6]][k]-floorPoints[i][j][k])
									*((float(pasrnd.random(2))-0.5f)*0.14f);
					}
				}
			}
		}

		void InitLava (const FloorTopology<N>& upper)
		{
			for (int i=1; i<N-1; ++i) for (int j=1; j<N-1; ++j)
			{
				if (upper.fields[i][j].index<=0)
				{
					topology.fields[i][j].index = 0;
					bool p = true;
					for (int dir=0; dir<4; ++dir)
					{
						if (upper.fields[i+dx[dir*2+0]][j+dy[dir*2+0]].index <= 0
						&&  upper.fields[i+dx[dir*2+1]][j+dy[dir*2+1]].index <= 0
						&&  upper.fields[i+dx[dir*2+2]][j+dy[dir*2+2]].index <= 0)
							p = false;
					}
					if (p && pasrnd.random(15)==0)
						for (int i2=i-1; i2<=i+1; ++i2) for (int j2=j-1; j2<=j+1; ++j2)
							topology.fields[i2][j2].index = 0;
				} else if (pasrnd.random(5)==0)
					topology.fields[i][j].index = 0;
			}
			
			for (int i=1; i<N-1; ++i) for (int j=1; j<N-1; ++j)
			{
				if (topology.fields[i][j].index<=0 && upper.fields[i][j].index>0)
				{
					int c=0;
					for (int i2=i-1; i2<=i+1; ++i2) for (int j2=j-1; j2<=j+1; ++j2)
						if (upper.fields[i2][j2].index<=0)
							++c;
					if (c>5 && pasrnd.random(5)>0)
						topology.fields[i][j].index = 1;
				}
			}
			
			for (int i=0; i<N; ++i)
			{
				topology.fields[i][0]  .index = 1;
				topology.fields[0][i]  .index = 1;
				topology.fields[i][N-1].index = 1;
				topology.fields[N-1][i].index = 1;
			}
		}		

		static const int holeModChanse=4;

		void CreateHoles (FloorGeometry& upper, int chanse, bool canNearHall)
		{
			for (int i=1; i<N-1; ++i) for (int j=1; j<N-1; ++j)	
			{
				if (upper.topology.fields[i][j].index==1 && topology.fields[i][j].index<=0 //
				&& !topology.fields[i][j].hasup && !topology.fields[i][j].hasdown //
				&& topology.fields[i][j].index % holeModChanse == 0) 
				{
					tblib::modarray<int, 4> xind, yind;
					for (int dir=0; dir<4; ++dir)	
					{
						xind[dir] = i+(dx[dir*2+1]+1)/2;
						yind[dir] = j+(dy[dir*2+1]+1)/2;
					}						

					bool ok=true;
					for (int dir=0; dir<4; ++dir)
						if (upper.floorPoints[xind[dir]][yind[dir]][1].z + 2.4 >= floorPoints[xind[dir]][yind[dir]][1].z)
							{ ok=false; break;}				
					ok = ok && (pasrnd.random(100)<chanse);
					if (ok)
					{
						bool checkHall = false;
						for (int dir=0; dir<4; ++dir)
							if (upper.topology.fields[i+dx[dir*2]][j+dy[dir*2]].index<0)
								{ checkHall=true; break;}
						if (checkHall)
							ok = canNearHall;
						if (ok)
						{
              if (upper.topology.fields[i][j].index>0)
								upper.topology.fields[i][j].index=0;
							upper.topology.fields[i][j].hasdown = true;
							topology.fields[i][j].hasup = true;
							for (int dir=0; dir<4; ++dir)
								floorPoints[xind[dir]][yind[dir]][0].z = upper.floorPoints[xind[dir]][yind[dir]][1].z+0.7f;   
						}
					}                    
				}
			}
		}		

		void InitWood (const FloorTopology<N>& down)
		{
			for (int i=1; i<N-1; ++i) for (int j=1; j<N-1; ++j)
			{
				if (topology.fields[i][j].index<=0 && !topology.fields[i][j].hasdown && down.fields[i][j].index<=0)
				{
					bool& wood = topology.fields[i][j].wood;
					wood=true;
					for (int dir=0; dir<4; ++dir)
						if (!topology.fields[i+dx[dir*2+0]][j+dy[dir*2+0]].hasdown
						&&  !topology.fields[i+dx[dir*2+1]][j+dy[dir*2+1]].hasdown
						&&  !topology.fields[i+dx[dir*2+2]][j+dy[dir*2+2]].hasdown)
							{ wood=false; break; }
					int c=0;
					for (int dir=0; dir<4; ++dir)
						if (topology.fields[i+dx[dir*2]][j+dy[dir*2]].index>0
						||topology.fields[i+dx[dir*2]][j+dy[dir*2]].hasdown)
							++c;
					if (c>=3)
						wood=false;
				}
			}
		}

		typedef tblib::array<int,2> Index;
		
		struct SideIndexes
		{
			Index top, middle, bottom;
		};

		struct SectorIndexes
		{
			Index ceil,floor;
			tblib::carray<SideIndexes,4> sides;
		};

		void Push (Index& ind, int fc1, int fc2)
		{
			while (fc1<fc2)
			{
				ind.push_back(fc1);
				++fc1;
			}
		}
		
		Sector* GetSector (int x, int y, 
			FloorGeometry* upper, FloorGeometry* prev, FloorGeometry* next) 
		{
			bool goprev=false, gonext=false;
			switch (index%4)
			{
			case 0 : if (x< 0) { x+=N; goprev=true; } if (y< 0) { y+=N; gonext=true; } break;
			case 1 : if (x< 0) { x+=N; gonext=true; } if (y>=N) { y-=N; goprev=true; } break;
			case 2 : if (x>=N) { x-=N; goprev=true; } if (y>=N) { y-=N; gonext=true; } break;
			case 3 : if (x>=N) { x-=N; gonext=true; } if (y< 0) { y+=N; goprev=true; } break;
			}
			FloorGeometry* cur = goprev ? prev : gonext ? next : this;

			if (cur->topology.fields[x][y].index<=0)
			{
				if (cur->topology.fields[x][y].hasup)
				{
					assert (!goprev && !gonext);
					assert (upper->topology.fields[x][y].index<=0);
          return &upper->sectors[x][y];
				} else
					return &cur->sectors[x][y];
			} else
				return NULL;
		}	

		template <int M>
		void InitPointArr (tblib::array<Point3D*, M>& pts, SectorIndexes& ind,
		int i, int j,
		FloorGeometry* upper, FloorGeometry* down, FloorGeometry* prev, FloorGeometry* next)
		{
			// немного порно с мамонтом-трасвеститом
			tblib::modarray<int, 4> xind,yind;
			for (int dir=0; dir<4; ++dir)	
			{
				xind[dir] = i+(dx[dir*2+1]+1)/2;
				yind[dir] = j+(dy[dir*2+1]+1)/2;
			}
			int fc=0;
			int ofc;
			ofc=fc;
			Add4PC(pts,fc
				,&floorPoints[xind[3]][yind[3]][0]
				,&floorPoints[xind[2]][yind[2]][0]
				,&floorPoints[xind[1]][yind[1]][0]
				,&floorPoints[xind[0]][yind[0]][0]);
			Push(ind.ceil, ofc,fc);

			for (int dir=0; dir<4; ++dir)
			{
				int ni = i+dx[dir*2], nj = j+dy[dir*2];
				bool inner = ni>=0 && ni<N && nj>=0 && nj<N;

				if (inner 
				&& topology.fields[ni][nj].index<=0
				&& topology.fields[i][j].hasdown && topology.fields[ni][nj].hasdown)
				{ // это большой такой портал между высокими секторами
					ofc=fc;
					Add8P(pts,fc
							,&      floorPoints[xind[dir-0]][yind[dir-0]][0]	
							,&      floorPoints[xind[dir-0]][yind[dir-0]][1]	
							,&down->floorPoints[xind[dir-0]][yind[dir-0]][0]
							,&down->floorPoints[xind[dir-0]][yind[dir-0]][1]
							,&down->floorPoints[xind[dir-1]][yind[dir-1]][1]
							,&down->floorPoints[xind[dir-1]][yind[dir-1]][0]
							,&      floorPoints[xind[dir-1]][yind[dir-1]][1]	
							,&      floorPoints[xind[dir-1]][yind[dir-1]][0]);									
					Push(ind.sides[dir].top, ofc,fc);
				} else
				{
					ofc=fc;
					// заклеиваем верхушку
					if (GetSector(ni, nj, upper, prev, next))
						Add4P(pts,fc	
							,&floorPoints[xind[dir-0]][yind[dir-0]][0]	
							,&floorPoints[xind[dir-0]][yind[dir-0]][1]	
							,&floorPoints[xind[dir-1]][yind[dir-1]][1]
							,&floorPoints[xind[dir-1]][yind[dir-1]][0]	);
					else
						Add4PC(pts,fc
							,&floorPoints[xind[dir-0]][yind[dir-0]][0]	
							,&floorPoints[xind[dir-0]][yind[dir-0]][1]	
							,&floorPoints[xind[dir-1]][yind[dir-1]][1]
							,&floorPoints[xind[dir-1]][yind[dir-1]][0]		);							
					Push(ind.sides[dir].top, ofc,fc);
					if (topology.fields[i][j].hasdown) // продолжаем вниз
					{
						assert(inner); // на границах не бывает дыр и ваще я не знаю что делать в таких случаях
						ofc=fc;
						Add4PC(pts,fc
							,&      floorPoints[xind[dir-0]][yind[dir-0]][1]	
							,&down->floorPoints[xind[dir-0]][yind[dir-0]][0]	
							,&down->floorPoints[xind[dir-1]][yind[dir-1]][0]
							,&      floorPoints[xind[dir-1]][yind[dir-1]][1]		);									
						Push(ind.sides[dir].middle, ofc,fc);	
						ofc=fc;
						if (down->GetSector(ni, nj, this, NULL, NULL)) // prev и next тут липовые ваще 
							Add4P(pts,fc	
								,&down->floorPoints[xind[dir-0]][yind[dir-0]][0]	
								,&down->floorPoints[xind[dir-0]][yind[dir-0]][1]	
								,&down->floorPoints[xind[dir-1]][yind[dir-1]][1]
								,&down->floorPoints[xind[dir-1]][yind[dir-1]][0]	);
						else
							Add4PC(pts,fc
								,&down->floorPoints[xind[dir-0]][yind[dir-0]][0]	
								,&down->floorPoints[xind[dir-0]][yind[dir-0]][1]	
								,&down->floorPoints[xind[dir-1]][yind[dir-1]][1]
								,&down->floorPoints[xind[dir-1]][yind[dir-1]][0]	);									
						Push(ind.sides[dir].bottom, ofc,fc);		
					}
				}
			}
			
			if (topology.fields[i][j].hasdown) // продолжаем вниз
			{
				ofc=fc;
				Add4PC(pts,fc
					,&down->floorPoints[xind[0]][yind[0]][1]
					,&down->floorPoints[xind[1]][yind[1]][1]
					,&down->floorPoints[xind[2]][yind[2]][1]
					,&down->floorPoints[xind[3]][yind[3]][1]);
				Push(ind.floor, ofc,fc);
			} else
			{
				ofc=fc;
				Add4PC(pts,fc
					,&floorPoints[xind[0]][yind[0]][1]
					,&floorPoints[xind[1]][yind[1]][1]
					,&floorPoints[xind[2]][yind[2]][1]
					,&floorPoints[xind[3]][yind[3]][1]);
				Push(ind.floor, ofc,fc);
			}
		}

		void CreateSectorLinks (Sector& s, SectorIndexes& ind,
		int i, int j,
		FloorGeometry* upper, FloorGeometry* down, FloorGeometry* prev, FloorGeometry* next, 
		Sector* hellS, Sector* skyS)
		{ 
			bool opened = true;
			if (upper!=NULL && upper->topology.fields[i][j].index!=3)
				opened=false;
			else for (int dir=0; dir<4; ++dir)
			{
				tblib::carray<Point3D, 2> &pt = floorPoints[i+(dx[dir*2+1]+1)/2][j+(dy[dir*2+1]+1)/2];
				if (pt[0].z+4.0f>pt[1].z)
				{
					opened = false;
					break;
				}
			}
			if (opened)
			{
				topology.fields[i][j].light = true;
				for (int c=0; c<ind.ceil.size(); ++c)
					s.faces[ind.ceil[c]].nextSector = skyS;			
			}
			for (int dir=0; dir<4; ++dir)
			{
				Index& top = ind.sides[dir].top;
				assert (top.size()>0);			
				Sector *ns = GetSector(i+dx[dir*2],j+dy[dir*2], upper, prev, next);
				if (ns)
				{
					assert(top.size()==1);
					s.faces[top[0]].nextSector = ns;
					s.faces[top[0]].penetrable = true;
				}
			}
			if (topology.fields[i][j].hasdown)
			{
				if (GetFloorType(index-4)==FT_DOWN) // всех в АД
				{
					for (int dir=0; dir<4; ++dir)
					{
						Index& bot = ind.sides[dir].bottom;		
						for (int c=0; c<bot.size(); ++c)
							s.faces[bot[c]].nextSector = hellS;			
					}
					for (int c=0; c<ind.floor.size(); ++c)
						s.faces[ind.floor[c]].nextSector = hellS;
				} else
				{
					for (int dir=0; dir<4; ++dir)
					{
						Index& bot = ind.sides[dir].bottom;	
						if (bot.size()>0) // что не факт т.к. бывают рядом высокие сектора
						{
							Sector *ns = down->GetSector(i+dx[dir*2],j+dy[dir*2], this, NULL, NULL);
							if (ns)
							{
								assert(bot.size()==1);
								s.faces[bot[0]].nextSector = ns;
								s.faces[bot[0]].penetrable = true;
							}
						}
					}
				}
			}
		}

		Texture* GetWallTexture (const FloorGeometry* upper, int i, int j, bool roof)
		{
			if (roof && upper && upper->topology.fields[i][j].wood)
				return &baseTxr[TXR_WOOD];
			else if (topology.fields[i][j].index % holeModChanse == 0)
			{
				switch (GetFloorType(index))
				{
				case FT_OPENED : 
				case FT_UPPER  : return &baseTxr[TXR_UPPER_WALL];
				case FT_NORMAL : 
				case FT_TECH   : return &baseTxr[TXR_WALL];
				case FT_HELL   : return &baseTxr[TXR_HELL_WALL];
				case FT_DOWN   : return &baseTxr[TXR_HELL];
				default				 : return NULL;
				}
			} else
			{
				if (GetFloorType(index)==FT_TECH)
					return roof ? &baseTxr[TXR_LIGHT] : &techTxr[ (topology.fields[i][j].index & 0xffff) % techTxr.size() ];
				else
					return &ancTxr[ (topology.fields[i][j].index & 0xffff) % ancTxr.size() ];
			}
		}
		
		Texture* GetFloorTexture (const FloorGeometry* down, int i, int j)
		{
			if ((topology.fields[i][j].hasdown && down->topology.fields[i][j].wood) || topology.fields[i][j].wood)
			{
				return &baseTxr[TXR_WOOD];
			} else	if (topology.fields[i][j].index % holeModChanse == 0)
			{
				switch (GetFloorType(index))
				{
				case FT_OPENED : 
				case FT_UPPER  : 
				case FT_NORMAL : return &baseTxr[TXR_GRASS];
				case FT_TECH   : return &baseTxr[TXR_METAL];
				case FT_HELL   : return &baseTxr[TXR_HELL_FLOOR];
				case FT_DOWN   : return &baseTxr[TXR_HELL];
				default				 : return NULL;
				}
			} else
			{
				switch (GetFloorType(index))
				{
				case FT_OPENED : 
				case FT_UPPER  : 
				case FT_NORMAL : return &baseTxr[TXR_STONE_FLOOR];
				case FT_TECH   : return &baseTxr[TXR_METAL];
				case FT_HELL   : return &baseTxr[TXR_STONE_FLOOR];
				case FT_DOWN   : return &baseTxr[TXR_HELL];
				default				 : return NULL;
				}
			}
		}

		Texture* GetMiddleTexture (int i, int j, int dir, Texture* def)
		{
			int ni = i+dx[dir*2], nj=j+dy[dir*2];
			if (ni>=0 && ni<N && nj>=0 && nj<N)
			{
				return topology.fields[ni][nj].wood ? &baseTxr[TXR_WOOD] : def;
			} else 
				return def;
		}

		static void SetCeilTexture (Face& f, Texture* t)
		{
			f.texture = t;
			f.vtx  = Point3D(32.0f,  0.0f,  0.0f);
			f.vtxc = 0.0f;
			f.vty  = Point3D( 0.0f, 32.0f,  0.0f);
			f.vtyc = 0.0f;
		}
		
		static void SetFloorTexture (Face& f, Texture* t)
		{
			f.texture = t;
			f.vtx  = Point3D( 28.0f, 14.0f,  0.0f);
			f.vtxc = 0.0f;
			f.vty  = Point3D(-14.0f, 28.0f,  0.0f);
			f.vtyc = 0.0f;
		}
		
		static void SetSideTexture (Face& f, Texture* t)
		{
			f.texture = t;
			f.vtx  = Point3D(20.0f,-20.0f,  0.0f);
			f.vtxc = 0.0f;
			f.vty  = Point3D( 0.0f,  0.0f, 32.0f);
			f.vtyc = 0.0f;
		}

		void SetTextures (const FloorGeometry* upper, const FloorGeometry* down, Sector& s, SectorIndexes& ind, int i, int j)
		{
			Texture 
				*ceilT  = GetWallTexture(upper, i,j,true),
				*sideT  = GetWallTexture(upper, i,j,false),
				*floorT = GetFloorTexture(down, i,j);			

			for (int c=0; c<ind.ceil.size(); ++c)
				SetCeilTexture(s.faces[ind.ceil[c]], ceilT);
			for (int dir=0; dir<4; ++dir)
			{
				for (int c=0; c<ind.sides[dir].top.size(); ++c)
					SetSideTexture(s.faces[ind.sides[dir].top[c]], sideT);
				for (int c=0; c<ind.sides[dir].middle.size(); ++c)
					SetSideTexture(s.faces[ind.sides[dir].middle[c]], GetMiddleTexture(i,j,dir,sideT));
				for (int c=0; c<ind.sides[dir].bottom.size(); ++c)
					SetSideTexture(s.faces[ind.sides[dir].bottom[c]], sideT);
			}						
			for (int c=0; c<ind.floor.size(); ++c)
				SetFloorTexture(s.faces[ind.floor[c]], floorT);
		}

		void SetMainLight(Sector& s, int i, int j, const FloorGeometry* upper)
		{
			if (GetFloorType(index) == FT_TECH 
			&& topology.fields[i][j].index % holeModChanse != 0
			&& !upper->topology.fields[i][j].wood)
				topology.fields[i][j].light = true;
			else if (GetFloorType(index-4) == FT_DOWN && topology.fields[i][j].hasdown)
				topology.fields[i][j].light = true;

			if (topology.fields[i][j].light)
			{
        for (int f = s.faces.low(); f<s.faces.high(); ++f)
					s.faces[f].light=s.faces[f].texture == &baseTxr[TXR_LIGHT] ? 255 : 64;
			}
		}
		
		void SetSecondaryLight(Sector& s, int i, int j,
			FloorGeometry* upper, FloorGeometry* prev, FloorGeometry* next)
		{
			if (s.faces[s.faces.low()].light<64)
			{
				int fc=0;
				for (int dir=0; dir<8; ++dir)
				{
					int i1 = i+dx[dir], j1=j+dy[dir];
					Sector*ns = GetSector(i1,j1,upper,prev,next);
					if (ns!=NULL && ns->faces[ns->faces.low()].light>=64)
					{
						if (i1==i || j1==j || GetSector(i,j1,upper,prev,next) || GetSector(i1,j,upper,prev,next))
							++fc;
					}
				}
				if (fc>=1 && fc<=8)
					for (int f=s.faces.low(); f<s.faces.high(); ++f)
						if (s.faces[f].light<255)
							s.faces[f].light=24;
			}
		} 
		
		static bool TexturesOk(const Sector &s)
		{
			for (int f=s.faces.low(); f<s.faces.high(); ++f)
				if (!s.faces[f].nextSector && !s.faces[f].texture)
					return false;
			return true;
		}

		void CreateSectors (
			FloorGeometry* upper, 
			FloorGeometry* down, 
			FloorGeometry* prev, 
			FloorGeometry* next,
			Sector *skyS, Sector *hellS)
		{
			// первичная инициализация
			for (int i=0; i<N; ++i) for (int j=0; j<N; ++j)
			{
				if (topology.fields[i][j].index<=0 && !topology.fields[i][j].hasup)
				{
					Sector& s = sectors[i][j];
					SectorIndexes ind;
					tblib::array<Point3D*, 28*4> pts;		      
					InitPointArr(pts, ind, i, j, upper, down, prev, next);
					s.Create(pts.get_slice(0, pts.size()));
					s.id = ( (topology.fields[i][j].hasdown ? (index-4) : index)<<16) | (i<<8) | j;
					assert (s.faces.high() >= s.faces.low()+4);
					CreateSectorLinks(s, ind, i, j, upper, down, prev, next, hellS, skyS);
					s.gravity = 0.003f;
					SetTextures(upper, down,  s, ind, i, j);	
					assert(TexturesOk(s));
					SetMainLight(s, i, j, upper);
				}      
			}
		}

		void LightSectors (
			FloorGeometry* upper, 
			FloorGeometry* prev, 
			FloorGeometry* next)
		{
			// второй прогон, чтоб выставить  светлые сектора			
			for (int i=0; i<N; ++i) for (int j=0; j<N; ++j)
			{
				if (topology.fields[i][j].index<=0 && !topology.fields[i][j].hasup)
				{
					Sector& s = sectors[i][j];
					SetSecondaryLight(s,i,j,upper,prev,next);
				}
			}
		}
	};	
	
	/*******************************************************************************************************

	Почему здесь, а не в начале?
	Потому что я хуёвый архитектор!

	*/
	
	tblib::carray<Point3D, 8> skyP, hellP, emptyP;
	Sector skyS, hellS, emptyS;
	tblib::carray<FloorGeometry, 32> floors;

	Monster player;
	Monster* boss;
	tblib::carray<Monster, maxMonsters> enemies;
	tblib::carray<Entity, maxEntitys> entitys;
	tblib::carray<Bullet, maxBullets> bullets;

	float gameTime;
	//*******************************************************************************************************

	void InitSkyBox (const tblib::slice<Point3D>& points, Sector& s, Texture& roof, Texture& floor)
	{
		assert (points.low()==0 && points.high()==8);

		points[0] = Point3D( 64.0f,-64.0f,-0.2f);
    points[1] = Point3D( 64.0f,-64.0f, 0.2f);
    points[2] = Point3D( 64.0f, 64.0f, 0.2f);
    points[3] = Point3D( 64.0f, 64.0f,-0.2f);
    points[4] = Point3D(-64.0f,-64.0f,-0.2f);
    points[5] = Point3D(-64.0f,-64.0f, 0.2f);
    points[6] = Point3D(-64.0f, 64.0f, 0.2f);
    points[7] = Point3D(-64.0f, 64.0f,-0.2f);   

		tblib::array<Point3D*, 30> a;
		int fc=0;

		Add4P(a, fc, &points[0], &points[1], &points[2], &points[3]); 
		Add4P(a, fc, &points[1], &points[0], &points[4], &points[5]); 
		Add4P(a, fc, &points[2], &points[1], &points[5], &points[6]); 
		Add4P(a, fc, &points[3], &points[2], &points[6], &points[7]); 
		Add4P(a, fc, &points[0], &points[3], &points[7], &points[4]); 
		Add4P(a, fc, &points[7], &points[6], &points[5], &points[4]); 
		s.Create(a.get_slice(0, a.size()));

		s.inProcess = 0;
		s.skybox = true;
		s.gravity = 0.03f;
		for (int i=s.faces.low(); i<s.faces.high(); ++i)
		{
			Face& face = s.faces[i];
			face.id = i;
			face.nextSector = NULL;
			face.penetrable = false;
			face.texture    = (i==s.faces.low()+2) ? &roof : &floor;
			face.light      = 255;
			face.vtx        = Point3D(400.0f, 0.0f, 0.0f);
			face.vtxc       = 0.0f;
			face.vty        = Point3D(0.0f, 400.0f, 0.0f);
			face.vtyc       = 0.0f;
		}
	}

	void InitGlobalShifts (DeltaArr<2*N> &globalx, DeltaArr<2*N> &globaly)
	{
		for (int i=0; i<2*N+1; ++i) for (int j=0; j<2*N+1; ++j)
		{
			globalx.d[i][j] = float(pasrnd.frandom())*10.0f;
			globaly.d[i][j] = float(pasrnd.frandom())*10.0f;
		}
		globalx.SmoothGlobal();
		globaly.SmoothGlobal();

		for (int i=0; i<2*N+1; ++i) for (int j=0; j<2*N+1; ++j)
		{
			globalx.d[i][j] += float(pasrnd.frandom())*0.14f;
			globaly.d[i][j] += float(pasrnd.frandom())*0.14f;
		}
	}

	void InitSectorsPoints ()
	{
		for (int i=0; i<floors.capacity(); ++i)
			floors[i].Create();
	}

	void InitLava ()
	{
		for (int i=0; i<4; ++i)
			floors[i].InitLava(floors[i+4].topology);
	}

	void MoveSectorsPoints ()
	{
    DeltaArr<2*N> dx, dy;
		InitGlobalShifts (dx, dy);
		for (int i=0; i<floors.capacity(); ++i)
			floors[i].ShiftPoints(dx,dy);
	}

	void InitHoles ()
	{
		for (int i=0; i<floors.capacity()-4; ++i)
		{
			int chanse 
				= (GetFloorType(i)==FT_DOWN)                               ? 99
				: (GetFloorType(i)==FT_HELL && GetFloorType(i+5)==FT_HELL) ? 0 
				: (GetFloorType(i)==FT_HELL && GetFloorType(i+4)==FT_HELL) ? 99
				: (GetFloorType(i)!=FT_TECH && GetFloorType(i+4)==FT_TECH) ? 0
				: (GetFloorType(i)==FT_TECH && GetFloorType(i+4)==FT_TECH) ? 45
				: (GetFloorType(i)==FT_TECH)                               ? 0
				: (i+1 == baseFloor)                                       ? 100
				: (i   == baseFloor)                                       ? 0
				:                                                            100;

			bool canNearHall = chanse<100;
			floors[i].CreateHoles(floors[i+4], chanse, canNearHall);
		}
	}

	void InitWood ()
	{
		for (int i=4; i<floors.capacity(); ++i)
			floors[i].InitWood(floors[i-4].topology);
	}

	void CreateSectors ()
	{
		for (int i=4; i<floors.capacity(); ++i)
			floors[i].CreateSectors(
				i>=floors.capacity()-4 ? NULL : &floors[i+4],
				&floors[i-4],
				i<=4                   ? NULL : &floors[i-1],
				i>=floors.capacity()-1 ? NULL : &floors[i+1],
				&skyS, &hellS);
	}
	
	void LightSectors ()
	{
		for (int i=4; i<floors.capacity(); ++i)
			floors[i].LightSectors(
				i>=floors.capacity()-4 ? NULL : &floors[i+4],
				i<=4                   ? NULL : &floors[i-1],
				i>=floors.capacity()-1 ? NULL : &floors[i+1]);
	}

	bool FacesCorrect()
	{
		for (int f=4; f<32; ++f) for (int i=0; i<N; ++i) for (int j=0; j<N; ++j)
		{
			if (floors[f].topology.fields[i][j].index<=0 && !floors[f].topology.fields[i][j].hasup)
			{
				Sector& s = floors[f].sectors[i][j];
				for (int fc=s.faces.low(); fc<s.faces.high(); ++fc)
				{
					Sector* ns=s.faces[fc].nextSector;
					if (ns && ns!=&skyS && ns!=&hellS)
					{
						bool ok=false;
						for (int fc2=ns->faces.low(); fc2<ns->faces.high(); ++fc2) 
							if (ns->faces[fc2].nextSector == &s)
								{ ok=true; break; }
						if (!ok)
							return false;
					}
				}
			}
		}
		return true;
	}

	void AddBox (int k, int i, int j, int &ci, bool &wt)
	{   
		if (ci >= entitys.size()) 
			return;
		int r = pasrnd.random(25);

		EntityModel* em = (r==0) ? &emBox[BXK_BIG_HEALTH] 
		               : (r<=20) ? &emBox[BXK_HEALTH] 
									           : &emBox[BXK_ARMOR];

		if (((i>=6 && k<=8) || (k>=11 && k<=13)) && pasrnd.random(2)==0) em = &emBox[BXK_ARMOR];
		else if (k>=19 && k<=23 && pasrnd.random(10)==0) em = &emBox[BXK_GUN];

    if (k==31 && !wt)
		{
			em = &emBox[BXK_BFG];
			wt = true;
		}
		entitys[ci].Create(&floors[k].sectors[i][j], em);
		++ci;
	}

	void AddEnemy (int k, int i, int j, int d, int& ce, bool &wb)
	{  
		if (ce>=enemies.size())
			return;
		float ml = (float(d)+float(pasrnd.frandom())*13.0f)/40.0f;
		tblib::shrink(ml, 1.0f);

		int nd = d+pasrnd.random(15);

		EntityModel* em = (nd<15) ? &emTrilobit[int(ml*float(emTrilobit.size()))]
		                : (nd<23) ? &emSnowman [int(ml*float(emSnowman.size()))]
		                : (nd<31) ? &emCock    [int(ml*float(emCock.size()))]
		                          : &emGasbag  [int(ml*float(emGasbag.size()))];

		bool doboss = k==4 && !wb;
		if (doboss)
		{
			em = &emBoss[0];
			wb = true;
		}

		enemies[ce].Create(&floors[k].sectors[i][j], em);
		if (doboss)
			boss = &enemies[ce];
		++ce;
	}

	void InitMonsters ()
	{
		player.Create(&floors[baseFloor].sectors[N-2][N-2], &emPlayer);

		int ce=0, ci=0;
		bool wt=false, wb=false;

		for (int k=4; k<32; ++k)
		{
			const int d =	k>=baseFloor-1 ? abs(k-baseFloor)	: baseFloor*2-1-k;
			for (int i=1; i<N-1; ++i) for (int j=1; j<N-1; ++j)
			{
				Field& f = floors[k].topology.fields[i][j];
				if (f.index<=0 && !f.hasup && !f.hasdown 
					&& f.index != floors[baseFloor].topology.fields[N-2][N-2].index
					&& pasrnd.random(7)==0)
				{
					if (pasrnd.random(d+40)>=d+20) AddBox(k,i,j, ci,wt);
					else AddEnemy(k,i,j,d, ce,wb);
				}
			}
		}
	}

	void InitBullets ()
	{
		for (int i=0; i<bullets.size(); ++i)
			bullets[i].Create();
	}

	void Create ()
	{
		InitSkyBox(skyP.get_slice(0,8), skyS, baseTxr[TXR_SKY], baseTxr[TXR_SKY]);
		InitSkyBox(hellP.get_slice(0,8), hellS, baseTxr[TXR_HELL], baseTxr[TXR_BLACK]);
		InitSkyBox(emptyP.get_slice(0,8), emptyS, baseTxr[TXR_BLACK], baseTxr[TXR_BLACK]);
		
		for (int i = 0; i<floors.capacity(); ++i)
			floors[i].index = i;

		InitSectorsPoints(); // устанавливаем точки и смещаем их по Z
		InitLava();          // устанавливаем топологию нижних уровней
		InitHoles();         // устанавливаем дыры между этажами
		InitWood();          // устанавливаем мостики, при этом точки тоже сдвигаются
		MoveSectorsPoints(); // двигаем точки этажей с учётом дыр
		CreateSectors();     // создаём сектора
		LightSectors();     // создаём сектора
    assert(FacesCorrect());

		maxSectors = 32*N*N+3; // инициализируем важный глобальный параметр

    InitMonsters();
    InitBullets();
    gameTime = 0.0f;
	}

private :
	Level (const Level&) {}
	Level&operator=(const Level&) {}
};

Level<24> l;