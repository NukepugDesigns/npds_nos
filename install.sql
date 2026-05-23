CREATE TABLE IF NOT EXISTS `npds_installed_nos` (
    `plate` VARCHAR(12) NOT NULL,
    `system` VARCHAR(50) DEFAULT NULL,
    `bottle1` FLOAT DEFAULT 0.0,
    `bottle2` FLOAT DEFAULT 0.0,
    `bottle1_type` VARCHAR(20) DEFAULT 'regular',
    `bottle2_type` VARCHAR(20) DEFAULT 'regular',
    `purge_config` LONGTEXT DEFAULT NULL,
    PRIMARY KEY (`plate`)
);
