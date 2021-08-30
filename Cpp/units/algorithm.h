#pragma once

namespace tblib
{
	template <typename T, typename U>
	void enlarge(T& t, const U& u)
	{ if (t<u) t=u; }
	
	template <typename T, typename U>
	void shrink(T& t, const U& u)
	{ if (t>u) t=u; }
	
	template <typename T, typename U>
	void inbound(T& t, const U& u1, const U& u2)
	{ if (t<u1) t=u1; else if (t>u2) t=u2; }
};