Twister 2.0
===
Addon to twist automatically.  
---
Provides a WF totem tracker icon and automated twisting.  
If you're a sicko thaty enjoys self-torture and being oom this is the addon for you.  
* Requires [SuperWoW](https://github.com/balakethelock/SuperWoW/)  
___
Use:
---
- Enable the addon with `/twister enable` or `/twister toggle`  
- - A keybind can be made in the keybinds menu to toggle the addon or you can use a macro of `/twister toggle`  
- Twisting will occur automatically as you cast in combat.  
- This addon uses a leeway to control how much sooner you want to drop WF before its duration expires, this is to account for latency, it is adjustable with `/twister leeway` to fit your particular ping.  The default is `0.3`.
- `/twister twist` will solely cycle twisting totems for you.  
- `/twister priotwist` will prioritise Grace of Air uptime over your casting uptime.
- `/twister` to explore other settings.

Example macros:
* Roids: `/cast [@mouseover] Chain Heal(Rank 1)`
* AutoMana+Clique script: `AutoMana("/run Clique:CastSpell(\"Chain Heal(Rank 1)\")")`
* Temporarily not using twister:
```
/twister pause
/cast [@mouseover] Healing Wave
/twister unpause
```

---
* This addon is made by and for `Weird Vibes` of Turtle WoW.  