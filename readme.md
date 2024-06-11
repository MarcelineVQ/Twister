Twister
===
Addon to twist automatically.
---
Provides a WF totem tracker icon and a function `TwistIt` to twist with.  
If you're a sicko thaty enjoys self-torture and being oom this is the addon for you.  
* Requires [SuperWoW](https://github.com/balakethelock/SuperWoW/)  
___
Use: Wrap a macro with `TwistIt(spellmacro,cast_duration,prio_twist)`
* Bare: `/run TwistIt("/cast Chain Heal(Rank 1)",2.1)`
* Roids: `/run TwistIt("/cast [@mouseover] Chain Heal(Rank 1)",2.1)`
* Clique: `/run TwistIt("/run Clique:CastSpell(\"Chain Heal(Rank 1)\",2.1)`
* AutoMana+Clique: `AutoMana("/run TwistIt(\"/run Clique:CastSpell(\\\"Chain Heal(Rank 1)\\\")\",2.1)")`

**Some people prefer to prio the twist** and don't care about casting downtime, if this is you then add a `true` argument:
* `/run TwistIt("/cast Chain Heal(Rank 1)",2.1,true)`

This will cast WF and wait the air totem gcd before casting GoA, costing casting time but maximizing GoA uptime.  
___
* `/run Twist()` is also provided to solely drop totems for those who just want one button twisting or are too lazy to press WF+GoA in sequence on their own.  
___

The current settings are:
* Toggle the addon being enabled
* Choose leeway to add to `cast_duration` for how soon to drop WF before expiration, default `0.5`.
* * Posibly just slightly higher than your ms latency is a good target, experiment.
* Lock totem timer
* Reset totem timer position

---

* This addon is made by and for `Weird Vibes` of Turtle WoW.  