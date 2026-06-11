using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class LunchAssignment
{
    public int Id { get; set; }

    public int? EnrollmentId { get; set; }

    public int PersonId { get; set; }

    public int LunchId { get; set; }

    public DateOnly AssignedDate { get; set; }

    public decimal UnitPrice { get; set; }

    public int? AssignedById { get; set; }

    public bool HasDebt { get; set; }

    public bool IsSettled { get; set; }

    public decimal? DebtPaidAmount { get; set; }

    public DateOnly? DebtPaidDate { get; set; }

    public virtual User? AssignedBy { get; set; }

    public virtual Enrollment? Enrollment { get; set; }

    public virtual Lunch Lunch { get; set; } = null!;

    public virtual Person Person { get; set; } = null!;
}
