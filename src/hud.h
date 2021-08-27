#pragma once

#include "tbal.h"
#include "level.h"
#include "monsters.h"
#include "font.h"
#include <sstream>

int fps;

void ShowHUD (const tbal::Bitmap &b, const Monster& m)
{
	static tbfont::Font f;
	f.Init(Fixed(b.sizeY(),10), Fixed(b.sizeY(),100));	
	b.Fill(tbal::Fill(tbal::Color(int(255.0f*(1.0f-m.lastDamageTime)), 0, 0)));
	
	if (l.boss && l.boss->Live())
	{
		tbal::Color fc = m.health>80.0f ? tbal::Color(0x80, 0xff, 0x80)
		               : m.health>30.0f ? tbal::Color(0xcc, 0xff, 0x40)
									                  : tbal::Color(0xff, 0x00, 0x00);

		{
			std::stringstream ss;
			ss<<"Здоровье: " << int(m.health);
			f.OutText(b, b.sizeX()/20, b.sizeY()*3/10, ss.str().c_str(), fc, 0, 1);
		}
		{
			std::stringstream ss;
			ss<<"Броня: " << int(m.armor);
			f.OutText(b, b.sizeX()/20, b.sizeY()*5/10, ss.str().c_str(), fc, 0, 1);
		}		
		{
			std::stringstream ss;
			ss<<"fps: " << int(fps);
			f.OutText(b, b.sizeX()/20, b.sizeY()*7/10, ss.str().c_str(), fc, 0, 1);
		}

		for (int i=1; i<=3; ++i) if (m.weapons[i].isWeapon)
		{
			tbal::Color wc = (i==m.currentWeapon) ? tbal::Color(0xff,0x00,0x00) : tbal::Color(0x77,0x77,0x77);
			f.OutText(b, b.sizeX()*6/9, b.sizeY()*(2*i)/10, m.weapons[i].entity.model->name, wc);
		}
		
		{
			std::stringstream ss;
			ss<<"Уровень: " << (m.legs->s->id >> 16) - 3;
			f.OutText(b, b.sizeX()/2, 0, ss.str().c_str(), fc, 1, 0);
		}

		mslice<int> hx (0, l.size+1, PK_TEMP); 
		mslice<int> hy (0, l.size+1, PK_TEMP); 
		for (int i=0; i<=l.size; ++i)
		{
			hx[i] = b.sizeX()/2 + (i*2-l.size)*b.sizeY() / (l.size*2);
			hy[i] = b.sizeY()/2 + (i*2-l.size)*b.sizeY() / (l.size*2);
		}

		const tbal::Color
			clw( 64, 32,  0),
			clf(128,255,  0),
			clh( 64,128,  0),
			clp(255,255,255);
		const int index = m.legs->s->id>>16;

		for (int i=0; i<l.size; ++i) for (int j=0; j<l.size; ++j)
		{
			b.Window(hx[i], hy[j], hx[i+1]-hx[i], hy[j+1]-hy[j]).Fill(tbal::Fill(
				(i==((m.legs->s->id>>8) & 0xff) && j== ((m.legs->s->id) & 0xff)) ? clp
				: l.floors[index].topology.fields[i][j].index>0                  ? clw
				: l.floors[index].topology.fields[i][j].hasdown                  ? clh
				: clf));
		}
	} else
	{
		f.OutText(b, b.sizeX()/2, b.sizeY()/2, "П О Б Е Д А ! ! !", tbal::Color(0x00,0xff,0x00), 1, 1);
	}

}