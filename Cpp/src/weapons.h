#pragma once
#include "entitys.h"

struct Weapon
{
	bool     isWeapon;
	Entity   entity;
	float    reloadLeft;

	Weapon() : isWeapon(false) {}

	void SetModel (EntityModel* em)
	{
		isWeapon = true;
		entity.model = em;
	}

	void Create (EntityModel* model);

private :
	Weapon(const Weapon&);
	Weapon&operator=(const Weapon&);
};