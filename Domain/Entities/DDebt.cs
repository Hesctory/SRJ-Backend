namespace SRJBackend.Domain.Entities;

public class DDebt
{
    public long Id { get; private set; }
    public int EnrollmentId { get; private set; }
    public string Description { get; private set; }
    public decimal BalanceDue { get; private set; }
    public DebtStatus Status { get; private set; }
    public DateOnly DueDate { get; private set; }

    public bool IsPayable =>
        Status is DebtStatus.Pending or DebtStatus.PartiallyPaid or DebtStatus.Overdue
        && BalanceDue > 0;

    public decimal ApplyPayment(decimal available)
    {
        if (available <= 0 || !IsPayable) return 0;
        var applied = Math.Min(available, BalanceDue);
        BalanceDue -= applied;
        Status = BalanceDue == 0 ? DebtStatus.Paid : DebtStatus.PartiallyPaid;
        return applied;
    }

    internal static DDebt Reconstitute(
        long id, int enrollmentId, string description,
        decimal balanceDue, DebtStatus status, DateOnly dueDate)
        => new(id, enrollmentId, description, balanceDue, status, dueDate);

    private DDebt(long id, int enrollmentId, string description,
        decimal balanceDue, DebtStatus status, DateOnly dueDate)
    {
        Id = id;
        EnrollmentId = enrollmentId;
        Description = description;
        BalanceDue = balanceDue;
        Status = status;
        DueDate = dueDate;
    }
}
