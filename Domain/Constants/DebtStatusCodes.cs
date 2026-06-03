using SRJBackend.Domain.Entities;
using SRJBackend.Domain.Exceptions;

namespace SRJBackend.Domain.Constants;

public static class DebtStatusCodes
{
    public const string Pending = "PENDING";
    public const string PartiallyPaid = "PARTIALLY_PAID";
    public const string Paid = "PAID";
    public const string Overdue = "OVERDUE";

    public static DebtStatus ToEnum(string code) => code switch
    {
        Pending      => DebtStatus.Pending,
        PartiallyPaid => DebtStatus.PartiallyPaid,
        Paid         => DebtStatus.Paid,
        Overdue      => DebtStatus.Overdue,
        _            => throw new DomainException($"Estado de deuda desconocido: {code}")
    };

    public static string FromEnum(DebtStatus status) => status switch
    {
        DebtStatus.Pending       => Pending,
        DebtStatus.PartiallyPaid => PartiallyPaid,
        DebtStatus.Paid          => Paid,
        DebtStatus.Overdue       => Overdue,
        _                        => throw new DomainException($"Estado de deuda desconocido: {status}")
    };
}
