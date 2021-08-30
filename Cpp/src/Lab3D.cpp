#include "textures.h"
#include "engine.h"
#include "render.h"


int lastNumber = -1;


void Draw (const tbal::Bitmap& b)
{
	b.Fill(tbal::Fill(tbal::COLOR_BLACK));
	ShowLevel(b, float(b.sizeX())/float(b.sizeY()*3/4), 1.0f);
}



void Phys (const tbal::Bitmap& b, float dt)
{
	POINT p;
	HWND h = tbal::GetWindowHandle();
	GetCursorPos(&p);
	ScreenToClient(h,&p);

	l.player.controls.dax = - float(p.y - b.sizeY()/2)*0.004f/dt;
	l.player.controls.daz =   float(p.x - b.sizeX()/2)*0.004f/dt;

	p.x = b.sizeX()/2;
	p.y = b.sizeY()/2;
	ClientToScreen(h,&p);
	SetCursorPos(p.x, p.y);

	l.player.controls.forw  = tbal::Pressed(tbal::CODE_W);
	l.player.controls.back  = tbal::Pressed(tbal::CODE_S);
	l.player.controls.left  = tbal::Pressed(tbal::CODE_A);
	l.player.controls.right = tbal::Pressed(tbal::CODE_D);
	l.player.controls.jump  = tbal::Pressed(tbal::CODE_SPACE);
	l.player.controls.sit   = tbal::Pressed(tbal::CODE_Z);
	l.player.controls.wpnumber = lastNumber;
	l.player.controls.shot  = tbal::Pressed(tbal::CODE_POINTER);

	EnginePhys(dt);
}

bool TbalMain (tbal::Action action, int code, int x, int y)
{
	(void)y;
	switch (code)
	{
	case tbal::CODE_GETNAME : 
		tbal::SetProjectName("Lab3D");
		break;
	case tbal::CODE_START : 		
		{
			InitPalette();
			InitFogTable(tbal::COLOR_BLACK);
			InitTextures();			
			InitModels();
			l.Create();
			tbal::SetTimer(1);
		}
		break;
	case tbal::CODE_TIMER : 
		{
			static int fpsc=0;
			static int rem=1000;

			++fpsc;
			rem -= x;
			if (rem<0)
			{
				rem = 1000;
				fps = fpsc;
				fpsc = 0;
			}
		}
		
		{	
			tbal::Buffer b;
			const int delta=15;
      static int rem = 0;
			rem += x;
			tblib::shrink(rem,100);
			while (rem>0)
			{
				rem -= delta;
				Phys(b, float(delta)*0.001f);
			}
			Draw(b);
		}
		break;
	case tbal::CODE_ESCAPE : 
		if (action == tbal::ACTION_UP)
			return false;
	case tbal::CODE_EXIT : 
		finish = true;
		break;
	case tbal::CODE_0 : lastNumber = 0; break;
	case tbal::CODE_1 : lastNumber = 1; break;
	case tbal::CODE_2 : lastNumber = 2; break;
	case tbal::CODE_3 : lastNumber = 3; break;
	case tbal::CODE_4 : lastNumber = 4; break;
	case tbal::CODE_5 : lastNumber = 5; break;
	case tbal::CODE_6 : lastNumber = 6; break;
	case tbal::CODE_7 : lastNumber = 7; break;
	case tbal::CODE_8 : lastNumber = 8; break;
	case tbal::CODE_9 : lastNumber = 9; break;
	}
	return true;
}