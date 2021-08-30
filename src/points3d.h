#pragma once

#include "math.h"

struct Point3D
{
	float x,y,z;
	Point3D () {}
	Point3D (float x, float y, float z) : x(x), y(y), z(z) {}

	float& operator [] (int i)
	{
		assert(i>=0 && i<3);
		return *(&x+i);
	}
	
	float operator [] (int i) const
	{
		assert(i>=0 && i<3);
		return *(&x+i);
	}

	Point3D& operator += (const Point3D& p) { x+=p.x; y+=p.y; z+=p.z; return *this; }
	Point3D operator + (const Point3D& p) const { Point3D p2(*this); return (p2+=p); }
	Point3D& operator -= (const Point3D& p) { x-=p.x; y-=p.y; z-=p.z; return *this; }
	Point3D operator - (const Point3D& p) const { Point3D p2(*this); return (p2-=p); }
	Point3D& operator *= (const float f) { x*=f; y*=f; z*=f; return *this; }
	Point3D operator * (const float f) const { Point3D p2(*this); return (p2*=f); }
	Point3D& operator /= (const float f) { x/=f; y/=f; z/=f; return *this; }
	Point3D operator / (const float f) const { Point3D p2(*this); return (p2/=f); }
	float SqrLength () const { return x*x+y*y+z*z; }
	float Length () const { return sqrt(SqrLength()); }
	void Normalize () { 
		assert (Length()!=0.0f); // O_O
		const float l=1.0f/Length(); x*=l; y*=l; z*=l; }
};

float Dot (const Point3D& p1, const Point3D& p2) { return p1.x*p2.x + p1.y*p2.y + p1.z*p2.z; }

Point3D Cross  (const Point3D& p1, const Point3D& p2)
{
	return Point3D(
		p1.y*p2.z-p1.z*p2.y,
		p1.z*p2.x-p1.x*p2.z,
		p1.x*p2.y-p1.y*p2.x);
}

float Volume (const Point3D& p1, const Point3D& p2, const Point3D& p3) 
{
	return Dot(p1, Cross(p2,p3));
}

float Volume (const Point3D& p1, const Point3D& p2, const Point3D& p3, const Point3D& p4) 
{
	return Dot(p2-p1, Cross(p3-p1,p4-p1));
}

struct Matrix3D
{
	Point3D px,py,pz,pt;
	Matrix3D () : px(1.0f,0.0f,0.0f), py(0.0f,1.0f,0.0f), pz(0.0f,0.0f,1.0f), pt(0.0f,0.0f,0.0f) {}

	void SetID () { 
		new(this) Matrix3D; 
	}

	Point3D RotateP (const Point3D& p) const	{
		return Point3D(Dot(px,p), Dot(py,p), Dot(pz,p)) + pt;
	}
	
	Point3D RotatePNoTr (const Point3D& p) const	{
		return Point3D(Dot(px,p), Dot(py,p), Dot(pz,p));
	}

	void Translate (const Point3D& p)	{
		pt += RotatePNoTr(p);
	}  

	static void RotateCoo (int i1, int i2, float c, float s, Point3D& p)
	{
		const float 
			t1 = p[i1]*c-p[i2]*s,
			t2 = p[i1]*s+p[i2]*c;
		p[i1]=t1;
		p[i2]=t2;
	}

	void Rotate (float c, float s, int axle)
	{
		assert(axle>=0 && axle<3);
		const int i1 = (axle+1)%3, i2 = (axle+2)%3;
		RotateCoo(i1,i2,c,s,px);
		RotateCoo(i1,i2,c,s,py);
		RotateCoo(i1,i2,c,s,pz);
	}
	
	void Rotate (float a, int axle) {
		Rotate(cos(a),sin(a), axle);
	}

	static void ScaleCoo (Point3D& p, float sx, float sy, float sz)
	{
		p.x *= sx;
		p.y *= sy;
		p.z *= sz;
	}

	void Scale (float sx, float sy, float sz)
	{
		ScaleCoo (px, sx,sy,sz);
		ScaleCoo (py, sx,sy,sz);
		ScaleCoo (pz, sx,sy,sz);
	}
	
	void Scale (float s) {
		Scale(s,s,s);
	}
};

bool CheckOrders ()
{
	Point3D pt;
	Matrix3D mt;
	return (
		&pt[0] == &pt.x ||
		&pt[1] == &pt.y ||
		&pt[2] == &pt.z );
}