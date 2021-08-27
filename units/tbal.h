#pragma once

#include "stdint.h"
#include <algorithm>
#include <vector>
#include "tbslice.h"
#include "tbarr2.h"

#ifdef ANDROID
	#include <jni.h>
	#include <android_native_app_glue.h> 
	#include <android/log.h>
#endif

#ifdef _WINDOWS
	#include "windows.h" 
#endif
namespace tbal {  
	#ifdef ANDROID
		#ifdef pf16bits
			#define rBits 5
			#define gBits 6
			#define bBits 5
			#define ColorValue uint16_t
			struct ColorStruct {
				uint16_t r:rBits, g:gBits, b:bBits; }; 
		#else
			#define rBits 8
			#define gBits 8
			#define bBits 8
			#define ColorValue uint32_t 
			struct ColorStruct {
				uint16_t r:rBits, g:gBits, b:bBits, extra:32-rBits-gBits-bBits; }; 
		#endif
		#define hBits rBits
		#define mBits gBits
		#define lBits bBits
	#endif

	#ifdef _WINDOWS
		#ifdef TBAL_16_BITS
			#define rBits 5
			#define gBits 5
			#define bBits 5
			#define ColorValue uint16_t
			struct ColorStruct	{
				uint16_t b:bBits, g:gBits, r:rBits;}; 
		#else
			#define rBits 8
			#define gBits 8
			#define bBits 8
			#define ColorValue uint32_t 
			struct ColorStruct	{
				uint16_t b:bBits, g:gBits, r:rBits, extra:32-rBits-gBits-bBits; }; 
		#endif
		#define hBits bBits
		#define mBits gBits
		#define lBits rBits
	#endif

	class Color {		
		union {
			ColorStruct components;
			ColorValue  v; 
		};
		Color (ColorValue v) : v(v) {}
		ColorValue UsedBits(ColorValue v) const {return v & ((1 << (rBits+gBits+bBits))-1);}
	public:
		Color(int r, int g, int b) {
			#ifndef TBAL_16_BITS
				components.extra = 0;
			#endif
			components.r = static_cast<uint16_t>(r) >> (8-rBits);
			components.g = static_cast<uint16_t>(g) >> (8-gBits);
			components.b = static_cast<uint16_t>(b) >> (8-bBits);	}
		#ifndef TBAL_16_BITS
		Color(int r, int g, int b, int extra) {
			components.extra = extra;
			components.r = static_cast<uint16_t>(r) >> (8-rBits);
			components.g = static_cast<uint16_t>(g) >> (8-gBits);
			components.b = static_cast<uint16_t>(b) >> (8-bBits);	}
		#endif
		Color() {}
		bool  operator ==(const Color c) const {return UsedBits(v) == UsedBits(c.v);}
		bool  operator !=(const Color c) const {return UsedBits(v) != UsedBits(c.v);}
		Color operator & (const Color c) const {return Color(v & c.v);}
		Color operator | (const Color c) const {return Color(v | c.v);}
		Color operator ^ (const Color c) const {return Color(v ^ c.v);}
		Color operator + (const Color c) const {return Color(v + c.v);}
		Color operator << (const int shift) const {return Color(v<<shift);}
		Color operator >> (const int shift) const {return Color(v>>shift);}
		Color operator - (const Color c) const {return Color(v - c.v);}
		Color& operator +=(const Color c) {v+=c.v; return *this;}
		Color& operator -=(const Color c) {v-=c.v; return *this;}
		Color& operator &=(const Color c) {v&=c.v; return *this;}
		Color& operator |=(const Color c) {v|=c.v; return *this;}
		Color& operator ^=(const Color c) {v^=c.v; return *this;}

		Color  operator *  (double s) const { return Color (int(components.r*s), int(components.g*s), int(components.b*s)); }
		Color& operator *= (double s) { components.r = int(components.r*s); components.g = int(components.g*s); components.b = int(components.b*s); return *this; }
		
		Color Half  () const {return Color (v>>1 & ~((((( 1<<lBits) +  1) <<mBits) +  1) << (hBits-1)));}
		Color Quart () const {return Color (v>>2 & ~((((( 3<<lBits) +  3) <<mBits) +  3) << (hBits-2)));}	
		Color Eigth () const {return Color (v>>3 & ~((((( 7<<lBits) +  7) <<mBits) +  7) << (hBits-3)));}	
		Color Sxtnh () const {return Color (v>>4 & ~(((((15<<lBits) + 15) <<mBits) + 15) << (hBits-4)));}	
		Color Saturate (int min, int max) const 	{
			const int ar=components.r<<(8-rBits), ag=components.g<<(8-gBits), ab=components.b<<(8-bBits);
			return Color(
				ar<min?min:ar>max?max:ar, 
				ag<min?min:ag>max?max:ag, 
				ab<min?min:ab>max?max:ab); }
		#ifndef TBAL_16_BITS
			int Extra() const {return components.extra;}
			Color NoExtra() const { return *this & Color(0xff,0xff,0xff);}
		#endif
		int R() const {return components.r<<(8-rBits);}
		int G() const {return components.g<<(8-gBits);}
		int B() const {return components.b<<(8-bBits);}};	

	#undef rBits
	#undef gBits
	#undef bBits
	#undef ColorValue
	#undef lBits
	#undef mBits
	#undef hBits

	const Color 
		COLOR_BLACK  (0x00, 0x00, 0x00), 
		COLOR_RED    (0xff, 0x00, 0x00), 
		COLOR_GREEN  (0x00, 0xff, 0x00), 
		COLOR_BLUE   (0x00, 0x00, 0xff), 
		COLOR_PURPLE (0xff, 0x00, 0xff), 
		COLOR_YELLOW (0xff, 0xff, 0x00), 
		COLOR_TEAL   (0x00, 0xff, 0xff), 
		COLOR_WHITE  (0xff, 0xff, 0xff);

	enum Action {
		ACTION_DOWN=0,
		ACTION_MOVE=1,
		ACTION_UP=2,
		ACTION_LOST=3 };

	const char* SetProjectName (const char* newName);
	const char *GetExternalFilesDir ();
	void RunUrl (const char* url);
	float GetXDPI ();
	float GetYDPI ();
	void SetTimer (int interval);

	void LogI(const char* c);
	void LogW(const char* c);

	// это говнофункторы
	class TransparentTest {
		Color tc;
	public:
		TransparentTest(const Color tc) : tc(tc) {}
		inline void operator () (Color &dst, const Color src) const {
			if (src != tc) dst=src;	
		}
	};
	
	class Fill	{
		Color tc;
	public:
		Fill(const Color tc) : tc(tc) {}
		inline void operator () (Color &dst) const {
			dst = tc;
		}
	};
	
	struct CopyPixel {
		inline void operator () (Color &dst, const Color src) const	{
			dst=src;
		}
	};

	// а теперь сам класс изображени€!
	typedef tblib::array2d_window<Color> Bitmap;

	typedef tblib::array2d<Color> Picture;    

	class Buffer : public Bitmap 
	{
		Buffer operator = (const Buffer&);
		Buffer (const Buffer&);// нельз€ копировать
	public : 
		Buffer  ();
		~Buffer ();	
	}; 

	class ManualBuffer : public Bitmap 
	{
		ManualBuffer operator = (const ManualBuffer&);
		ManualBuffer (const ManualBuffer&);
		bool assigned;
	public :
		ManualBuffer () : Bitmap(0,0,0,NULL), assigned(false) {}
		void OutBuffer () { if (assigned) { ((Buffer*)(this))->~Buffer(); assigned=false; } }
		~ManualBuffer  () { OutBuffer (); }
		void GetBuffer () { OutBuffer (); new (this) Buffer(); assigned=true; }
	};

	#ifdef ANDROID
		struct FileDescriptor 
		{
			int32_t descr;
			off_t start;
			off_t length;
		};
	#endif
	#ifdef _WINDOWS
		typedef std::ifstream FileDescriptor;
	#endif

	struct Asset
	{
		Asset ();
		~Asset ();
		void Open (const char *filename);
		size_t GetLength();
		char*  GetBuffer();
		void GetDescriptor(FileDescriptor& fd);
	private :
		#ifdef ANDROID
			AAsset *asset;
		#endif
		#ifdef _WINDOWS
			std::string filename;
			bool loaded;
			std::vector<char> buffer;
			void Load();
		#endif
		Asset (const Asset&);
	};

#ifdef _WINDOWS
	HWND GetWindowHandle();
#endif

	bool SetSingleBuffer (bool newSingle);
	bool IsSingleBuffer ();

	int MSec (); 
	int CreateScreenButton (int code, int px, int py, int sx, int sy, Color transparentColor, const Picture& image, const Picture& imagePushed, bool creepable = false);
	bool ShowButton (int number, bool show);
	void GetButtonPosition (int number, int &px, int &py, int &sx, int &sy);
	void SetButtonPosition (int number, int  px, int  py, int  sx, int  sy);
	void SetButtonImages(int number, Color transparentColor, const Picture& image, const Picture& imagePushed);	
	void DrawButton (const Bitmap& buffer, int number);
	bool Pressed (int code);		
	#ifdef _WINDOWS
	// коды клавиш ну и не только
		enum Codes {
			CODE_UP      = VK_UP,
			CODE_DOWN    = VK_DOWN,
			CODE_LEFT    = VK_LEFT,
			CODE_RIGHT   = VK_RIGHT,
			CODE_POINTER = 256,
			CODE_TIMER   = 257, 
			CODE_ESCAPE  = VK_ESCAPE, 
			CODE_HOME    = VK_HOME,
			CODE_ENTER   = VK_RETURN ,
			CODE_START	 = 258,
			CODE_EXIT    = 259,
			CODE_LOSTFOCUS = 260,
			CODE_GETNAME   = 261,
			CODE_CUSTOM    = 512, 

			CODE_0		 = '0',
			CODE_1		 = '1',
			CODE_2		 = '2',
			CODE_3		 = '3',
			CODE_4		 = '4',
			CODE_5		 = '5',
			CODE_6		 = '6',
			CODE_7		 = '7',
			CODE_8		 = '8',
			CODE_9		 = '9',
			CODE_A		 = 'A',
			CODE_B		 = 'B',
			CODE_C		 = 'C',
			CODE_D		 = 'D',
			CODE_E		 = 'E',
			CODE_F		 = 'F',
			CODE_G		 = 'G',
			CODE_H		 = 'H',
			CODE_I		 = 'I',
			CODE_J		 = 'J',
			CODE_K		 = 'K',
			CODE_L		 = 'L',
			CODE_M		 = 'M',
			CODE_N		 = 'N',
			CODE_O		 = 'O',
			CODE_P		 = 'P',
			CODE_Q		 = 'Q',
			CODE_R		 = 'R',
			CODE_S		 = 'S',
			CODE_T		 = 'T',
			CODE_U		 = 'U',
			CODE_V		 = 'V',
			CODE_W		 = 'W',
			CODE_X		 = 'X',
			CODE_Y		 = 'Y',
			CODE_Z		 = 'Z',
			CODE_SPACE = VK_SPACE};
	#endif

	#ifdef ANDROID
		enum Codes	{
			CODE_UP      = AKEYCODE_DPAD_UP    ,
			CODE_DOWN    = AKEYCODE_DPAD_DOWN  ,
			CODE_LEFT    = AKEYCODE_DPAD_LEFT  ,
			CODE_RIGHT   = AKEYCODE_DPAD_RIGHT ,
			CODE_POINTER = 256,
			CODE_TIMER   = 257,
			CODE_ESCAPE  = AKEYCODE_BACK,
			CODE_HOME    = AKEYCODE_HOME,
			CODE_ENTER   = AKEYCODE_ENTER,
			CODE_START	 = 258,
			CODE_EXIT    = 259,
			CODE_LOSTFOCUS = 260,
			CODE_GETNAME   = 261,
			CODE_CUSTOM    = 512, 
			// јЌƒ–ќ»ƒќЅЋяƒ—“¬ќ
			CODE_0		 = AKEYCODE_0,
			CODE_1		 = AKEYCODE_1,
			CODE_2		 = AKEYCODE_2,
			CODE_3		 = AKEYCODE_3,
			CODE_4		 = AKEYCODE_4,
			CODE_5		 = AKEYCODE_5,
			CODE_6		 = AKEYCODE_6,
			CODE_7		 = AKEYCODE_7,
			CODE_8		 = AKEYCODE_8,
			CODE_9		 = AKEYCODE_9,
			CODE_A		 = AKEYCODE_A,
			CODE_B		 = AKEYCODE_B,
			CODE_C		 = AKEYCODE_C,
			CODE_D		 = AKEYCODE_D,
			CODE_E		 = AKEYCODE_E,
			CODE_F		 = AKEYCODE_F,
			CODE_G		 = AKEYCODE_G,
			CODE_H		 = AKEYCODE_H,
			CODE_I		 = AKEYCODE_I,
			CODE_J		 = AKEYCODE_J,
			CODE_K		 = AKEYCODE_K,
			CODE_L		 = AKEYCODE_L,
			CODE_M		 = AKEYCODE_M,
			CODE_N		 = AKEYCODE_N,
			CODE_O		 = AKEYCODE_O,
			CODE_P		 = AKEYCODE_P,
			CODE_Q		 = AKEYCODE_Q,
			CODE_R		 = AKEYCODE_R,
			CODE_S		 = AKEYCODE_S,
			CODE_T		 = AKEYCODE_T,
			CODE_U		 = AKEYCODE_U,
			CODE_V		 = AKEYCODE_V,
			CODE_W		 = AKEYCODE_W,
			CODE_X		 = AKEYCODE_X,
			CODE_Y		 = AKEYCODE_Y,
			CODE_Z		 = AKEYCODE_Z,
			CODE_SPACE = AKEYCODE_SPACE};
	#endif
};

bool TbalMain (tbal::Action action, int code, int x, int y);
