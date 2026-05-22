using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class SchoolYearMonth
{
    public int Id { get; set; }

    public int SchoolYearId { get; set; }

    public short Month { get; set; }

    public DateOnly BillingOpenDate { get; set; }

    public DateOnly DueDate { get; set; }

    public bool IsActive { get; set; }

    public virtual SchoolYear SchoolYear { get; set; } = null!;
}
