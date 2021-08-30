#pragma once
#include "tbslice.h"
#include "tbarr.h"
#include "stdint.h"
#include "assert.h"
#include "pasrand.h"

#ifndef NDEBUG
#include <list>
#include <sstream>
#include <typeinfo>
#endif

bool finish = false;

class StackPool
{
	int size;
	uint8_t *data;
	uint8_t *beg;
	uint8_t *maxmem;
	bool global;
	
#ifndef NDEBUG
	std::list<std::string> listOfAllocs;
#endif


	StackPool(const StackPool&);
	StackPool& operator =(const StackPool&);
public :
	StackPool (uint8_t* mem, int size, bool global) : data(mem), beg(data), maxmem(data), size(size), global(global) {}

	template <typename T>
	T* Alloc (int count)
	{
			
		int bytecount = count*sizeof(T);
		if (bytecount>0)
		{	
			beg = (uint8_t*)((size_t(beg)+15)&(~15)); // выравнивание

#ifndef NDEBUG
			std::stringstream ss;
			ss<<typeid(T).name()<<"*"<<count;
			listOfAllocs.push_back(ss.str());
			if(!(beg+bytecount-1 < data+size))
			{
				std::stringstream lr;
				lr << "Memory overflow!!!";
				for (std::list<std::string>::iterator it = listOfAllocs.begin(); it!=listOfAllocs.end(); ++it)
				{
					lr << *it << std::endl;
				}
				tbal::LogW(lr.str().c_str());
				assert(false);
			}
#endif

			T* result = (T*)beg;
			beg += bytecount;
			if (beg>maxmem) 
				maxmem=beg;


			return result;
		} else
			return NULL;
	}

	typedef uint8_t *MemoryState;

	bool ValidEnd (uint8_t* ptr) { return ptr<=beg; } // валиден либо на границе
 	void SaveState (MemoryState &ms) { ms=beg; }
	void RestoreState (MemoryState ms) 
	{ 
#ifndef NDEBUG
		assert(!global || finish);			
		if (!finish || !global) { 
			assert(beg>=ms); 
			beg=ms; 
			listOfAllocs.pop_back();
		} 
#else
		beg=ms;
#endif
	} // порядок освобождения определить нельзя(
};

#define DefineStackPool(Name,Size,Global)\
	uint8_t __##Name[Size];\
	StackPool Name(__##Name,Size,Global)

DefineStackPool(globalStackPool,0x2000000,true);
DefineStackPool(temporaryStackPool,0x800000,false);

Random markerrnd(0);

enum PoolKind { PK_GLOBAL, PK_TEMP };

template <typename T>
class basic_marray : public tblib::slice<T>
{
	int marker;
#ifndef NDEBUG
	int *pmarker;
#endif
	StackPool* pool;
	StackPool::MemoryState ms;

	basic_marray (const basic_marray&);
	basic_marray& operator= (const basic_marray&);

public :
	basic_marray () 
	{
		pool = NULL;
		new (this) tblib::slice<T>(NULL, 0, 0);
	}
  
	basic_marray ( int low, int high, PoolKind poolKind ) 
	{		
		pool = poolKind==PK_GLOBAL ? &globalStackPool : &temporaryStackPool;
		pool->SaveState (ms);
#ifndef NDEBUG
		pmarker = pool->Alloc<int>(1);
		markerrnd.NextSeed();
		*pmarker = markerrnd.randseed;
		marker   = *pmarker;
#endif
		T* ptr = pool->Alloc<T>(high-low+1);
		new(this)	tblib::slice<T>(ptr, low, high);
	}
	
	void Init (int low, int high, PoolKind poolKind ) 
	{
		this->~basic_marray();
		new (this) basic_marray(low, high, poolKind);
	}

	~basic_marray ()
	{
		if (pool)
		{
			pool->RestoreState (ms);
		}
	}

	T& operator [] (int index)
	{
		assert (pmarker);
		assert (marker == *pmarker);
		assert (pool->ValidEnd((uint8_t*)(end())));
		return tblib::slice<T>::operator [] (index);
	}
	
	T& operator [] (int index) const
	{
		assert (pmarker);
		assert (marker == *pmarker);
		assert (pool->ValidEnd((uint8_t*)(end())));
		return tblib::slice<T>::operator [] (index);
	}
};

template <typename T>
class mslice : public basic_marray<T>
{
	mslice (const mslice&);
	mslice& operator= (const mslice&);
public :
	mslice () : basic_marray<T> () {}

	mslice ( int low, int high, PoolKind poolKind ) : basic_marray<T> (low, high, poolKind)
	{				
		construct(begin(), end());
	}
	
	void Init (int low, int high, PoolKind poolKind ) 
	{
		this->~mslice();
		new (this) mslice(low, high, poolKind);
	}

	~mslice () {	destroy(begin(), end()); }
};

template <typename T>
class marray : public basic_marray<T>
{
	marray (const marray&);
	marray& operator= (const marray&);
	int m_size;
public :
	int high() { return m_size; }
	iterator end () {	return begin() + (high()-low()); }	
	marray () : basic_marray<T> (), m_size(low()) {}
	marray ( int low, int high, PoolKind poolKind ) : basic_marray<T> (low, high, poolKind), m_size(low) {}
	
	void Init (int low, int high, PoolKind poolKind ) 
	{
		this->~marray();
		new (this) marray(low, high, poolKind);
	}

	int capacity () { return m_high-m_low; }
	~marray () {	destroy(begin(), end()); }

	void  emplace_back ()	
		{	assert (m_size<m_high);	new (end()) T;	++m_size;	}
	template<typename A1> void  emplace_back (const A1&a1) 
		{	assert (m_size<m_high);	new (end()) T(a1);	++m_size;	}
	template<typename A1, typename A2> void  emplace_back (const A1&a1, const A2&a2) 
		{	assert (m_size<m_high);	new (end()) T(a1,a2);	++m_size;	}
	template<typename A1, typename A2, typename A3> void  emplace_back (const A1&a1, const A2&a2, const A3&a3) 
		{	assert (m_size<m_high);	new (end()) T(a1,a2,a3);	++m_size;	}
	template<typename A1, typename A2, typename A3, typename A4> void  emplace_back (const A1&a1, const A2&a2, const A3&a3, const A4&a4) 
		{	assert (m_size<m_high);	new (end()) T(a1,a2,a3,a4);	++m_size;	}
	template<typename A1, typename A2, typename A3, typename A4, typename A5> void  emplace_back (const A1&a1, const A2&a2, const A3&a3, const A4&a4, const A5&a5) 
		{	assert (m_size<m_high);	new (end()) T(a1,a2,a3,a4,a5);	++m_size;	}


	void push_back (const T& t)
	{
		assert (m_size<m_high);		
		std::uninitialized_fill_n(end(), 1, t);
		++m_size;
	}

	T& operator [] (int index)
	{
		assert (index<m_size);
		return basic_marray<T>::operator [] (index);
	}
	
	T& operator [] (int index) const
	{
		assert (index<m_size);
		return basic_marray<T>::operator [] (index);
	}
};

template <typename T, int N>
struct Pool
{
	struct PoolItem : T
	{
		bool free;
		PoolItem* next;
	};

	int poolCount;
	PoolItem items[N];
	PoolItem* freePool;

	T* NewPtr()
	{
		assert(poolCount<N);
		assert(freePool);
		assert(freePool->free);
		T* result = freePool;
		freePool->free = false;
		freePool = freePool->next;
		++poolCount;
		return result;
	}

	void FreePtr (T* p)
	{
		PoolItem* pi = (PoolItem*)p;
		assert (!pi->free);
		pi->free = true;
		pi->next = freePool;
		freePool = pi;
		--poolCount;
	}

	Pool()
	{
		poolCount=0;
		freePool = &items[0];
		for (int i=0; i<N-1; ++i)
		{
			items[i].next = &items[i+1];
			items[i].free = true;
		}
		items[N-1].next = NULL;
		items[N-1].free = true;
	}

	~Pool()
	{
		assert(poolCount==0);
	}
};