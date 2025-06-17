# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
missing version numbers are for refactoring, tests and code optimisations.

[README.md](README.md)

## [Unreleased]

* get-help for all modules
* RelaxedIT.GetConfigfromAz ? (Company/Unit/Team)

## [0.0.83] - 2025-06-17

* 0.0.83 fixes and error handling on azlog
* 0.0.82 version logging to azlog, make faster maxhours skip TTL to 72h

## [0.0.78] - 2025-06-02

* 0.0.7* fixes
* 0.0.69, trycatch azlog
* 0.0.68, Rename RelaxedIT.3rdParty.chocolist
* 0.0.67, Fixes
* 0.0.66 FeatureTest: SoftwareOutdated
* 0.0.65 Fix: install.ps1, OneclickInstall, Feature: choco list depricated, RelaxedIT.3rdParty.chocolist,

## [0.0.64] - 2025-05-21

* 0.0.64 Fixes, Fixes, Fixes
* 0.0.62 New: Write-RelaxedIT params $noNewline $noWriteDate
* 0.0.61 Fixes, Fixes, optimizes in outputs debugs
* 0.0.58 New: skip state in azlog
* 0.0.57 New: Azlog pendingdrivers updates
* 0.0.56 Fix: azlog "action" write table not found error
* 0.0.55 New: Prepare Auto-install Windows Optional Updates

## [0.0.53] - 2025-05-15

* 0.0.53 New: Azlog CPU + RAM
* 0.0.52 New: Azlog Hardware + OS Infos
* 0.0.51 New: example config for [energysaver.json](config/energysaver.json)

## [0.0.50] - 2025-04-19

* 0.0.50 Mew: monitor-timeout-ac  n energysaver.json

## [0.0.47] - 2025-04-04

* v0.0.48 New: Uninstall then Install 3rd party Software
* v0.0.47 New: RelaxedIT.3rdParty.Update manage weekly 3rd Party Software upgrades via https://chocolatey.org/

## [0.0.44] - 2025-03-24

* v0.0.44 New: Start/Stop Log to Azure Table: RelaxedIT.AzLog.Run.Ping -action "Start" / "Done"
* v0.0.37 replace: global write-host in submodules: via publish.ps1 Update-InFileContent
* V0.0.36 New: RelaxdeIT.Tools
* v0.0.35 Fix: #1 (requirements check energysaver)

## [0.0.30] - 2025-03-13

- V0.0.30 New: Start-RelaxedLog -action "logfilepraefix"
- V0.0.29 New: AUTOUPDATER Task: **RelaxedIT.Update.Task.Install**
- V0.0.28 New: RelaxedIT.Install.All
- V0.0.27 Output Color Changes
- V0.0.26 Rename Write-Host Function to "Write-RelaxedIT"
- v0.0.25 Editor Colors, Get-ColorText colors

## [0.0.21] - 2025-03-11

- v0.0.21 Fix: Update-RelaxedITModuleAndRemoveOld
- v0.0.20 Fix: Version Numbering, Update
- v0.0.17 Initial Release for RelaxedIT.Update.All

## [0.0.12] - 2025-03-07

- v0.0.12 RelaxedIT.EnergySaver.Run

## [0.0.1] - 2025-03-07

### Added

- v0.0.1 Initial Release for https://www.powershellgallery.com/

### Changed

### Fixed
