using SRJBackend.Domain.Constants;
using SRJBackend.Domain.Exceptions;

namespace SRJBackend.Domain.Entities;

public class DDebt
{
    public long Id { get; private set; }
    public int EnrollmentId { get; private set; }
    public string Description { get; private set; }
    public decimal BalanceDue { get; private set; }
    public DebtStatus Status { get; private set; }
    public DateOnly DueDate { get; private set; }

    // Fields below are only populated for newly-created debts (via Create) and are
    // used by the repository when persisting. They stay at defaults on the payment
    // read path (Reconstitute), which never needs them.
    public int StudentId { get; private set; }
    public int SchoolYearId { get; private set; }
    public string ChargeTypeCode { get; private set; } = "";
    public decimal Amount { get; private set; }
    public short? PeriodMonth { get; private set; }

    /// <summary>
    /// Creates a brand-new, unpaid debt to be persisted. Status is derived from the due
    /// date relative to <paramref name="asOf"/> (OVERDUE if already past, else PENDING),
    /// mirroring <c>database/backfill_enrollment_debts.sql</c>.
    /// </summary>
    public static DDebt Create(
        int studentId, int enrollmentId, int schoolYearId, string chargeTypeCode,
        decimal amount, string description, DateOnly dueDate, short? periodMonth, DateOnly asOf)
    {
        if (amount <= 0)
            throw new DomainException("El monto de la deuda debe ser mayor a cero.");

        if (chargeTypeCode == ChargeTypeCodes.Tuition && periodMonth is null)
            throw new DomainException("Las deudas de pensión requieren un mes (period_month).");

        if (chargeTypeCode != ChargeTypeCodes.Tuition && periodMonth is not null)
            throw new DomainException("Solo las deudas de pensión pueden tener un mes (period_month).");

        var status = dueDate < asOf ? DebtStatus.Overdue : DebtStatus.Pending;

        return new DDebt(0, enrollmentId, description, amount, status, dueDate)
        {
            StudentId = studentId,
            SchoolYearId = schoolYearId,
            ChargeTypeCode = chargeTypeCode,
            Amount = amount,
            PeriodMonth = periodMonth,
        };
    }

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
