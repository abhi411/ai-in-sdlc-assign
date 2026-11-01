using InvoiceApp.Domain;
using NetArchTest.Rules;
using Xunit;

namespace InvoiceApp.Tests;

/// <summary>
/// Structural rule from AGENTS.md: "InvoiceApp.Domain: business rules, no web or storage code."
/// Today this protects the Domain from drifting; after persistence and PayEx arrive it keeps
/// SQL and HTTP details in the Api/Infrastructure side.
/// </summary>
public class ArchitectureTests
{
    private static readonly System.Reflection.Assembly DomainAssembly = typeof(ApprovalService).Assembly;

    [Fact]
    public void Domain_DoesNotDependOnApiWebStorageOrHttpCode()
    {
        var result = Types.InAssembly(DomainAssembly)
            .ShouldNot()
            .HaveDependencyOnAny(
                "InvoiceApp.Api",
                "Microsoft.AspNetCore",
                "Microsoft.EntityFrameworkCore",
                "Microsoft.Data.SqlClient",
                "System.Data.SqlClient",
                "System.Net.Http")
            .GetResult();

        var offenders = string.Join(", ", result.FailingTypeNames ?? Array.Empty<string>());
        Assert.True(result.IsSuccessful,
            "InvoiceApp.Domain must not depend on web, storage or HTTP code. Offending types: " + offenders);
    }
}
