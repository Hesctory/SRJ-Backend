using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class Lunch
{
    public int Id { get; set; }

    public int LunchCategoryId { get; set; }

    public string? LunchName { get; set; }

    public decimal? CostPrice { get; set; }

    public decimal? SalePrice { get; set; }

    public string? Comment { get; set; }

    public virtual LunchCategory LunchCategory { get; set; } = null!;
}
