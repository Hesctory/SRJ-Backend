using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class DisabilityDegree
{
    public int Id { get; set; }

    public string? Degree { get; set; }

    public virtual ICollection<Disability> Disabilities { get; set; } = new List<Disability>();
}
