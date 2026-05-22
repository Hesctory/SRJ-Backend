using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class Payment
{
    public int Id { get; set; }

    public DateOnly PaymentDate { get; set; }

    public decimal? Amount { get; set; }

    public int PaymentMethodId { get; set; }

    public string? NOperation { get; set; }

    public int? CreatedBy { get; set; }

    public string? Notes { get; set; }

    public bool IsVoided { get; set; }

    public DateTime? VoidedAt { get; set; }

    public int? VoidedBy { get; set; }

    public DateTime CreatedAt { get; set; }

    public virtual User? CreatedByNavigation { get; set; }

    public virtual ICollection<PaymentDebtAllocation> PaymentDebtAllocations { get; set; } = new List<PaymentDebtAllocation>();

    public virtual PaymentMethod PaymentMethod { get; set; } = null!;

    public virtual User? VoidedByNavigation { get; set; }
}
