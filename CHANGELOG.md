# Changelog

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
