#pragma once
#include <vector>

namespace tblib
{
	template <typename T>
	class array2d_window
	{
	protected :
		int	m_sizeX, m_sizeY;
		int m_stride;
		T *m_begin;
	public :
		array2d_window () 
			: m_sizeX(0), m_sizeY(0), m_stride(0), m_begin(NULL) {}

		array2d_window (int sizeX, int sizeY, int stride, T *begin)	
			: m_sizeX(sizeX), m_sizeY(sizeY), m_stride(stride), m_begin(begin) {}
			
#ifdef NDEBUG
		class line
		{
			const int m_stride;
			T* m_begin;
		public:
			line (const array2d_window<T>& window, int index) 
				: m_stride(window.m_stride), m_begin(window.m_begin+index*window.m_stride)		{}

			line (const line& line) : m_stride(line.m_stride), m_begin(line.m_begin) {}

			line& operator = (const line& line) { 
				new(this) line(line); return *this; 
			}

			line& operator ++() { 
				m_begin += m_stride; return *this; 
			} 

			line operator ++(int) { 
				line tmp(*this); ++(*this); return tmp; 
			} 

			T& operator [] (int index) const {
				return m_begin[index];
			}
		};
#else
		class line
		{
			const array2d_window<T>& m_window;
			int m_index;
			T* m_begin;
		public:
			line (const array2d_window<T>& window, int index) 
				: m_window(window), m_index(index), m_begin(window.m_begin+index*window.m_stride)		{}

			line (const line& line) : m_window(line.m_window), m_index(line.m_index), m_begin(line.m_begin) {}

			line& operator = (const line& line) { 
				new(this) line(line); return *this; 
			}

			line& operator ++() { 
				m_index+=1; 
				m_begin += m_window.m_stride; return *this; 
			} 

			line operator ++(int) { 
				line tmp(*this); ++(*this); return tmp; 
			} 

			T& operator [] (int index) const {
				assert (m_index>=0 && m_index<m_window.m_sizeY && index>=0 && index<m_window.m_sizeX);
				return m_begin[index];
			}
		};
#endif

		int sizeX() const { return m_sizeX; }
		int sizeY() const { return m_sizeY; }

		line operator [] (int y) const { return line(*this, y); }
		
		array2d_window<T> Window (int wposX, int wposY, int wsizeX, int wsizeY) const 
		{
			const int 
				fx = std::max(0      , wposX),
				fy = std::max(0      , wposY),
				lx = std::min(m_sizeX, wposX+wsizeX),
				ly = std::min(m_sizeY, wposY+wsizeY);
			if (lx>fx && ly>fy)
				return array2d_window<T>(lx-fx, ly-fy, m_stride, m_begin+fx+fy*m_stride);
			else 
				return array2d_window<T>(0, 0, 0, NULL);
		}

		template <typename F, typename T> 
		void Copy (F f, const array2d_window<T>& src, const int dstX, const int dstY) const 
		{
			const int 
				fx  = std::max(0      , dstX),
				fy  = std::max(0      , dstY),
				lx  = std::min(sizeX(), dstX+src.sizeX()),
				ly  = std::min(sizeY(), dstY+src.sizeY());

			typename array2d_window<T>::line srcl = src[fy-dstY];
			line dstl = (*this)[fy];

			if (lx>fx)
			{
				for (int j=fy; j<ly; ++j) 
				{
					for (int i=fx; i<lx; ++i)
						f(dstl[i], srcl[i-dstX]);
					++srcl;
					++dstl;
				}
			}
		}
		
		template <typename F> 
		void Fill (F f) const 
		{
			const int
				sx=sizeX(), 
				sy=sizeY();
			line dstl = (*this)[0];
			if (sizeY()>0)
			{
				for (int j=0; j<sy; ++j) 
				{
					for (int i=0; i<sx; ++i)
						f(dstl[i]);
					++dstl;
				}
			}
		}
	};

	template <typename T>
	class array2d : public array2d_window<T>
	{ 
		std::vector<T> memory;

		T* get_begin()	{
			return  (m_sizeX>0 && m_sizeY>0) ? &memory[0] : NULL;
		}
	public:
		array2d () {}

		array2d (int sx, int sy) 
		: array2d_window<T>(sx,sy,sx,NULL)	{
			memory.resize(sx*sy);
			m_begin = get_begin();
		}
		
		array2d (int lx, int ly, int sx, int sy) : array2d_window<T>(lx,ly,sx,sy,sx,NULL) {
			memory.resize(sx*sy);
			m_begin = get_begin();
		}

		array2d& operator = (const array2d<T> &p) {
      new (this) array2d_window<T>(p);
			memory = p.memory;
			m_begin = get_begin();
			return *this;
		}

		array2d (const array2d &p) 
		: memory(p.memory), array2d_window<T>(p.sizeX(), p.sizeY(), p.m_stride, NULL) {
			m_begin = get_begin();
		}

		void Init (int sx, int sy)
		{
			memory.resize(sx*sy);
			new (this) array2d_window<T>(sx, sy, sx, NULL);
			m_begin = get_begin();
		}
	};
};