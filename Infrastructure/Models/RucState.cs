using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class RucState
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;

    public virtual ICollection<Institution> Institutions { get; set; } = new List<Institution>();
}
