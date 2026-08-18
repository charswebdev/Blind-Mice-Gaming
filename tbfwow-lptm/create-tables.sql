-- Light Paws Talent Manager — community catalogs
-- phpMyAdmin: open your database, then SQL tab, then Import this file or paste it.
-- Do not put a password in this file. Hyphens are not used in table names.

SET NAMES utf8mb4;
SET time_zone = '+00:00';

CREATE TABLE IF NOT EXISTS `lptm_retail` (
  `id` CHAR(36) NOT NULL,
  `name` VARCHAR(200) NOT NULL,
  `content` VARCHAR(120) NOT NULL DEFAULT '',
  `build_type` VARCHAR(120) NOT NULL DEFAULT '',
  `class_id` VARCHAR(32) NOT NULL DEFAULT '',
  `class_name` VARCHAR(64) NOT NULL DEFAULT '',
  `spec_id` VARCHAR(32) NOT NULL DEFAULT '',
  `spec_name` VARCHAR(64) NOT NULL DEFAULT '',
  `hero_id` VARCHAR(64) NOT NULL DEFAULT '',
  `hero_name` VARCHAR(64) NOT NULL DEFAULT '',
  `patch` VARCHAR(16) NOT NULL DEFAULT '',
  `created` DATETIME NOT NULL,
  `updated` DATETIME NOT NULL,
  `trees` LONGTEXT NOT NULL,
  `talent_string` TEXT NOT NULL,
  `owner_hash` CHAR(64) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_updated` (`updated`),
  KEY `idx_class_spec` (`class_id`, `spec_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `lptm_classic` (
  `id` CHAR(36) NOT NULL,
  `name` VARCHAR(200) NOT NULL,
  `content` VARCHAR(120) NOT NULL DEFAULT '',
  `build_type` VARCHAR(120) NOT NULL DEFAULT '',
  `class_id` VARCHAR(32) NOT NULL DEFAULT '',
  `class_name` VARCHAR(64) NOT NULL DEFAULT '',
  `spec_id` VARCHAR(32) NOT NULL DEFAULT '',
  `spec_name` VARCHAR(64) NOT NULL DEFAULT '',
  `hero_id` VARCHAR(64) NOT NULL DEFAULT '',
  `hero_name` VARCHAR(64) NOT NULL DEFAULT '',
  `patch` VARCHAR(16) NOT NULL DEFAULT '',
  `created` DATETIME NOT NULL,
  `updated` DATETIME NOT NULL,
  `trees` LONGTEXT NOT NULL,
  `talent_string` TEXT NOT NULL,
  `owner_hash` CHAR(64) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_updated` (`updated`),
  KEY `idx_class_spec` (`class_id`, `spec_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `lptm_classic_era` (
  `id` CHAR(36) NOT NULL,
  `name` VARCHAR(200) NOT NULL,
  `content` VARCHAR(120) NOT NULL DEFAULT '',
  `build_type` VARCHAR(120) NOT NULL DEFAULT '',
  `class_id` VARCHAR(32) NOT NULL DEFAULT '',
  `class_name` VARCHAR(64) NOT NULL DEFAULT '',
  `spec_id` VARCHAR(32) NOT NULL DEFAULT '',
  `spec_name` VARCHAR(64) NOT NULL DEFAULT '',
  `hero_id` VARCHAR(64) NOT NULL DEFAULT '',
  `hero_name` VARCHAR(64) NOT NULL DEFAULT '',
  `patch` VARCHAR(16) NOT NULL DEFAULT '',
  `created` DATETIME NOT NULL,
  `updated` DATETIME NOT NULL,
  `trees` LONGTEXT NOT NULL,
  `talent_string` TEXT NOT NULL,
  `owner_hash` CHAR(64) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_updated` (`updated`),
  KEY `idx_class_spec` (`class_id`, `spec_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `lptm_anniversary` (
  `id` CHAR(36) NOT NULL,
  `name` VARCHAR(200) NOT NULL,
  `content` VARCHAR(120) NOT NULL DEFAULT '',
  `build_type` VARCHAR(120) NOT NULL DEFAULT '',
  `class_id` VARCHAR(32) NOT NULL DEFAULT '',
  `class_name` VARCHAR(64) NOT NULL DEFAULT '',
  `spec_id` VARCHAR(32) NOT NULL DEFAULT '',
  `spec_name` VARCHAR(64) NOT NULL DEFAULT '',
  `hero_id` VARCHAR(64) NOT NULL DEFAULT '',
  `hero_name` VARCHAR(64) NOT NULL DEFAULT '',
  `patch` VARCHAR(16) NOT NULL DEFAULT '',
  `created` DATETIME NOT NULL,
  `updated` DATETIME NOT NULL,
  `trees` LONGTEXT NOT NULL,
  `talent_string` TEXT NOT NULL,
  `owner_hash` CHAR(64) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_updated` (`updated`),
  KEY `idx_class_spec` (`class_id`, `spec_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
