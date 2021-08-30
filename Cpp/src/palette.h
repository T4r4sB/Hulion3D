#pragma once

#include "tbal.h"
#include "tbarr.h"

typedef tblib::array<tbal::Color, 256> Palette;

Palette palette;
tblib::array<Palette, 320> fogTable;

void InitPalette ()
{
	tblib::array<tbal::Color, 15> baseColors;
	baseColors.push_back(tbal::Color(255,170,  0));
	baseColors.push_back(tbal::Color(192,170, 64));
	baseColors.push_back(tbal::Color(128,170,128));
	baseColors.push_back(tbal::Color( 64,170,192));
	baseColors.push_back(tbal::Color(  0,170,255));

	baseColors.push_back(tbal::Color(255,128,  0));
	baseColors.push_back(tbal::Color(255,192,128));
	baseColors.push_back(tbal::Color(255,255,255));
	baseColors.push_back(tbal::Color(128,192,255));
	baseColors.push_back(tbal::Color(  0,128,255));

	baseColors.push_back(tbal::Color(255, 85,  0));
	baseColors.push_back(tbal::Color(255,149,128));
	baseColors.push_back(tbal::Color(255,212,255));
	baseColors.push_back(tbal::Color(128,149,255));
	baseColors.push_back(tbal::Color(  0, 85,255));

	for (int i=0; i<palette.capacity(); ++i)
	{
		if (i==0)
			palette.push_back(tbal::Color(0,0,0));
		else
		{
			int l = (i-1)/15+1;
			int c = (i-1)%15;

			palette.push_back(tbal::Color(
				baseColors[c].R()*l/17,
				baseColors[c].G()*l/17,
				baseColors[c].B()*l/17));
		}
	}
}

uint8_t NearestIndex (int r, int g, int b)
{
	int dst = 255*255*3;
	uint8_t result=0;
	for (int i=0; i<palette.size(); ++i)
	{
		const int 
			dR = r-palette[i].R(),
			dG = g-palette[i].G(), 
			dB = b-palette[i].B(), 
			adst = dR*dR+dG*dG+dB*dB;
		if (adst<dst)
		{
			dst = adst;
			result = uint8_t(i);
		}
	}
	return result;
}

void InitFogTable (tbal::Color fog)
{
	for (int i=0; i<fogTable.capacity(); ++i)
	{
		const int 
			i4 = std::min(i*8,256),
			f = (i4*(256*2-i4)) / 256;
		fogTable.push_back(Palette());
    
		for (int j=0; j<fogTable[i].capacity(); ++j)
		{
			fogTable[i].push_back(tbal::Color(
				(palette[j].R()*f + fog.R()*(256-f))/256,
				(palette[j].G()*f + fog.G()*(256-f))/256,
				(palette[j].B()*f + fog.B()*(256-f))/256));
		}
	}
}