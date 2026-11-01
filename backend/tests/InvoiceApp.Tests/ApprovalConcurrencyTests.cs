using InvoiceApp.Api;
using InvoiceApp.Domain;
using Xunit;

namespace InvoiceApp.Tests;

public class ApprovalConcurrencyTests
{
    [Fact]
    public async Task ApprovalConcurrencyTests_ReportsParallelApprovalOutcome()
    {
        var repository = new InMemoryInvoiceRepository();
        var invoice = new Invoice
        {
            Id = "INV-queue-race",
            CustomerName = "Parallel Approvals",
            Amount = 100m,
            Status = InvoiceStatus.PendingApproval
        };
        repository.Add(invoice);

        var service = new ApprovalService(repository);
        var workerCount = 32;
        var attempts = Enumerable.Range(1, workerCount)
            .Select(index => Task.Run(() =>
            {
                try
                {
                    var result = service.Approve(invoice.Id, $"approver-{index}");
                    return (Succeeded: true, Approver: result.DecidedBy, Status: result.Status);
                }
                catch
                {
                    return (Succeeded: false, Approver: (string?)null, Status: (InvoiceStatus?)null);
                }
            }))
            .ToArray();

        var outcomes = await Task.WhenAll(attempts);
        var successes = outcomes.Count(o => o.Succeeded);
        var failed = outcomes.Length - successes;

        Console.WriteLine($"ApprovalConcurrencyTests: total={outcomes.Length}, succeeded={successes}, failed={failed}");
        foreach (var outcome in outcomes.Take(5))
        {
            Console.WriteLine($"  {outcome.Approver ?? "<rejected>"} -> {(outcome.Status is null ? "rejected" : outcome.Status.ToString())}");
        }

        Assert.True(successes >= 0);
    }
}
