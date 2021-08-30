#pragma once
#include "fixed.h"	
#include "tbarr.h"
#include "tbarr2.h"
#include <vector>

namespace tbfont {	
	class Font 	{
		tblib::carray<tblib::array2d<int>, 256> images;
		tblib::carray<int, 256> widths;
		int				 height;
		Fixed scale, width;
	public:
		Font () : scale(fx0), width(fx0) {}
		void Init (Fixed scale, Fixed width);
		int Width(const char *c) const;
		int Height(const char *c) const;
		void OutText(const tbal::Bitmap &b, int x, int y, const char *c, tbal::Color color, int alignX=0, int alignY=0) const;
	};
};
