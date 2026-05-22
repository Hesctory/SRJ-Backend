using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class VOverdueDebt
{
    public long? DebtId { get; set; }

    public int? StudentId { get; set; }

    public int? EnrollmentId { get; set; }

    public int? SchoolYearId { get; set; }

    public string? ChargeTypeCode { get; set; }

    public string? ChargeTypeName { get; set; }

    public decimal? AmountCharged { get; set; }

    public decimal? TotalPaid { get; set; }

    public decimal? BalanceDue { get; set; }

    public DateOnly? DueDate { get; set; }

    public short? PeriodMonth { get; set; }

    public short? SchoolYear { get; set; }

    public string? StatusCode { get; set; }

    public string? StatusName { get; set; }

    public string? Description { get; set; }

    public string? Notes { get; set; }

    public DateTime? CreatedAt { get; set; }

    public DateTime? UpdatedAt { get; set; }

    public int? DaysOverdue { get; set; }
}
