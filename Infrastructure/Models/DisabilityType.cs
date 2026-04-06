using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class DisabilityType
{
    public int Id { get; set; }

    public string Type { get; set; } = null!;

    public virtual ICollection<Disability> Disabilities { get; set; } = new List<Disability>();
}
