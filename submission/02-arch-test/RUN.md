# Architecture test: how to run it

Rule: InvoiceApp.Domain must not depend on InvoiceApp.Api, ASP.NET Core, EF Core, SQL client libraries or System.Net.Http.
Why this rule: AGENTS.md says Domain has "no web or storage code"; Domain.csproj has no references today (verified), so the rule is TRUE now; and it is the rule most at risk once PayEx and Azure SQL code is added.

## Status: EXECUTED
The rule was run in the repo and the real outputs were captured.

## Final command to hand in
dotnet test backend/InvoiceApp.sln --filter "FullyQualifiedName~ArchitectureTests"

## Real results
- Pass result: 1 passed, 0 failed.
- Fail proof result: compile failed with CS0116 because the sabotage field was placed at namespace scope instead of inside class Invoice. This was a minimal placement error, not a problem with the architecture rule itself.
- Full suite result after the revert and after adding the concurrency evidence test: 9 passed, 0 failed.

## Minimal fix for compile issues
If the sabotage field is inserted outside the class, the compiler reports:
`CS0116: A namespace cannot directly contain members such as fields, methods or statements.`
The minimal fix is to move `private static readonly System.Net.Http.HttpClient Sneaky = new();` inside the `Invoice` class, then revert it immediately after recording the failing proof.

## Steps (run in the repo root)
1. cp submission/02-arch-test/ArchitectureTests.cs backend/tests/InvoiceApp.Tests/ArchitectureTests.cs
2. dotnet add backend/tests/InvoiceApp.Tests/InvoiceApp.Tests.csproj package NetArchTest.Rules
3. Run only this test (the command to hand in):
   dotnet test backend/InvoiceApp.sln --filter "FullyQualifiedName~ArchitectureTests"
   Real result: Passed: 1, Failed: 0.
4. Prove it can fail: add this field inside class Invoice in backend/src/InvoiceApp.Domain/Invoice.cs
   private static readonly System.Net.Http.HttpClient Sneaky = new();
   and re-run the same command. Real result: compile failure CS0116 if placed at namespace scope; the correct placement is inside the class.
5. Revert the added field immediately after saving the fail output.
6. Save both outputs (pass and fail) as 02-arch-test/pass.txt and 02-arch-test/fail.txt.
7. Run the full suite once: dotnet test backend/InvoiceApp.sln

## Alternative rule if you prefer one about controllers
A rule "controllers must not depend on InMemoryInvoiceRepository" is true today (InvoicesController injects IInvoiceRepository). A rule "controllers must not use IInvoiceRepository" is FALSE today because InvoicesController does exactly that (InvoicesController.cs lines 11-18); do not pick it unless you also fix the code.
