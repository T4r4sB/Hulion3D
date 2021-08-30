#pragma once
#include "fixed.h"

struct Point 
{
	Fixed x,y;
	Point () {}
	Point (Fixed x, Fixed y) : x(x),y(y) {}

	inline Point &operator -= (const Point &p) {x-=p.x; y-=p.y; return *this;}
	inline Point &operator += (const Point &p) {x+=p.x; y+=p.y; return *this;}
	inline Point &operator *= (const Fixed f)  {x*=f;   y*=f;   return *this;}
	inline Point &operator /= (const Fixed f)  {x/=f;   y/=f;   return *this;}

	inline Point operator -(const Point &p) const {return Point (x-p.x, y-p.y);}
	inline Point operator +(const Point &p) const {return Point (x+p.x, y+p.y);}	
	inline Point operator *(const Fixed f)  const {return Point (x*f,   y*f  );}	
	inline Point operator /(const Fixed f)  const {return Point (x/f,   y/f  );}	
	inline Point operator ~() const {return Point(x, -y);} // ����������� ����������

	inline const Point &operator +() const {return *this;}
	inline Point  operator -() const {return Point(-x,-y);}

	inline Fixed operator *(const Point &p) const {return x*p.x+y*p.y;}
	inline Point operator &(const Point &p) const 
	{
		const Fixed m = (x+y)*(p.y+p.x);
		const Fixed n = (x-y)*(p.y-p.x);
		return Point (((m-n)>>1) - ((y*p.y)<<1), (m+n)>>1);
	} // ����������� ���������
	inline Fixed operator ^(const Point &p) const {return x*p.y-y*p.x;}
	
	inline Fixed Length () const 
	{			
		
		Fixed dx = x.Abs();
		Fixed dy = y.Abs();
		Fixed result;
		if (dx>dy) 
		{
			dy = (dy>>1) - (dx>>3);
			if (dy>=fx0) result = dx+dy; else result = dx;
		} else
		{
			dx = (dx>>1) - (dy>>3);
			if (dx>=fx0) result = dx+dy; else result = dy;
		}			
		if (result.g>=5)
		{
			// ����� ��� ������, ��� � ���� ����
			Fixed revr = fx1/result;
			return (result + x*(x*revr)+y*(y*revr))>>1;		
		} else 
			return result;
	}

	inline Point Normalize () const {return *this/(this->Length());}
	inline Point Rot90 () const {return Point(y, -x);}
};

const Fixed fxPi(3141593,1000000), fxPi2(1570796,1000000), fxPi4(785398,1000000), fx2Pi(6283185,1000000);

inline Fixed NSin(Fixed a)
{
	const Fixed ia = Fixed(-1233428, 1000000), ib = Fixed(252301, 1000000), ic = -fx1-ia-ib;
	a.g &= ((1<<(Fixed::BP+2))-1);

	if (a>Fixed(2))
	{
		Fixed b=a-Fixed(3), b2=b*b;
		return -((ic*b2+ib)*b2+ia)*b2-fx1;
	} else		
	{
		Fixed b=a-Fixed(1), b2=b*b;
		return ((ic*b2+ib)*b2+ia)*b2+fx1;
	} 
}

inline Fixed Sin(Fixed a)
{
	const Fixed m = fx1/fxPi2;
	return NSin(a*m);
}

inline Fixed Cos(Fixed a)
{
	const Fixed m = fx1/fxPi2;
	return NSin(a*m+fx1);
}

inline Point SinCos (Fixed a)
{
	return Point(Cos(a), Sin(a));	
}

inline Fixed NAngle (const Point& p) // x>0; abs(y)<abs(x)
{
	const Fixed ia=Fixed(1190,1000000),ib=Fixed(-45790,1000000),ic=Fixed(318652,1000000),id=Fixed(1001560,1000000);

	Fixed x=p.x,y=p.y;

	if      (x>Fixed(2048)) { x=x>>12; y=y>>12; }
	if      (x>Fixed(128)) { x=x>>8; y=y>>8; }
	else if (x>Fixed(8)) { x=x>>4; y=y>>4; }
	else if (x<Fixed(1,8192)) {x=x<<16; y=y<<16; }
	else if (x<Fixed(1,512)) {x=x<<12; y=y<<12; }
	else if (x<Fixed(1,32)) {x=x<<8; y=y<<8; }
	else if (x<Fixed(1,2)) { x=x<<4; y=y<<4; }

	Fixed x2=x*x, y2=y*y;
	return (y*x*(x2+ia*y2)) / ((ib*y2+ic*x2)*y2+id*x2*x2);
}

inline Fixed Angle (const Point& p)
{
	if (p.x>=p.y.Abs())	
	{
		if (p.x==fx0 && p.y==fx0) return fx0;
		return NAngle(p);
	} else if (p.y>=p.x.Abs())
		return NAngle(Point(p.y,-p.x))+fxPi2;
	else if (p.y<=-p.x.Abs())
		return NAngle(Point(-p.y,p.x))-fxPi2;
	else if (p.y>=fx0) 
		return NAngle(Point(-p.x,-p.y))+fxPi;
	else
		return NAngle(Point(-p.x,-p.y))-fxPi;
}