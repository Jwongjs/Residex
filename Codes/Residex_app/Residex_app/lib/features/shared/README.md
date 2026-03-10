# Shared Features

This folder contains features accessible to both landlords and tenants:

- **Bills** - Bill splitting and expense tracking with OCR
- **Maintenance** - Maintenance ticket system with SLA tracking
- **Scores** - Dual Score System (Fiscal + Harmony scores)
- **Community** - Community board for announcements and discussions
- **Property** - Property and group management
- **Rex AI**
  - **Lease Sentinel** - AI-powered contract analysis (RM15-30/month value)
  - **DocuMind** - Document Q&A assistant (RM29-49/month value)

## Architecture
Each feature follows Clean Architecture:
- domain/entities/ - Business entities
- domain/repositories/ - Repository interfaces
- data/datasources/ - Data sources (local/remote)
- data/repositories/ - Repository implementations
- presentation/providers/ - State management (Riverpod)
- presentation/screens/ - Screen widgets
- presentation/widgets/ - Reusable UI components
