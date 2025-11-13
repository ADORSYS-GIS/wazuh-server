## [0.1.6]

### Added

- None

### Changed

- Changed yara-server.sh active-response script. Now won't remove malware when detected, due to potential false positives from yara rules. [#75](https://github.com/ADORSYS-GIS/wazuh-yara/pull/75)

### Fixed

- None

### Deleted

- None

## [0.1.5]

### Added

- Add support for yara on Windows Server 22, Ubuntu server (22 and 24), rhel >= 9.6, CentOS >= 9, macOS server ([#8](https://github.com/ADORSYS-GIS/wazuh-server/pull/8)
- Add yara-server.sh active-response script with no notification and auto-remediation of found malware

### Changed

- None

### Fixed

- None

### Deleted

- None

## [0.1.4]

### Added

- Add support for suricata installation on Windows Server 22, Ubuntu server (22 and 24), rhel >= 9.6, CentOS >= 9 ([#7](https://github.com/ADORSYS-GIS/wazuh-server/pull/7))

### Changed

- None

### Fixed

- None

### Deleted

- None

## [0.1.3]

### Added

- Add support for  wazuh-agent installation on Windows Server 22, Ubuntu server (22 and 24), rhel >= 9.6, CentOS >= 8.5 ([#5](https://github.com/ADORSYS-GIS/wazuh-server/pull/5))
- Add `CHANGELOG.md` file to track changes 

### Changed

- Enhance `deps.ps1` to install **Visual C++ Redistributable** and **GNU sed**

### Fixed

- None

### Deleted

- None


## [0.1.2]

### Added

- Add support for  wazuh-agent installation on Windows Server 22 ([#4](https://github.com/ADORSYS-GIS/wazuh-server/pull/4))

### Changed

- Simplify `deps.ps1` to core dependencies only (curl + jq)
- Enhance `install.ps1` with version checking and upgrade logic
- Update documentation

### Fixed

- Fix uninstall validation with reliable file/process detection

### Deleted

- None


## [0.1.1] -> Initial Version

### Added

- Scripts to install `wazuh agent` on Ubuntu server (22 and 24), rhel >= 9.6, CentOS >= 8.5

### Changed

- None

### Fixed

- None

### Deleted

- None
