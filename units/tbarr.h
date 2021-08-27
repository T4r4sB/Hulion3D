#pragma once

#include "stdint.h"
#include "assert.h"
#include <algorithm>
#include "tbslice.h"
#include "align.h"

// FUCK THE EXCEPTIONS

template <typename T>
void construct (T* first, T* last) {
	while (first!=last)	{
		new(first) T;
		++first;
	}
}

template <typename T>
void destroy (T* first, T* last)	{
	while (last!=first)	{
		--last;
		last->~T();
	}
}

namespace tblib
{	
	template <typename T, int N>
	class base_array
	{
		union
		{
			uint8_t memory [sizeof(T[N])];
			align<T> aligner;
		};
#ifndef NDEBUG
		T* m_begin;
#endif
	public :
		typedef T value_type;
		typedef value_type * iterator;
		typedef const value_type * const_iterator;
		
		iterator begin () {
			return reinterpret_cast<T*> (memory);
		}
		
		const_iterator begin () const {
			return reinterpret_cast<const T*> (memory);
		}

#ifndef NDEBUG
		base_array () : m_begin (begin()) {}
#endif

		T& operator [] (int index) {
			assert (index>=0 && index<N);			
			return begin()[index];
		}

		const T& operator [] (int index) const {
			assert (index>=0 && index<N);			
			return begin()[index];
		}

		int capacity() const {
			return N;
		}
	};

	template <typename T, int N>
	class carray : public base_array <T,N>
	{
	public :
		iterator end ()  {
			return begin()+N;
		}
		
		const_iterator end () const {
			return begin()+N;
		}		

		carray () {
			construct(begin(), end());
		}
		
		carray (const T& t) {
			std::uninitialized_fill(begin(), end(), t);
		}

		carray (const T a[N]) {
			std::uninitialized_copy(a, a+N, begin());
		}

		~carray () 
		{
			destroy(begin(), begin()+N);
		}

		carray& operator = (const carray &a) {
			if (this!=&a)	{
				std::copy(a.begin(), a.end(), begin());
			}
			return *this;
		}		

		carray& operator = (const T a[N]) {
			std::copy(a, a+N, begin());
			return *this;
		}

		slice<T> get_slice(int low, int high)	{
			assert (low>=0 && high<=N);
			return tblib::slice<T>(&(*this)[low], low, high);
		}

		int size() const { 
			return N; 
		};
	};
	
	template <typename T, int N>
	class modarray : public carray <T,N>
	{
		static int mod (int index, int n)
		{
			if (n&(n-1))
			{
				index %= n;
				if (index<0) index += n;
				return index;
			} else
				return index & (n-1);
		}
	public :		
		modarray () : carray<T,N> () {}		
		modarray (const T& t) : carray<T,N> (t) {}
		modarray (const carray<T,N> &a) : carray<T,N> (a) {}
		modarray (const T a[N]) : carray<T,N> (a) {}

		T& operator [] (int index) {
			return this->carray<T,N>::operator[] (mod(index,N));
		}

		const T& operator [] (int index) const {
			return this->carray<T,N>::operator[] (mod(index,N));
		}
	};

	template <typename T, int N>
	class array : public base_array <T,N>
	{
		int m_size;
	public :
		iterator end ()  {
			return begin()+size();
		}
		
		const_iterator end () const {
			return begin()+size();
		}		

		array () : m_size(0) {}

		array (int a_size) : m_size(a_size) {
			construct(begin(), end());
		}		
		
		array (int a_size, const T& t) : m_size(a_size) {
			std::uninitialized_fill(begin(), end(), t);
		}		

		~array () {
			shrink(0);
		}

		template <int M>
		array (const array<T, M> &a)
		{
			assert (a.size()<=N);
			std::uninitialized_copy(a.begin(), a.end(), begin());
			m_size = a.size();
		}		

		template <int M>
		array (const T a[M])
		{
			assert (M<=N);
			std::uninitialized_copy(a, a+M, begin());
			m_size = M;
		}		

		template <int M>
		array (const carray<T, M> &a)
		{
			assert (M<=N);
			std::uninitialized_copy(a, a+M, begin());
			m_size = M;
		}		

		template <int M>
		array& operator = (const array<T, M> &a)
		{
			if (this!=&a) {
				assert (a.size()<=N);
				if (size()<a.size()) { // увеличить
					std::copy(a.begin(), a.begin()+size(), begin());
					std::uninitialized_copy(a.begin()+size(), a.end(), end());
				} else { // уменьшить
					std::copy(a.begin(), a.end(), begin());
					destroy(begin()+a.size(), end());
				}
				m_size = a.size(); 
			}
			return *this;
		}		

		template <int M>
		array& operator = (const T a[M])
		{
			assert (M<=N);
			if (size()<M) { // увеличить
				std::copy(a, a+size(), begin());
				std::uninitialized_copy(a+size(), a+M, end());
			} else { // уменьшить
				std::copy(a, a+M, begin());
				destroy(begin()+M, end());
			}
			m_size = M; 
			return *this;
		}		

		template <int M>
		array& operator = (const carray<T, M> &a)
		{
			assert (M<=N);
			if (size()<M) { // увеличить
				std::copy(a, a+size(), begin());
				std::uninitialized_copy(a+size(), a+M, end());
			} else { // уменьшить
				destroy(begin()+M, end());
				std::copy(a, a+M, begin());
			}
			m_size = M; 
			return *this;
		}

		void push_back (const T& t)
		{
			assert (m_size<N);
			std::uninitialized_fill_n(end(), 1, t);
			++m_size;
		}

		void  emplace_back ()	
			{	assert (m_size<N);	new (end()) T;	++m_size;	}
		template<typename A1> void  emplace_back (const A1&a1) 
			{	assert (m_size<N);	new (end()) T(a1);	++m_size;	}
		template<typename A1, typename A2> void  emplace_back (const A1&a1, const A2&a2) 
			{	assert (m_size<N);	new (end()) T(a1,a2);	++m_size;	}
		template<typename A1, typename A2, typename A3> void  emplace_back (const A1&a1, const A2&a2, const A3&a3) 
			{	assert (m_size<N);	new (end()) T(a1,a2,a3);	++m_size;	}
		template<typename A1, typename A2, typename A3, typename A4> void  emplace_back (const A1&a1, const A2&a2, const A3&a3, const A4&a4) 
			{	assert (m_size<N);	new (end()) T(a1,a2,a3,a4);	++m_size;	}
		template<typename A1, typename A2, typename A3, typename A4, typename A5> void  emplace_back (const A1&a1, const A2&a2, const A3&a3, const A4&a4, const A5&a5) 
			{	assert (m_size<N);	new (end()) T(a1,a2,a3,a4,a5);	++m_size;	}

		int size() const {
			return m_size;
		}

		void shrink (int a_size) {
			assert (a_size<=m_size);
			destroy(begin()+a_size, end());
			m_size=a_size;
		}		

		void resize (int a_size) {
			if (a_size<size())
				shrink(a_size);
			else
				contsruct(end(), begin()+a_size);
			m_size=a_size;
		}		

		slice<T> get_slice(int low, int high)	{
			assert (low>=0 && high<=m_size);
			return tblib::slice<T>(&(*this)[low], low, high);
		}		

		T& operator [] (int index) {
			assert (index>=0 && index<m_size);			
			return this->base_array<T,N>::operator[] (index);
		}

		const T& operator [] (int index) const {
			assert (index>=0 && index<m_size);			
			return this->base_array<T,N>::operator[] (index);
		}
	};	
};