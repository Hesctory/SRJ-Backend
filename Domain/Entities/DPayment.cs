using SRJBackend.Domain.Exceptions;

namespace SRJBackend.Domain.Entities;

public class DPayment
{
    public int EnrollmentId { get; private set; }
    public int PaymentMethodId { get; private set; }
    public DateOnly Date { get; private set; }
    public decimal Amount { get; private set; }
    public string? NOperation { get; private set; }
    public IReadOnlyList<DPaymentLine> Lines { get; private set; }
    public decimal TotalAllocated { get; private set; }
    public decimal Change { get; private set; }

    public static DPayment Allocate(
        int enrollmentId,
        int paymentMethodId,
        DateOnly date,
        decimal amount,
        string? nOperation,
        IEnumerable<DDebt> debts)
    {
        if (amount <= 0)
            throw new DomainException("El monto debe ser mayor a cero.");

        var lines = new List<DPaymentLine>();
        var remaining = amount;

        foreach (var debt in debts.OrderBy(d => d.DueDate))
        {
            if (remaining <= 0) break;
            var applied = debt.ApplyPayment(remaining);
            if (applied <= 0) continue;
            remaining -= applied;
            lines.Add(new DPaymentLine(debt.Id, debt.Description, applied, debt.BalanceDue, debt.Status));
        }

        if (lines.Count == 0)
            throw new DomainException("No se encontraron deudas pendientes para esta matrícula.");

        return new DPayment(enrollmentId, paymentMethodId, date, amount, nOperation,
            lines, amount - remaining, remaining);
    }

    internal static DPayment Reconstitute(
        int enrollmentId, int paymentMethodId, DateOnly date, decimal amount,
        string? nOperation, List<DPaymentLine> lines, decimal totalAllocated, decimal change)
        => new(enrollmentId, paymentMethodId, date, amount, nOperation, lines, totalAllocated, change);

    private DPayment(
        int enrollmentId, int paymentMethodId, DateOnly date, decimal amount,
        string? nOperation, List<DPaymentLine> lines, decimal totalAllocated, decimal change)
    {
        EnrollmentId = enrollmentId;
        PaymentMethodId = paymentMethodId;
        Date = date;
        Amount = amount;
        NOperation = nOperation;
        Lines = lines.AsReadOnly();
        TotalAllocated = totalAllocated;
        Change = change;
    }
}
