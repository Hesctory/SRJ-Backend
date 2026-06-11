using SRJBackend.Domain.Exceptions;

namespace SRJBackend.Domain.Entities;

public class DLunchAssignment
{
    public int Id { get; private set; }
    public int PersonId { get; private set; }
    public int? EnrollmentId { get; private set; }
    public int LunchId { get; private set; }
    public string? LunchName { get; private set; }
    public DateOnly AssignedDate { get; private set; }
    public decimal UnitPrice { get; private set; }
    public int? AssignedById { get; private set; }
    public bool HasDebt { get; private set; }
    public bool IsSettled { get; private set; }
    public decimal? DebtPaidAmount { get; private set; }
    public DateOnly? DebtPaidDate { get; private set; }

    public decimal BalanceDue =>
        HasDebt && !IsSettled ? UnitPrice - (DebtPaidAmount ?? 0m) : 0m;

    public bool IsPayable => HasDebt && !IsSettled && BalanceDue > 0;

    public static DLunchAssignment Create(
        int personId, int? enrollmentId, int lunchId,
        DateOnly assignedDate, decimal unitPrice, int? assignedById, bool isPaid)
    {
        if (personId <= 0)
            throw new ArgumentException("La persona indicada no es válida.");
        if (lunchId <= 0)
            throw new ArgumentException("El almuerzo indicado no es válido.");
        if (assignedDate == default)
            throw new ArgumentException("La fecha de asignación es obligatoria.");
        if (unitPrice <= 0)
            throw new DomainException("El precio del almuerzo debe ser mayor a cero.");

        return new DLunchAssignment(
            id: 0, personId, enrollmentId, lunchId, lunchName: null,
            assignedDate, unitPrice, assignedById,
            hasDebt: !isPaid, isSettled: false,
            debtPaidAmount: null, debtPaidDate: null);
    }

    public decimal ApplyPayment(decimal available, DateOnly paymentDate)
    {
        if (available <= 0 || !IsPayable) return 0;
        var applied = Math.Min(available, BalanceDue);
        DebtPaidAmount = (DebtPaidAmount ?? 0m) + applied;
        DebtPaidDate = paymentDate;
        IsSettled = DebtPaidAmount >= UnitPrice;
        return applied;
    }

    internal static DLunchAssignment Reconstitute(
        int id, int personId, int? enrollmentId, int lunchId, string? lunchName,
        DateOnly assignedDate, decimal unitPrice, int? assignedById,
        bool hasDebt, bool isSettled, decimal? debtPaidAmount, DateOnly? debtPaidDate)
        => new(id, personId, enrollmentId, lunchId, lunchName,
            assignedDate, unitPrice, assignedById,
            hasDebt, isSettled, debtPaidAmount, debtPaidDate);

    private DLunchAssignment(
        int id, int personId, int? enrollmentId, int lunchId, string? lunchName,
        DateOnly assignedDate, decimal unitPrice, int? assignedById,
        bool hasDebt, bool isSettled, decimal? debtPaidAmount, DateOnly? debtPaidDate)
    {
        Id = id;
        PersonId = personId;
        EnrollmentId = enrollmentId;
        LunchId = lunchId;
        LunchName = lunchName;
        AssignedDate = assignedDate;
        UnitPrice = unitPrice;
        AssignedById = assignedById;
        HasDebt = hasDebt;
        IsSettled = isSettled;
        DebtPaidAmount = debtPaidAmount;
        DebtPaidDate = debtPaidDate;
    }
}
