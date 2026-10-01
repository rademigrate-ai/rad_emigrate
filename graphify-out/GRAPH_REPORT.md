# Graph Report - rad_emigrate  (2026-10-02)

## Corpus Check
- Corpus is ~35,912 words - fits in a single context window. You may not need a graph.

## Summary
- 1362 nodes · 1697 edges · 142 communities (85 shown, 57 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 26 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- macOS Storage Plugin Bridge
- Profile Management and State
- Application Repository Workflows
- Auth Repository Tests
- AI Response Model
- Linux Secure Storage Plugin
- API Client and Interceptors
- App Shell and Route Setup
- Application Detail Timeline
- Dashboard Data Integration
- Windows Native Type Bindings
- App Dependency Providers
- Authentication State Controller
- AI Assistant Chat Interface
- Application Remote Datasources
- Document Status Entities
- RAD Design System Colors
- Visa Program Browser
- Document Repository Layer
- Windows Desktop Window API
- Authentication Form Submission
- Login and OTP Forms
- Shared Text Field Widget
- Spacing and Size Tokens
- Profile Editing Flow
- Project 02 Architecture Rules
- Application Domain Status
- Local Persistence Datasources
- Supabase Auth Integration
- User Profile Entity
- Demo Auth Repository Fallback
- Auth Contract and Mock Repository
- RAD Brand Component
- App Environment Configuration
- Empty and Error States
- Document Repository Workflow
- Session Lifecycle Management
- Secure Session Token Storage
- API Exception Handling
- Project Architecture Roadmap
- Application Status Entities
- Supabase and Theme Configuration
- Error and Section Headers
- Login and OTP Navigation
- Authentication and App Pages
- Document Type and Status
- Session State Model
- Windows Flutter Embedder Types
- Status Badge Widget
- Profile Completion Form
- Project Foundation Contracts
- Shared Button Widget
- Progress Step Components
- Document Type Serialization
- Flutter Web App Metadata
- Router and Placeholder Pages
- API Response Wrapper
- Windows Desktop Window Lifecycle
- Windows Message Handling
- App Bootstrap and Widget Tests
- Loading State Widgets
- Profile Repository Operations
- Package and SDK Dependencies
- Shared App Card Widget
- Application Exception Hierarchy
- AI Request Model
- Section Card Widget
- Windows Plugin Registration
- Local Auth Session Storage
- Authentication Repository Interface
- Empty View Widget
- App Shell Navigation
- Remote Auth API
- Geometry Data Types
- AI Service Interface
- Environment Enum
- Local Document Storage
- Windows Runner Lifecycle
- Accessibility and UI Standards
- Document Repository Contract
- App Placeholder Component
- Clean Architecture Layers
- Mock Document Catalog
- Application Status Enum
- Linux Desktop Build Setup
- Android Main Activity
- RAD App Icon Mark
- Mock Application Records
- Windows Build Configuration
- Flutter Analyzer Rules
- RAD Logo Identity
- RAD Institute Branding
- Authentication Flow Navigation
- Feature Isolation Principles
- Repository Contracts and Mocks
- Project 01 Release Gate
- Project 03 Stabilization
- Immigration Portal Visual Language
- Cyan iOS App Icon
- Flutter App Launcher Icon
- Flutter Logo Asset
- Flutter Framework Icon
- Flutter Logo Icon Variant
- Web Manifest and Bootstrap
- Flutter Android Launcher
- RAD Launcher Mark
- Blue Geometric Launcher Icon
- Flutter Framework Branding
- Cyan App Icon Design
- Immutable Model Serialization
- Flutter Logo Asset Variant
- iOS App Icon 20px
- Blue Angular Icon Mark
- Blue and Cyan App Symbol
- Flutter iOS Icon Asset
- Blue Geometric Icon
- Folded Chevron App Icon
- Geometric App Icon Variant
- Flutter Icon Branding
- Flutter Logo App Icon
- Flutter iOS App Branding
- Flutter App Logo Variant
- Flutter Logo Artwork
- iOS Launch Screen
- Blank iOS Launch Asset
- iOS Launch Screen Variant
- Flutter Application Icon
- Small App Icon Asset
- RAD macOS Application Icon
- Flutter macOS Icon Variant
- Flutter Logo App Mark
- Blue Web Favicon
- Flutter Web App Icon
- Flutter Logo Icon Variant
- Maskable Flutter App Icon

## God Nodes (most connected - your core abstractions)
1. `Win32Window` - 24 edges
2. `authControllerProvider` - 19 edges
3. `MessageHandler` - 12 edges
4. `build` - 10 edges
5. `FlutterWindow` - 10 edges
6. `Create` - 10 edges
7. `WndProc` - 10 edges
8. `MessageHandler` - 9 edges
9. `_` - 8 edges
10. `ApiClient` - 7 edges

## Surprising Connections (you probably didn't know these)
- `Secure Token Storage` --semantically_similar_to--> `flutter_secure_storage Dependency`  [INFERRED] [semantically similar]
  docs/PROJECT02_IMPLEMENTATION.md → pubspec.yaml
- `iOS Launch Screen Assets` --conceptually_related_to--> `RAD Emigrate`  [INFERRED]
  ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md → README.md
- `_FakeAuthRepository` --implements--> `AuthRepository`  [EXTRACTED]
  test/core/session_manager_test.dart → lib/features/auth/domain/repositories/auth_repository.dart
- `Graphify-First Repository Navigation Policy` --references--> `RAD Emigrate`  [EXTRACTED]
  .github/copilot-instructions.md → README.md
- `Feature-First Clean Architecture` --references--> `Feature-First Clean Architecture`  [EXTRACTED]
  README.md → docs/architecture.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Presentation, Domain, Data, and External Services Layers** — docs_architecture_presentation_layer, docs_architecture_domain_layer, docs_architecture_data_layer, docs_architecture_external_services [EXTRACTED 1.00]
- **PROJECT 03 User Experience Journey** — docs_project03_uiux_completion_user_journey, docs_project03_uiux_completion_shared_design_system, docs_project03_uiux_completion_accessible_interactions [EXTRACTED 1.00]
- **PROJECT 01 Authentication Journey** — docs_project01_implementation_authentication_lifecycle, docs_project01_final_audit_app_bootstrap, docs_project01_final_audit_gorouter_ownership [INFERRED 0.85]

## Communities (142 total, 57 thin omitted)

### Community 0 - "macOS Storage Plugin Bridge"
Cohesion: 0.06
Nodes (17): app_links, Cocoa, Flutter, flutter_secure_storage_macos, FlutterMacOS, Foundation, AppDelegate, SceneDelegate (+9 more)

### Community 1 - "Profile Management and State"
Cohesion: 0.05
Nodes (30): ApplicationController, authenticated, copyWith, email, fullName, isAuthenticated, phone, profileComplete (+22 more)

### Community 2 - "Application Repository Workflows"
Cohesion: 0.05
Nodes (30): allowOfflineFallback, ApplicationRepositoryImpl, createApplication, _ensureLocal, getApplication, listApplications, local, remote (+22 more)

### Community 3 - "Auth Repository Tests"
Cohesion: 0.05
Nodes (18): AuthRemoteDataSource, main, main, main, main, main, completeProfile, loggedOut (+10 more)

### Community 4 - "AI Response Model"
Cohesion: 0.05
Nodes (34): AiResponse, AiSource, authority, conversationId, sources, text, title, uncertain (+26 more)

### Community 5 - "Linux Secure Storage Plugin"
Cohesion: 0.08
Nodes (14): fl_register_plugins(), main(), first_frame_cb(), my_application_activate(), my_application_class_init(), my_application_dispose(), my_application_init(), my_application_local_command_line() (+6 more)

### Community 6 - "API Client and Interceptors"
Cohesion: 0.07
Nodes (17): _config, _dio, _extractMessage, _mapDio, AuthInterceptor, onRequest, enabled, LoggingInterceptor (+9 more)

### Community 7 - "App Shell and Route Setup"
Cohesion: 0.08
Nodes (6): build, RadEmigrateApp, appRouterProvider, AuthRefreshNotifier, authRefreshNotifierProvider, ref

### Community 8 - "Application Detail Timeline"
Cohesion: 0.10
Nodes (15): VisaApplication, createState, _selected, _timeline, _tone, DashboardPage, Document, build (+7 more)

### Community 9 - "Dashboard Data Integration"
Cohesion: 0.10
Nodes (10): icon, label, onTap, value, HomePage, build, createState, dispose (+2 more)

### Community 10 - "Windows Native Type Bindings"
Cohesion: 0.12
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 11 - "App Dependency Providers"
Cohesion: 0.09
Nodes (17): apiClientProvider, appBootstrapProvider, appConfigProvider, auth, config, envName, fromAppConfig, fromName (+9 more)

### Community 12 - "Authentication State Controller"
Cohesion: 0.09
Nodes (19): _apiClientProvider, _appConfigProvider, applySession, authRepositoryProvider, completeProfile, config, current, envName (+11 more)

### Community 13 - "AI Assistant Chat Interface"
Cohesion: 0.10
Nodes (19): aiServiceProvider, AiAssistantPage, _AiAssistantPageState, build, _ChatMessage, _controller, createState, dispose (+11 more)

### Community 14 - "Application Remote Datasources"
Cohesion: 0.11
Nodes (14): ApiClient, ApplicationRemoteDataSource, _client, create, list, update, _client, DocumentRemoteDataSource (+6 more)

### Community 15 - "Document Status Entities"
Cohesion: 0.10
Nodes (19): aiSummary, copyWith, DocumentVerificationStatus, DocumentVerificationStatusX, fileUrl, fromJson, fromString, hashCode (+11 more)

### Community 16 - "RAD Design System Colors"
Cohesion: 0.10
Nodes (20): AppColors, background, border, borderSubtle, charcoal, darkRed, error, info (+12 more)

### Community 17 - "Visa Program Browser"
Cohesion: 0.11
Nodes (12): mockCategories, mockCountries, mockPrograms, build, createState, onBack, program, _ProgramDetail (+4 more)

### Community 18 - "Document Repository Layer"
Cohesion: 0.11
Nodes (16): DocumentRepositoryImpl, DocumentRepository, addPlaceholder, config, documentRepositoryProvider, _EmptyDocumentRepository, getDocument, getInstance (+8 more)

### Community 19 - "Windows Desktop Window API"
Cohesion: 0.16
Nodes (12): Scale(), Create, Destroy, SetQuitOnClose, Show, UpdateTheme, Win32Window::Win32Window(), WindowClassRegistrar (+4 more)

### Community 20 - "Authentication Form Submission"
Cohesion: 0.15
Nodes (11): _submit, build, _submit, build, _submit, build, authControllerProvider, build (+3 more)

### Community 21 - "Login and OTP Forms"
Cohesion: 0.12
Nodes (14): createState, dispose, _error, identifier, _otpCtrl, createState, dispose, _emailCtrl (+6 more)

### Community 22 - "Shared Text Field Widget"
Cohesion: 0.11
Nodes (13): autofillHints, build, controller, enabled, hint, keyboardType, label, maxLines (+5 more)

### Community 23 - "Spacing and Size Tokens"
Cohesion: 0.11
Nodes (15): AppSpacing, cardPadding, lg, md, page, radiusLg, radiusMd, radiusPill (+7 more)

### Community 24 - "Profile Editing Flow"
Cohesion: 0.12
Nodes (16): _controllersReady, createState, dispose, _editing, _email, _firstName, _formKey, _hydrate (+8 more)

### Community 25 - "Project 02 Architecture Rules"
Cohesion: 0.12
Nodes (15): AI Service Foundation, PlaceholderAiService, ApiClient Network Boundary, Preserved AuthRepository Contract, AuthRepositoryImpl with Remote and Local Datasources, AppConfig and APP_ENV Configuration, Non-Production Offline Demo Auth Fallback, PROJECT 02 Production Platform Foundation (+7 more)

### Community 26 - "Application Domain Status"
Cohesion: 0.12
Nodes (14): copyWith, country, createdAt, fromJson, hashCode, id, notes, operator (+6 more)

### Community 27 - "Local Persistence Datasources"
Cohesion: 0.14
Nodes (11): ApplicationLocalDataSource, _key, _prefs, readAll, writeAll, clear, _keyPrefix, _prefs (+3 more)

### Community 28 - "Supabase Auth Integration"
Cohesion: 0.12
Nodes (10): initialize, RadSupabaseClient, _client, login, logout, _mapSession, register, _requireClient (+2 more)

### Community 29 - "User Profile Entity"
Cohesion: 0.12
Nodes (14): avatar, copyWith, createdAt, email, firstName, fromJson, hashCode, id (+6 more)

### Community 30 - "Demo Auth Repository Fallback"
Cohesion: 0.13
Nodes (12): allowDemoFallback, completeProfile, _demoLogin, _demoOtp, _demoToken, local, login, logout (+4 more)

### Community 31 - "Auth Contract and Mock Repository"
Cohesion: 0.13
Nodes (13): AuthRepositoryImpl, completeProfile, _demoOtp, _demoToken, login, logout, MockAuthRepository, register (+5 more)

### Community 32 - "RAD Brand Component"
Cohesion: 0.14
Nodes (12): AppTextField, build, darkSurface, _FallbackMark, _height, label, RadBrand, RadBrandSize (+4 more)

### Community 33 - "App Environment Configuration"
Cohesion: 0.13
Nodes (13): apiBaseUrl, AppConfig, connectTimeout, development, enableLogging, environment, featureFlags, fromName (+5 more)

### Community 34 - "Empty and Error States"
Cohesion: 0.14
Nodes (11): actionLabel, build, EmptyState, icon, onAction, subtitle, title, build (+3 more)

### Community 35 - "Document Repository Workflow"
Cohesion: 0.14
Nodes (8): allowOfflineFallback, _ensureLocal, getDocument, listDocuments, local, remote, _seed, upsertDocument

### Community 36 - "Session Lifecycle Management"
Cohesion: 0.14
Nodes (10): _authRepository, clear, isAuthenticated, logout, restore, session, SessionManager, setAuthenticated (+2 more)

### Community 37 - "Secure Session Token Storage"
Cohesion: 0.14
Nodes (11): clear, _emailKey, _fullNameKey, getToken, getUserMeta, _phoneKey, saveToken, saveUserMeta (+3 more)

### Community 38 - "API Exception Handling"
Cohesion: 0.14
Nodes (12): cause, code, forbidden, fromStatusCode, message, network, notFound, server (+4 more)

### Community 39 - "Project Architecture Roadmap"
Cohesion: 0.15
Nodes (13): Graphify-First Repository Navigation Policy, Independent Feature Extensibility, Feature-First Clean Architecture, GoRouter Navigation, Riverpod State Management, Presentation Refinement with Architecture Preserved, iOS Launch Screen Assets, Feature-First Clean Architecture (+5 more)

### Community 40 - "Application Status Entities"
Cohesion: 0.17
Nodes (11): Application, ApplicationStatus, ApplicationStatusX, ColorStatus, country, id, notes, programName (+3 more)

### Community 41 - "Supabase and Theme Configuration"
Cohesion: 0.15
Nodes (9): _, anonKey, isConfigured, SupabaseConfig, url, AppTheme, dark, light (+1 more)

### Community 42 - "Error and Section Headers"
Cohesion: 0.15
Nodes (10): build, ErrorView, message, onRetry, actionLabel, build, onAction, SectionHeader (+2 more)

### Community 43 - "Login and OTP Navigation"
Cohesion: 0.17
Nodes (10): build, createState, dispose, _error, _formKey, _identifierCtrl, LoginPage, _LoginPageState (+2 more)

### Community 44 - "Authentication and App Pages"
Cohesion: 0.21
Nodes (10): ApplicationsPage, _ApplicationsPageState, build, applicationControllerProvider, OtpPage, _OtpPageState, RegisterPage, _RegisterPageState (+2 more)

### Community 45 - "Document Type and Status"
Cohesion: 0.18
Nodes (10): description, DocumentItem, DocumentStatus, DocumentStatusX, DocumentType, id, name, status (+2 more)

### Community 46 - "Session State Model"
Cohesion: 0.17
Nodes (9): copyWith, isAuthenticated, session, SessionState, SessionStatus, status, token, unauthenticated (+1 more)

### Community 47 - "Windows Flutter Embedder Types"
Cohesion: 0.17
Nodes (4): FlutterWindow, flutter_controller_, MessageHandler, project_

### Community 48 - "Status Badge Widget"
Cohesion: 0.18
Nodes (8): _bg, build, _fg, _icon, label, StatusBadge, StatusTone, tone

### Community 49 - "Profile Completion Form"
Cohesion: 0.20
Nodes (8): createState, dispose, _error, _formKey, _nameCtrl, _nationalityCtrl, ProfileCompletionPage, _ProfileCompletionPageState

### Community 50 - "Project Foundation Contracts"
Cohesion: 0.18
Nodes (9): AI Service Boundary for Future Integration, Application Bootstrap and Session Restoration, Centralized GoRouter Ownership, AI Service Integration Foundation, Authentication Lifecycle, Visa, Applications, Documents, and Profile Modules, PROJECT 01 Flutter Foundation, Responsive App Shell (+1 more)

### Community 51 - "Shared Button Widget"
Cohesion: 0.18
Nodes (10): AppButton, AppButtonVariant, build, expanded, icon, label, loading, onPressed (+2 more)

### Community 52 - "Progress Step Components"
Cohesion: 0.18
Nodes (10): build, isLast, label, ProgressStep, ProgressSteps, ProgressStepState, state, step (+2 more)

### Community 53 - "Document Type Serialization"
Cohesion: 0.20
Nodes (10): description, DocumentType, DocumentTypeKind, DocumentTypeKindX, fromJson, fromString, id, kind (+2 more)

### Community 54 - "Flutter Web App Metadata"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 55 - "Router and Placeholder Pages"
Cohesion: 0.20
Nodes (7): AppRoutes, build, home, login, onGenerateRoute, _PlaceholderPage, title

### Community 56 - "API Response Wrapper"
Cohesion: 0.20
Nodes (7): ApiResponse, data, fail, message, ok, statusCode, success

### Community 57 - "Windows Desktop Window Lifecycle"
Cohesion: 0.29
Nodes (8): OnCreate, Win32Window, child_content_, GetClientArea, OnCreate, quit_on_close_, SetChildContent, window_handle_

### Community 58 - "Windows Message Handling"
Cohesion: 0.36
Nodes (5): EnableFullDpiSupportIfAvailable(), GetHandle, GetThisFromHandle, MessageHandler, WndProc

### Community 59 - "App Bootstrap and Widget Tests"
Cohesion: 0.22
Nodes (3): initialize, main, main

### Community 60 - "Loading State Widgets"
Cohesion: 0.22
Nodes (6): build, LoadingState, message, build, LoadingView, message

### Community 61 - "Profile Repository Operations"
Cohesion: 0.22
Nodes (5): allowOfflineFallback, getProfile, local, remote, updateProfile

### Community 62 - "Package and SDK Dependencies"
Cohesion: 0.22
Nodes (9): Secure Token Storage, Dart SDK Constraint ^3.13.4, Dio Dependency, rad_emigrate Flutter Package, flutter_riverpod Dependency, flutter_secure_storage Dependency, go_router Dependency, shared_preferences Dependency (+1 more)

### Community 63 - "Shared App Card Widget"
Cohesion: 0.22
Nodes (7): AppCard, build, child, emphasized, margin, onTap, padding

### Community 64 - "Application Exception Hierarchy"
Cohesion: 0.28
Nodes (7): AppException, AuthException, code, message, NetworkException, toString, ApiException

### Community 65 - "AI Request Model"
Cohesion: 0.22
Nodes (7): AiRequest, AiRequestKind, conversationId, kind, locale, metadata, prompt

### Community 66 - "Section Card Widget"
Cohesion: 0.22
Nodes (8): build, child, icon, onTap, SectionCard, subtitle, title, trailing

### Community 68 - "Local Auth Session Storage"
Cohesion: 0.25
Nodes (6): SessionStorage, AuthLocalDataSource, clear, readSession, saveSession, _storage

### Community 69 - "Authentication Repository Interface"
Cohesion: 0.25
Nodes (6): completeProfile, login, logout, register, restoreSession, verifyOtp

### Community 70 - "Empty View Widget"
Cohesion: 0.25
Nodes (6): action, build, EmptyView, icon, subtitle, title

### Community 71 - "App Shell Navigation"
Cohesion: 0.25
Nodes (5): AppShell, build, child, _items, _selectedIndex

### Community 72 - "Remote Auth API"
Cohesion: 0.25
Nodes (7): _client, completeProfile, login, logout, _mapSession, register, verifyOtp

### Community 73 - "Geometry Data Types"
Cohesion: 0.21
Nodes (6): Point, x, y, Size, height, width

### Community 74 - "AI Service Interface"
Cohesion: 0.33
Nodes (4): AiService, ask, complete, PlaceholderAiService

### Community 75 - "Environment Enum"
Cohesion: 0.33
Nodes (5): AppEnvironment, AppEnvironmentX, isDevelopment, isProduction, isStaging

### Community 76 - "Local Document Storage"
Cohesion: 0.29
Nodes (5): DocumentLocalDataSource, _key, _prefs, readAll, writeAll

### Community 77 - "Windows Runner Lifecycle"
Cohesion: 0.29
Nodes (3): FlutterWindow::FlutterWindow(), OnDestroy, OnDestroy

### Community 78 - "Accessibility and UI Standards"
Cohesion: 0.40
Nodes (5): Accessible 48px Interactive Controls, PROJECT 03 UI/UX Production Experience Hardening, Responsive Navigation Shell, Shared RAD Design System, Semantic and Non-Color-Only Accessibility

### Community 79 - "Document Repository Contract"
Cohesion: 0.40
Nodes (3): getDocument, listDocuments, upsertDocument

### Community 80 - "App Placeholder Component"
Cohesion: 0.40
Nodes (3): AppPlaceholder, build, title

### Community 82 - "Clean Architecture Layers"
Cohesion: 0.50
Nodes (4): Data Layer, Domain Layer, External Services Layer, Presentation Layer

### Community 84 - "Application Status Enum"
Cohesion: 0.50
Nodes (3): ApplicationStatus, ApplicationStatusX, fromString

### Community 85 - "Linux Desktop Build Setup"
Cohesion: 0.50
Nodes (4): Linux Desktop Runner Configuration, GTK 3 Linux Runner Dependency, Linux Flutter Managed Build Rules, Linux rad_emigrate Executable

### Community 87 - "RAD App Icon Mark"
Cohesion: 0.67
Nodes (3): White R monogram, Rad Emigrate logo mark, Red rounded-square icon background

### Community 90 - "Windows Build Configuration"
Cohesion: 1.00
Nodes (3): Windows Desktop Runner Configuration, Windows Flutter Managed Build Rules, Windows rad_emigrate Executable

## Knowledge Gaps
- **745 isolated node(s):** `appConfigProvider`, `envName`, `secureStorageProvider`, `sessionStorageProvider`, `networkConfigProvider` (+740 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 921 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **57 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `VisaApplication` connect `Application Detail Timeline` to `Application Domain Status`?**
  _High betweenness centrality (0.051) - this node is a cross-community bridge._
- **Why does `Document` connect `Application Detail Timeline` to `Document Status Entities`?**
  _High betweenness centrality (0.043) - this node is a cross-community bridge._
- **Why does `ApiClient` connect `Application Remote Datasources` to `Remote Auth API`, `App Dependency Providers`, `Authentication State Controller`, `API Client and Interceptors`?**
  _High betweenness centrality (0.032) - this node is a cross-community bridge._
- **What connects `appConfigProvider`, `envName`, `secureStorageProvider` to the rest of the system?**
  _745 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `macOS Storage Plugin Bridge` be split into smaller, more focused modules?**
  _Cohesion score 0.05647840531561462 - nodes in this community are weakly interconnected._
- **Should `Profile Management and State` be split into smaller, more focused modules?**
  _Cohesion score 0.05365853658536585 - nodes in this community are weakly interconnected._
- **Should `Application Repository Workflows` be split into smaller, more focused modules?**
  _Cohesion score 0.0524390243902439 - nodes in this community are weakly interconnected._