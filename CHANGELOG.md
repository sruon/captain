# Changelog

## [1.7.0](https://github.com/sruon/captain/compare/v1.6.1...v1.7.0) (2025-12-02)


### Features

* **actionview:** allow configuring actions to display and mob filter through the UI ([6c6927f](https://github.com/sruon/captain/commit/6c6927f705131394e6d6b714747c8c860bc48f7e))
* **actionview:** display critical hits on mobskills and player weaponskills ([3b5d56b](https://github.com/sruon/captain/commit/3b5d56be9ccaa1f145f7c6774519800450ede885))
* **actionview:** print knockback values ([36d4053](https://github.com/sruon/captain/commit/36d40530b2f51ef1bf3a4172e736d13f8fb5e3c9))
* **actionview:** show additional effects on melee attacks ([2a01e09](https://github.com/sruon/captain/commit/2a01e090d8a72189a58df95efb3f2eb09261edb4))
* **actionview:** track max distance and max target spread for mobskills finish ([d541818](https://github.com/sruon/captain/commit/d541818b7c39993457d49cb427085040c74d8f6c))
* **actionview:** Track ready time for mobskills and spells ([78dd995](https://github.com/sruon/captain/commit/78dd9959038adea6aac8aa9a8a0bed2565406392))
* **addon:** immunitytrack tracks immunities on mobs, including resist traits procs ([fc81c63](https://github.com/sruon/captain/commit/fc81c639d38474bc75deba7594778d5793f59ef3))
* **addon:** POITrack - saves HELM points, Treasure Chest/Coffers positions ([7d88419](https://github.com/sruon/captain/commit/7d88419791a8d9259f04c7fd2166e357cf24158c))
* **attackdelay:** stop tracking when mob casts a spell or use a skill. Show live data in a new window. ([94b9d4d](https://github.com/sruon/captain/commit/94b9d4d7a393770b9db1e86be360aae9e581c8b1))
* **guildstock:** optionally print the entries to chat as they get captured ([8b0c7ea](https://github.com/sruon/captain/commit/8b0c7ea3f7abab5913c47603e4785b3692011c16))
* **packetlogger:** milliseconds precision on timestamps ([d3b897b](https://github.com/sruon/captain/commit/d3b897bf0dd8e642e2ca1f10c59ddac6cf12d959))
* **sqlite:** automatically add missing columns ([5588cad](https://github.com/sruon/captain/commit/5588cad775bcd03155d920b83675474b8735d2bf))
* **targetinfo:** display animsub ([8dad39b](https://github.com/sruon/captain/commit/8dad39b48ad0d8e936883a2bc19c7a36a7c3d51b))
* **targetinfo:** print target model/hitbox/model size/speed ([1e476e0](https://github.com/sruon/captain/commit/1e476e0762b51af721711f77cf0c66469a332c01))


### Bug Fixes

* **checkparam:** Collect syncid ([7c967b7](https://github.com/sruon/captain/commit/7c967b703ac22d0618f3fd2ae5c1b9883717f301))
* **npclogger:** properly capture model_id ([cfb0c8e](https://github.com/sruon/captain/commit/cfb0c8ed44cfbf15147ccab1aff017ddb4103fb9))

## [1.6.1](https://github.com/sruon/captain/compare/v1.6.0...v1.6.1) (2025-09-25)


### Bug Fixes

* **checkparam:** missing nil check ([65abf91](https://github.com/sruon/captain/commit/65abf918510d1f4a19a7dc4a4f82da9fa33a29e1))

## [1.6.0](https://github.com/sruon/captain/compare/v1.5.2...v1.6.0) (2025-09-25)


### Features

* **addon:** /checkparam ([2303f37](https://github.com/sruon/captain/commit/2303f374ddd8a7cb59fa5b53980920ee7c1431b6))
* **addon:** CraftTrack - log crafting results ([117e066](https://github.com/sruon/captain/commit/117e066ac0cb2acc3f35e4fac5f8a0a0d16dd328))
* **addon:** LevelRangeTrack - capture min/max level per unique mob ([fc81bfe](https://github.com/sruon/captain/commit/fc81bfeb9cdf03165eabb7b491f2624451664b92))
* **addon:** SpawnTrack ([744e1cd](https://github.com/sruon/captain/commit/744e1cd2d93eb507190b88bfd35629a90ab8b674))
* **attackdelay:** Calculate hits per slot / kick attacks ([23e19e8](https://github.com/sruon/captain/commit/23e19e829737e5c462ad8805c7737e21feb7901f))
* **spawntrack:** Save to CSV ([d30f790](https://github.com/sruon/captain/commit/d30f790e75350e0def293ff8f484fc99a20ddb5d))


### Bug Fixes

* **attackdelay:** Detect mobs falling to the ground ([c2fdb50](https://github.com/sruon/captain/commit/c2fdb50b030fedffa04445df463f44832b224824))
* **hptrack:** Detect mobs falling to the ground ([fae7520](https://github.com/sruon/captain/commit/fae752096040a7a66a412d9277f9754ee0632c68))
* **packetlogger:** Clear per-ID file handles in between captures ([49ce207](https://github.com/sruon/captain/commit/49ce2073b0524f92a0e674484afadd050aaf75eb))

## [1.5.2](https://github.com/sruon/captain/compare/v1.5.1...v1.5.2) (2025-08-28)


### Bug Fixes

* Strip MSB on Message IDs ([f298c62](https://github.com/sruon/captain/commit/f298c62e0a5bf67627130b1db1e0155b00ae4d0b))

## [1.5.1](https://github.com/sruon/captain/compare/v1.5.0...v1.5.1) (2025-08-15)


### Bug Fixes

* **npclogger:** Fix Flags0/1/2/3 being written as zeroes to the db ([#10](https://github.com/sruon/captain/issues/10)) ([51b258d](https://github.com/sruon/captain/commit/51b258d1a4d9437f3461761cc7971f281ecb2f92))

## [1.5.0](https://github.com/sruon/captain/compare/v1.4.0...v1.5.0) (2025-08-07)


### Features

* **core:** accept arbitrary args after /cap start to name the capture ([9fcaa83](https://github.com/sruon/captain/commit/9fcaa83223d2773e882bcb8764a96ae270ca5fa7))

## [1.4.0](https://github.com/sruon/captain/compare/v1.3.0...v1.4.0) (2025-08-06)


### Features

* **addon:** Check captain version ([4ec60a6](https://github.com/sruon/captain/commit/4ec60a6c47a99a998ba7dde74638f21a1e8bcedd))
* **addon:** ZoneDump, queries all static entities ([13820b7](https://github.com/sruon/captain/commit/13820b7af77a2c3200f0e80858e8a5ce8199755d))
* **guildstock:** track hidden items ([2c6b1d1](https://github.com/sruon/captain/commit/2c6b1d1886cb3e89d23afafc2e54d4c33dcee260))


### Bug Fixes

* **actionview:** remove useless databases ([d361de3](https://github.com/sruon/captain/commit/d361de3006320921d3f8b72bf27bf171e0dd878d))
* **config:** Show addons ordered ([5c1c073](https://github.com/sruon/captain/commit/5c1c073defb9224d01aa4ad7b035ba7289ada8c0))
* **core:** only store diffs in history table ([95feb24](https://github.com/sruon/captain/commit/95feb24a494c95f0df19922a7e65a37e4da94271))
* **core:** settings ([a2603b5](https://github.com/sruon/captain/commit/a2603b539bf285983b6f107dd500b105521c426f))
* dont process packets until fully initialized ([e669ea5](https://github.com/sruon/captain/commit/e669ea5dd1c628d00d6409f1ff77364855ae10d6))
* **eventview:** Wait for client to be ready before creating DB ([8ce6c0e](https://github.com/sruon/captain/commit/8ce6c0e6215f7a4c223207d11a96e444557f5f20))

## [1.3.0](https://github.com/sruon/captain/compare/v1.2.1...v1.3.0) (2025-08-05)


### Features

* **addon:** GuildStock, logs items purchased and sold by Guild Shops. ([7cc983f](https://github.com/sruon/captain/commit/7cc983f29122db55c9245f0ab2ee4e6826feef43))
* **addons:** ShopStock ([94347d5](https://github.com/sruon/captain/commit/94347d5a2d8234a46c5456e54bcb9e3fdeaa2734))
* **core:** Save manifest at root of capture directory ([24a6d6e](https://github.com/sruon/captain/commit/24a6d6e266a721c399893247a75000f2cad99a52))
* **core:** witness protection ([3f1abce](https://github.com/sruon/captain/commit/3f1abceb6d62f08df523dd289b83a9db7ddd1edf))
* **playerinfo:** In-memory retail check, display icon ([af74491](https://github.com/sruon/captain/commit/af74491ff4e4f2a092cf4301bc1b823d52b0a109))


### Bug Fixes

* **core:** delay initialization until player is ready ([ad50280](https://github.com/sruon/captain/commit/ad5028038cfee1402867224282b121760ce7f5ce))
* **core:** Deprecate concept of frozen notifications ([98a9551](https://github.com/sruon/captain/commit/98a9551e0fcdf83cfa1b4e6ffbd10a1a7af36ee4))
* **core:** Notifications no longer need to be destroyed explicitly ([4ff289e](https://github.com/sruon/captain/commit/4ff289e74639e4aea4c22bce7b473c33aac53467))

## [1.2.1](https://github.com/sruon/captain/compare/v1.2.0...v1.2.1) (2025-08-03)


### Bug Fixes

* auto-update captain.lua ver ([14eca47](https://github.com/sruon/captain/commit/14eca47e55d44de5146d5d169a10c13572300efe))
* print table content in chat notifications ([0e76046](https://github.com/sruon/captain/commit/0e76046dab04216176777fb8b6ff57dc27a18426))
* update semver ([2ff0e46](https://github.com/sruon/captain/commit/2ff0e466ab29529354a28d842223f715dc1ae4be))
* use right semver format ([c98889d](https://github.com/sruon/captain/commit/c98889d59adde5d2d7f03eaf0e0cc789d94b4aa6))

## [1.2.0](https://github.com/sruon/captain/compare/v1.1.0...v1.2.0) (2025-08-03)


### Features

* err/warn messages ([fe70514](https://github.com/sruon/captain/commit/fe70514806710def2779945fc37fb4d5217e83a3))


### Bug Fixes

* release test ([c90aa59](https://github.com/sruon/captain/commit/c90aa59376b8c593a2fb5aaeb13e82c3f19d0f2a))

## [1.1.0](https://github.com/sruon/captain/compare/v1.0.0...v1.1.0) (2025-08-03)


### Features

* CI ([a5a0230](https://github.com/sruon/captain/commit/a5a0230978eed2a05e9ead886ecf0f0262ebabd7))


### Bug Fixes

* Add issues permissions ([ea8cbbb](https://github.com/sruon/captain/commit/ea8cbbb8a05493c663f4ee94ac23af2e083d2098))

## 1.0.0 (2025-08-03)


### Features

* CI ([a5a0230](https://github.com/sruon/captain/commit/a5a0230978eed2a05e9ead886ecf0f0262ebabd7))
