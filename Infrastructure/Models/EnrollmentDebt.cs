using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class EnrollmentDebt
{
    public long Id { get; set; }

    public int StudentId { get; set; }

    public int EnrollmentId { get; set; }

    public int SchoolYearId { get; set; }

    public short ChargeTypeId { get; set; }

    public decimal Amount { get; set; }

    public string? Description { get; set; }

    public DateOnly DueDate { get; set; }

    public short? PeriodMonth { get; set; }

    public short StatusId { get; set; }

    public string? Notes { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime UpdatedAt { get; set; }

    public int? CreatedBy { get; set; }

    public virtual ChargeType ChargeType { get; set; } = null!;

    public virtual User? CreatedByNavigation { get; set; }

    public virtual Enrollment Enrollment { get; set; } = null!;

    public virtual ICollection<PaymentDebtAllocation> PaymentDebtAllocations { get; set; } = new List<PaymentDebtAllocation>();

    public virtual SchoolYear SchoolYear { get; set; } = null!;

    public virtual DebtStatus Status { get; set; } = null!;

    public virtual Student Student { get; set; } = null!;
}
