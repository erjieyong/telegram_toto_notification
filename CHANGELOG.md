# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - 2025-10-05

### Added
- Improve Dockerfile deployment
- Added deploy.sh for automated deployment process

## [0.2.0] - 2025-10-05

### Added
- Support for multiple Telegram chat IDs (comma-separated) in the `CHAT_ID` environment variable
- Individual error handling for each chat ID with success/failure tracking
- Comprehensive logging for message delivery status per chat
- Summary reporting of successful and failed message sends

### Changed
- Enhanced `send_notification()` function to parse and iterate through multiple chat IDs
- Improved error handling to continue sending to other chat IDs even if one fails

## [0.1.0] - 2025-02-02

### Added
- Initial AWS Lambda deployment with Chrome and Selenium web scraping
- Automated TOTO jackpot prize monitoring from Singapore Pools website
- Telegram bot integration for prize notifications
- Configurable prize threshold via `PRIZE_THRESHOLD` environment variable
- Lambda handler function for serverless execution
- Headless Chrome configuration optimized for AWS Lambda environment
- Docker configuration for Lambda deployment
- WebDriverWait implementation for reliable page element loading
- Helper function `get_chat_id()` for retrieving Telegram chat IDs

### Changed
- Migrated from BeautifulSoup4 to Selenium + Chrome for web scraping due to reliability issues
- Restructured project for AWS Lambda deployment
- Updated dependencies to support Selenium-based scraping

### Removed
- BeautifulSoup4 dependency in favor of Selenium

## Initial Development

### 2025-01-10
- Initial project setup and requirements
- Basic web scraping implementation
- Telegram notification system foundation
