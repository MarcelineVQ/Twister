Twister
===
Addon to twist automatically.
---
Provides a WF totem tracker icon and a function `TwistIt` to twist with.  
If you're a sicko thaty enjoys self-torture and being oom this is the addon for you.  
* Requires [SuperWoW](https://github.com/balakethelock/SuperWoW/)  
___
Use: Wrap a macro with `TwistIt(spellmacro,cast_duration)`
* Bare: `/run TwistIt("/cast Chain Heal(Rank 1)",2.1)`
* Roids: `/run TwistIt("/cast [@mouseover] Chain Heal(Rank 1)",2.1)`
* Clique: `/run TwistIt("/run Clique:CastSpell(\"Chain Heal(Rank 1)\",2.1)`
* AutoMana+Clique: `AutoMana("/run TwistIt(\"/run Clique:CastSpell(\\\"Chain Heal(Rank 1)\\\")\",2.1)")`
___

The current settings are:
* Toggle the addon being enabled
* Choose leeway to add to `cast_duration` for how soon to drop WF before expiration, default `0.5`
* Lock totem timer
* Reset totem timer position

---

* This addon is made by and for `Weird Vibes` of Turtle WoW.  