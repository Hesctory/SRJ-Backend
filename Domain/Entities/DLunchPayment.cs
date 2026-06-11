using SRJBackend.Domain.Exceptions;

namespace SRJBackend.Domain.Entities;

public class DLunchPayment
{
    public int PersonId { get; private set; }
    public DateOnly Date { get; private set; }
    public decimal Amount { get; private set; }
    public IReadOnlyList<DLunchPaymentLine> Lines { get; private set; }
    public decimal TotalAllocated { get; private set; }
    public decimal Change { get; private set; }

    public static DLunchPayment Allocate(
        int personId,
        DateOnly date,
        decimal amount,
        IEnumerable<DLunchAssignment> assignments)
    {
        if (amount <= 0)
            throw new DomainException("El monto debe ser mayor a cero.");

        var lines = new List<DLunchPaymentLine>();
        var remaining = amount;

        foreach (var assignment in assignments.OrderBy(a => a.AssignedDate).ThenBy(a => a.Id))
        {
            if (remaining <= 0) break;
            var applied = assignment.ApplyPayment(remaining, date);
            if (applied <= 0) continue;
            remaining -= applied;
            lines.Add(new DLunchPaymentLine(
                assignment.Id, assignment.AssignedDate, assignment.LunchName,
                applied, assignment.BalanceDue, assignment.IsSettled));
        }

        if (lines.Count == 0)
            throw new DomainException("La persona no tiene deudas de almuerzo pendientes.");

        return new DLunchPayment(personId, date, amount, lines, amount - remaining, remaining);
    }

    private DLunchPayment(
        int personId, DateOnly date, decimal amount,
        List<DLunchPaymentLine> lines, decimal totalAllocated, decimal change)
    {
        PersonId = personId;
        Date = date;
        Amount = amount;
        Lines = lines.AsReadOnly();
        TotalAllocated = totalAllocated;
        Change = change;
    }
}
