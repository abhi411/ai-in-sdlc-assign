#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

check() {
  local label="$1"
  shift
  echo "== $label =="
  "$@"
  echo
}

check "E1" grep -nE 'api\(|decide\(|sessionStorage' backend/src/InvoiceApp.Api/wwwroot/app.js
check "E2" grep -nE 'WebApplication\.CreateBuilder' backend/src/InvoiceApp.Api/Program.cs
check "E3" grep -nE 'UseDefaultFiles|UseStaticFiles' backend/src/InvoiceApp.Api/Program.cs
check "E4" grep -nE 'SessionAuthMiddleware|StatusCodes\.Status401Unauthorized|StartsWithSegments\("/api"\)' backend/src/InvoiceApp.Api/Auth/SessionAuthMiddleware.cs backend/src/InvoiceApp.Api/Program.cs
check "E5" grep -nE 'SessionStore|Create\(|Get\(|Remove\(|AddSingleton<SessionStore>' backend/src/InvoiceApp.Api/Auth/SessionStore.cs backend/src/InvoiceApp.Api/Program.cs
check "E6" grep -nE 'RequireRoleAttribute|OnActionExecuting|Status403Forbidden' backend/src/InvoiceApp.Api/Auth/RequireRoleAttribute.cs
check "E7" grep -nE 'class AuthController|Login\(|Logout\(' backend/src/InvoiceApp.Api/Controllers/AuthController.cs
check "E7a" grep -nE 'DemoUsersOptions|DemoUser|Configure<DemoUsersOptions>|Users' backend/src/InvoiceApp.Api/Program.cs backend/src/InvoiceApp.Api/Auth/UserSession.cs backend/src/InvoiceApp.Api/appsettings.json
check "E8" grep -nE 'class InvoicesController|GetAll\(|GetById\(|Create\(|Submit\(|Delete\(|RequireRole\("Admin"\)' backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs
check "E9" grep -nE 'class ApprovalsController|RequireRole\("Approver", "Admin"\)|Approve\(|Reject\(' backend/src/InvoiceApp.Api/Controllers/ApprovalsController.cs
check "E10" grep -nE 'class ApiControllerBase|Handle\(|NotFound\(|Conflict\(|BadRequest\(' backend/src/InvoiceApp.Api/Controllers/ApiControllerBase.cs
check "E11" grep -nE 'class ApprovalService|Submit\(|Approve\(|Reject\(|EnsurePending\(' backend/src/InvoiceApp.Domain/ApprovalService.cs
check "E12" grep -nE 'interface IInvoiceRepository' backend/src/InvoiceApp.Domain/IInvoiceRepository.cs
check "E13" grep -nE 'class InMemoryInvoiceRepository|AddSingleton<IInvoiceRepository|lock \(_lock\)|Seeded with a few invoices' backend/src/InvoiceApp.Api/InMemoryInvoiceRepository.cs backend/src/InvoiceApp.Api/Program.cs
check "E14" grep -nE 'class Invoice|enum InvoiceStatus' backend/src/InvoiceApp.Domain/Invoice.cs backend/src/InvoiceApp.Domain/InvoiceStatus.cs
check "E15" grep -nE 'class DiscountCalculator' backend/src/InvoiceApp.Domain/DiscountCalculator.cs
check "E16" grep -nE 'class ApprovalServiceTests|class FakeInvoiceRepository' backend/tests/InvoiceApp.Tests/ApprovalServiceTests.cs backend/tests/InvoiceApp.Tests/FakeInvoiceRepository.cs
check "E17" grep -nE 'build-and-test|dotnet build|dotnet test' .github/workflows/ci.yml
check "E18" grep -nE 'defineConfig|\.gitkeep' e2e/playwright.config.ts e2e/tests/.gitkeep
check "E19" grep -nE 'ProjectReference' backend/src/InvoiceApp.Api/InvoiceApp.Api.csproj backend/tests/InvoiceApp.Tests/InvoiceApp.Tests.csproj backend/src/InvoiceApp.Domain/InvoiceApp.Domain.csproj
