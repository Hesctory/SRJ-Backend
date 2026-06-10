using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class LunchCategory
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;

    public virtual ICollection<Lunch> Lunches { get; set; } = new List<Lunch>();
}
