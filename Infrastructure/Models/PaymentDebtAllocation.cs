using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class PaymentDebtAllocation
{
    public long Id { get; set; }

    public int PaymentId { get; set; }

    public long DebtId { get; set; }

    public decimal AmountApplied { get; set; }

    public DateTime AllocatedAt { get; set; }

    public string? Notes { get; set; }

    public virtual EnrollmentDebt Debt { get; set; } = null!;

    public virtual Payment Payment { get; set; } = null!;
}
