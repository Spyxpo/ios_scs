# Changelog

All notable changes to the SCS iOS SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-12-20

### Added
- Initial release of SCS iOS SDK
- Authentication module with register, login, logout, and profile management
- Auth state observation via Combine publishers
- Database module with document CRUD operations and subcollections
- Query builder with filters, ordering, and pagination
- Storage module with data and URL-based file upload
- File download, listing, and management
- Realtime Database with WebSocket synchronization
- Cloud Messaging for push notifications with APNS token support
- Topic subscription and management
- Remote Configuration for dynamic app settings
- Cloud Functions invocation with HttpsCallable support
- Machine Learning APIs for text recognition (OCR) and image labeling
- AI Services for chat, completion, and image generation
- Fluent Chat Builder API

### Features
- Swift-first async/await API design
- Combine framework integration for reactive programming
- Cross-platform support (iOS, macOS, tvOS, watchOS)
- Swift Package Manager distribution
- ScsError enum for typed error handling
- Singleton pattern with shared instance
