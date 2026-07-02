# Task 1: Delete Tenant Frontend Feature Folder

**Files:**
- Delete: `residex_app/lib/features/tenant/` (entire folder, 64 .dart files)
- Modify: `residex_app/lib/main.dart` (remove tenant route/navigation)
- Modify: `residex_app/pubspec.yaml` (if tenant-specific deps exist, remove)

**Interfaces:**
- Consumes: None (deletion only)
- Produces: Frontend still boots, landlord routes work, no tenant screens accessible

- [ ] **Step 1: Backup tenant folder (safety)**

```bash
cd residex_app
mv lib/features/tenant lib/features/tenant.backup
```

- [ ] **Step 2: Check main.dart for tenant route registration**

Run: `grep -n "tenant" lib/main.dart`

Expected output: Any lines referencing tenant navigation. Note them.

- [ ] **Step 3: Remove tenant routes from main.dart**

If main.dart has GoRouter or navigation setup with tenant routes, remove those lines. Example:

```dart
// DELETE this section if it exists:
GoRoute(
  path: '/tenant',
  builder: (context, state) => TenantScreen(),
)
```

- [ ] **Step 4: Check pubspec.yaml for tenant-specific packages**

Run: `grep -i "tenant\|expense\|maintenance_request" pubspec.yaml`

Expected: May be empty (tenant deps likely shared). If matches, remove only those specific deps.

- [ ] **Step 5: Run flutter pub get to verify no broken imports**

```bash
flutter pub get
```

Expected: Completes without "Missing packages" errors.

- [ ] **Step 6: Run flutter analyze to check for unused imports**

```bash
flutter analyze
```

Expected: No errors related to tenant imports. Warnings OK at this stage.

- [ ] **Step 7: Permanently delete tenant.backup folder**

```bash
rm -rf lib/features/tenant.backup
```

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: remove tenant feature from frontend"
```
